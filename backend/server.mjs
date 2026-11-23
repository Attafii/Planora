import { googleIntegration } from './google-integration.mjs';
import { accountAi } from './account-ai.mjs';
import http from 'node:http';
import { DatabaseSync } from 'node:sqlite';
import { randomBytes, randomUUID, createHash, scrypt, timingSafeEqual } from 'node:crypto';
import { promisify } from 'node:util';
import { mkdirSync, readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { privateAnalytics } from './analytics.mjs';
import { accountControls } from './account-controls.mjs';

const derive = promisify(scrypt);
const hash = value => createHash('sha256').update(value).digest('hex');
const now = () => new Date().toISOString();
class ApiError extends Error {
  constructor(status, code, message, fields = {}) { super(message); Object.assign(this, { status, code, fields }); }
}
function fail(message, fields = {}) { throw new ApiError(422, 'validation', message, fields); }
function zone(value) { if (typeof value !== 'string' || value.length > 100) fail('Choose a valid timezone.'); try { new Intl.DateTimeFormat('en', { timeZone: value }).format(); } catch { fail('Choose a valid timezone.', { timezone: 'Invalid IANA timezone.' }); } }
function email(value) {
  if (typeof value !== 'string' || value.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value.trim())) fail('Enter a valid email.', { email: 'Enter a valid email address.' });
  return value.trim().toLowerCase();
}
function name(value) { if (typeof value !== 'string' || value.trim().length < 2 || value.trim().length > 80) fail('Check your name.', { name: 'Use 2–80 characters.' }); return value.trim(); }
function password(value) { if (typeof value !== 'string' || value.length < 12 || value.length > 128) fail('Check your password.', { password: 'Use 12–128 characters.' }); return value; }
function allowed(body, keys) { if (Object.keys(body).some(key => !keys.includes(key))) fail('This request contains unsupported fields.'); }

function policyFile(path) { return path ? JSON.parse(readFileSync(path, 'utf8')) : null; }

export function createApi({ accountDb = null, database = resolve('backend/data/planify.sqlite'), sessionMs = 7 * 86400000, clock = Date.now, activitySource = null, workspace = null, proposeAgent = null, dataPolicy = policyFile(process.env.ACCOUNT_DATA_POLICY_FILE), aiPolicy = policyFile(process.env.INSIGHTS_AI_POLICY_FILE), origins = ['http://localhost:5173', 'http://127.0.0.1:5173'] } = {}) {
  if (!accountDb && database !== ':memory:') mkdirSync(dirname(database), { recursive: true });
  const db = accountDb || new DatabaseSync(database);
  let controls;
  const ready = (async () => {
  (await db.exec(`PRAGMA foreign_keys=ON; PRAGMA journal_mode=WAL;
    CREATE TABLE IF NOT EXISTS users (id TEXT PRIMARY KEY, name TEXT NOT NULL, email TEXT UNIQUE NOT NULL, email_verified_at TEXT, password_hash TEXT NOT NULL, salt TEXT NOT NULL, timezone TEXT NOT NULL, language TEXT NOT NULL DEFAULT 'en', created_at TEXT NOT NULL, updated_at TEXT NOT NULL);
    CREATE TABLE IF NOT EXISTS preferences (user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE, theme TEXT NOT NULL DEFAULT 'system', cloud_ai INTEGER NOT NULL DEFAULT 0, consent_version TEXT, consent_updated_at TEXT);
    CREATE TABLE IF NOT EXISTS sessions (token_hash TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE, expires_at INTEGER NOT NULL);
    CREATE INDEX IF NOT EXISTS session_expiry ON sessions(expires_at);
    CREATE TABLE IF NOT EXISTS personal_sync (
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      collection TEXT NOT NULL, revision INTEGER NOT NULL, snapshot TEXT NOT NULL,
      PRIMARY KEY (user_id, collection)
    );`));
  for (const column of ['google_sub','google_tokens']) {
    const columns=await db.prepare('PRAGMA table_info(users)').all();
    if(!columns.some(c=>c.name===column)) await db.exec(`ALTER TABLE users ADD COLUMN ${column} TEXT`);
  }
  await db.exec('CREATE UNIQUE INDEX IF NOT EXISTS google_identity ON users(google_sub)');
  controls = await accountControls({ db, clock, derivePassword, activitySource, dataPolicy, aiPolicy });
  })();
  const limits = new Map();
  // Password work has bounded concurrency as well as per-address rate limits.
  let activeHashes = 0;
  async function derivePassword(value, salt) {
    if (activeHashes >= 8) throw new ApiError(503, 'busy', 'Please try again in a moment.');
    activeHashes++;
    try { return await derive(value, salt, 64); } finally { activeHashes--; }
  }


  function rateLimit(req) {
    const key = req.socket.remoteAddress;
    const time = clock();
    for (const [k, v] of limits) if (v.until <= time) limits.delete(k);
    const item = limits.get(key) ?? { count: 0, until: time + 60000 };
    item.count++; limits.set(key, item);
    if (item.count > 20) throw new ApiError(429, 'rate_limited', 'Too many attempts. Try again in a minute.');
  }
  async function user(id) {
    const u = (await db.prepare('SELECT id,name,email,email_verified_at,timezone,language,created_at,updated_at FROM users WHERE id=?').get(id));
    const p = (await db.prepare('SELECT theme,cloud_ai,consent_version,consent_updated_at FROM preferences WHERE user_id=?').get(id));
    return { ...u, preferences: { ...p, cloud_ai: Boolean(p.cloud_ai) } };
  }
  async function identity(req) {
    const token = req.headers.authorization?.match(/^Bearer ([a-f0-9]{64})$/)?.[1];
    const s = token && (await db.prepare('SELECT id,user_id,expires_at,last_used_at FROM sessions WHERE token_hash=?').get(hash(token)));
    if (!s || s.expires_at <= clock()) {
      if (token) (await db.prepare('DELETE FROM sessions WHERE token_hash=?').run(hash(token)));
      throw new ApiError(401, 'unauthorized', 'Your session has ended. Please sign in again.');
    }
    if (!s.last_used_at || clock() - s.last_used_at >= 60000) (await db.prepare('UPDATE sessions SET last_used_at=? WHERE id=?').run(clock(), s.id));
    return { id: s.user_id, token, sessionId: s.id };
  }
  async function startSession(id, req) {
    (await db.prepare('DELETE FROM sessions WHERE expires_at<=?').run(clock()));
    const token = randomBytes(32).toString('hex');
    const expires = clock() + sessionMs;
    const agent = String(req.headers['user-agent'] ?? '');
    const platform = /Android/i.test(agent) ? 'Android' : /iPhone|iPad/i.test(agent) ? 'iOS' : /Windows/i.test(agent) ? 'Windows' : /Mac/i.test(agent) ? 'macOS' : /Linux/i.test(agent) ? 'Linux' : 'Device';
    const browser = agent.includes('Edg/') ? 'Edge' : agent.includes('Chrome/') ? 'Chrome' : agent.includes('Firefox/') ? 'Firefox' : agent.includes('Safari/') ? 'Safari' : 'Planify app';
    (await db.prepare('INSERT INTO sessions (token_hash,user_id,expires_at,id,created_at,last_used_at,device) VALUES (?,?,?,?,?,?,?)').run(hash(token), id, expires, randomUUID(), clock(), clock(), platform + ' · ' + browser));
    (await controls.notice(id, 'new_session'));
    return { token, expires_at: new Date(expires).toISOString(), user: (await user(id)) };
  }
  const handler = async (req, res) => {
    await ready;
    res.setHeader('Content-Type', 'application/json');
    res.setHeader('Cache-Control', 'no-store');
    res.setHeader('X-Content-Type-Options', 'nosniff');
    const origin = req.headers.origin;
    if (origin && origins.includes(origin)) { res.setHeader('Access-Control-Allow-Origin', origin); res.setHeader('Vary', 'Origin'); }
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization, Idempotency-Key');
    res.setHeader('Access-Control-Allow-Methods', 'GET,POST,PATCH,DELETE,OPTIONS');
    const send = (status, body) => { res.writeHead(status); res.end(JSON.stringify(body)); };
    try {
      if (origin && !origins.includes(origin)) throw new ApiError(403, 'origin', 'Origin is not allowed.');
      if (req.method === 'OPTIONS') { res.writeHead(204); res.end(); return; }
      (await controls.sweep());
      const url = new URL(req.url, 'http://localhost');
      const path = url.pathname;
      const syncCollection = path.match(/^\/users\/me\/sync\/(tasks|planning|focus|check-ins)$/)?.[1];
      if (path === '/health' && req.method === 'GET') return send(200, { status: 'ok' });
      if (workspace && /^\/(goals|tasks|projects|invitations|assistant|gamification|achievements|challenges|integrations)(\/|$)/.test(path)) {
        const profile = path.startsWith('/integrations/') ? null : (await user((await identity(req)).id));
        if (profile && path.startsWith('/assistant/')) profile.personalCollections = Object.fromEntries((await db.prepare('SELECT collection,revision,snapshot FROM personal_sync WHERE user_id=?').all(profile.id)).map(row => [row.collection, row]));
        return workspace(req, res, profile, profile && /^\/goals(?:\/|$)/.test(path)
          ? (await db.prepare("SELECT snapshot FROM personal_sync WHERE user_id=? AND collection='tasks'").get(profile.id))?.snapshot
          : undefined);
      }
      if (path.startsWith('/auth/') && req.method === 'POST') rateLimit(req);
      let body = {};
      if (['POST', 'PATCH', 'DELETE'].includes(req.method)) {
        if (!req.headers['content-type']?.startsWith('application/json')) throw new ApiError(415, 'content_type', 'Use application/json.');
        const maxBytes = syncCollection && req.method === 'POST' ? 2 * 1024 * 1024 : 16384;
        const chunks = [];
        let bytes = 0;
        for await (const chunk of req) {
          bytes += chunk.length;
          if (bytes > maxBytes) throw new ApiError(413, 'too_large', 'Request is too large.');
          chunks.push(chunk);
        }
        const raw = Buffer.concat(chunks).toString('utf8');
        try { body = JSON.parse(raw || '{}'); } catch { throw new ApiError(400, 'json', 'Invalid JSON.'); }
        if (!body || Array.isArray(body) || typeof body !== 'object') fail('Expected an object.');
      }
      if (await googleIntegration({db,identity,startSession,req,path,body,send,clock})) return;
      if (proposeAgent && req.method === 'POST' && ['/agents/tasks', '/agents/planning', '/agents/focus'].includes(path)) {
        const profile = (await user((await identity(req)).id));
        rateLimit(req);
        return send(200, await proposeAgent(path, body, profile));
      }
      if (path === '/auth/register' && req.method === 'POST') {
        allowed(body, ['name','email','password','timezone','language']);
        const n = name(body.name), e = email(body.email), pw = password(body.password);
        const timezone = body.timezone ?? 'Africa/Tunis'; zone(timezone);
        const language = body.language ?? 'en'; if (!['en', 'fr'].includes(language)) fail('Unsupported language.');
        const salt = randomBytes(16).toString('hex');
        const digest = (await derivePassword(pw, salt)).toString('hex');
        const id = randomUUID();
        (await db.exec('BEGIN'));
        try {
          (await db.prepare('INSERT INTO users (id,name,email,email_verified_at,password_hash,salt,timezone,language,created_at,updated_at) VALUES (?,?,?,?,?,?,?,?,?,?)').run(id,n,e,null,digest,salt,timezone,language,now(),now()));
          (await db.prepare('INSERT INTO preferences (user_id) VALUES (?)').run(id));
          (await db.exec('COMMIT'));
        } catch (error) { (await db.exec('ROLLBACK')); if ((error.code?.startsWith('ERR_SQLITE') || error.code === '23505') && (await db.prepare('SELECT id FROM users WHERE email=?').get(e))) throw new ApiError(409, 'email_taken', 'This email is already registered.', { email: 'Try signing in instead.' }); throw error; }
        return send(201, (await startSession(id, req)));
      }
      if (path === '/auth/login' && req.method === 'POST') {
        allowed(body, ['email','password']);
        const e = email(body.email);
        if (typeof body.password !== 'string' || body.password.length > 128) fail('Enter your password.');
        const u = (await db.prepare('SELECT * FROM users WHERE email=?').get(e));
        const candidate = await derivePassword(body.password, u?.salt ?? '00000000000000000000000000000000');
        if (!u || !timingSafeEqual(candidate, Buffer.from(u.password_hash, 'hex'))) throw new ApiError(401, 'invalid_credentials', 'Email or password is incorrect.');
        return send(200, (await startSession(u.id, req)));
      }
      if (['/auth/password-reset','/auth/password-reset/confirm'].includes(path) && req.method === 'POST') throw new ApiError(503, 'email_unavailable', 'Password recovery is not available yet. Email delivery has not been configured.');
      if (path === '/auth/logout' && req.method === 'POST') {
        const token = req.headers.authorization?.replace(/^Bearer /, '');
        if (token) (await db.prepare('DELETE FROM sessions WHERE token_hash=?').run(hash(token)));
        return send(200, { success: true });
      }
      if (!path.startsWith('/users/me')) throw new ApiError(404, 'not_found', 'Route not found.');
      const auth = (await identity(req));
      if (path === '/users/me/reauthenticate' && req.method === 'POST') rateLimit(req);
      if (path === '/users/me/sync' && req.method === 'GET') {
        const rows = (await db.prepare('SELECT collection,revision,snapshot FROM personal_sync WHERE user_id=?').all(auth.id));
        return send(200, { collections: Object.fromEntries(rows.map(
          ({ collection, revision, snapshot }) => [collection, { revision, snapshot }],
        )) });
      }
      if (syncCollection && req.method === 'POST') {
        allowed(body, ['revision', 'snapshot']);
        if (!Number.isSafeInteger(body.revision) || body.revision < 0 || typeof body.snapshot !== 'string') {
          fail('A valid revision and snapshot are required.');
        }
        let snapshot;
        try { snapshot = JSON.parse(body.snapshot); } catch { fail('Snapshot must be valid JSON.'); }
        if (!snapshot || typeof snapshot !== 'object' || Array.isArray(snapshot) !== (syncCollection === 'tasks')) {
          fail('Invalid personal data collection.');
        }
        if (syncCollection === 'focus' && !['sessions', 'reminders', 'inbox'].every(key => Array.isArray(snapshot[key]))) {
          fail('Invalid focus collection.');
        }
        if (syncCollection === 'check-ins' && Object.entries(snapshot).some(
          ([date, mood]) => !/^\d{4}-\d{2}-\d{2}$/.test(date) || typeof mood !== 'string' || mood.length > 100,
        )) fail('Invalid check-in collection.');

        (await db.exec('BEGIN IMMEDIATE'));
        let result;
        try {
          const current = (await db.prepare('SELECT revision,snapshot FROM personal_sync WHERE user_id=? AND collection=?')
            .get(auth.id, syncCollection)) ?? { revision: 0, snapshot: null };
          if (current.snapshot === body.snapshot) {
            result = { applied: true, ...current };
          } else if (current.revision !== body.revision) {
            result = { applied: false, ...current };
          } else {
            result = { applied: true, revision: current.revision + 1, snapshot: body.snapshot };
            (await db.prepare('INSERT INTO personal_sync(user_id,collection,revision,snapshot) VALUES (?,?,?,?) ' +
              'ON CONFLICT(user_id,collection) DO UPDATE SET revision=excluded.revision,snapshot=excluded.snapshot')
              .run(auth.id, syncCollection, result.revision, result.snapshot));
          }
          (await db.exec('COMMIT'));
        } catch (error) { (await db.exec('ROLLBACK')); throw error; }
        return send(200, result);
      }
      if (['/users/me/onboarding','/users/me/setup-assist','/users/me/sync-assist'].includes(path)) {
        if(path.endsWith('-assist')) rateLimit(req);
        const result=await accountAi({db,auth,path,method:req.method,body,profile:await user(auth.id),lockAccount:accountDb ? id=>accountDb.lockAccount(id) : null});
        if(path.endsWith('-assist') && !(await user(auth.id)).preferences.cloud_ai) throw new ApiError(403,'consent_required','Cloud AI was disabled. Nothing was applied.');
        return send(200,result);
      }
      const controlled = await controls.handle({ req, path, url, body, auth });
      if (controlled) return send(controlled.status, controlled.data);
      if (path === '/users/me' && req.method === 'GET') return send(200, (await user(auth.id)));
      if (path === '/users/me' && req.method === 'PATCH') {
        allowed(body, ['name']);
        (await db.prepare('UPDATE users SET name=?,updated_at=? WHERE id=?').run(name(body.name), now(), auth.id));
        (await controls.notice(auth.id, 'profile_updated'));
        return send(200, (await user(auth.id)));
      }
      if (path === '/users/me/preferences' && req.method === 'GET') return send(200, { timezone: (await user(auth.id)).timezone, language: (await user(auth.id)).language, ...(await user(auth.id)).preferences });
      if (path === '/users/me/preferences' && req.method === 'PATCH') {
        allowed(body, ['timezone','language','theme','cloud_ai','expected']);
        (await db.exec('BEGIN'));
        try {
        if (accountDb) await accountDb.lockAccount(auth.id);
        const u = (await user(auth.id));
        if ('expected' in body) {
          if (!body.expected || Array.isArray(body.expected) || typeof body.expected !== 'object') fail('Invalid original settings.');
          allowed(body.expected, ['timezone','language','theme']);
          const current = { timezone: u.timezone, language: u.language, theme: u.preferences.theme };
          for (const [key, previous] of Object.entries(body.expected)) {
            if (!(key in body) || typeof previous !== 'string') fail('Invalid original settings.');
            if (current[key] !== previous && current[key] !== body[key]) {
              throw new ApiError(409, 'preferences_changed', 'These preferences changed on another device. Reopen Preferences to review the current settings.');
            }
          }
        }
        const timezone = body.timezone ?? u.timezone; zone(timezone);
        const language = body.language ?? u.language, theme = body.theme ?? u.preferences.theme;
        if (!['en','fr'].includes(language)) fail('Unsupported language.', { language: 'Choose English or French.' });
        if (!['system','light','dark'].includes(theme)) fail('Unsupported theme.');
        if ('cloud_ai' in body && typeof body.cloud_ai !== 'boolean') fail('Cloud AI must be a boolean.');
        const consent = body.cloud_ai ?? u.preferences.cloud_ai;
          (await db.prepare('UPDATE users SET timezone=?,language=?,updated_at=? WHERE id=?').run(timezone,language,now(),auth.id));
          (await db.prepare('UPDATE preferences SET theme=?,cloud_ai=?,consent_version=?,consent_updated_at=? WHERE user_id=?').run(theme,consent ? 1 : 0,'cloud-context-v1', 'cloud_ai' in body ? now() : u.preferences.consent_updated_at,auth.id));
          if ('timezone' in body) (await db.prepare('UPDATE users SET timezone_reviewed=1 WHERE id=?').run(auth.id));
          (await controls.notice(auth.id, 'cloud_ai' in body ? 'privacy_updated' : 'preferences_updated'));
          (await db.exec('COMMIT'));
        } catch (error) { (await db.exec('ROLLBACK')); throw error; }
        return send(200, (await user(auth.id)));
      }
      if (path === '/users/me/analytics' && req.method === 'GET') {
        const from = url.searchParams.get('from'), to = url.searchParams.get('to');
        const start = Date.parse(from), end = Date.parse(to);
        if (!from?.endsWith('Z') || !to?.endsWith('Z') || !Number.isFinite(start) || !Number.isFinite(end) || end <= start || end - start > 366*86400000) fail('Choose a valid range up to one year.');
        return send(200, await privateAnalytics({ source: activitySource, userId: auth.id, from, to, timezone: (await user(auth.id)).timezone }));
      }
      if ((path === '/users/me/export' && req.method === 'POST') || (path === '/users/me' && req.method === 'DELETE')) throw new ApiError(503, 'policy_pending', 'Account export and deletion are awaiting the product retention and shared ownership policy. No data has been changed.');
      throw new ApiError(404, 'not_found', 'Route not found.');
    } catch (error) {
      if (!res.headersSent) send(error.status ?? 500, { error: { code: error.code ?? 'internal', message: error.status ? error.message : 'Something went wrong. Please try again.', fields: error.fields ?? {} } });
    }
  };
  let queue = Promise.resolve();
  const server = http.createServer((req, res) => {
    const run = () => handler(req, res);
    (accountDb ? accountDb.withConnection(run) : (queue = queue.then(run, run))).catch(() => {
      if (!res.headersSent) res.writeHead(503, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: { code: 'database_unavailable', message: 'Storage is temporarily unavailable. Your local work is preserved. Retry shortly.' } }));
    });
  });
  server.ready = ready;
  ready.catch(() => {});
  server.requestTimeout = 15000;
  server.headersTimeout = 10000;
  server.on('close', () => { void db.close(); });
  return server;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const server = createApi({ database: process.env.DATABASE_PATH ?? resolve('backend/data/planify.sqlite'), origins: (process.env.ALLOWED_ORIGINS ?? 'http://localhost:5173,http://127.0.0.1:5173').split(',') });
  server.listen(Number(process.env.PORT ?? 3000), process.env.HOST ?? '127.0.0.1', () => console.log('Planify account API is ready.'));
}

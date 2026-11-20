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

export function createApi({ database = resolve('backend/data/planify.sqlite'), sessionMs = 7 * 86400000, clock = Date.now, activitySource = null, dataPolicy = policyFile(process.env.ACCOUNT_DATA_POLICY_FILE), aiPolicy = policyFile(process.env.INSIGHTS_AI_POLICY_FILE), origins = ['http://localhost:5173', 'http://127.0.0.1:5173'] } = {}) {
  if (database !== ':memory:') mkdirSync(dirname(database), { recursive: true });
  const db = new DatabaseSync(database);
  db.exec(`PRAGMA foreign_keys=ON; PRAGMA journal_mode=WAL;
    CREATE TABLE IF NOT EXISTS users (id TEXT PRIMARY KEY, name TEXT NOT NULL, email TEXT UNIQUE NOT NULL, email_verified_at TEXT, password_hash TEXT NOT NULL, salt TEXT NOT NULL, timezone TEXT NOT NULL, language TEXT NOT NULL DEFAULT 'en', created_at TEXT NOT NULL, updated_at TEXT NOT NULL);
    CREATE TABLE IF NOT EXISTS preferences (user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE, theme TEXT NOT NULL DEFAULT 'system', cloud_ai INTEGER NOT NULL DEFAULT 0, consent_version TEXT, consent_updated_at TEXT);
    CREATE TABLE IF NOT EXISTS sessions (token_hash TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE, expires_at INTEGER NOT NULL);
    CREATE INDEX IF NOT EXISTS session_expiry ON sessions(expires_at);`);
  const limits = new Map();
  // Password work has bounded concurrency as well as per-address rate limits.
  let activeHashes = 0;
  async function derivePassword(value, salt) {
    if (activeHashes >= 8) throw new ApiError(503, 'busy', 'Please try again in a moment.');
    activeHashes++;
    try { return await derive(value, salt, 64); } finally { activeHashes--; }
  }
  const controls = accountControls({ db, clock, derivePassword, activitySource, dataPolicy, aiPolicy });
  const cleanup = setInterval(() => controls.sweep(), 1000);
  cleanup.unref();
  function rateLimit(req) {
    const key = req.socket.remoteAddress;
    const time = clock();
    for (const [k, v] of limits) if (v.until <= time) limits.delete(k);
    const item = limits.get(key) ?? { count: 0, until: time + 60000 };
    item.count++; limits.set(key, item);
    if (item.count > 20) throw new ApiError(429, 'rate_limited', 'Too many attempts. Try again in a minute.');
  }
  function user(id) {
    const u = db.prepare('SELECT id,name,email,email_verified_at,timezone,language,created_at,updated_at FROM users WHERE id=?').get(id);
    const p = db.prepare('SELECT theme,cloud_ai,consent_version,consent_updated_at FROM preferences WHERE user_id=?').get(id);
    return { ...u, preferences: { ...p, cloud_ai: Boolean(p.cloud_ai) } };
  }
  function identity(req) {
    const token = req.headers.authorization?.match(/^Bearer ([a-f0-9]{64})$/)?.[1];
    const s = token && db.prepare('SELECT id,user_id,expires_at,last_used_at FROM sessions WHERE token_hash=?').get(hash(token));
    if (!s || s.expires_at <= clock()) {
      if (token) db.prepare('DELETE FROM sessions WHERE token_hash=?').run(hash(token));
      throw new ApiError(401, 'unauthorized', 'Your session has ended. Please sign in again.');
    }
    if (!s.last_used_at || clock() - s.last_used_at >= 60000) db.prepare('UPDATE sessions SET last_used_at=? WHERE id=?').run(clock(), s.id);
    return { id: s.user_id, token, sessionId: s.id };
  }
  function startSession(id, req) {
    db.prepare('DELETE FROM sessions WHERE expires_at<=?').run(clock());
    const token = randomBytes(32).toString('hex');
    const expires = clock() + sessionMs;
    const agent = String(req.headers['user-agent'] ?? '');
    const platform = /Android/i.test(agent) ? 'Android' : /iPhone|iPad/i.test(agent) ? 'iOS' : /Windows/i.test(agent) ? 'Windows' : /Mac/i.test(agent) ? 'macOS' : /Linux/i.test(agent) ? 'Linux' : 'Device';
    const browser = agent.includes('Edg/') ? 'Edge' : agent.includes('Chrome/') ? 'Chrome' : agent.includes('Firefox/') ? 'Firefox' : agent.includes('Safari/') ? 'Safari' : 'Planify app';
    db.prepare('INSERT INTO sessions (token_hash,user_id,expires_at,id,created_at,last_used_at,device) VALUES (?,?,?,?,?,?,?)').run(hash(token), id, expires, randomUUID(), clock(), clock(), platform + ' · ' + browser);
    controls.notice(id, 'new_session');
    return { token, expires_at: new Date(expires).toISOString(), user: user(id) };
  }
  const server = http.createServer(async (req, res) => {
    res.setHeader('Content-Type', 'application/json');
    res.setHeader('Cache-Control', 'no-store');
    res.setHeader('X-Content-Type-Options', 'nosniff');
    const origin = req.headers.origin;
    if (origin && origins.includes(origin)) { res.setHeader('Access-Control-Allow-Origin', origin); res.setHeader('Vary', 'Origin'); }
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    res.setHeader('Access-Control-Allow-Methods', 'GET,POST,PATCH,DELETE,OPTIONS');
    const send = (status, body) => { res.writeHead(status); res.end(JSON.stringify(body)); };
    try {
      if (origin && !origins.includes(origin)) throw new ApiError(403, 'origin', 'Origin is not allowed.');
      if (req.method === 'OPTIONS') { res.writeHead(204); res.end(); return; }
      controls.sweep();
      const url = new URL(req.url, 'http://localhost');
      const path = url.pathname;
      if (path === '/health' && req.method === 'GET') return send(200, { status: 'ok' });
      if (path.startsWith('/auth/') && req.method === 'POST') rateLimit(req);
      let body = {};
      if (['POST', 'PATCH', 'DELETE'].includes(req.method)) {
        if (!req.headers['content-type']?.startsWith('application/json')) throw new ApiError(415, 'content_type', 'Use application/json.');
        let raw = '';
        for await (const chunk of req) { raw += chunk; if (Buffer.byteLength(raw) > 16384) throw new ApiError(413, 'too_large', 'Request is too large.'); }
        try { body = JSON.parse(raw || '{}'); } catch { throw new ApiError(400, 'json', 'Invalid JSON.'); }
        if (!body || Array.isArray(body) || typeof body !== 'object') fail('Expected an object.');
      }
      if (path === '/auth/register' && req.method === 'POST') {
        allowed(body, ['name','email','password','timezone','language']);
        const n = name(body.name), e = email(body.email), pw = password(body.password);
        const timezone = body.timezone ?? 'Africa/Tunis'; zone(timezone);
        const language = body.language ?? 'en'; if (!['en', 'fr'].includes(language)) fail('Unsupported language.');
        const salt = randomBytes(16).toString('hex');
        const digest = (await derivePassword(pw, salt)).toString('hex');
        const id = randomUUID();
        db.exec('BEGIN');
        try {
          db.prepare('INSERT INTO users (id,name,email,email_verified_at,password_hash,salt,timezone,language,created_at,updated_at) VALUES (?,?,?,?,?,?,?,?,?,?)').run(id,n,e,null,digest,salt,timezone,language,now(),now());
          db.prepare('INSERT INTO preferences (user_id) VALUES (?)').run(id);
          db.exec('COMMIT');
        } catch (error) { db.exec('ROLLBACK'); if (error.code?.startsWith('ERR_SQLITE') && db.prepare('SELECT id FROM users WHERE email=?').get(e)) throw new ApiError(409, 'email_taken', 'This email is already registered.', { email: 'Try signing in instead.' }); throw error; }
        return send(201, startSession(id, req));
      }
      if (path === '/auth/login' && req.method === 'POST') {
        allowed(body, ['email','password']);
        const e = email(body.email);
        if (typeof body.password !== 'string' || body.password.length > 128) fail('Enter your password.');
        const u = db.prepare('SELECT * FROM users WHERE email=?').get(e);
        const candidate = await derivePassword(body.password, u?.salt ?? '00000000000000000000000000000000');
        if (!u || !timingSafeEqual(candidate, Buffer.from(u.password_hash, 'hex'))) throw new ApiError(401, 'invalid_credentials', 'Email or password is incorrect.');
        return send(200, startSession(u.id, req));
      }
      if (['/auth/password-reset','/auth/password-reset/confirm'].includes(path) && req.method === 'POST') throw new ApiError(503, 'email_unavailable', 'Password recovery is not available yet. Email delivery has not been configured.');
      if (path === '/auth/logout' && req.method === 'POST') {
        const token = req.headers.authorization?.replace(/^Bearer /, '');
        if (token) db.prepare('DELETE FROM sessions WHERE token_hash=?').run(hash(token));
        return send(200, { success: true });
      }
      if (!path.startsWith('/users/me')) throw new ApiError(404, 'not_found', 'Route not found.');
      const auth = identity(req);
      if (path === '/users/me/reauthenticate' && req.method === 'POST') rateLimit(req);
      const controlled = await controls.handle({ req, path, url, body, auth });
      if (controlled) return send(controlled.status, controlled.data);
      if (path === '/users/me' && req.method === 'GET') return send(200, user(auth.id));
      if (path === '/users/me' && req.method === 'PATCH') {
        allowed(body, ['name']);
        db.prepare('UPDATE users SET name=?,updated_at=? WHERE id=?').run(name(body.name), now(), auth.id);
        controls.notice(auth.id, 'profile_updated');
        return send(200, user(auth.id));
      }
      if (path === '/users/me/preferences' && req.method === 'GET') return send(200, { timezone: user(auth.id).timezone, language: user(auth.id).language, ...user(auth.id).preferences });
      if (path === '/users/me/preferences' && req.method === 'PATCH') {
        allowed(body, ['timezone','language','theme','cloud_ai']);
        const u = user(auth.id);
        const timezone = body.timezone ?? u.timezone; zone(timezone);
        const language = body.language ?? u.language, theme = body.theme ?? u.preferences.theme;
        if (!['en','fr'].includes(language)) fail('Unsupported language.', { language: 'Choose English or French.' });
        if (!['system','light','dark'].includes(theme)) fail('Unsupported theme.');
        if ('cloud_ai' in body && typeof body.cloud_ai !== 'boolean') fail('Cloud AI must be a boolean.');
        const consent = body.cloud_ai ?? u.preferences.cloud_ai;
        db.exec('BEGIN');
        try {
          db.prepare('UPDATE users SET timezone=?,language=?,updated_at=? WHERE id=?').run(timezone,language,now(),auth.id);
          db.prepare('UPDATE preferences SET theme=?,cloud_ai=?,consent_version=?,consent_updated_at=? WHERE user_id=?').run(theme,consent ? 1 : 0,'cloud-context-v1', 'cloud_ai' in body ? now() : u.preferences.consent_updated_at,auth.id);
          if ('timezone' in body) db.prepare('UPDATE users SET timezone_reviewed=1 WHERE id=?').run(auth.id);
          controls.notice(auth.id, 'cloud_ai' in body ? 'privacy_updated' : 'preferences_updated');
          db.exec('COMMIT');
        } catch (error) { db.exec('ROLLBACK'); throw error; }
        return send(200, user(auth.id));
      }
      if (path === '/users/me/analytics' && req.method === 'GET') {
        const from = url.searchParams.get('from'), to = url.searchParams.get('to');
        const start = Date.parse(from), end = Date.parse(to);
        if (!from?.endsWith('Z') || !to?.endsWith('Z') || !Number.isFinite(start) || !Number.isFinite(end) || end <= start || end - start > 366*86400000) fail('Choose a valid range up to one year.');
        return send(200, await privateAnalytics({ source: activitySource, userId: auth.id, from, to, timezone: user(auth.id).timezone }));
      }
      if ((path === '/users/me/export' && req.method === 'POST') || (path === '/users/me' && req.method === 'DELETE')) throw new ApiError(503, 'policy_pending', 'Account export and deletion are awaiting the product retention and shared ownership policy. No data has been changed.');
      throw new ApiError(404, 'not_found', 'Route not found.');
    } catch (error) {
      if (!res.headersSent) send(error.status ?? 500, { error: { code: error.code ?? 'internal', message: error.status ? error.message : 'Something went wrong. Please try again.', fields: error.fields ?? {} } });
    }
  });
  server.requestTimeout = 15000;
  server.headersTimeout = 10000;
  server.on('close', () => { clearInterval(cleanup); db.close(); });
  return server;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const server = createApi({ database: process.env.DATABASE_PATH ?? resolve('backend/data/planify.sqlite'), origins: (process.env.ALLOWED_ORIGINS ?? 'http://localhost:5173,http://127.0.0.1:5173').split(',') });
  server.listen(Number(process.env.PORT ?? 3000), process.env.HOST ?? '127.0.0.1', () => console.log('Planify account API is ready.'));
}

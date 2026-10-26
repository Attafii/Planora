import { randomUUID, timingSafeEqual, createHash } from 'node:crypto';
import { privateAnalytics } from './analytics.mjs';

export const CONTEXT_VERSION = 'personal-insights-v1';
const error = (status, code, message) => Object.assign(new Error(message), { status, code });

// Migrations preserve existing accounts and token hashes. No other feature tables are read.
export function accountControls({ db, clock, derivePassword, activitySource, dataPolicy, aiPolicy }) {
  const addColumn = (table, name, definition) => {
    if (!db.prepare(`PRAGMA table_info(${table})`).all().some(c => c.name === name)) db.exec(`ALTER TABLE ${table} ADD COLUMN ${name} ${definition}`);
  };
  for (const [key, type] of Object.entries({ id: 'TEXT', created_at: 'INTEGER', last_used_at: 'INTEGER', device: 'TEXT', reauthenticated_at: 'INTEGER' })) addColumn('sessions', key, type);
  addColumn('users', 'timezone_reviewed', 'INTEGER NOT NULL DEFAULT 0');
  db.exec(`CREATE UNIQUE INDEX IF NOT EXISTS session_public_id ON sessions(id);
    CREATE TABLE IF NOT EXISTS account_notices (id TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE, type TEXT NOT NULL, created_at INTEGER NOT NULL, read_at INTEGER);
    CREATE TABLE IF NOT EXISTS insight_consent (user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE, enabled INTEGER NOT NULL DEFAULT 0, version TEXT NOT NULL, updated_at INTEGER NOT NULL, withdrawn_at INTEGER);
    CREATE TABLE IF NOT EXISTS consent_events (id TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE, enabled INTEGER NOT NULL, version TEXT NOT NULL, created_at INTEGER NOT NULL);
    CREATE TABLE IF NOT EXISTS account_exports (id TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE, created_at INTEGER NOT NULL, expires_at INTEGER NOT NULL, consumed_at INTEGER, payload TEXT NOT NULL);
    CREATE TABLE IF NOT EXISTS account_deletions (user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE, id TEXT NOT NULL, requested_at INTEGER NOT NULL, execute_at INTEGER NOT NULL, policy_version TEXT NOT NULL);`);
  for (const s of db.prepare('SELECT token_hash FROM sessions WHERE id IS NULL').all()) db.prepare('UPDATE sessions SET id=?,device=? WHERE token_hash=?').run(randomUUID(), 'Previously signed-in device', s.token_hash);
  // Policy is operator-supplied, never accepted from an HTTP caller.
  const dataReady = Boolean(dataPolicy?.approved === true && dataPolicy.accountOnly === true && dataPolicy.sharedRecords === 'none' && typeof dataPolicy.version === 'string' && dataPolicy.version.trim().length > 0 && typeof dataPolicy.retentionNotice === 'string' && dataPolicy.retentionNotice.trim().length > 0 && typeof dataPolicy.backupNotice === 'string' && dataPolicy.backupNotice.trim().length > 0 && Number.isInteger(dataPolicy.recoverySeconds) && dataPolicy.recoverySeconds >= 60 && Number.isInteger(dataPolicy.exportTtlSeconds) && dataPolicy.exportTtlSeconds >= 60 && dataPolicy.exportTtlSeconds <= 86400);
  const aiReady = Boolean(aiPolicy?.approved === true && typeof aiPolicy.provider === 'string' && aiPolicy.provider.trim() && typeof aiPolicy.retentionNotice === 'string' && aiPolicy.retentionNotice.trim());
  const contextVersion = aiReady ? CONTEXT_VERSION + ':' + createHash('sha256').update(JSON.stringify([aiPolicy.provider, aiPolicy.retentionNotice])).digest('hex').slice(0, 16) : CONTEXT_VERSION;
  const iso = value => value == null ? null : new Date(value).toISOString();
  const notice = (id, type) => db.prepare('INSERT INTO account_notices VALUES (?,?,?,?,NULL)').run(randomUUID(), id, type, clock());
  const sessions = auth => ({ sessions: db.prepare('SELECT id,created_at,last_used_at,expires_at,device FROM sessions WHERE user_id=? AND expires_at>? ORDER BY last_used_at DESC').all(auth.id, clock()).map(s => ({ ...s, current: s.id === auth.sessionId, created_at: iso(s.created_at), last_used_at: iso(s.last_used_at), expires_at: iso(s.expires_at) })) });
  const consent = id => {
    const c = db.prepare('SELECT enabled,version,updated_at,withdrawn_at FROM insight_consent WHERE user_id=?').get(id);
    return { enabled: Boolean(c?.enabled && c.version === contextVersion), version: contextVersion, updated_at: iso(c?.updated_at), withdrawn_at: iso(c?.withdrawn_at) };
  };
  const cloudAllowed = id => db.prepare('SELECT cloud_ai FROM preferences WHERE user_id=?').get(id)?.cloud_ai === 1;
  function sweep() {
    const time = clock();
    db.prepare('DELETE FROM account_exports WHERE expires_at<=?').run(time);
    // Policy must remain approved across restarts before a pending deletion executes.
    if (dataReady) for (const r of db.prepare('SELECT user_id FROM account_deletions WHERE execute_at<=? AND policy_version=?').all(time, dataPolicy.version)) {
      db.prepare('DELETE FROM users WHERE id=?').run(r.user_id);
    }
  }
  function recent(auth) {
    const s = db.prepare('SELECT reauthenticated_at FROM sessions WHERE id=? AND user_id=?').get(auth.sessionId, auth.id);
    if (!s?.reauthenticated_at || clock() - s.reauthenticated_at >= 5 * 60000) throw error(403, 'reauthentication_required', 'Confirm your password before continuing.');
  }
  function range(url) {
    const from = url.searchParams.get('from'), to = url.searchParams.get('to');
    if (!from?.endsWith('Z') || !to?.endsWith('Z') || !Number.isFinite(Date.parse(from)) || !Number.isFinite(Date.parse(to)) || Date.parse(to) <= Date.parse(from) || Date.parse(to) - Date.parse(from) > 366 * 86400000) throw error(422, 'validation', 'Choose a valid range up to one year.');
    return { from, to };
  }
  async function preview(id, url) {
    const { from, to } = range(url);
    const u = db.prepare('SELECT timezone FROM users WHERE id=?').get(id);
    const a = await privateAnalytics({ source: activitySource, userId: id, from, to, timezone: u.timezone });
    // Explicit fields only: never serialize the account, activity records, or preferences.
    const context = { range: { from, to, end_exclusive: true }, timezone: u.timezone, status: a.status, tasks_completed: a.tasks_completed, goals_completed: a.goals_completed };
    return { version: contextVersion, provider_available: aiReady, provider: aiReady ? aiPolicy.provider : null, retention_notice: aiReady ? aiPolicy.retentionNotice : null, cloud_ai_enabled: cloudAllowed(id), consent: consent(id), context, excluded: ['name', 'email', 'password', 'session credentials', 'raw activity records', 'unrelated preferences'], transmitted: false };
  }
  const blocked = () => { if (!dataReady) throw error(503, 'policy_pending', 'Export and deletion await approved retention, recovery and shared-record rules. No data has been changed.'); };
  const clean = (body, keys) => { if (Object.keys(body).some(k => !keys.includes(k))) throw error(422, 'validation', 'Unsupported fields.'); };
  async function handle({ req, path, url, body, auth }) {
    const method = req.method;
    const ok = data => ({ status: 200, data });
    if (path === '/users/me/reauthenticate' && method === 'POST') {
      clean(body, ['password']);
      if (typeof body.password !== 'string' || body.password.length > 128) throw error(422, 'validation', 'Enter your password.');
      const u = db.prepare('SELECT salt,password_hash FROM users WHERE id=?').get(auth.id);
      const candidate = await derivePassword(body.password, u.salt);
      // Confirm that the session still exists after asynchronous password work.
      if (!timingSafeEqual(candidate, Buffer.from(u.password_hash, 'hex'))) throw error(403, 'incorrect_password', 'Password is incorrect.');
      const result = db.prepare('UPDATE sessions SET reauthenticated_at=? WHERE id=? AND user_id=? AND expires_at>?').run(clock(), auth.sessionId, auth.id, clock());
      if (!result.changes) throw error(401, 'unauthorized', 'Your session has ended.');
      return ok({ confirmed: true, expires_at: iso(clock() + 300000) });
    }
    if (path === '/users/me/sessions' && method === 'GET') return ok(sessions(auth));
    if (path === '/users/me/sessions' && method === 'DELETE') {
      clean(body, []); recent(auth);
      const result = db.prepare('DELETE FROM sessions WHERE user_id=? AND id<>?').run(auth.id, auth.sessionId);
      if (result.changes) notice(auth.id, 'other_sessions_revoked');
      return ok({ success: true, revoked: Number(result.changes) });
    }
    if (path.startsWith('/users/me/sessions/') && method === 'DELETE') {
      clean(body, []);
      const id = path.slice('/users/me/sessions/'.length);
      const result = db.prepare('DELETE FROM sessions WHERE id=? AND user_id=?').run(id, auth.id);
      if (result.changes) notice(auth.id, 'session_revoked');
      return ok({ success: true, signed_out: id === auth.sessionId });
    }
    if (path === '/users/me/notices' && method === 'GET') return ok({ notices: db.prepare('SELECT id,type,created_at,read_at FROM account_notices WHERE user_id=? ORDER BY created_at DESC,rowid DESC LIMIT 100').all(auth.id).map(n => ({ ...n, created_at: iso(n.created_at), read_at: iso(n.read_at) })) });
    if (path === '/users/me/notices/read' && method === 'POST') {
      clean(body, []); db.prepare('UPDATE account_notices SET read_at=? WHERE user_id=? AND read_at IS NULL').run(clock(), auth.id); return ok({ success: true });
    }
    if (path === '/users/me/profile-quality' && method === 'GET') {
      const u = db.prepare('SELECT name,timezone,language,timezone_reviewed FROM users WHERE id=?').get(auth.id);
      const p = db.prepare('SELECT theme FROM preferences WHERE user_id=?').get(auth.id);
      let validZone = Boolean(u.timezone);
      try { if (validZone) new Intl.DateTimeFormat('en', { timeZone: u.timezone }).format(); } catch { validZone = false; }
      const checks = [
        { field: 'name', status: u.name?.trim().length >= 2 ? 'ready' : 'missing' },
        { field: 'timezone', status: !u.timezone ? 'missing' : !validZone ? 'unsupported' : !u.timezone_reviewed ? 'review' : 'ready' },
        { field: 'language', status: ['en', 'fr'].includes(u.language) ? 'ready' : 'unsupported' },
        { field: 'theme', status: ['system', 'light', 'dark'].includes(p.theme) ? 'ready' : 'unsupported' },
      ];
      return ok({ checks, ready: checks.every(c => c.status === 'ready'), timezone: u.timezone });
    }
    if (path === '/users/me/privacy/preview' && method === 'GET') return ok(await preview(auth.id, url));
    if (path === '/users/me/privacy/consent' && method === 'PATCH') {
      clean(body, ['enabled', 'version']);
      if (typeof body.enabled !== 'boolean' || body.version !== contextVersion) throw error(422, 'validation', 'Review the current context version before choosing.');
      if (body.enabled && !aiReady) throw error(503, 'provider_pending', 'AI summaries are not connected. No data has been sent.');
      if (body.enabled && !cloudAllowed(auth.id)) throw error(403, 'cloud_ai_disabled', 'Enable your Cloud AI preference before allowing personal insights context.');
      db.exec('BEGIN');
      try {
        db.prepare('INSERT INTO insight_consent VALUES (?,?,?,?,?) ON CONFLICT(user_id) DO UPDATE SET enabled=excluded.enabled,version=excluded.version,updated_at=excluded.updated_at,withdrawn_at=excluded.withdrawn_at').run(auth.id, Number(body.enabled), contextVersion, clock(), body.enabled ? null : clock());
        db.prepare('INSERT INTO consent_events VALUES (?,?,?,?,?)').run(randomUUID(), auth.id, Number(body.enabled), contextVersion, clock());
        notice(auth.id, body.enabled ? 'insights_consent_enabled' : 'insights_consent_withdrawn');
        db.exec('COMMIT');
      } catch (e) { db.exec('ROLLBACK'); throw e; }
      return ok(consent(auth.id));
    }
    if (path === '/users/me/privacy/context' && method === 'POST') {
      clean(body, []);
      if (!aiReady || !cloudAllowed(auth.id) || !consent(auth.id).enabled) throw error(403, 'consent_required', 'Current, explicit consent and Cloud AI permission are required.');
      const result = await preview(auth.id, url);
      if (!cloudAllowed(auth.id) || !consent(auth.id).enabled || !db.prepare('SELECT id FROM sessions WHERE id=? AND expires_at>?').get(auth.sessionId, clock())) throw error(403, 'consent_required', 'Consent or session changed. Review your choices again.');
      return ok({ version: contextVersion, context: result.context, transmitted: false });
    }
    if (path === '/users/me/data-tools' && method === 'GET') {
      const deletion = db.prepare('SELECT id,requested_at,execute_at,policy_version FROM account_deletions WHERE user_id=?').get(auth.id);
      const publicPolicy = dataReady ? { version: dataPolicy.version, retentionNotice: dataPolicy.retentionNotice, backupNotice: dataPolicy.backupNotice, recoverySeconds: dataPolicy.recoverySeconds } : null;
      return ok({ available: dataReady, policy: publicPolicy, reason: dataReady ? null : 'policy_pending', deletion: deletion ? { ...deletion, requested_at: iso(deletion.requested_at), execute_at: iso(deletion.execute_at), status: dataReady && deletion.policy_version === dataPolicy.version ? 'scheduled' : 'paused' } : null, exports: db.prepare('SELECT id,created_at,expires_at,consumed_at FROM account_exports WHERE user_id=? ORDER BY created_at DESC LIMIT 10').all(auth.id).map(e => ({ ...e, created_at: iso(e.created_at), expires_at: iso(e.expires_at), consumed_at: iso(e.consumed_at) })) });
    }
    if (path === '/users/me/deletion' && method === 'GET') {
      const r = db.prepare('SELECT id,execute_at,policy_version FROM account_deletions WHERE user_id=?').get(auth.id);
      return ok({ deletion: r ? { id: r.id, execute_at: iso(r.execute_at), status: dataReady && r.policy_version === dataPolicy.version ? 'scheduled' : 'paused' } : null });
    }
    if (path.startsWith('/users/me/export/') && method === 'GET') {
      const r = db.prepare('SELECT id,expires_at,consumed_at FROM account_exports WHERE id=? AND user_id=?').get(path.slice('/users/me/export/'.length), auth.id);
      if (!r) throw error(404, 'not_found', 'This export is unavailable or has expired.');
      return ok({ id: r.id, expires_at: iso(r.expires_at), status: r.consumed_at ? 'consumed' : 'ready' });
    }
    if (path === '/users/me/export' && method === 'POST') {
      blocked(); clean(body, []); recent(auth);
      const existing = db.prepare('SELECT id,expires_at FROM account_exports WHERE user_id=? AND consumed_at IS NULL AND expires_at>?').get(auth.id, clock());
      if (existing) return ok({ id: existing.id, status: 'ready', expires_at: iso(existing.expires_at) });
      // One bounded snapshot per account; account-only scope deliberately excludes other modules.
      const profile = db.prepare('SELECT id,name,email,email_verified_at,timezone,language,created_at,updated_at FROM users WHERE id=?').get(auth.id);
      const preferences = db.prepare('SELECT theme,cloud_ai,consent_version,consent_updated_at FROM preferences WHERE user_id=?').get(auth.id);
      const payload = { format_version: 'planify-account-v1', exported_at: iso(clock()), policy_version: dataPolicy.version, profile, preferences, sessions: sessions(auth).sessions, notices: db.prepare('SELECT type,created_at,read_at FROM account_notices WHERE user_id=?').all(auth.id), insight_consent: consent(auth.id), consent_history: db.prepare('SELECT enabled,version,created_at FROM consent_events WHERE user_id=?').all(auth.id) };
      const id = randomUUID(), expires = clock() + dataPolicy.exportTtlSeconds * 1000;
      db.exec('BEGIN');
      try {
        db.prepare('DELETE FROM account_exports WHERE user_id=?').run(auth.id);
        db.prepare('INSERT INTO account_exports VALUES (?,?,?,?,NULL,?)').run(id, auth.id, clock(), expires, JSON.stringify(payload));
        notice(auth.id, 'export_created'); db.exec('COMMIT');
      } catch (e) { db.exec('ROLLBACK'); throw e; }
      return { status: 201, data: { id, status: 'ready', expires_at: iso(expires) } };
    }
    if (path.startsWith('/users/me/export/') && method === 'POST') {
      blocked(); recent(auth); clean(body, []);
      const id = path.slice('/users/me/export/'.length);
      const row = db.prepare('SELECT payload FROM account_exports WHERE id=? AND user_id=? AND expires_at>? AND consumed_at IS NULL').get(id, auth.id, clock());
      if (!row) throw error(404, 'not_found', 'This export is unavailable or has expired. Create a new export.');
      db.prepare("UPDATE account_exports SET consumed_at=?,payload='{}' WHERE id=?").run(clock(), id);
      return ok({ filename: 'planify-account.json', content: JSON.parse(row.payload) });
    }
    if ((path === '/users/me/deletion' && method === 'POST') || (path === '/users/me' && method === 'DELETE')) {
      blocked(); clean(body, ['confirmation']); recent(auth);
      if (body.confirmation !== 'DELETE') throw error(422, 'validation', 'Type DELETE to confirm.');
      const existing = db.prepare('SELECT id,execute_at FROM account_deletions WHERE user_id=?').get(auth.id);
      if (existing) return ok({ id: existing.id, execute_at: iso(existing.execute_at), status: 'scheduled' });
      const id = randomUUID(), execute = clock() + dataPolicy.recoverySeconds * 1000;
      db.prepare('INSERT INTO account_deletions VALUES (?,?,?,?,?)').run(auth.id, id, clock(), execute, dataPolicy.version);
      notice(auth.id, 'deletion_scheduled'); return { status: 202, data: { id, execute_at: iso(execute), status: 'scheduled' } };
    }
    if (path === '/users/me/deletion' && method === 'DELETE') {
      clean(body, []); recent(auth);
      const result = db.prepare('DELETE FROM account_deletions WHERE user_id=?').run(auth.id);
      if (result.changes) notice(auth.id, 'deletion_cancelled');
      return ok({ cancelled: Boolean(result.changes) });
    }
    return null;
  }
  return { handle, notice, sweep };
}

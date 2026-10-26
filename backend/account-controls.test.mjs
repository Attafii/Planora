import { test } from 'node:test';
import assert from 'node:assert/strict';
import { once } from 'node:events';
import { DatabaseSync } from 'node:sqlite';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createApi } from './server.mjs';

const password = 'An example private password';
const range = '?from=2026-10-01T00:00:00Z&to=2026-10-20T00:00:00Z';
const policy = { approved: true, accountOnly: true, sharedRecords: 'none', version: 'test-policy-v1', retentionNotice: 'Test fixture: remove account records after recovery.', backupNotice: 'Test fixture has no backups.', recoverySeconds: 60, exportTtlSeconds: 60 };
const aiPolicy = { approved: true, provider: 'Test-only provider', retentionNotice: 'Test metadata. No remote calls.' };
async function fixture(t, options = {}) {
  const server = createApi({ database: ':memory:', ...options });
  server.listen(0, '127.0.0.1'); await once(server, 'listening');
  t.after(() => new Promise(resolve => server.close(resolve)));
  const call = async (path, method = 'GET', body, token) => {
    const r = await fetch(`http://127.0.0.1:${server.address().port}${path}`, { method, headers: { 'content-type': 'application/json', ...(token ? { authorization: `Bearer ${token}` } : {}) }, ...(body === undefined ? {} : { body: JSON.stringify(body) }) });
    return { status: r.status, data: await r.json() };
  };
  const register = async email => (await call('/auth/register', 'POST', { name: 'Eya', email, password })).data;
  const reauth = token => call('/users/me/reauthenticate', 'POST', { password }, token);
  return { call, register, reauth };
}

test('session metadata, ownership, idempotent revoke and revoke-all recent authentication', async t => {
  let clock = Date.now(); const f = await fixture(t, { clock: () => clock });
  const a = await f.register('eya@example.com'), b = await f.register('other@example.com');
  const a2 = (await f.call('/auth/login', 'POST', { email: a.user.email, password })).data;
  const list = (await f.call('/users/me/sessions', 'GET', undefined, a.token)).data.sessions;
  assert.equal(list.length, 2); assert.equal(list.filter(s => s.current).length, 1);
  assert.equal(JSON.stringify(list).includes(a.token), false); assert.equal(JSON.stringify(list).includes('token_hash'), false);
  const otherId = (await f.call('/users/me/sessions', 'GET', undefined, b.token)).data.sessions[0].id;
  assert.equal((await f.call('/users/me/sessions/' + otherId, 'DELETE', {}, a.token)).status, 200);
  assert.equal((await f.call('/users/me', 'GET', undefined, b.token)).status, 200);
  assert.equal((await f.call('/users/me/sessions', 'DELETE', {}, a.token)).status, 403);
  assert.equal((await f.call('/users/me/reauthenticate', 'POST', { password: 'wrong' }, a.token)).status, 403);
  await f.reauth(a.token);
  assert.equal((await f.call('/users/me/sessions', 'DELETE', {}, a.token)).data.revoked, 1);
  assert.equal((await f.call('/users/me', 'GET', undefined, a2.token)).status, 401);
  assert.equal((await f.call('/users/me', 'GET', undefined, a.token)).status, 200);
  clock += 300001;
  assert.equal((await f.call('/users/me/sessions', 'DELETE', {}, a.token)).status, 403);
});

test('quality flags defaults and clears review after timezone confirmation; notices persist and isolate', async t => {
  const f = await fixture(t); const a = await f.register('eya@example.com'), b = await f.register('other@example.com');
  const before = (await f.call('/users/me/profile-quality', 'GET', undefined, a.token)).data;
  assert.equal(before.checks.find(c => c.field === 'timezone').status, 'review');
  await f.call('/users/me/preferences', 'PATCH', { timezone: 'Europe/Paris' }, a.token);
  assert.equal((await f.call('/users/me/profile-quality', 'GET', undefined, a.token)).data.ready, true);
  await f.call('/users/me', 'PATCH', { name: 'Eya Updated' }, a.token);
  const notices = (await f.call('/users/me/notices', 'GET', undefined, a.token)).data.notices;
  assert.ok(notices.some(n => n.type === 'profile_updated'));
  assert.equal((await f.call('/users/me/notices', 'GET', undefined, b.token)).data.notices.some(n => n.type === 'profile_updated'), false);
  await f.call('/users/me/notices/read', 'POST', {}, a.token);
  assert.ok((await f.call('/users/me/notices', 'GET', undefined, a.token)).data.notices.every(n => n.read_at));
});

test('context is an exact allowlist, private, opt-in gated, and withdrawal blocks context release', async t => {
  const f = await fixture(t, { aiPolicy, activitySource: async ({ userId }) => ({ tasks: [{ id: 'one', owner_id: userId, accessible: true, completed_at: '2026-10-02T12:00:00Z' }], goals: [] }) });
  const a = await f.register('eya@example.com');
  const preview = (await f.call('/users/me/privacy/preview' + range, 'GET', undefined, a.token)).data;
  assert.equal(preview.transmitted, false); assert.equal(preview.consent.enabled, false);
  assert.deepEqual(Object.keys(preview.context).sort(), ['goals_completed', 'range', 'status', 'tasks_completed', 'timezone']);
  assert.equal(preview.context.tasks_completed, 1); assert.equal(preview.context.goals_completed, 0);
  assert.equal(JSON.stringify(preview.context).includes(a.user.email), false);
  assert.equal((await f.call('/users/me/privacy/context' + range, 'POST', {}, a.token)).status, 403);
  assert.equal((await f.call('/users/me/privacy/consent', 'PATCH', { enabled: true, version: 'old' }, a.token)).status, 422);
  assert.equal((await f.call('/users/me/privacy/consent', 'PATCH', { enabled: true, version: preview.version }, a.token)).status, 403);
  await f.call('/users/me/preferences', 'PATCH', { cloud_ai: true }, a.token);
  await f.call('/users/me/privacy/consent', 'PATCH', { enabled: true, version: preview.version }, a.token);
  assert.equal((await f.call('/users/me/privacy/context' + range, 'POST', {}, a.token)).status, 200);
  await f.call('/users/me/preferences', 'PATCH', { cloud_ai: false }, a.token);
  assert.equal((await f.call('/users/me/privacy/context' + range, 'POST', {}, a.token)).status, 403);
  await f.call('/users/me/preferences', 'PATCH', { cloud_ai: true }, a.token);
  await f.call('/users/me/privacy/consent', 'PATCH', { enabled: false, version: preview.version }, a.token);
  assert.equal((await f.call('/users/me/privacy/context' + range, 'POST', {}, a.token)).status, 403);
  assert.equal((await f.call('/users/me/privacy/preview' + range)).status, 401);
});

test('unconfigured policies fail closed, preview remains available, and withdrawal is always allowed', async t => {
  const f = await fixture(t); const { token } = await f.register('eya@example.com');
  assert.equal((await f.call('/users/me/data-tools', 'GET', undefined, token)).data.available, false);
  for (const [path, method, body] of [['/users/me/export', 'POST', {}], ['/users/me/deletion', 'POST', { confirmation: 'DELETE' }], ['/users/me', 'DELETE', {}]]) assert.equal((await f.call(path, method, body, token)).status, 503);
  const preview = (await f.call('/users/me/privacy/preview' + range, 'GET', undefined, token)).data;
  assert.equal(preview.context.tasks_completed, null); assert.equal(preview.provider_available, false);
  assert.equal((await f.call('/users/me/privacy/consent', 'PATCH', { enabled: true, version: preview.version }, token)).status, 503);
  assert.equal((await f.call('/users/me/privacy/consent', 'PATCH', { enabled: false, version: preview.version }, token)).status, 200);
});

test('private exports require recent auth, omit credentials, expire and can only be consumed once', async t => {
  let clock = Date.now(); const f = await fixture(t, { dataPolicy: policy, clock: () => clock });
  const a = await f.register('eya@example.com'), b = await f.register('other@example.com');
  assert.equal((await f.call('/users/me/export', 'POST', {}, a.token)).status, 403);
  await f.reauth(a.token); await f.reauth(b.token);
  const created = await f.call('/users/me/export', 'POST', {}, a.token); assert.equal(created.status, 201);
  assert.equal((await f.call('/users/me/export/' + created.data.id, 'POST', {}, b.token)).status, 404);
  const downloaded = await f.call('/users/me/export/' + created.data.id, 'POST', {}, a.token);
  assert.equal(downloaded.status, 200); assert.equal(downloaded.data.content.profile.email, a.user.email);
  const json = JSON.stringify(downloaded.data); for (const secret of [a.token, password, 'password_hash', 'token_hash', b.user.email]) assert.equal(json.includes(secret), false);
  assert.equal((await f.call('/users/me/export/' + created.data.id, 'POST', {}, a.token)).status, 404);
  const expires = await f.call('/users/me/export', 'POST', {}, a.token); clock += 60001;
  assert.equal((await f.call('/users/me/export/' + expires.data.id, 'POST', {}, a.token)).status, 404);
});

test('deletion supports explicit confirmation, cancellation, recovery expiry, and isolates other accounts', async t => {
  let clock = Date.now(); const f = await fixture(t, { dataPolicy: policy, clock: () => clock });
  const a = await f.register('eya@example.com'), b = await f.register('other@example.com');
  await f.reauth(a.token);
  assert.equal((await f.call('/users/me/deletion', 'POST', {}, a.token)).status, 422);
  const created = await f.call('/users/me/deletion', 'POST', { confirmation: 'DELETE' }, a.token); assert.equal(created.status, 202);
  const retry = await f.call('/users/me/deletion', 'POST', { confirmation: 'DELETE' }, a.token); assert.equal(retry.data.id, created.data.id);
  assert.equal((await f.call('/users/me', 'GET', undefined, a.token)).status, 200);
  assert.equal((await f.call('/users/me/deletion', 'DELETE', {}, a.token)).data.cancelled, true);
  clock += 60001; assert.equal((await f.call('/users/me', 'GET', undefined, a.token)).status, 200);
  await f.call('/users/me/deletion', 'POST', { confirmation: 'DELETE' }, a.token); clock += 60001;
  assert.equal((await f.call('/users/me', 'GET', undefined, a.token)).status, 401);
  assert.equal((await f.call('/users/me', 'GET', undefined, b.token)).status, 200);
  assert.equal((await f.call('/auth/login', 'POST', { email: a.user.email, password })).status, 401);
});

test('existing SQLite session rows migrate without exposing or invalidating credentials', async t => {
  const folder = mkdtempSync(join(tmpdir(), 'planify-migration-'));
  const file = join(folder, 'account.sqlite');
  // Recreate the previous session table shape around a real persisted token.
  const first = createApi({ database: file }); first.listen(0, '127.0.0.1'); await once(first, 'listening');
  const response = await fetch(`http://127.0.0.1:${first.address().port}/auth/register`, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ name: 'Eya', email: 'eya@example.com', password }) });
  const account = await response.json(); await new Promise(resolve => first.close(resolve));
  const db = new DatabaseSync(file); db.exec('DROP INDEX session_public_id; ALTER TABLE sessions RENAME TO old_sessions; CREATE TABLE sessions (token_hash TEXT PRIMARY KEY,user_id TEXT REFERENCES users(id) ON DELETE CASCADE,expires_at INTEGER NOT NULL); INSERT INTO sessions SELECT token_hash,user_id,expires_at FROM old_sessions; DROP TABLE old_sessions;'); db.close();
  const f = await fixture(t, { database: file });
  t.after(() => rmSync(folder, { recursive: true }));
  const restored = await f.call('/users/me/sessions', 'GET', undefined, account.token);
  assert.equal(restored.status, 200); assert.equal(restored.data.sessions[0].current, true); assert.equal(restored.data.sessions[0].created_at, null);
});

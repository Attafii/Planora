import { test } from 'node:test';
import assert from 'node:assert/strict';
import pg from 'pg';
import { randomUUID } from 'node:crypto';
import { openAccountDatabase } from '../src/account_database.mjs';
import { createApi } from '../server.mjs';

test('Neon account restore, isolation, conflict detection and retry across API instances', { skip: !process.env.RUN_NEON_TESTS }, async () => {
  const schema = 'qa_' + randomUUID().replaceAll('-', '');
  const url = process.env.DATABASE_URL;
  const admin = new pg.Pool({ connectionString: url });
  const servers = [];
  async function start() {
    const accountDb = await openAccountDatabase(url, { schema });
    const server = createApi({ accountDb });
    await server.ready;
    await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
    servers.push(server);
    return `http://127.0.0.1:${server.address().port}`;
  }
  let base;
  async function request(path, token, body, method) {
    const response = await fetch(base + path, { method: method || (body ? 'POST' : 'GET'), headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) }, ...(body ? { body: JSON.stringify(body) } : {}) });
    return { status: response.status, body: await response.json() };
  }
  try {
    base = await start();
    const a = await request('/auth/register', null, { name: 'Synthetic QA', email: 'qa@example.test', password: 'Synthetic-test-password', timezone: 'Africa/Tunis' });
    assert.equal(a.status, 201);
    const token = a.body.token;
    const b = await request('/auth/register', null, { name: 'Second QA', email: 'second@example.test', password: 'Synthetic-test-password' });
    assert.equal(b.status, 201);
    const saved = await request('/users/me/sync/tasks', token, { revision: 0, snapshot: JSON.stringify([{ id: 'synthetic-task' }]) });
    assert.equal(saved.status, 200, JSON.stringify(saved));
    base = await start();
    assert.equal((await request('/users/me', token)).body.id, a.body.user.id);
    const restored = await request('/users/me/sync', token);
    assert.match(JSON.stringify(restored.body), /synthetic-task/);
    assert.doesNotMatch(JSON.stringify((await request('/users/me/sync', b.body.token)).body), /synthetic-task/);
    const retry = await request('/users/me/sync/tasks', token, { revision: 0, snapshot: JSON.stringify([{ id: 'synthetic-task' }]) });
    assert.equal(retry.status, 200);
    const conflict = await request('/users/me/sync/tasks', token, { revision: 0, snapshot: JSON.stringify([{ id: 'different-edit' }]) });
    assert.equal(conflict.status, 200);
    assert.equal(conflict.body.applied, false);
    assert.equal(conflict.body.revision, 1);
    const preferenceWrites = await Promise.all(['fr', 'en'].map(language => request('/users/me/preferences', token, { language, expected: { language: 'en' } }, 'PATCH')));
    assert.ok(preferenceWrites.every(r => [200, 409].includes(r.status)));
    const writes = await Promise.all([1, 2].map(n => request('/users/me/sync/tasks', token, { revision: 1, snapshot: JSON.stringify([{ id: `concurrent-${n}` }]) })));
    assert.equal(writes.filter(w => w.body.applied).length, 1);
  } finally {
    await Promise.all(servers.map(s => new Promise(resolve => s.close(resolve))));
    await admin.query(`DROP SCHEMA ${schema} CASCADE`);
    await admin.end();
  }
});

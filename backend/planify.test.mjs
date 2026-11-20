import assert from 'node:assert/strict';
import { once } from 'node:events';
import { test } from 'node:test';
import { openDatabase } from './src/database.mjs';
import { createPlanifyServer } from './planify.mjs';

test('one account session authorizes workspace routes and gates AI', async () => {
  const db = await openDatabase({ path: ':memory:' });
  const server = createPlanifyServer(db, { database: ':memory:' });
  try {
    server.listen(0, '127.0.0.1');
    await once(server, 'listening');
    const base = `http://127.0.0.1:${server.address().port}`;
    let token;
    const request = (path, method = 'GET', body) => fetch(base + path, {
      method,
      headers: {
        'Content-Type': 'application/json',
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
      },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    assert.equal((await request('/goals')).status, 401);
    const signup = await request('/auth/register', 'POST', {
      name: 'Integration account', email: 'workspace@example.com',
      password: 'integration-test-password',
    });
    assert.equal(signup.status, 201);
    ({ token } = await signup.json());

    for (const route of ['/users/me', '/goals', '/projects', '/assistant/capabilities', '/gamification/summary']) {
      assert.equal((await request(route)).status, 200, route);
    }
    for (const route of ['/agents/tasks', '/agents/planning', '/agents/focus']) {
      const denied = await request(route, 'POST', {});
      assert.equal(denied.status, 403, route);
      assert.equal((await denied.json()).error.code, 'consent_required');
    }

    const saved = await request('/users/me/preferences', 'PATCH', { theme: 'dark' });
    assert.equal(saved.status, 200);
    assert.equal((await saved.json()).preferences.theme, 'dark');
    assert.equal((await request('/auth/logout', 'POST', {})).status, 200);
    assert.equal((await request('/projects')).status, 401);
  } finally {
    server.closeAllConnections();
    await new Promise(resolve => server.close(resolve));
    await db.close();
  }
});

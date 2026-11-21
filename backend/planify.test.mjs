import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
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

test('canonical personal goal progress and assignment-aware project planning use the signed-in account', async () => {
  const db = await openDatabase({ path: ':memory:' });
  const server = createPlanifyServer(db, { database: ':memory:' });
  try {
    server.listen(0, '127.0.0.1');
    await once(server, 'listening');
    const base = `http://127.0.0.1:${server.address().port}`;
    async function request(account, method, path, body, expected = 200) {
      const response = await fetch(base + path, {
        method,
        headers: {
          'Content-Type': 'application/json',
          ...(account ? { Authorization: `Bearer ${account.token}` } : {}),
        },
        body: body === undefined ? undefined : JSON.stringify(body),
      });
      const result = await response.json();
      assert.equal(response.status, expected, `${method} ${path}: ${JSON.stringify(result)}`);
      return result;
    }
    const owner = await request(null, 'POST', '/auth/register', {
      name: 'Project owner', email: 'project-owner@example.test', password: 'synthetic-test-account-123',
    }, 201);
    const member = await request(null, 'POST', '/auth/register', {
      name: 'Project member', email: 'project-member@example.test', password: 'synthetic-test-account-123',
    }, 201);
    const personalId = '1764000000000000-0';
    const dependencyId = '1764000000000000-1';
    const localTask = {id:personalId,title:'Review sources',minutes:25,done:true,skipped:false,requires:[dependencyId]};
    const dependency = {id:dependencyId,title:'Gather sources',minutes:15,done:false,skipped:false,requires:[]};
    const snapshot = tasks => JSON.stringify(tasks);
    const sync = (revision, tasks) => request(owner, 'POST', '/users/me/sync/tasks', {
      revision, snapshot:snapshot(tasks),
    });
    const goalDraft = {title:'Finish personal research', request_id:randomUUID()};
    const goal = await request(owner, 'POST', '/goals', goalDraft, 201);
    assert.equal(goal.progress, null);
    assert.equal((await request(owner, 'POST', '/goals', goalDraft, 201)).id, goal.id);
    assert.equal((await request(owner, 'GET', '/goals')).items.length, 1);
    const goalPath = `/goals/${goal.id}`;
    await request(owner, 'GET', '/goals/personal-tasks', undefined, 409);
    const first = await sync(0, [localTask, dependency]);
    assert.equal(first.applied, true);
    await request(member, 'GET', '/goals/personal-tasks', undefined, 409);
    await request(member, 'GET', goalPath, undefined, 403);
    await request(member, 'POST', goalPath+'/personal-tasks', {task_id:personalId}, 403);
    for (let attempt=0; attempt<2; attempt++) {
      const linked = await request(owner, 'POST', goalPath+'/personal-tasks', {task_id:personalId});
      assert.equal(linked.progress, 0);
      assert.equal(linked.item_count, 1);
      assert.equal(linked.tasks[0].personal, true);
    }
    const paused = await request(owner, 'PATCH', goalPath, {
      title:goal.title,status:'paused',expected_updated_at:goal.updated_at,
    });
    assert.equal(paused.status, 'paused');
    await request(owner, 'PATCH', goalPath, {
      title:'Stale edit',status:'active',expected_updated_at:goal.updated_at,
    }, 409);
    await request(owner, 'PATCH', goalPath, {title:goal.title,status:'completed'}, 409);
    const persisted = [localTask, {...dependency,done:true}];
    const second = await sync(first.revision, persisted);
    // The same canonical revision can be retried after a lost response.
    const retry = await sync(first.revision, persisted);
    assert.equal(retry.revision, second.revision);
    const finished = await request(owner, 'GET', goalPath);
    assert.equal(finished.progress, 100);
    assert.equal(finished.completed_count, 1);
    assert.ok(finished.progress_checked_at);
    await request(owner, 'PATCH', goalPath, {title:goal.title,status:'completed'});
    await sync(second.revision, [dependency]);
    const deleted = await request(owner, 'GET', goalPath);
    assert.equal(deleted.progress, null);
    assert.deepEqual(deleted.missing_personal_tasks, [personalId]);
    await request(owner, 'DELETE', goalPath+'/personal-tasks/'+personalId);
    assert.deepEqual((await request(owner, 'GET', goalPath)).missing_personal_tasks, []);
    await request(owner, 'PATCH', goalPath, {title:goal.title,status:'archived'});

    const projectDraft = {title:'Shared research',request_id:randomUUID()};
    const project = await request(owner, 'POST', '/projects', projectDraft, 201);
    assert.equal(project.progress, null);
    assert.equal((await request(owner, 'POST', '/projects', projectDraft, 201)).id, project.id);
    const projectPath = `/projects/${project.id}`;
    const invitation = await request(owner, 'POST', projectPath+'/invitations', {
      email:member.user.email,role:'collaborator',
    }, 201);
    for (let attempt=0; attempt<2; attempt++) {
      await request(member, 'POST', `/invitations/${invitation.token}/respond`, {accept:true});
    }
    const draft = {title:'Draft methods',project_id:project.id,request_id:randomUUID()};
    const shared = await request(owner, 'POST', '/tasks', draft, 201);
    assert.equal((await request(owner, 'POST', '/tasks', draft, 201)).id, shared.id);
    const assignment = {task_id:shared.id,user_id:member.user.id};
    await request(member, 'POST', projectPath+'/assignments', assignment, 403);
    await request(owner, 'POST', projectPath+'/assignments', assignment);
    await request(owner, 'POST', projectPath+'/assignments', assignment);
    const sharedGoal = await request(owner, 'POST', '/goals', {
      title:'Shared milestone',project_id:project.id,
    }, 201);
    await request(owner, 'POST', `/goals/${sharedGoal.id}/tasks`, {task_id:shared.id});
    await request(owner, 'POST', `/goals/${sharedGoal.id}/personal-tasks`, {task_id:personalId}, 422);
    const assigned = await request(member, 'GET', '/projects/planning-tasks');
    assert.deepEqual(assigned.items.map(item => item.id), [shared.id]);
    assert.equal(assigned.items[0].title, undefined);
    assert.deepEqual((await request(owner, 'GET', '/projects/planning-tasks')).items, []);
    const taskPath = `/tasks/${shared.id}`;
    await request(owner, 'PATCH', taskPath, {status:'completed',from_plan:true}, 403);
    await request(member, 'PATCH', taskPath, {status:'completed',from_plan:true});
    await request(member, 'PATCH', taskPath, {status:'completed',from_plan:true});
    assert.equal((await request(owner, 'GET', projectPath)).progress, 100);
    assert.equal((await request(owner, 'GET', `/goals/${sharedGoal.id}`)).progress, 100);
    assert.equal((await request(owner, 'GET', goalPath)).progress, null);
    await request(owner, 'DELETE', projectPath+'/members/'+member.user.id);
    assert.deepEqual((await request(member, 'GET', '/projects/planning-tasks')).items, []);
    await request(member, 'GET', projectPath, undefined, 403);
    await request(member, 'GET', `/goals/${sharedGoal.id}`, undefined, 403);
    await request(member, 'PATCH', taskPath, {status:'completed',from_plan:true}, 403);
    await request(member, 'POST', `/invitations/${invitation.token}/respond`, {accept:true}, 403);
  } finally {
    server.closeAllConnections();
    await new Promise(resolve => server.close(resolve));
    await db.close();
  }
});

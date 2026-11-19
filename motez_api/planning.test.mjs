import assert from 'node:assert/strict';
import { test } from 'node:test';
import { proposePlanning } from './planning.mjs';

const env = { AI_API_KEY: 'example', AI_MODEL: 'example' };
function provider(name, result) {
  return async (_url, { body }) => {
    const request = JSON.parse(body);
    if (request.tool_choice === 'none') {
      const context = request.messages.at(-1);
      assert.equal(context.role, 'tool');
      assert.equal(JSON.parse(context.content).date, '2026-11-19');
      return Response.json({ choices: [{ message: { content: JSON.stringify(result) } }] });
    }
    assert.equal(request.tool_choice.function.name, name);
    return Response.json({ choices: [{ message: { role: 'assistant', tool_calls: [
      { id: 'read', type: 'function', function: { name, arguments: '{}' } },
    ] } }] });
  };
}

test('interpretation accepts a bounded constraint and rejects a past reservation', async () => {
  const body = { kind: 'interpret', date: '2026-11-19', input: 'Keep 2–3 pm free',
    cutoff: 600, workday: { start: 540, end: 1020 } };
  const result = { kind: 'unavailable', start: 840, end: 900 };
  assert.deepEqual(await proposePlanning(body, env, provider('read_planning_context', result)), result);
  await assert.rejects(proposePlanning(body, env,
    provider('read_planning_context', { ...result, start: 500 })), /invalid planning proposal/);
});

test('explanation requires real change indexes and avoids alternative clock times', async () => {
  const body = { kind: 'explain', date: '2026-11-19', changes: [{
    id: 0, title: 'Prepare', status: 'moved', before: '09:00–10:00', after: '11:00–12:00',
    reason: 'The previous slot overlaps Class.',
  }] };
  const result = { items: [{ id: 0, text: 'This moved to make room for Class.' }] };
  assert.deepEqual(await proposePlanning(body, env, provider('read_schedule_changes', result)), result);
  for (const item of [{ id: 1, text: 'Unknown' }, { id: 0, text: 'Moves to 20:00' }]) {
    await assert.rejects(proposePlanning(body, env, provider('read_schedule_changes',
      { items: [item] })), /invalid planning proposal/);
  }
});

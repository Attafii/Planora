import assert from 'node:assert/strict';
import { test } from 'node:test';
import { propose } from './server.mjs';

const env = { AI_API_KEY: 'test-key', AI_MODEL: 'test-model:free' };
function provider(tool, result) {
  let read = false;
  return async (_url, options) => {
    const input = JSON.parse(options.body);
    if (!read) {
      read = true;
      assert.equal(input.tool_choice.function.name, tool);
      return Response.json({ choices: [{ message: { role: 'assistant', tool_calls: [
        { id: 'read', type: 'function', function: { name: tool, arguments: '{}' } },
      ] } }] });
    }
    assert.equal(input.tool_choice, 'none');
    assert.equal(input.messages.at(-1).role, 'tool');
    return Response.json({ choices: [{ message: { content: JSON.stringify(result) } }] });
  };
}

test('decomposition removes existing and repeated steps', async () => {
  const request = provider('read_task_context', { steps: ['Read brief', 'Draft outline', 'draft outline'] });
  const action = await propose({ kind: 'decompose', title: 'Prepare report', minutes: 30,
    existing: ['Read brief'] }, env, request);
  assert.deepEqual(action.steps, ['Draft outline']);
});

test('next action accepts an eligible ID and rejects an invented candidate', async () => {
  const input = { kind: 'next_action', minutes: 30, energy: 'medium', candidates: [
    { id: 'step1', title: 'Start outline', minutes: 10, energy: 'low' },
  ] };
  assert.deepEqual(await propose(input, env, provider('read_eligible_actions',
    { id: 'step1', reason: 'Fits your time.' })), { id: 'step1', reason: 'Fits your time.' });
  await assert.rejects(propose(input, env, provider('read_eligible_actions',
    { id: 'step2', reason: 'Invented step' })), /invalid proposal/);
});

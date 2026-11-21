import { test } from 'node:test';
import assert from 'node:assert/strict';
import { aiRequest, configureAiBudget } from '../src/ai_provider.mjs';
import { openDatabase } from '../src/database.mjs';
const endpoint = 'https://openrouter.ai/api/v1/chat/completions';
const options = model => ({ method: 'POST', body: JSON.stringify({ model, messages: [] }) });
test('paid models and other remote endpoints cannot receive a request', async () => {
  let calls = 0;
  const request = async () => { calls++; };
  await assert.rejects(aiRequest(endpoint, options('paid/model'), request), e => e.code === 'ai_configuration');
  await assert.rejects(aiRequest('https://example.com/chat/completions', options('openrouter/free'), request), e => e.code === 'ai_configuration');
  assert.equal(calls, 0);
});
test('shared database budget is atomic across concurrent provider calls and persists', async () => {
  const db = await openDatabase({ url: '', path: ':memory:' });
  configureAiBudget(db);
  let calls = 0;
  try {
    const request = async (_, init) => {
      calls++;
      assert.deepEqual(JSON.parse(init.body).provider.max_price, { prompt: 0, completion: 0 });
      return new Response('{}');
    };
    const results = await Promise.allSettled(Array.from({ length: 5 }, () => aiRequest(endpoint, options('openrouter/free'), request, { AI_DAILY_LIMIT: '2' })));
    assert.equal(calls, 2);
    assert.equal(results.filter(r => r.status === 'fulfilled').length, 2);
    assert.ok(results.filter(r => r.status === 'rejected').every(r => r.reason.code === 'ai_rate_limited'));
    assert.equal((await db.query('SELECT requests FROM ai_daily_usage')).rows[0].requests, 2);
  } finally { configureAiBudget(undefined); await db.close(); }
});

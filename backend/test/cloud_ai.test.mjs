import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { cloudAnswer } from '../src/cloud_ai.mjs';
import { openDatabase } from '../src/database.mjs';
import { createApp } from '../src/app.mjs';

let provider, api, db, base, payload, token, conversation;
let status = 200, content = '{"message":"A clear next step.","actions":[]}', delay = 0;
const previous = Object.fromEntries(['AI_BASE_URL', 'AI_MODEL', 'AI_API_KEY'].map(key => [key, process.env[key]]));
const messages = [{ role: 'user', content: 'Summarize my QA work.' }];
async function request(path, body) {
  const response = await fetch(base + path, {
    method: body ? 'POST' : 'GET',
    headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });
  return { status: response.status, data: await response.json() };
}
before(async () => {
  provider = createServer(async (req, res) => {
    let body = '';
    for await (const chunk of req) body += chunk;
    payload = JSON.parse(body);
    if (delay) await new Promise(resolve => setTimeout(resolve, delay));
    res.writeHead(status, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ choices: [{ message: { content } }] }));
  }).listen(0, '127.0.0.1');
  await new Promise(resolve => provider.once('listening', resolve));
  process.env.AI_BASE_URL = `http://127.0.0.1:${provider.address().port}`;
  process.env.AI_MODEL = 'qa-model:free';
  process.env.AI_API_KEY = 'synthetic-test-key';
  db = await openDatabase({ url: '', path: ':memory:' });
  api = createApp(db).listen(0, '127.0.0.1');
  await new Promise(resolve => api.once('listening', resolve));
  base = `http://127.0.0.1:${api.address().port}`;
  token = (await request('/auth/register', { name: 'Cloud QA', email: 'cloud@example.test', password: 'QA-test-password' })).data.token;
  conversation = (await request('/assistant/conversations', { title: 'Cloud test' })).data.id;
});
after(async () => {
  await Promise.all([new Promise(resolve => api.close(resolve)), new Promise(resolve => provider.close(resolve))]);
  await db.close();
  for (const [key, value] of Object.entries(previous)) {
    if (value === undefined) delete process.env[key]; else process.env[key] = value;
  }
});

test('cloud response is validated and persisted for the conversation screen', async () => {
  content = '```json\n{"message":"A clear next step.","actions":[]}\n```';
  const result = await request('/assistant/messages', { conversation_id: conversation, message: messages[0].content, use_cloud: true });
  assert.equal(result.status, 200);
  assert.equal(result.data.message, 'A clear next step.');
  assert.equal(payload.model, 'qa-model:free');
  assert.deepEqual(payload.response_format, { type: 'json_object' });
  const saved = (await request(`/assistant/conversations/${conversation}`)).data;
  assert.equal(saved.messages.length, 2);
  assert.equal(saved.messages[1].body, result.data.message);
});
test('malformed and incomplete responses give actionable errors without saving partial messages', async () => {
  for (const bad of ['not JSON', '{"actions":[]}', '{"message":"","actions":[]}']) {
    content = bad;
    const result = await request('/assistant/messages', { conversation_id: conversation, message: 'QA request', use_cloud: true });
    assert.equal(result.status, 502);
    assert.equal(result.data.error.code, 'ai_invalid_response');
  }
  assert.equal((await request(`/assistant/conversations/${conversation}`)).data.messages.length, 2);
});
test('provider rate limits and outages are distinguished', async () => {
  for (const [code, expected] of [[429, 'ai_rate_limited'], [503, 'ai_unavailable']]) {
    status = code;
    await assert.rejects(cloudAnswer(messages), error => error.code === expected);
  }
  status = 200;
});
test('slow provider requests produce a specific recoverable timeout', async () => {
  content = '{"message":"A clear next step.","actions":[]}';
  delay = 100;
  await assert.rejects(cloudAnswer(messages, { timeoutMs: 10 }), error => error.status === 504 && error.code === 'ai_timeout');
  delay = 0;
});

import { aiRequest } from './ai_provider.mjs';
import { z } from 'zod';
import { ApiError } from './core.mjs';

const answerSchema = z.object({
  message: z.string().trim().min(1).max(4000),
  actions: z.array(z.unknown()).max(20).default([]),
});

// Free providers can queue requests. Keep this deadline below the client's 75s.
export async function cloudAnswer(messages, { timeoutMs = 60000, tools = [], readTool = null, validateResult = null, allowRepair = false } = {}) {
  const base = (process.env.AI_BASE_URL || 'https://openrouter.ai/api/v1').replace(/\/$/, '');
  const openrouter = new URL(base).hostname === 'openrouter.ai';
  try {
    const deadline = Date.now() + timeoutMs;
    messages = [...messages];
    let repairing = false;
    for (let turn=0; turn<4; turn++) {
    const response = await aiRequest(`${base}/chat/completions`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${process.env.AI_API_KEY}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model: process.env.AI_MODEL,
        response_format: { type: 'json_object' },
        max_tokens: 3000,
        ...(openrouter ? { provider: { require_parameters: true } } : {}),
        messages,
        ...(tools.length ? { tools, tool_choice: turn < 3 && !repairing ? 'auto' : 'none' } : {}),
      }),
      signal: AbortSignal.timeout(Math.max(1, deadline-Date.now())),
    });
    if (response.status === 429) throw new ApiError(429, 'The AI provider is busy or its free request limit has been reached. Wait a minute and retry, or switch to the local assistant.', 'ai_rate_limited');
    if (!response.ok) throw new ApiError(502, 'Cloud AI is temporarily unavailable. Retry or switch to the local assistant. Your work has not changed.', 'ai_unavailable');
    const data = await response.json();
    const reply = data.choices?.[0]?.message;
    if (reply?.tool_calls?.length) {
      if (!readTool || turn === 3 || reply.tool_calls.length > 3) throw new ApiError(502, 'The assistant could not finish reading your workspace. Nothing was applied.', 'ai_invalid_response');
      messages.push(reply);
      for (const call of reply.tool_calls) {
        if (!tools.some(tool => tool.function.name === call.function?.name)) throw new ApiError(502, 'The assistant requested an unsupported tool.', 'ai_invalid_response');
        const value = await readTool(call.function.name, JSON.parse(call.function.arguments || '{}'));
        messages.push({role:'tool',tool_call_id:call.id,content:JSON.stringify(value)});
      }
      continue;
    }
    // Some compatible providers wrap JSON in a Markdown code fence.
    const content = data.choices?.[0]?.message?.content;
    let result;
    try {
      result = answerSchema.safeParse(JSON.parse(typeof content === 'string' ? content.trim().replace(/^```(?:json)?\s*/i, '').replace(/\s*```$/, '') : 'null'));
      if (result.success && validateResult) validateResult(result.data);
      if (!result.success) throw Error('Incomplete response');
    } catch {
      if (allowRepair && !repairing && turn < 3 && Date.now() < deadline) {
        repairing = true;
        messages.push({role:'assistant',content:typeof content==='string'?content.slice(0,12000):'{}'}, {role:'user',content:'That response did not match the supported schema. Return exactly JSON {"message":"your conversational answer","actions":[]}. If proposing an action, use ONLY the exact kind and payload fields in the system schemas. Otherwise leave actions empty and ask a clarifying question. Never claim any change was applied.'});
        continue;
      }
      throw new ApiError(502, 'Cloud AI returned an incomplete or unsupported response. Retry or switch to the local assistant. Nothing was applied.', 'ai_invalid_response');
    }
    return result.data;
    }
    throw new ApiError(502, 'The assistant reached its reading limit. Please narrow your request.', 'ai_invalid_response');
  } catch (error) {
    if (error instanceof ApiError) throw error;
    if (error.name === 'TimeoutError' || error.name === 'AbortError') throw new ApiError(504, 'Cloud AI took too long to respond. Your message is still here. Retry or switch to the local assistant.', 'ai_timeout');
    if (error instanceof SyntaxError) throw new ApiError(502, 'Cloud AI returned an unreadable response. Retry or switch to the local assistant. Nothing was applied.', 'ai_invalid_response');
    throw new ApiError(502, 'Cannot reach the AI provider. Retry or switch to the local assistant. Your work has not changed.', 'ai_unavailable');
  }
}

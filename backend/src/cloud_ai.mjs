import { z } from 'zod';
import { ApiError } from './core.mjs';

const answerSchema = z.object({
  message: z.string().trim().min(1).max(4000),
  actions: z.array(z.unknown()).max(20).default([]),
});

// Free providers can queue requests. Keep this deadline below the client's 75s.
export async function cloudAnswer(messages, { timeoutMs = 60000 } = {}) {
  const base = (process.env.AI_BASE_URL || 'https://api.openai.com/v1').replace(/\/$/, '');
  const openrouter = new URL(base).hostname === 'openrouter.ai';
  try {
    const response = await fetch(`${base}/chat/completions`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${process.env.AI_API_KEY}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model: process.env.AI_MODEL,
        response_format: { type: 'json_object' },
        max_tokens: 2000,
        ...(openrouter ? { provider: { require_parameters: true } } : {}),
        messages,
      }),
      signal: AbortSignal.timeout(timeoutMs),
    });
    if (response.status === 429) throw new ApiError(429, 'The AI provider is busy or its free request limit has been reached. Wait a minute and retry, or switch to the local assistant.', 'ai_rate_limited');
    if (!response.ok) throw new ApiError(502, 'Cloud AI is temporarily unavailable. Retry or switch to the local assistant. Your work has not changed.', 'ai_unavailable');
    const data = await response.json();
    // Some compatible providers wrap JSON in a Markdown code fence.
    const content = data.choices?.[0]?.message?.content;
    const result = answerSchema.safeParse(JSON.parse(typeof content === 'string' ? content.trim().replace(/^```(?:json)?\s*/i, '').replace(/\s*```$/, '') : 'null'));
    if (!result.success) throw new ApiError(502, 'Cloud AI returned an incomplete response. Retry or switch to the local assistant. Nothing was applied.', 'ai_invalid_response');
    return result.data;
  } catch (error) {
    if (error instanceof ApiError) throw error;
    if (error.name === 'TimeoutError' || error.name === 'AbortError') throw new ApiError(504, 'Cloud AI took too long to respond. Your message is still here. Retry or switch to the local assistant.', 'ai_timeout');
    if (error instanceof SyntaxError) throw new ApiError(502, 'Cloud AI returned an unreadable response. Retry or switch to the local assistant. Nothing was applied.', 'ai_invalid_response');
    throw new ApiError(502, 'Cannot reach the AI provider. Retry or switch to the local assistant. Your work has not changed.', 'ai_unavailable');
  }
}

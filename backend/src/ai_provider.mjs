import { ApiError } from './core.mjs';
let budgetDatabase;
let localDay = '', localCount = 0;
export function configureAiBudget(db) { budgetDatabase = db; }
export async function aiRequest(url, options, request = fetch, env = process.env) {
  const endpoint = new URL(url);
  const local = ['localhost', '127.0.0.1', '[::1]'].includes(endpoint.hostname);
  if (!local && (endpoint.origin !== 'https://openrouter.ai' || endpoint.pathname !== '/api/v1/chat/completions')) {
    throw new ApiError(503, 'AI must use the configured OpenRouter endpoint.', 'ai_configuration');
  }
  const body = JSON.parse(options.body);
  if (!local && body.model !== 'openrouter/free' && !body.model?.endsWith(':free')) {
    throw new ApiError(503, 'Only free OpenRouter models are enabled.', 'ai_configuration');
  }
  if (!local) {
    body.provider = { ...body.provider, require_parameters: true, max_price: { prompt: 0, completion: 0 } };
    const limit = Math.min(1000, Math.max(1, Number(env.AI_DAILY_LIMIT) || 1000));
    if (budgetDatabase) {
      const result = await budgetDatabase.query(`INSERT INTO ai_daily_usage(day, requests) VALUES ((CURRENT_TIMESTAMP AT TIME ZONE 'UTC')::date, 1)
        ON CONFLICT(day) DO UPDATE SET requests=ai_daily_usage.requests+1 WHERE ai_daily_usage.requests < $1 RETURNING requests`, [limit]);
      if (!result.rows.length) throw new ApiError(429, 'The shared daily AI limit has been reached. Try again tomorrow. Your work is preserved.', 'ai_rate_limited');
    } else {
      const day = new Date().toISOString().slice(0, 10);
      if (day !== localDay) { localDay = day; localCount = 0; }
      if (localCount >= limit) throw new ApiError(429, 'The shared daily AI limit has been reached.', 'ai_rate_limited');
      localCount++;
    }
  }
  const response = await request(url, { ...options, body: JSON.stringify(body) });
  if (response.status === 429) throw new ApiError(429, 'OpenRouter is busy or its free request limit was reached. Retry later. Your work is preserved.', 'ai_rate_limited');
  return response;
}

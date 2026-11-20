import { mkdir } from 'node:fs/promises';
import { dirname } from 'node:path';
import { propose as proposeFocus } from '../oumayma_api/server.mjs';
import { propose } from '../motez_api/server.mjs';
import { proposePlanning } from '../motez_api/planning.mjs';
import { pathToFileURL } from 'node:url';
import { createApi } from './server.mjs';
import { createApp } from './src/app.mjs';
import { openDatabase } from './src/database.mjs';
import { ApiError } from './src/core.mjs';

const profiles = new WeakMap();

export function createPlanifyServer(db, options = {}) {
  const workspace = createApp(db, {
    async identify(req, tx) {
      const profile = profiles.get(req);
      if (!profile) throw new ApiError(401, 'Sign in to continue.', 'unauthorized');
      await tx.query(
        `INSERT INTO users(id, name, email, password_hash, timezone, created_at)
         VALUES($1, $2, $3, $4, $5, $6)
         ON CONFLICT (id) DO UPDATE SET name=EXCLUDED.name, timezone=EXCLUDED.timezone`,
        [profile.id, profile.name, profile.email, 'external-account', profile.timezone, profile.created_at],
      );
      return { ...profile, cloudAi: profile.preferences.cloud_ai };
    },
  });

  return createApi({
    ...options,
    async proposeAgent(path, body, profile) {
      if (!profile.preferences.cloud_ai) {
        throw new ApiError(403, 'Enable cloud AI in Privacy to use this feature.', 'consent_required');
      }
      try {
                const agent = {
          '/agents/tasks': propose,
          '/agents/planning': proposePlanning,
          '/agents/focus': proposeFocus,
        }[path];
        return await agent(body);
      } catch (error) {
        throw new ApiError(error.status || 502, error.status ? error.message : 'The AI provider is unavailable.', 'agent_error');
      }
    },
    workspace(req, res, profile) {
      profiles.set(req, profile);
      workspace(req, res);
    },
  });
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const path = process.env.WORKSPACE_DATABASE_PATH || './data/workspace';
  if (!process.env.DATABASE_URL && path !== ':memory:') {
    await mkdir(dirname(path), { recursive: true });
  }
  const db = await openDatabase({ path });
  const origins = (process.env.ALLOWED_ORIGINS || 'http://localhost:8052,http://127.0.0.1:8052,http://localhost:8053,http://127.0.0.1:8053').split(',');
  const server = createPlanifyServer(db, {
    database: process.env.ACCOUNT_DATABASE_PATH || './data/accounts.sqlite',
    origins,
    dataPolicy: null,
  });
  const port = Number(process.env.PORT || 4100);
  const host = process.env.HOST || '127.0.0.1';
  server.listen(port, host, () => console.info(`Planify API listening on ${host}:${port}`));
  for (const signal of ['SIGINT', 'SIGTERM']) {
    process.once(signal, () => server.close(() => db.close()));
  }
}

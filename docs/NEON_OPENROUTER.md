# Shared Neon and OpenRouter configuration

Start the integrated app with `npm --prefix backend start`. Its ignored
`backend/.env` contains the existing Ahmed Neon connection and OpenRouter key.
Never copy that file into Flutter assets, Dart defines, tracked files or logs.
For another server, securely configure those same environment variables there.
The Flutter app continues to use the authenticated Planify API via API_BASE_URL.

## Persistence

With DATABASE_URL set, the whole integrated API uses Neon:

- `planify_account`: accounts, password hashes/salts, session-token hashes,
  preferences, consent/security records and revisioned personal-sync snapshots.
- `public`: projects, goals, project tasks, memberships, invitations, assistant
  conversations/proposals, attributable activity and the shared AI request budget.

Personal task, calendar and focus records keep their existing snapshot contract;
this change does not create competing task or calendar records. The workspace
user table is the existing authorized profile projection, not an authentication
source. Account table names are qualified and workspace search paths are scoped
inside transactions, compatible with the Neon pooled connection.

Startup applies additive/idempotent schema updates. Production refuses to start
without DATABASE_URL. Without it, development and regression tests can still use
SQLite accounts and embedded PostgreSQL workspace data.

`npm --prefix backend run db:provision` explicitly provisions the configured
Neon schemas. `npm --prefix backend run db:migrate-accounts -- <source.sqlite>`
imports an existing local account database; paths are relative to backend.
Imports are transactional, retain the read-only source, skip identical records,
and stop on conflicting records without overwriting remote data.

On this machine both existing local account databases were migrated with explicit
user approval: 16 records from the integrated checkout and 11 from the preserved
Desktop checkout. Repeating both imports inserted zero records. Source files and
Desktop working-tree edits were preserved. The existing Neon workspace data was
retained. Device-only unsynced work will upload through normal account sync.

## Free AI only

AI_BASE_URL=https://openrouter.ai/api/v1 and AI_MODEL=openrouter/free are configured.
All assistant, task breakdown, next-action, scheduling interpretation/explanation,
focus and reminder provider calls share the server-side provider adapter.
Other remote providers and paid model names are rejected before sending requests.
An explicit :free model may be used. Requests also restrict provider prompt and
completion prices to zero. There is no paid fallback.

AI_DAILY_LIMIT defaults to 1000 and cannot exceed 1000. An atomic Neon counter
limits calls across server instances, accounts and features. Each provider call
counts, including tool rounds and failed attempts; an interaction can consume
multiple requests. No automatic retry spends extra calls. Quota reservations
remain counted after provider failure. OpenRouter can apply a lower remaining
allowance if other applications share the key or impose per-minute/provider limits.
The key metadata endpoint confirmed a 1000/day allowance during verification.

Cloud AI remains opt-in and enforced at the authenticated API. Provider errors,
rate limits and invalid output never apply a proposal or claim success. Local
planning and the local assistant remain useful without cloud availability.

## Verification

- Backend syntax checks and all 34 normal backend tests passed (the optional
  live Neon test is skipped without RUN_NEON_TESTS).
- All 8 simulated-provider agent tests passed.
- Live Neon test used a temporary synthetic schema, verified account restoration
  across API instances, isolation, retry, concurrent sync and preference writes,
  then removed that test schema. Enable with RUN_NEON_TESTS=1 and DATABASE_URL.
- Live free OpenRouter calls returned validated assistant, task breakdown,
  next-action, planning and focus results. One initial next-action output was
  rejected by validation; its exact-ID/output-length instruction was tightened
  and a subsequent call returned a valid proposal.
- Normal backend startup and health passed on temporary port 4187. Port 4100
  was already occupied by an existing process, which was left running. Restart
  that development API to load the updated code and environment.
- Flutter UI and API payload contracts are unchanged. Real-device/iOS verification
  limitations from PLANIFY_INTEGRATION.md still apply.

An HTTPS API deployment and secure environment configuration on that host are
still needed for access from devices outside the development machine. Email
recovery and external calendar providers remain separate unconfigured services.

# Eya AI setup and sync help

## Entry points

The daily workspace offers personalized setup when the account has no setup state.
Not now saves a skipped state. Preferences always exposes Personalized setup to
resume or revisit it. Setup asks for a short description of explicitly stated
needs and supports only timezone (IANA), English/French, and system/light/dark
appearance. Unsupported planning, accessibility and notification account fields
are explained rather than invented.

Current choices remain editable. AI suggestions first appear as a proposal;
Review suggested settings fills the form, and Confirm and save settings writes
through the existing preference endpoint with expected original values. No AI
response directly changes settings. Manual choices work without Cloud AI.

## Persistence and privacy

A nullable `users.onboarding_state` column stores revisioned setup status/draft;
the normal idempotent account migration provisions it in Neon and SQLite. Drafts
are also cached per API address/account ID. Failed requests retain the local
pending draft, and server revision conflicts require explicit review/rebase.
Online Save draft, Skip and Complete persist across sessions and devices.
Offline edits resume on that device; revisit setup and save when connected to
upload them. Offline Skip is explicitly device-only until saved online.

AI calls require the existing Cloud AI preference AND a per-request context
review. Setup sends only the written needs and current timezone/language/theme.
Do not type sensitive details into the needs field. Sync help sends only collection,
base/server revisions and difference counts, or a generic failure category.
Credentials, raw errors and snapshot contents are not part of AI context.
OpenRouter free-model enforcement and the shared request budget are reused.
Setup output is validated against supported settings; malformed output gets one
bounded correction attempt and otherwise leaves the manual form intact.

## Sync review

Personal sync review shows a local preview of differing collection entries and
the device/server versions. Contents are shown locally in an expandable view;
AI receives only the counts. Counts compare device to server, not a verified
chronology. Focus/planning differences can be grouped at the collection-key level.
There are no recorded device names or edit timestamps in this contract; help
reports them as unavailable. There is no merge action.

AI explains and recommends review; only the explicit Keep this device / Use server
confirmation invokes the existing sync engine. Before resolution the engine fetches
current server data and compares the reviewed local/base/remote fingerprint.
Changed previews are rejected. Keeping local uses the existing server compare-and-
swap revision write; concurrent changes remain conflicts. Conflicting declined
copies stay in saved versions. Network errors preserve local data and expose retry.
Offline/server failures have static recovery guidance and optional metadata-only
AI help; no help text claims a successful sync or backup.

## API

- GET/PATCH `/users/me/onboarding`: private draft/status with optimistic revision.
- POST `/users/me/setup-assist`: explicit needs/context consent; suggestions only.
- POST `/users/me/sync-assist`: reviewed metadata or failure category; explanation only.

The endpoints use the existing authenticated session, rate limit, consent recheck
and account boundaries. No password, session-token or task/calendar schema changed.

## Verification

Backend regressions: 40 passed, optional live Neon test skipped. Flutter regressions:
73 passed. Analysis: no issues. Focused tests cover offline draft resumption,
manual fallback, draft/session persistence, account isolation, stale draft rejection,
AI consent and context minimization, invalid output, stale sync previews and recovery.
Live free OpenRouter/Neon testing with a disposable account passed setup draft
restoration, valid suggestions without preference mutation, sync explanations
without snapshot writes, and explicit preference save/completion. QA records were
removed. An earlier live response lacked useful suggestions and was rejected;
output constraints were tightened and the follow-up run passed.

No physical Android/iOS device verification was performed for this change.

# Eya account controls — implementation and setup

Implemented on `eya-authentication`. These additions use the existing account API, SQLite store, secure token storage and `AppSession`.

## Available with the default configuration

- **Security and devices:** list current-user active sessions, identify this device, revoke a session, and revoke all other sessions after password confirmation. Last-used writes are throttled to once per minute. Existing token hashes migrate without signing users out; historical device/creation metadata is labeled as unrecorded.
- **Account notices:** persist sign-in, profile/preferences/privacy changes, consent changes, export and deletion events; list and mark notices read. Notices are private and in-app. External email/push delivery is not configured.
- **Profile setup:** deterministic checks for name, IANA timezone, supported language and theme. Existing/new default timezones prompt review; saving a timezone confirms it. Analytics uses the same saved timezone.
- **Account Help:** searchable curated English/French content, accessible from sign-in and account screens. Search runs locally and does not receive account data. Public `/help` and protected `/security` routes are available.
- **AI context preview:** date range, timezone, availability and verified personal analytics counts. Missing sources remain unavailable. Name/email, credentials, raw records and unrelated preferences are excluded. Preview does not call an AI provider.
- **Personal data status:** explains policy requirements and shows any owned export/deletion request status. Export/deletion stay disabled without explicit operator policy configuration.

New screens reuse Planify fonts, colors and components; entrance transitions and help-result resizing honor reduced motion. Loading, retry, empty and confirmation states are implemented.

## Policy configuration

No retention, shared-record, recovery or AI-provider policy is assumed approved by this implementation. Do not turn configuration examples into product policy without the team’s decision.

`createApi` accepts `dataPolicy` and `aiPolicy` options. The server and local preview can also load JSON from `ACCOUNT_DATA_POLICY_FILE` and `INSIGHTS_AI_POLICY_FILE`. Missing values keep dependent functionality unavailable; malformed JSON prevents startup.

An approved data policy must include:

| Property | Meaning |
|---|---|
| `approved: true` | Operator confirms the policy was approved |
| `accountOnly: true` | Export/deletion covers this module’s account records only |
| `sharedRecords: "none"` | Confirm no shared ownership or records need handling by this module |
| `version` | Nonempty approved policy identifier |
| `retentionNotice` | Nonempty, user-facing description of retention/deletion |
| `backupNotice` | Nonempty, accurate description of backup handling and retention |
| `recoverySeconds` | Approved recovery window, at least 60 seconds |
| `exportTtlSeconds` | Approved download lifetime, 60–86400 seconds |

If shared-record transfers, anonymization, retention exceptions or another feature’s cleanup are required, this account-only policy is insufficient. Leave deletion disabled until the responsible owners provide the approved implementation.

After the policy is configured:

1. Creating or downloading an export and scheduling/cancelling deletion require password confirmation within five minutes. Confirmation is tied to the server session and rate-limited.
2. Exports are bounded account JSON snapshots rather than a separate job queue. A pending unconsumed export is reused on retry. It contains profile/preferences, redacted session metadata, account notices and consent history, excluding credentials and other feature modules. A new export replaces a consumed one.
3. Export requests have owned status endpoints. Retrieval requires authentication, is single-use, and removes the stored payload after consumption. Expired snapshots are removed by cleanup. Web delivers a JSON download; all platforms offer a selectable JSON view and copy action. A native file-save picker is not included.
4. Deletion is persisted as a scheduled request with an explicit recovery deadline. It removes the user and account-owned rows through foreign-key cascades, including session credentials, notices, consent history, exports and the deletion request. Requests are retry-safe and can be cancelled during recovery.
5. Cleanup runs every second while the API is running and before incoming requests. Due requests resume after restart. Deletion executes only while the same approved policy version remains active; a missing/changed policy pauses it. An account with a paused deletion can cancel it after password confirmation.
6. This module does not manage backups or delete shared records. Operator backup handling must match the approved notice. It never claims to erase a record from backups automatically.

An approved AI policy must include `approved: true`, a nonempty `provider`, and a nonempty `retentionNotice`. This enables the explicit consent choice for the allowlisted personal-insights fields. It does not connect an AI model or generate a summary. Provider/retention metadata contributes to the consent version; changing it invalidates old consent. Both the existing general Cloud AI preference and purpose-specific insights consent must be enabled before context release. Turning either off blocks subsequent requests. The general preference alone does not authorize personal-insights context release.

## Account API additions

All routes below derive user identity from the authenticated session. They do not accept an acting user ID from the client.

| Route | Purpose |
|---|---|
| `POST /users/me/reauthenticate` | Confirm the current password; wrong password returns 403 without clearing the session |
| `GET /users/me/sessions` | Redacted active sessions with opaque IDs |
| `DELETE /users/me/sessions/{id}` | Idempotent owned-session revocation |
| `DELETE /users/me/sessions` | Revoke all other sessions; retain current; requires recent authentication |
| `GET /users/me/notices` | Latest 100 private account notices |
| `POST /users/me/notices/read` | Mark current-user notices read |
| `GET /users/me/profile-quality` | Required/supported setting checks |
| `GET /users/me/privacy/preview?from=…&to=…` | Exact allowlisted analytics preview; authenticated, no AI transmission |
| `PATCH /users/me/privacy/consent` | Versioned purpose-specific consent/withdrawal |
| `POST /users/me/privacy/context?from=…&to=…` | Enforce current consent/provider policy and return only allowed context; sends no data externally |
| `GET /users/me/data-tools` | Policy availability and owned request history |
| `POST /users/me/export` | Create or reuse a ready private export |
| `GET /users/me/export/{id}` | Read owned export status |
| `POST /users/me/export/{id}` | Consume an authenticated single-use export |
| `POST /users/me/deletion` | Schedule deletion with `confirmation: "DELETE"` |
| `GET /users/me/deletion` | Owned deletion status |
| `DELETE /users/me/deletion` | Cancel a pending deletion after recent authentication |

The context endpoint checks consent before and after asynchronous analytics loading and verifies the session still exists before returning context. A future AI-summary caller must use this boundary for each request. No assistant, planning, goal/project/task write workflow or achievement feature is added here.

## Verification

Run `node --test backend/account.test.mjs backend/analytics.test.mjs backend/account-controls.test.mjs`, `flutter test --no-pub`, `flutter analyze --no-pub` and `flutter build web --release --no-pub`.

Backend tests cover registration/session regression, two-account session isolation and revocation, profile review/notices, consent allowlisting and withdrawal, policy gates, recent authentication, private export expiry/single use, deletion cancellation/execution and old-session migration. Approved policy/provider settings in tests are synthetic fixtures, not real product approval.

Flutter tests cover public help search, narrow layouts with large text, session confirmation and revocation, retry recovery, unavailable context/policy states, consent withdrawal and wrong-password handling, plus the existing account/session/DST tests.

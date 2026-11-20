# Planify — Eya implementation plan

**Owner:** Eya  
**Branch:** `eya-authentication`  
**Base:** `master` at `4b7d811` (`initialize Flutter project structure`)  
**Status:** Account foundation and Eya-only UI implemented. Email delivery, account-retention policy, and real activity-source integration remain dependency-gated; see `EYA_IMPLEMENTATION_HANDOFF.md` for implemented behavior and validation.

## Purpose and scope

Deliver the Eya-owned account and personal-data layer that Ahmed’s goal, project, assistant and achievement views can rely on. Eya owns authentication and session lifecycle, the personal profile, persistent user preferences, and private user analytics. The feature must work with the product’s authenticated API and data store; it must not create a second login/session system for each feature.

The project plan names authentication, profile, preferences and analytics as Eya’s responsibility. It identifies timezone, language and privacy/AI preferences as shared integration needs. Ahmed’s existing implementation work is preserved separately in a Git stash; it is not present on this clean base branch. Eya’s changes should therefore be built against the agreed interfaces below and integrated with Ahmed’s branch when the shared implementation is ready.

## User journeys and screens

### 1. Authentication

1. **Welcome / sign in:** email and password, show/hide password, submit progress, useful invalid-credential and connectivity errors, and a link to registration.
2. **Create account:** name, email, password and confirmation, terms notice if the product requires it, field-level validation, duplicate-email handling and safe submission feedback.
3. **Forgot password / reset:** request a reset without revealing whether an email belongs to an account; accept a short-lived, single-use reset token; confirm completion. This flow depends on an approved email delivery provider. Until one is configured, expose a truthful unavailable state rather than a fake successful reset.
4. **Session restore:** restore a valid session at app startup; show a loading state; route to sign-in when no valid session exists; clear local credentials and return to sign-in after expiry or revocation.
5. **Sign out:** revoke the server session, clear the local token even when the network is unavailable, and return to sign-in.

### 2. Profile and preferences

1. **Profile overview:** current display name, email, timezone, language and account status; clear entry points to edit profile, preferences and privacy controls.
2. **Edit profile:** update name and supported account fields with validation, duplicate-email handling and a save state. Require a verified email-change flow before treating a new email as the account’s verified login address.
3. **Preferences:** persist timezone, language, theme and notification preferences only for settings that the product actually supports. Apply language and theme across the app; use timezone in dates, streaks and analytics boundaries.
4. **AI and privacy controls:** explain what context Cloud AI receives; keep cloud AI off until the user chooses it; allow consent to be withdrawn; explain which data remains on Planify’s backend. Do not treat consent as blanket authorization to send unrelated profile or account data.
5. **Account lifecycle:** provide a clear account-data export and account-deletion path if required by the product’s privacy contract. Deletion must reauthenticate, explain the records and team content affected, and use the product’s recovery policy. Confirm the retention and ownership rules with the team before deleting shared records.

### 3. Private analytics

1. **Insights overview:** show verified, understandable measures for a selected time range, such as completed tasks, completed goals, active work and verified focus sessions when the focus feature exists.
2. **Time range and timezone:** provide practical ranges (week, month, custom if supported), calculate calendar boundaries using the saved profile timezone, and label incomplete or unavailable periods honestly.
3. **Progress detail:** link a summary back to the relevant goals/tasks where the viewer has permission. Use only server-authorized records belonging to the user or records the user can currently access.
4. **Empty and error states:** explain how to produce the first data point, distinguish a true zero from unavailable data, and offer retry for failed requests.

Analytics should describe recorded activity; it should not assign an unsupported productivity score, infer behavior from time estimates, or expose one collaborator’s private totals to another. Agree the metric definitions with Ahmed and the team before implementation. If focus sessions are not yet available, omit those measures rather than estimating them.

## Ownership and integration boundaries

| Area | Eya owns | Integration contract |
|---|---|---|
| Session and identity | Registration, sign-in, restore, expiry, sign-out, current-user model | Shared `AppSession` (or team-approved equivalent); one token store and one API client |
| Profile | Read/update current user’s supported fields | Stable current-user response includes `id`, `name`, verified `email`, `timezone`, `language` and supported preferences |
| Preferences | Persistent settings, local application and validation | Ahmed reads timezone and AI/privacy settings through the shared session/preferences service; no duplicate settings store |
| Analytics | Private insights screen and query handling | Backend computes authorized metrics; IDs and date semantics match the goal/task/focus APIs |
| Navigation | Public account routes, authenticated profile/preferences/analytics routes | Ahmed’s feature routes remain usable inside the authenticated shell; achievements entry from profile links to Ahmed’s achievements route |
| Shared shell and design | Auth/profile presentation components for Eya’s routes | Use the shared Planify theme/tokens and brand assets; coordinate shell/router edits before merging |

No feature should store a raw password or bearer token in ordinary preferences. Frontend permission checks are for clear UX; the backend remains the authorization authority. API error codes, timestamps, pagination and validation responses should follow the shared API conventions.

## Proposed API and data contract

The exact route names should be agreed with the team before coding. A coherent first contract is:

| Method and route | Purpose | Notes |
|---|---|---|
| `POST /auth/register` | Create account and return a session | Normalize email; validate password/timezone; return the same user shape used by session restore |
| `POST /auth/login` | Authenticate and start a session | Generic invalid-credential response; rate-limited |
| `POST /auth/logout` | Revoke current session | Idempotent from the client’s perspective |
| `POST /auth/password-reset` | Request reset | Requires email service; avoid account enumeration |
| `POST /auth/password-reset/confirm` | Apply one-time reset token | Enforce expiry, one-time use and session revocation policy |
| `GET /users/me` | Read current profile | Authenticated; never accept a user ID from the client for self access |
| `PATCH /users/me` | Update supported profile fields | Validate and audit sensitive changes; verify email before activation |
| `GET /users/me/preferences` | Read persisted preferences | Return explicit defaults for new accounts |
| `PATCH /users/me/preferences` | Update supported preferences | Validate IANA timezone and allowed language/theme/notification values |
| `GET /users/me/analytics?from=…&to=…` | Return private, server-computed analytics | Validate range and timezone; exclude inaccessible records |
| `POST /users/me/export` / `DELETE /users/me` | Export or delete account data, if in confirmed scope | Require recent authentication and clearly defined shared-record retention behavior |

Prefer explicit database columns/tables for stable, queryable settings. Avoid placing unrelated data in an unchecked JSON blob. Proposed profile fields are `name`, normalized `email`, `email_verified_at`, `timezone`, `language` and timestamps. Store notification and privacy choices in a dedicated preferences table or explicit columns once the team agrees their versioned meaning. Store password hashes, session token hashes, reset-token hashes and expiry/revocation timestamps server-side only.

Analytics payloads should make metric semantics explicit, for example `{range, timezone, generated_at, tasks_completed, goals_completed, focus_minutes}` where each measure has a documented definition and null/unsupported measures are not reported as zero. Add pagination only to detailed event lists, not small aggregates.

## Implementation phases and exit criteria

### Phase 0 — Contract and integration agreement

- Compare the team’s product spec and current API contract with this plan; confirm authentication provider, verification/reset email provider, required profile fields, supported preferences, account deletion rules and analytics definitions.
- Agree the session/user/preferences interface with Ahmed so his features consume one identity and one timezone source.
- Confirm how this branch will receive shared foundation changes from Ahmed’s work; avoid independently replacing the router, API client, shell or theme.

**Exit:** API shapes, metric definitions, reset-email dependency and shared ownership are written down and accepted by both feature owners.

### Phase 1 — Session and authentication foundation

- Implement typed auth requests/responses and one session service.
- Implement sign-in, registration, startup restore, expiry handling and sign-out.
- Store credentials using the platform’s secure storage mechanism; clear them on logout, expiry and account deletion.
- Add server-side password hashing, generic login errors, rate limits, session expiry/revocation and strict input validation if the existing backend does not already supply them.

**Exit:** register → sign out → sign in → app restart → session expiry works end to end, and unauthenticated requests cannot read private records.

### Phase 2 — Profile and preferences

- Implement current-profile read/update and server validation.
- Implement timezone and language preferences first; add theme and notifications only after their behavior is agreed.
- Apply preference changes to shared formatting/theme/localization services without reloading unrelated feature data.
- Add privacy and AI-consent controls and expose their values to Ahmed through the shared service.

**Exit:** profile and preference changes persist through restart, timezone-sensitive surfaces use the saved timezone, and AI/privacy choices are respected by assistant entry points.

### Phase 3 — Password recovery and account lifecycle

- Wire reset request and one-time reset flows only after a delivery provider and safe token handling exist.
- Define email verification and email-change behavior.
- Implement export/deletion only if they are confirmed product requirements, with reauthentication, clear consequences and server-side cleanup/retention rules.

**Exit:** account recovery cannot reveal account existence, reset tokens expire and work once, and account lifecycle actions meet the agreed data-retention policy.

### Phase 4 — Analytics service and UI

- Define each metric using authoritative task, goal and focus events with the responsible feature owner.
- Implement authenticated server aggregates with timezone-aware ranges and access filtering.
- Build an insights overview and useful empty/loading/error states using the existing Planify design system.
- Add accessible chart/table summaries and drill-down links; every chart must have a readable textual equivalent.

**Exit:** sample records produce verified values; time boundaries, authorization and empty datasets are covered; no metric is derived from unverified client claims.

### Phase 5 — Integration, accessibility and release review

- Integrate the profile route into the shared authenticated shell and ensure Ahmed’s goals, projects, assistant and achievements consume the same identity/preferences services.
- Verify direct navigation to public and protected routes, session expiry during use, deep links and mobile/desktop layouts.
- Review privacy disclosures, field labels, screen-reader semantics, focus order, contrast and reduced-motion behavior.
- Run backend tests, Flutter tests, static analysis and production web build; fix introduced failures before merge.

**Exit:** the end-to-end account → preferences → Ahmed feature → analytics flow passes with at least two accounts and the agreed role/access cases; the branch is reviewable and contains only Eya-scoped changes plus approved shared integration.

## Validation checklist

### Authentication and security

- Valid registration/login; duplicate email; malformed inputs; weak password; invalid timezone; incorrect credentials.
- Rate-limited repeated login; session restore; expired/revoked token; sign-out offline; multiple active sessions policy.
- Reset request for known and unknown email gives indistinguishable public responses; expired/used token fails safely.
- Private profile/preferences/analytics return unauthorized without a session and never permit cross-user access.
- No password, token, reset token or sensitive environment value is logged or returned beyond its intended boundary.

### Profile and preferences

- Update and refresh persistence; invalid email/name/timezone/language rejected with field-level feedback.
- Preference defaults on existing and newly registered accounts; localization/timezone changes affect dates and streak boundaries correctly.
- Cloud AI stays disabled until explicit opt-in; revoking preference takes effect on the next assistant interaction.

### Analytics and responsive UX

- Zero activity, partial activity, DST transitions, month/year boundaries, timezone changes, large ranges and unavailable focus data.
- Confirm user isolation and project-role filtering; verify totals against source records.
- Test phone/tablet/desktop widths, loading/empty/error/retry, screen-reader summary, keyboard navigation and accessible chart descriptions.

## Risks and decisions to close before implementation

1. **Reset/email verification:** no mail provider is named in the available project files. Select one or explicitly defer recovery/verification UI.
2. **Analytics meaning:** “analytics” is broad. Agree exact user-facing measures, event sources and date semantics before designing charts.
3. **Privacy/legal policy:** retention, export, deletion and shared-project ownership rules need product decisions; do not invent destructive data behavior.
4. **Parallel branches:** this branch starts at `master`, while Ahmed’s implementation was uncommitted and is preserved in a local stash. Integration requires an agreed merge/rebase after Ahmed’s work is committed or a reviewed cherry-pick of shared foundation changes.
5. **Scope boundaries:** task editing/status belongs to Moetaz; Ahmed owns goals, projects, assistant and achievement integration. Eya’s analytics reads verified data and should not duplicate those features’ write workflows.

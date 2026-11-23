# Planify — Eya account controls and privacy features plan

**Owner:** Eya  
**Branch:** `eya-authentication`  
**Status:** Account implementation completed with dependency gates. See `EYA_ACCOUNT_FEATURES_SETUP.md` for delivered behavior, configuration, verification and limits. Export/deletion activation awaits approved policy; AI opt-in awaits approved provider/retention metadata. No AI summary/assistant is added.  
**Parent scope:** `PLANIFY_EYA_AUTHENTICATION_IMPLEMENTATION_PLAN.md`

## Goal

Extend Eya’s account and personal-data experience with session security controls, profile quality guidance, in-product account help, policy-governed data export/deletion, and a transparent AI context preview. Keep each feature within account, profile, preferences, privacy, and private analytics ownership.

## Scope boundary

Included: current-user sessions, security notices, account/profile settings, explanations of privacy and data handling, the user’s own export/deletion request, and preview/consent for the profile or personal analytics context an AI summary would use.

Excluded: goals, projects, tasks, planning workflows, assistant conversations or capabilities, achievements, focus features, and other feature owners’ routes or data writes. AI context preview describes and controls consent at the account boundary; it does not build or change an assistant. Analytics context is limited to Eya’s existing private, server-authorized analytics contract.

## Feature plans

### 1. Session and security controls

**User experience**

- Add a Security section under account settings with active sessions and a clear current-device indicator.
- Show a useful device label, approximate location only if reliably available and privacy-approved, created/last-used time, and expiry. Never expose bearer tokens or token hashes.
- Let the user revoke one other session or all other sessions. Require a confirmation step and explain that revoking the current session signs the user out.
- Show an in-app notice after security-sensitive account changes, including password changes and session revocations. Only add email/push notices after an approved delivery channel exists.

**Backend/API proposal**

- `GET /users/me/sessions`: list only the authenticated user’s sessions, redacting secrets.
- `DELETE /users/me/sessions/{sessionId}`: revoke one owned session; return an idempotent result.
- `DELETE /users/me/sessions`: revoke all sessions, with an explicit policy for whether the current session is retained.
- Add opaque session IDs, created/last-used timestamps, optional user-agent summary, and revocation timestamps. Continue storing only hashes of session credentials.
- Update last-used metadata at a bounded frequency to avoid a database write on every request.

**Acceptance checks**

- Two accounts cannot view or revoke one another’s sessions; unknown and unowned IDs do not reveal ownership.
- Revoked credentials fail on their next request; local sign-out clears secure storage even offline.
- Session list remains usable on narrow screens and labels current versus other sessions accessibly.

### 2. Profile quality checks

**User experience**

- Add a compact “Profile setup” status to profile/preferences, with actionable items and dismissible informational guidance.
- Check only supported account settings: valid IANA timezone, supported language/theme, and required profile fields. Distinguish missing values from unsupported/invalid values.
- Explain that analytics calendar boundaries are calculated in the saved timezone, so a missing or incorrect timezone can shift which local day/week contains an event.
- Provide a direct link to correct the setting; do not block sign-in or invent a timezone based on unreliable location data.

**Implementation notes**

- Reuse server validation and the current profile/preferences response as the source of truth. Keep the check deterministic and local; no AI inference is needed.
- Make timezone defaults explicit. If the backend supplies a default for new accounts, label it as a default and offer a review prompt rather than claiming the field is missing.
- Analytics already labels the selected timezone; retain that explanation and use the same timezone value in checks.

**Acceptance checks**

- Valid settings produce no warning; missing, defaulted, and unsupported states have distinct, truthful copy.
- Changing timezone updates the profile check and analytics date-boundary label after the saved response returns.
- Invalid preference values remain rejected by the backend even if a client is modified.

### 3. Smarter account support

**User experience**

- Add a searchable or topic-grouped Help panel reachable from sign-in and authenticated account settings.
- Cover sign-in and session expiry, active sessions/revocation, profile and timezone, language/preferences, AI/privacy choices, analytics date boundaries, and data export/deletion status.
- Use short, versioned answers with links to the relevant Eya-owned screen. Include recovery contact/status only when the actual provider is configured.
- Explain unavailable capabilities truthfully and offer a support route only after the team supplies one.

**Implementation notes**

- Start with curated local content and deterministic topic search. This is safer, testable, and useful without sending personal information to an AI provider.
- If an AI help answer is considered later, it must be separately approved, clearly labeled, grounded in the same curated content, and must not receive credentials, session identifiers, or profile data by default.

**Acceptance checks**

- Help content is accessible from public sign-in and authenticated account routes, localized for supported languages, and usable with keyboard/screen reader.
- Answers do not promise reset email, notifications, export, deletion, or support channels that are not configured.
- Search empty/error states offer the full topic list; no account data is included in help queries or logs.

### 4. Personal data tools: export and deletion

**Release gate: product policy decisions are required before implementation.** Confirm applicable legal/product requirements, export format and included records, retention periods, deletion recovery window, identity reauthentication, audit retention, shared/team record ownership, and effects on backups. Until accepted, keep the existing API response that reports the feature as policy-pending; do not simulate success or mutate records.

**User experience after policy approval**

- Export: show covered data/categories and format, require recent authentication, create an owned export job, show progress/expiry, and provide a short-lived download. Make the response private and avoid sending it to logs or analytics.
- Deletion: show exactly which personal data is removed, anonymized, retained, or detached; identify effects on shared records using policy-approved wording; require recent authentication and an explicit final confirmation; provide the approved cancellation/recovery path.
- Notify the user of request status only through configured channels; always provide in-app status while signed in where feasible.

**Backend/API proposal**

- `POST /users/me/export` creates an idempotent export request; `GET /users/me/export/{requestId}` returns status; download uses a short-lived, single-use authorization mechanism.
- `POST /users/me/deletion` creates a deletion request after recent reauthentication; `GET /users/me/deletion` returns status; `DELETE /users/me/deletion` cancels only within the approved recovery window.
- Use background jobs for large exports/deletions, audit state transitions without storing exported content, and ensure authorization derives from the session rather than a caller-supplied user ID.

**Acceptance checks**

- No export or deletion starts without approved policy, recent authentication, and server-side authorization.
- Export contains only the authenticated user’s approved records; downloads expire and cannot be reused by another account.
- Deletion follows the approved shared-record and backup policy, revokes sessions, and is retry-safe; cancellation obeys the published cutoff.
- Failure/retry states do not falsely say data was exported or deleted.

### 5. Privacy context preview

**User experience**

- Extend Eya’s privacy settings with an “AI context preview” that shows the exact categories and representative fields that an AI-generated personal analytics summary would use.
- Default opt-in to off. Let the user enable or withdraw consent; explain the provider/retention behavior once known, what stays on Planify’s backend, and that unrelated profile/account data is excluded.
- Preview the selected date range and analytics measures, including unavailable/null measures, before the user proceeds. Never imply that this screen runs an assistant or generates a summary.
- Provide a “use only these analytics fields” boundary; profile name/email and credentials are excluded unless a separately justified, explicit use is approved.

**Implementation notes**

- Build the preview from an allowlisted, typed context schema backed by Eya’s existing private analytics endpoint. Do not serialize the full user or preferences model.
- Store consent version, timestamp, and withdrawal timestamp. On every future authorized AI-summary request, the receiving service must check current consent server-side and use only the previewed allowlist; withdrawal takes effect for subsequent requests.
- Keep this feature on the Eya privacy route and expose a stable consent/context contract for later integration. Do not edit or add Ahmed’s assistant flow as part of this plan.

**Acceptance checks**

- Default and withdrawn consent prevent AI context release; client-side toggles alone cannot bypass server enforcement.
- Preview fields match the payload allowlist; secrets, email, unrelated preferences, and other users’ records never appear.
- Missing analytics data is shown as unavailable, not zero. Consent copy identifies any provider/retention facts before opt-in.
- Consent withdrawal and schema version changes are auditable and require refreshed consent when the context meaning materially changes.

## Delivery phases

### Phase A — Contracts and decisions

- Confirm session metadata/retention requirements and notification channels.
- Agree which profile fields are required and the timezone default/review behavior.
- Approve Help topics, translations, and a real support destination or omit contact claims.
- Resolve all export/deletion policy questions and name the approving product/privacy owner.
- Identify the AI-summary provider, data handling/retention facts, exact analytics fields, consent versioning, and the backend enforcement point. If any are unresolved, retain a preview-only prototype with no data transmission and keep consent off.

**Exit:** written API/data contracts and policy decisions are approved; unresolved dependencies are explicitly deferred.

### Phase B — Session controls and profile checks

- Add session metadata/list/revoke APIs and account security UI.
- Add profile quality status and timezone guidance based on authoritative current-user preferences.
- Add security change notices in-app; add external notices only when delivery is configured.

**Exit:** cross-account isolation, revoke behavior, preference validation, and timezone guidance pass acceptance checks.

### Phase C — Account Help

- Build the localized curated Help panel, navigation links, search, and truthful dependency status.

**Exit:** all account topics can be found from public/authenticated entry points without exposing user data.

### Phase D — Privacy context preview

- Define the allowlisted preview schema and consent version; build the Eya privacy preview and server contract.
- Keep data transmission disabled until provider and enforcement are approved and implemented.

**Exit:** preview is accurate, consent defaults off, revocation is effective, and server-side checks cover every receiving request.

### Phase E — Export/deletion (policy gated)

- Implement request/status jobs, confirmation/re-authentication, secure download, deletion/recovery, and audited state transitions only after Phase A approval.

**Exit:** end-to-end scenarios satisfy the approved retention, shared-record, backup, and recovery policy.

### Phase F — Eya-only release review

- Verify responsive UX, accessibility, localization, secure storage/logging, rate limits, authorization, errors, and migrations.
- Review changed files and routes to confirm scope remains account/security/profile/privacy/help/private analytics only.

**Exit:** all approved Eya journeys pass; dependency-gated features remain clearly unavailable; no Ahmed-owned behavior is introduced or modified.

## Dependencies and unresolved decisions

| Decision | Needed for | Safe behavior until decided |
|---|---|---|
| Session/device metadata retention and location policy | Session list | Show only metadata that is collected and approved; omit location by default |
| Security email/push delivery provider | External security notices | In-app notice only |
| Required profile fields and timezone defaults | Quality checks | Treat current server defaults honestly; do not infer location |
| Export contents, format, and download lifetime | Export | Keep endpoint policy-pending |
| Deletion, retention, backup, shared-record, and recovery policy | Deletion | Do not mutate or delete data |
| AI provider retention and exact analytics context schema | Context preview/consent | Preview an allowlist only; do not transmit data; consent stays off |

## Non-goals and guardrails

- No goals, tasks, projects, achievements, scheduling, focus, or assistant implementation.
- No second identity/session store; extend the existing Eya account API and `AppSession` contract.
- No guessed productivity scores, inferred behavior, location-derived timezone, or claims unsupported by available records.
- No export, deletion, external notice, or AI data transfer before its required policy/provider/security contract exists.
- UI checks improve clarity but backend authorization and consent enforcement remain authoritative.

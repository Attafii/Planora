# Planify — Eya account layer

Branch: `eya-authentication`, based on `master` at `4b7d811`.

This branch implements authentication, personal profile, persistent preferences,
privacy consent, and private insights. It contains no task editing, goal/project
management, assistant implementation, achievement views, or focus tracking.
Ahmed's stash is preserved.

Session/security controls, profile quality guidance, searchable account Help,
AI context preview, and policy-gated personal data tools are documented in
[Eya account features setup](docs/EYA_ACCOUNT_FEATURES_SETUP.md).

## Run locally

Requirements: Flutter matching pubspec.yaml; Node.js 22.17 or later (built-in SQLite).
No npm dependencies or mail credentials are required.

```powershell
flutter pub get
flutter build web --release
node backend/preview.mjs
```

Open http://localhost:5173. Create your own account; there are no seeded users.
The preview runs the API on 127.0.0.1:3000 and web on 127.0.0.1:5173.
SQLite state is kept under `backend/data/` and is ignored by Git.

For Flutter development, run the API and Flutter separately:

```powershell
node backend/server.mjs
flutter run -d chrome --web-port 5173 --dart-define=API_BASE_URL=http://localhost:3000
```

For Android emulator use API_BASE_URL=http://10.0.2.2:3000 and a reachable development
API listener (`HOST=0.0.0.0` only on a trusted local development network). Native
release builds require an HTTPS API. Android release has Internet permission;
cleartext HTTP is not enabled in release. iOS/macOS builds require Apple tooling;
Linux secure storage requires the package's libsecret prerequisites.

## Verification

```powershell
node --test backend/account.test.mjs backend/analytics.test.mjs backend/account-controls.test.mjs
flutter test
flutter analyze
flutter build web --release
```

## Shared integration

Use `AppSession` in `lib/core/services/app_session.dart` as the single session
service. It exposes account identity, IANA timezone, language, theme and cloudAi.
All feature HTTP calls must use `session.request()` to share authorization and
expiry handling. Tokens are stored through flutter_secure_storage, never ordinary
preferences. API_BASE_URL is compile-time configuration; use HTTPS outside local
development. Web storage requires HTTPS or localhost and a secured hosting origin.

Current routes: `/`, `/login`, `/register`, `/forgot-password`, `/profile`,
`/preferences`, `/privacy`, `/analytics`, `/security`, and public `/help`. Protected routes render authentication
when no valid session exists. Session expiry resets the authenticated navigator.
Do not introduce another account/session/preferences store when merging features.

## Explicit dependencies and deferred behavior

- Reset requests and reset confirmation return `503 email_unavailable` until an
  approved mail provider, expiring one-time tokens and session revocation policy
  are implemented. The UI never claims an email was sent.
- Email is visibly unverified. Email editing is not supported until verification
  delivery exists. Name editing is supported; users cannot patch sensitive fields.
- Export/deletion return `503 policy_pending` by default. The implemented account-only
  export/deletion engine requires an explicitly approved retention/shared-record/recovery
  policy; sensitive actions require recent password confirmation. See the setup document.
- Account/security notices are available in-app. External notification delivery and
  focus statistics remain unavailable until their delivery/source dependencies exist.
- Cloud AI starts off. Its versioned preference and timestamp persist; this module
  never invokes an AI provider. Assistant integration must read current consent on
  every request and enforce consent server-side before transmitting chosen context.
  Personal insights adds a separate allowlisted preview and versioned purpose consent;
  both this consent and the general Cloud AI preference must allow context release.
- Account surfaces support English/French and light/dark/system appearance.
  Public authentication and transport/validation error messages are English.

## Analytics contract

`GET /users/me/analytics?from=<UTC ISO timestamp>&to=<UTC ISO timestamp>` uses an
inclusive start and exclusive end, with a maximum range of 366 days. Flutter
calculates calendar boundaries using the saved IANA timezone, including DST. Week
starts Monday; week/month include today and are incomplete periods. Focus measures
are absent. No client endpoint accepts activity events or metrics.

The default API reports null metrics with `status: unavailable` until authoritative
sources are integrated. It never manufactures zeroes or sample data for the app.

Inject the server-only `activitySource` into `createApi` to supply verified records:

```js
createApi({
  activitySource: async ({ userId, from, to, timezone }) => ({
    tasks: await taskRepository.accessibleCompletedForOwner(userId, from, to),
    goals: await goalRepository.accessibleCompletedForOwner(userId, from, to),
  }),
});
```

Each record must contain `{id, owner_id, completed_at, accessible}` from the
server's authoritative data and current access query. Missing sources return null;
connected sources with no records return an empty array. Aggregation filters by
owner, current access and time range, then counts each source record ID once.
Collaborators' private records are excluded. These metrics count currently
completed records by their authoritative completion timestamp; they do not score
productivity. Team approval of definitions and adapters is still required.

The UI displays connected aggregates with textual metric summaries and distinguishes
partial/unavailable data from zero. Source drill-down links await real authorized
feature routes; this branch does not invent those routes or write workflows.

## API deployment

Configure PORT, HOST, DATABASE_PATH and comma-separated ALLOWED_ORIGINS. Defaults
are local-only. Terminate TLS at a trusted reverse proxy; preserve the correct
client address for per-address rate limiting (do not trust arbitrary forwarded
headers). The built-in in-memory rate limiter is for a single API process; a
multi-instance deployment needs shared limits. Sessions last seven days, support
multiple devices, and are individually revocable. Passwords use salted scrypt;
only SHA-256 session-token hashes are stored in SQLite. Never log request bodies
or Authorization headers. Plan production backups, database access controls and
recovery before deployment. The local preview is not a production hosting server.

## Branding

Eya's screens use the supplied Planify identity: navy, blue, teal, violet and
warm off-white; Manrope display type and Inter body type. The logo is a scalable
vector recreation of the supplied board. See assets/branding/README.md for the
editable symbol, font licenses and platform-icon generation instructions.

# Personal data sync and session restoration

Planify stores the bearer token, expiry, verified account details, and API address in the platform secure store. A recent verified account can open its device data during a server outage while its token is valid. Planify verifies the session at startup and during sync. An expired or rejected credential returns to sign-in. Signing out removes the local credential and attempts server revocation. When offline, use Security from another signed-in device to revoke the old session if needed.

## Device data

The unified workspace syncs personal tasks, calendar day plans, focus sessions, reminders (including whether each alert is enabled), and daily check-ins. Existing account-specific device data is migrated from its existing storage keys on first open. Standalone data with no account association stays in its original store. Sync runs after edits, every 15 seconds while the workspace is open, when it resumes, and on demand. Local storage holds the current snapshot and its acknowledged server revision together, so queued snapshots survive ordinary application restarts.

When another device saves a collection, Planify loads it on workspace start if this device has no changes to that collection. While the workspace is open it offers to load the update. Simultaneous changes to the same collection require a choice. Planify keeps both copies until the user selects a version. The other copy then remains available to copy from Saved versions on that device. Collections sync independently. No automatic field-level merge is attempted because task dependencies, approved plans, and focus state can span multiple records. If an upload response is lost, the server recognizes an identical snapshot without creating a new revision. If a newer revision has already arrived, the original upload cannot overwrite it.

Device copies and conflict archives stay on the device after sign-out and are shown only after signing back into the same account. Project collaboration, goals, project tasks, and cloud AI continue to use their existing online APIs. Offline startup on web requires the browser to be able to load the app shell. Sign-in, registration, and changes to account preferences require a connection. Preferences compare original values only for edited fields so changes to different settings can coexist. When the same setting changes, the app retains selections and lets the user review the server settings before applying them again. Native reminder permission is per device.

## API and deployment

- `GET /users/me/sync` returns an object named `collections` keyed by `tasks`, `planning`, `focus`, and `check-ins`. A stored collection has `revision` and `snapshot` fields. An absent collection starts at revision zero.
- `POST /users/me/sync/{collection}` takes a revision and a JSON snapshot string (up to a 2 MiB request). It returns `applied`, `revision`, and `snapshot`. A conflicting revision returns the current version with `applied: false`. No account ID is accepted from the client. The account database creates `personal_sync` at startup with an account/collection primary key and cascading ownership.
- `PATCH /users/me/preferences` accepts optional `expected` values for timezone, language, and theme. A concurrent change to the same setting returns 409 unless the submitted value already matches the server.

Use a durable account database for server sync. Synced snapshots and their device copies contain personal planning data. Backups and operational access follow the deployment's existing data controls. Password recovery still requires an email provider. Integrated account export/deletion remains gated by approved shared-data and retention policies.

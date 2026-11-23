# Google integration

Google Identity Services popup authorization is supported in the Flutter web app. Continue with Google uses basic identity scopes; Calendar connection requests calendar.events separately. Existing email accounts must first sign in with their password before linking Google from Calendar. Google identity is keyed by verified subject, never silently linked by email.

## Configuration
Ignored backend/.env requires GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET and GOOGLE_TOKEN_KEY (64 lowercase hex characters). Keep the encryption key stable and backed up with deployment secrets; replacing it makes stored Calendar credentials unreadable. No secrets belong in Flutter builds. The configured localhost origins are localhost and localhost:8052. Popup code exchange uses postmessage, so no backend redirect URL is required for this web flow.

Enable Google Calendar API in project planify-515609. Configure Google Auth Platform Branding, Audience/test users, and Data Access for openid/email/profile and https://www.googleapis.com/auth/calendar.events. Production requires production origins, privacy information, and any Google-required verification.

## Behavior and limits
Calendar > External calendars opens Google Calendar. Connect grants access to the primary calendar; view up to 2500 events in the next 31 days (larger ranges fail explicitly), refresh, create an event with explicit timezone offsets, and revoke Calendar access. Failed creation retains form contents and the request ID; Google event IDs prevent duplicate creation on retry. Disconnect preserves Google sign-in identity and existing events. Provider requests stay server-side; tokens are AES-256-GCM encrypted in the account database. Sign-out leaves the user-owned Google connection for future sign-in.

Two nullable account users columns google_sub and google_tokens plus a unique subject index migrate automatically at startup. Existing personal_sync data is unchanged.

The reviewed sync extension below imports busy constraints and exports approved tasks. It does not continuously synchronize edits/deletions. Calendar requires network connectivity. Native sign-in code is present; OAuth registration requirements are detailed below. Password-protected sensitive account actions still require a password; newly created Google-only accounts cannot perform those actions until provider reauthentication is implemented.

## Original web-only verification
42 backend tests passed, one optional Neon test skipped; 73 Flutter tests passed; analysis clean; release web build passed. Focused tests verify encryption integrity, cross-account linking rejection, existing email collision, Calendar isolation, and duplicate event retry. Backend live startup applied schema and configured provider status. Real user consent and Google event access require an authorized Google tester; automated mocked-provider tests are not evidence of a successful live Google connection.


## Reviewed plan synchronization and mobile setup (23 November 2026)

Calendar > External calendars now offers Preview busy-time import and Preview approved-plan export for the selected date within the next 30 days. Import fetches complete Google events (fails rather than using a truncated result), excludes cancelled, transparent, declined and Planify-exported events, and maps busy instants to the account timezone. All-day end dates are exclusive. Existing commitments and breaks remain; busy minutes already covered by them are not duplicated. Imported busy segments have stable IDs, replace earlier imported segments for that selected date, and enter the existing scheduling proposal/revision/approval flow. The current approved plan stays intact until approval. Invalid/DST intervals and changed proposals use existing validation. Imported constraints persist via the same personal planning sync contract and remain available offline. Refresh/import and export require network access. Importing another date does not refresh other dates; disconnect does not erase previously approved constraints.

Export previews future, eligible approved task blocks with UTC times before Google writes. IDs derive from account/date/task and retries reuse them. Updates to a previously exported event require a matching Google ETag and Planify metadata; changes during review fail safely. A partial batch reports confirmed count and can be retried. Existing exported events for removed tasks are not deleted automatically. No task, focus or calendar source of truth was added.

Native Android/iOS code now uses google_sign_in, returning verified Google identity tokens for login and server authorization codes for Calendar. No client secret is embedded in the mobile app. Platform registration is an external requirement, not completed by possession of the web client credentials:

1. In project planify-515609 create an Android OAuth client with package com.example.mobile_project and the signing SHA-1. Current local debug SHA-1 is EC:75:BD:3F:52:2F:3B:A9:08:77:64:94:78:55:A1:15:5C:65:9A:C5. Register release and Play signing certificates separately before distribution. The web client is supplied as serverClientId automatically from backend config; no google-services.json is required for this setup.
2. The supplied iOS client is configured for bundle ID com.example.mobileProject. Its client ID and callback URL scheme are included in Dart and Info.plist; no extra Dart define or Xcode variable is required. These public client IDs are not secrets.
3. Enable Calendar API and grant tester access. Run with a reachable HTTPS API on devices; localhost on a phone points to that phone.

No physical Android/iOS device was connected during this change. iOS compilation and device consent cannot be verified on Windows. The owner supplied Android and iOS client IDs; live Google authorization still requires matching registration settings and user consent. New Google-only accounts still lack provider-based reauthentication for password-protected sensitive account actions.

Verification for the reviewed-sync/native change: 75 Flutter tests passed; 42 backend tests passed with one optional live Neon test skipped; focused import/export and provider tests passed; Android debug APK compiled successfully. Initial web release build passed. Real-device sign-in, consent, and live Google event writes were not verified.


## Registered mobile client IDs

- Android: 408247407549-6jq87fje0d9l6kps4skcuv8rlvlb7nql.apps.googleusercontent.com. Android identifies this registration by package and signing certificate. Dart intentionally passes the existing web client as serverClientId, not the Android client ID.
- iOS: 408247407549-j47mofcp5bkhsapep2if7957li1tfo1a.apps.googleusercontent.com. Dart initializes this iOS client only on iOS, and Info.plist registers com.googleusercontent.apps.408247407549-j47mofcp5bkhsapep2if7957li1tfo1a as the callback scheme.

These IDs were supplied by the project owner on 23 November 2026. Their Google Cloud package/certificate/bundle restrictions cannot be verified from the IDs alone. Test consent on a registered Android device and on iOS through macOS/Xcode before release.

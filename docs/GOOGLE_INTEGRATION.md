# Google integration

Google Identity Services popup authorization is supported in the Flutter web app. Continue with Google uses basic identity scopes; Calendar connection requests calendar.events separately. Existing email accounts must first sign in with their password before linking Google from Calendar. Google identity is keyed by verified subject, never silently linked by email.

## Configuration
Ignored backend/.env requires GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET and GOOGLE_TOKEN_KEY (64 lowercase hex characters). Keep the encryption key stable and backed up with deployment secrets; replacing it makes stored Calendar credentials unreadable. No secrets belong in Flutter builds. The configured localhost origins are localhost and localhost:8052. Popup code exchange uses postmessage, so no backend redirect URL is required for this web flow.

Enable Google Calendar API in project planify-515609. Configure Google Auth Platform Branding, Audience/test users, and Data Access for openid/email/profile and https://www.googleapis.com/auth/calendar.events. Production requires production origins, privacy information, and any Google-required verification.

## Behavior and limits
Calendar > External calendars opens Google Calendar. Connect grants access to the primary calendar; view up to 100 upcoming events, refresh, create an event with explicit timezone offsets, and revoke Calendar access. Failed creation retains form contents and the request ID; Google event IDs prevent duplicate creation on retry. Disconnect preserves Google sign-in identity and existing events. Provider requests stay server-side; tokens are AES-256-GCM encrypted in the account database. Sign-out leaves the user-owned Google connection for future sign-in.

Two nullable account users columns google_sub and google_tokens plus a unique subject index migrate automatically at startup. Existing personal_sync data is unchanged.

This first integration presents live Google events separately from approved Planify plans: it does not automatically import commitments, export approved schedules, synchronize edits/deletions, or change scheduling constraints. Calendar requires network connectivity. Native Android/iOS Google clients and native sign-in UI are not configured by the supplied web credentials; native builds show an unavailable explanation. Password-protected sensitive account actions still require a password; newly created Google-only accounts cannot perform those actions until provider reauthentication is implemented.

## Verification
42 backend tests passed, one optional Neon test skipped; 73 Flutter tests passed; analysis clean; release web build passed. Focused tests verify encryption integrity, cross-account linking rejection, existing email collision, Calendar isolation, and duplicate event retry. Backend live startup applied schema and configured provider status. Real user consent and Google event access require an authorized Google tester; automated mocked-provider tests are not evidence of a successful live Google connection.

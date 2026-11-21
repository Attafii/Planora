# Planify integration

Use Moncef as the base since it already includes Motez and the dated calendar. Integrate Ahmed's goals, projects, assistant and rewards, Eya's account and privacy workflows, and the focus branch associated with Oumayma. Resolve overlapping app entry points and keep feature tests from every branch. Consolidate navigation and theme, then verify Flutter and backend flows.

## Run the integrated app

Start the shared server from `backend` using `npm ci` and `npm start`. In the repository root run `flutter pub get`, then `flutter run -d chrome --web-port 8052`. The default API port is 4100. Change the Flutter API address with `--dart-define=API_BASE_URL=...`, and set the server's `ALLOWED_ORIGINS` to match the web origin.

Create a Planify account to open the workspace. For live cloud suggestions, set `AI_API_KEY`, `AI_MODEL`, and the provider's `AI_BASE_URL` in the backend environment, then enable cloud AI in Privacy. The branches' existing AI adapters use OpenAI-compatible provider endpoints. The calendar engine and local assistant can run independently of a configured AI provider.

Personal tasks, schedules, focus sessions, reminders and daily check-ins use per-account device storage and sync through the account API. Project and goal data live on the workspace server. See [Personal data sync and session restoration](EYA_SESSION_AND_SYNC.md) for offline behavior, conflicts, and deployment dependencies, and [Goals, projects, and recorded work](AHMED_WORK_PROGRESS.md) for activity and permission rules.

## Mobile daily flow

On registration, Planify uses the device's IANA timezone when available. If the host cannot provide a supported timezone, Planify uses UTC. Change the calendar timezone from Account and preferences. Today refreshes when the app resumes. Completed, blocked and elapsed task blocks remain visible in the day timeline with their status. They offer a focus action only while eligible.

For an Android debug smoke test, run the local API, connect an emulator, run `adb reverse tcp:4100 tcp:4100`, and launch with `flutter run -d <device-id> --dart-define=API_BASE_URL=http://127.0.0.1:4100`. Exercise onboarding, task capture, calendar proposal and approval, linked focus, interruption recovery and sync after reconnect. Check the dock with large system text and reduced motion. Use `flutter build apk --release` for the Android build check. The repository's release build uses its development signing configuration. Building and testing on iOS requires macOS, Xcode and a connected device or simulator.

Offline sessions still use the account's existing personal-data queue. Cloud AI requires consent and a configured provider. External calendar connections remain unavailable until a provider is configured.

## Shared Neon and free OpenRouter configuration

Accounts, sessions and personal sync now join goals/projects on Neon when
DATABASE_URL is configured. All AI provider adapters enforce free OpenRouter
models and share a persistent daily request budget. See
[Neon and OpenRouter](NEON_OPENROUTER.md) for migration results and verification.

## Conversational agent

The assistant now retains conversation context, reads authorized workspace data,
shows server-calculated charts and prepares personal task/calendar actions through
the existing approval and sync contracts. See [Conversational agent](CONVERSATIONAL_AGENT.md)
for supported actions, provider limits and verification.

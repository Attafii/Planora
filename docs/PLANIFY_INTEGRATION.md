# Planify integration

Use Moncef as the base since it already includes Motez and the dated calendar. Integrate Ahmed's goals, projects, assistant and rewards, Eya's account and privacy workflows, and the focus branch associated with Oumayma. Resolve overlapping app entry points and keep feature tests from every branch. Consolidate navigation and theme, then verify Flutter and backend flows.

## Run the integrated app

Start the shared server from `backend` using `npm ci` and `npm start`. In the repository root run `flutter pub get`, then `flutter run -d chrome --web-port 8052`. The default API port is 4100. Change the Flutter API address with `--dart-define=API_BASE_URL=...`, and set the server's `ALLOWED_ORIGINS` to match the web origin.

Create a Planify account to open the workspace. For live cloud suggestions, set `AI_API_KEY`, `AI_MODEL`, and the provider's `AI_BASE_URL` in the backend environment, then enable cloud AI in Privacy. The branches' existing AI adapters use OpenAI-compatible provider endpoints. The calendar engine and local assistant can run independently of a configured AI provider.

Personal tasks, schedules, focus sessions, reminders and daily check-ins use per-account device storage and sync through the account API. Project and goal data live on the workspace server. See [Personal data sync and session restoration](EYA_SESSION_AND_SYNC.md) for offline behavior, conflicts, and deployment dependencies, and [Goals, projects, and recorded work](AHMED_WORK_PROGRESS.md) for activity and permission rules.

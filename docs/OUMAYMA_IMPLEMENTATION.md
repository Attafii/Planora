# Oumayma mobile implementation

The [focus follow-through guide](OUMAYMA_FOCUS_FOLLOW_THROUGH.md) describes the current integrated Calendar, task, and sync flows. The original module handoff follows.

Implemented on the local `Oumayma` branch. The app opens directly into Today, with Focus, Reminders and Time log navigation. Authentication, task CRUD, calendar planning and teammate dashboards are outside this branch's pages.

## Run

Use `flutter pub get`, then `flutter run` with an Android or iOS target. For layout review use `flutter run -d chrome`. The browser does not schedule native device reminders. Android uses inexact alarms, which the operating system may delay. Allow notifications from the Reminders page.

## Included flows

- Shared Today home with week selection, actual focused minutes, reminders for the selected day and a focus entry. `HomePage.sections` accepts other branches' sections during integration.
- Countdown, Pomodoro and stopwatch setup; one active session; pause/resume; optional five-minute Pomodoro break; completion and cancellation.
- Timestamp-based elapsed time, restoration after app reload/restart, pause/break exclusion, extra-time requests, blocker/interruption recording and session notes.
- Session reflection with actual/target time, completion intention, notes and event log. A session completion intention does not update an unconnected task.
- Reminder create/edit/delete, enable/disable, daily/weekly recurrence, one-off reminders, and ten-minute snooze. Recurring snoozes add a one-off alert without changing recurrence.
- Android/iOS local notification scheduling, permission request, reboot receiver configuration on Android and notification entry into the module. A notification being scheduled is not proof of delivery.
- Time history with All/Today/7 days filters; session detail; in-app updates for blockers and timer overruns.

State is local to this installation/browser origin, serialized with SharedPreferencesAsync. This is a local feature implementation, not an authenticated backend or cloud synchronization service. Shared preferences are unsuitable as the final authoritative store for critical time records; connect the repository to durable backend storage during integration. No credentials or login are required here.

## Connections for later branches

Moetaz supplies canonical tasks and subtasks. Replace the free-text session title entry with a task picker plus optional standalone focus and persist task IDs. Moncef consumes overrun/blocker records and supplies approval-based replanning. Current updates explain that Calendar is pending; this branch does not claim to replan the day. Eya consumes session actual-time records and supplies locale/theme/timezone preferences. Ahmed can link focus actions to approved assistant workflows.

Push notifications require a configured backend, device-token lifecycle and a push provider. This branch includes local device alerts and the notification page; remote push delivery is not implemented. Deadline-relative task reminders also require the canonical task/deadline contract. Dark mode and other members' preference pages are not added in this branch.

Before final integration, reconcile shared theme/shell history, replace local storage through a repository, map stable task/user IDs, add server authorization/idempotency, and verify push plus task-deadline adapters.

## Validation

Five tests cover restored elapsed-time calculation, exclusion of pauses/breaks, clock rollback protection, recurrence advancement, 390-pixel home layout and required session-title validation. Run `flutter test test/widget_test.dart`; run `dart analyze lib test` for static checks. The narrow-screen browser journey was also exercised: home → setup → start → pause → reload → restored session.

Android and iOS notification delivery, background behavior, timezone changes and permission denial require device verification before release. iOS builds require macOS/Xcode. Native validation results must be recorded separately from successful browser preview checks.

The generated plugin changes from the prior Ahmed checkout were preserved in a named Git stash before switching branches. The existing backend directory belongs to prior branch work and is not part of Oumayma's implementation.

Android build attempt on 1 November 2026: Gradle 9.3.1 distribution download stalled; a competing diagnostic wrapper timed out waiting for that download lock. Attempts were stopped and no wrapper Java process remained. Android compilation is not yet verified. Static analysis and five tests passed after the final source changes.


Feature access: use the permanent Smart tools tab or Explore 4 smart tools near the top of Today. The hub directly opens Adaptive focus, Reminder guard, AI focus coach, and AI reminder agent without requiring selection in a hidden dropdown. AI connection status is displayed in the hub.


## Contextual feature design revision

This revision supersedes the earlier separate Smart tools tab and page. Navigation is Today, Focus, Reminders and Time log. Adaptive focus is integrated into Focus setup as a suggested-duration chip, derived from real session history. Focus has an AI coach sparkle action that opens a contextual bottom sheet. Reminders has an AI compose sparkle action beside Add; each saved reminder has a shield action for quiet-hour/conflict review with its context already selected. No tool-picker page or stacked feature directory remains. Focus proposals emphasize a time block and action steps; reminder proposals emphasize the proposed clock time and date. Approval and rejection still use the existing validated commands. AI still requires provider configuration.

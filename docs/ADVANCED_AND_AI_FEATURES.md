# Advanced and AI feature requirements

Every member's branch must deliver two distinct advanced business features and two distinct AI features, preferably with tool use and approval-based execution. Basic CRUD and cosmetic screens do not count. Rule-based recommendations must not be labeled AI. Each branch needs acceptance evidence, error handling, explained proposals and integration contracts before its final merge.

## Oumayma implemented additions

| Category | Feature | Behavior and evidence |
|---|---|---|
| Advanced 1 | Adaptive focus prescription | Uses up to ten completed sessions, actual duration and interruption frequency to recommend a bounded 10–60 minute block. Cold start is explicit. Approval starts the session. Unit-tested. |
| Advanced 2 | Reminder guard | Searches for a slot outside 22:00–08:00 quiet hours, keeping ten-minute separation from existing enabled reminders including recurrence. Before approval, previews the move and recurrence effect; detects stale reminder edits. Unit-tested. |
| AI 1 | Focus coach agent | Reads recent focus statistics through a bounded tool call; proposes concrete steps and a session duration. Approval starts a session and saves steps as notes. |
| AI 2 | Reminder agent | Reads upcoming reminder load through a tool call, interprets a natural-language request, and proposes a dated reminder and recurrence. Approval creates the reminder and invokes local notification scheduling. |

Entry point: Today → Smart focus & reminder tools. AI requires the local service documented in `oumayma_api/README.md`. Seven Flutter tests and two backend tests pass. Live model behavior requires configured provider credentials and remains unverified. Proposals can be rejected; approved actions are recorded in notification history. Existing task/calendar/push integration limitations still apply.

## Other branches

Audit Eya and Ahmed's existing work against this requirement rather than assuming it is satisfied. Before implementing Moetaz or Moncef, explicitly select and document their two advanced and two AI features within their own module ownership. Do not count Oumayma's tools again in another branch or duplicate Ahmed's general assistant as a substitute for module-specific workflows.

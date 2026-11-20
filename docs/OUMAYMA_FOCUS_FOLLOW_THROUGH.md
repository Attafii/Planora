# Focus follow-through

Open an approved task block in Calendar or Today and choose **Start focus**. Setup shows the task, calendar date, slot, and planned duration. You can start early. Planify checks the exact approved slot and the current task before starting. A missing, changed, ended, completed or blocked task explains why it cannot start. Go back to the plan, start unassigned focus, or continue the active timer if one is already running.

Each linked session stores the canonical task ID and the selected date, start, end, and timezone. Moving the block later leaves the session linked to its original task. Running time is measured from the saved timer anchor, including time while the app is away. Pauses and breaks stop accumulation. The app preserves subsecond time through transitions and restores the timer from the last saved state.

Finishing a countdown or Pomodoro before its target asks for confirmation and records **Ended early** with its active time. Stopwatch finish and sessions that reach the target record **Completed**. Interrupted sessions retain their interruption notes. Abandonment asks for confirmation and preserves active time in the time log. An abandoned session contributes no time to the linked task.

Task details show recorded time from saved, linked sessions, with subtasks included in their parent's total. Finishing or ending early leaves the task open. Session reflection offers **Continue later** and **Mark task done**. The latter requires a separate confirmation and uses the task's existing prerequisite rules. Repeating the completion command cannot reopen the task. Older sessions continue to appear as unassigned history.

Start, pause, resume, finish, abandonment, and task completion work offline after the workspace has loaded. Failed saves retain the session and offer Retry. Task time is counted after the session saves on the device. Focus and task changes use Eya's existing account-scoped snapshots and sync independently. Concurrent device edits use the existing conflict review, which retains both collection versions. Session retries reuse the same saved record and slot. There is a single active timer in the selected device snapshot; the app has no distributed timer lock.

The focus snapshot adds optional scheduled-slot and accumulated-time fields, plus an early-end status. The existing API and database schema carry these values. [Session and sync contract](EYA_SESSION_AND_SYNC.md)

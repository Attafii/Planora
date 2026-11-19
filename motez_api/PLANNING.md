# Planify calendar and scheduling

Run Flutter from this branch and choose **Calendar**. Tasks use Motez’s local task store. Switch between Month, Week and Day. Select any date to see its agenda, add a fixed commitment or break, or change its working hours. Use Today or the month label to jump directly to a date. Preview a schedule, then approve it to save a revision. The planner schedules eligible tasks by due date and stable task ID. If a prerequisite is incomplete or no contiguous slot fits, the preview lists the task with a reason.

Use **Report interruption** to enter a period of unavailability. The preview keeps task blocks before the interruption, preserves the elapsed portion of an interrupted block, and allocates remaining planned minutes around the downtime. Review past approvals using **Revision history**. Task or calendar edits invalidate an open proposal. Working hours default to 09:00–17:00 with a 12:00–13:00 break and can be adjusted per day.

The calendar uses device-local dates and wall-clock times. Interruption reporting currently uses the Calendar form. Future focus integration can call the same preview method with a stable interruption event ID. Elapsed minutes are derived from the approved schedule on this branch. Actual time from Oumayma’s focus module can replace that estimate during integration.

## AI

Start the local Node service using the [task service setup](README.md). The calendar uses the same URL and provider settings.

- **Ask planning AI** interprets a single unavailable interval or a replacement work window for the displayed date. Select that date before asking. The engine calculates all task times. Review and approve the resulting proposal to save.
- **Explain with AI** uses the engine’s actual changes, including times and reasons, as read-only context. The original before and after comparison remains visible if AI is unavailable.

Both deterministic workflows operate without provider credentials. The service binds to localhost for development.

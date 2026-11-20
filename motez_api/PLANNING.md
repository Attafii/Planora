# Planify calendar and scheduling

Start the [integrated Planify app](../docs/PLANIFY_INTEGRATION.md) and open **Calendar**. Month, Week, and Day show real dates. Select a date to see the approved agenda and unfinished work without an approved slot. Add a fixed commitment or break, edit its time to move it within that date, or remove it. These edits open a review before any schedule changes. Adjacent reservations can touch. New or changed reservations that overlap an existing commitment or break are rejected. A reported interruption can overlap an existing reservation because it records additional unavailability.

## Scheduling and constraints

Planify reads Motez's existing personal task store. Tasks with incomplete prerequisites stay unscheduled, even when a prerequisite is placed earlier in the proposal. Ready tasks are ordered by due date, then stable task ID. The engine uses the task estimate and looks for one contiguous interval within working hours after accounting for reservations, elapsed plan time, and any selected task time window. A time window is a hard constraint for the selected date. Infeasible work appears in the review with its reason and in the agenda as unscheduled work.

Working hours, commitments, breaks, task windows, and interruptions can be entered offline. Cloud AI can interpret one unavailable interval or one replacement workday on the selected date. The resulting times open in an editor where they can be corrected before previewing. Ambiguous or unsupported requests ask for clarification. AI can highlight changes; the app shows the engine's actual times and reasons. Cloud AI requires account consent and a configured compatible provider. See the [agent setup](README.md).

Calendar dates use the account's IANA timezone in the integrated app. Existing date and wall-clock values stay readable, and a timezone preference change keeps those civil dates and times. A range can end at 24:00; overnight events use separate dates. Planify avoids skipped and repeated minutes at daylight-saving changes. Hours can span the transition, with the affected minutes excluded from placement. New reservations and task windows must use unambiguous minutes.

## Approval, recovery, and sync

An interruption review can start from Calendar or from Focus after logging a disruption, or from the overrun action on an active timer. The interruption window is editable. The proposal retains unaffected elapsed plan slices, protects reservations, and allocates remaining estimated time. Focus records actual time separately. Only approval changes the calendar.

Failed saves leave the proposal open. A changed task, day revision, timezone, or reloaded device snapshot invalidates the proposal. Recalculate to review the latest inputs; changes to the same reservation or constraint require reopening its editor. Retrying a successful approval or an already applied interruption cannot create another revision.

New revisions store the approved blocks, reservations and task windows alongside the change log. Preview restore on an editable date to reuse the earlier constraints and favor earlier slots that still fit. Approval creates a new revision and preserves the elapsed plan. Older revisions remain readable as change logs.

Approved edits use Eya's account-scoped planning snapshot, offline queue, retry, and whole-collection conflict review. See [session and sync](../docs/EYA_SESSION_AND_SYNC.md). The API and database schema retain the same snapshot contract; new snapshot fields are optional. External calendar import and export require a configured provider and an authorized connector. Calendar shows the unavailable state while local planning is usable.

The optional `PLANNING_API_URL` setting is a separate Assistant-to-planner adapter; it does not configure an external calendar provider.

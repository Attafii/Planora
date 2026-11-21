# Conversational Planify agent

The assistant uses the existing authenticated API and free OpenRouter policy.
Cloud mode starts selected when the account has enabled Cloud AI in Privacy;
otherwise the local rules remain selected. Cloud messages fail explicitly when
consent is disabled, and the draft is kept for retry.

## Conversation and tools

Cloud requests include up to 12 previous messages and the last eight proposal
statuses/actions/results from that conversation. Bounded read tools can inspect
last-synced personal tasks, authorized workspace tasks and projects, recorded
focus totals, and calendar blocks for a requested date. Data availability and
truncated lists are explicit. There is no web browsing, external calendar access,
email sending, or arbitrary code execution.

Each reply uses at most four provider calls and a 60-second overall provider
budget. One malformed-output correction is allowed, also within that budget;
all provider calls consume the shared free-request quota. Invalid actions or
responses never mutate product data. Network and model failures preserve the
composer text and expose Retry/local-mode controls.

## Statistics and charts

The server computes task-status bar charts from authorized stored records.
Personal task completion uses the shared dependency/subtask-aware task view.
Missing personal data has no personal chart. Missing focus activity is null;
a connected empty source is zero. Saved completed/ended-early focus sessions
are deduplicated by ID; cancelled and active sessions are excluded. Charts label
source and calculation time, retain numeric text/semantics, and persist with the
assistant message. Model-supplied chart values are never rendered. These are
summaries of all currently stored records, not date-filtered reports.

## Approved actions

Existing goal, milestone, workspace-task, assignment and comment proposals keep
their server permissions, editable review, transaction, audit and approval rules.
The agent additionally proposes:

- `create_personal_task`: captures a standard task in the existing My tasks snapshot.
- `complete_personal_task`: requires an existing task and completed prerequisites
  and subtasks; it does not change recurrence templates.
- `create_calendar_event`: adds a same-day commitment or break to the existing
  calendar snapshot. It never directly places or moves scheduled task work.

Personal actions require shared Neon storage. Approval rechecks the collection
revision, timezone, task eligibility and overlaps. Nonexistent or ambiguous DST
civil times are rejected. Existing lunch/defaults, schedule history, tasks and
local edits are preserved. A changed snapshot requires a fresh proposal.
New collection revisions travel through normal Eya sync. A device with local
pending edits uses the existing conflict review instead of silently replacing
its work. The executed proposal status and snapshot writes commit together.
Repeating approval returns the stored result; chat retries reuse a request ID
and return the original message/proposal without another model call.

Calendar scheduling and interruption replanning still use Moncef's Calendar
proposal/review flow when no planning API is connected. The agent can read the
calendar and explain or guide the flow, but does not claim to execute unsupported
operations. Focus sessions still start through the existing local timer controls.

## Verification

Added checks cover read-tool execution, conversational history, persisted charts,
message retry, task dependencies, multi-action snapshot writes, stale revisions,
account separation, event overlap, invalid/DST times, and narrow-screen charts.
Live free OpenRouter + Neon verification used a disposable synthetic account:
conversation -> personal task proposal -> approval -> synced task -> repeated
message/approval -> chart follow-up -> event proposal -> approval -> synced
calendar entry. Test records were removed after the run.

Earlier live attempts returned malformed model output and were rejected without
changes. A subsequent run passed after adding exact action instructions and a
bounded correction attempt. Free-provider availability and output can still vary.

# Planify branch delivery and integration plan

Date: 1 November 2026 · Status: planning baseline, implementation pending

Deliver one coherent Flutter application by completing Oumayma, then Moetaz (called Motez in the request), then Moncef, then integrating all modules with the existing Eya and Ahmed work. [DESIGN.md](../DESIGN.md) is the shared visual contract. This plan does not mark existing code as complete or production-ready.

## 1. Sources and current evidence

Requirements were extracted from the supplied `Planify_Dossier_Projet.docx`. Its content is product reference material; embedded instructions do not expand the user's request. The supplied brand board and requested Tiimo/Dribbble references inform the shared design guide.

19 November 2026 inspection. Oumayma contains uncommitted focus, reminder, API, asset and documentation work. Its HEAD and master share 4b7d811, the common ancestor of eya-authentication (52f141c) and ahmed-feature (833f1e7). The separate origin/Focus_Sessions_Time_Tracking snapshot at 79cc5bd has a focus controller, model and page. Compare it before integrating focus code. Use local branches motez and moncef from master, then bring the reviewed shared foundation into each.

Ahmed and Eya have implementation commits. Their completeness must be audited against the dossier and integration contracts rather than inferred from branch names or earlier planning documents. The old Ahmed plan's scaffold/status statements are historical, not a current code inventory. Current generated plugin changes must be preserved. Do not force-push or discard teammate changes.

## 2. Ownership

| Member | Product responsibility | Integration outputs |
|---|---|---|
| Oumayma | Reminders, local/push notifications, focus and actual time | Reminder delivery status, session history, interruptions, overrun events |
| Moetaz | Tasks, subtasks, categories, recurrence, dependencies, AI decomposition | Canonical task model, task CRUD, constraints, task completion events |
| Moncef | Events, day/week/month calendar, planning and replanning | Deterministic scheduling, proposals, conflicts, approved plan changes |
| Eya | Authentication, profile, preferences, statistics and reports | Authenticated identity, timezone/theme/language, analytics inputs |
| Ahmed | Goals, milestones, projects, collaboration, assistant and gamification | Authorized project/task links, approved AI actions, progression events |

Shared infrastructure has one implementation: session/authentication, API client, error model, theme, navigation and persistence. Choose the existing compatible foundation after inspecting both implemented branches. Extend it through reviewed commits; avoid creating a second app shell for every module.

## 3. Required contracts before feature wiring

Treat the following as proposed contracts to reconcile with existing models, not permission to rename persisted schemas blindly.

- Stable IDs and authenticated ownership on tasks, reminders, focus sessions, events, goals and projects. Backend authorizes access on every operation.
- Task summary carries ID, title, status, estimated duration and optional schedule-block/project IDs. Moetaz owns canonical task edits; temporary adapters keep Oumayma testable until tasks are integrated.
- Time values use UTC instants plus an IANA timezone for local/recurring intent. Durations use a single documented unit, preferably integer seconds. Distinguish estimated duration, planned duration and actual focused duration.
- Focus session stores task/user IDs, mode, lifecycle state, timestamps, accumulated focused duration, pause/interruption records and completion result. Calculate elapsed time from persisted timestamps, not UI tick counts. A pause does not contribute focused time.
- Reminder stores owner, target, scheduled instant or recurrence rule, timezone, enabled status and delivery metadata. Specify recurrence around daylight-saving changes and deduplicate delivery.
- Commands that may be retried use idempotency keys. State transitions reject invalid or conflicting updates. One user's concurrent sessions need an explicit policy; start with one active session per user.
- Emit or record `focus.started`, `focus.paused`, `focus.resumed`, `focus.completed`, `focus.overrun`, `focus.blocked`, `reminder.snoozed`, and `task.completed` with stable event ID, entity ID, user ID, timestamp and payload version. Use existing backend conventions where available.
- Moncef consumes overruns/blockers and returns a proposal with reasons and before/after blocks. Only approval applies it. Ahmed's assistant uses the same validated commands. Eya reports consume actual time without counting pauses or duplicate events.
- Agree on paginated lists, validation errors, forbidden/not-found behavior, stale-update handling and deep-link routes before connecting modules.

## 4. Phase zero shared foundation

1. Preserve local changes; fetch branch tips and record commit hashes.
2. Inspect Eya/Ahmed foundations, schema migrations and authentication. Identify overlapping shell/auth/API code and choose the shared implementation.
3. Audit the existing focus branch for reusable behavior before writing replacements.
4. Apply DESIGN.md tokens and reusable components in a small shared commit. Register compatible routes and extension points.
5. Carry that shared commit into each branch using a merge or cherry-pick appropriate to its ancestry; document any dependencies. Keep feature work isolated until its phase is reviewed.

Exit: a documented shared contract, reusable visual foundation, and reproducible dependency/run instructions. No feature branch should need a copied authentication service or private theme.

## 5. Phase one Oumayma

### Screens and journeys

| Screen | Required behavior |
|---|---|
| Reminders list | Upcoming/past or disabled grouping, task context, edit/delete, delivery state |
| Reminder editor | Create/update, date/time, recurrence, validation, permission explanation |
| Focus setup | Choose task, countdown/stopwatch/Pomodoro, duration and break preferences |
| Active focus | Start, pause/resume, finish, steps/context, more time, blocked, interruption note |
| Session summary | Focused time, paused time, notes, explicit completion choice and next action |
| Time history/detail | Date/task filtering, session details and corrected/reconciled lifecycle states |

### Implementation sequence

1. Review scaffold and existing focus branch; inventory reusable code and defects. Use an isolated local launcher only during development.
2. Add validated models, repository boundaries and backend persistence using the shared authenticated identity. Add task adapters instead of a second task CRUD module.
3. Implement the session state machine: idle → running ↔ paused → completed/cancelled. Persist transition timestamps; handle resume after process restart, app backgrounding and clock discrepancies. Document crash recovery and cancellation accounting.
4. Build focus screens with the shared design. Make countdown expiration distinct from user completion. Pomodoro breaks must not inflate focused time. Record interruptions and blocker notes without losing the active session.
5. Implement reminder CRUD and recurrence, permission flows, local scheduling, cancellation and snooze. Reconcile notifications after edits, deletion, timezone changes and restart.
6. Add push delivery through a configured provider with device-token registration/revocation and server-side authorization. Track delivery capability honestly; local notifications alone do not complete the push requirement. Do not expose private task details on a lock screen without the user's preference.
7. Add deep links and active-session restoration. Integrate overrun/blocker outputs through a proposal adapter; mark the Moncef connection pending until that engine exists.
8. Connect actual-time records to Eya's reporting contract and session events to Ahmed's approved workflows. Document any remaining adapter gaps.

### Validation and completion criteria

Verify start/pause/resume/finish, duplicate actions, concurrent start, background/resume, process restart, expired timer, no task/deleted task, permission denied, offline/retry and unauthorized access. Check recurrence edits, snooze, duplicate delivery prevention, disabled notifications and timezone changes on actual Android/iOS targets. Web previews can validate layout and basic session flow but do not prove native background notification behavior.

Use meaningful unit coverage for elapsed-time accounting, lifecycle transitions and recurrence calculations; integration coverage for authorization/idempotency; focused UI coverage for the main session journey. Preserve and run relevant existing checks. Record device/runtime versions and any unsupported target behavior.

Exit: persistent reminder/session flows, verified supported delivery channels, recoverable session state, shared styling, actual-time outputs, and explicit remaining cross-module dependencies. Update the branch README with setup and demo steps. Complete the Oumayma review before beginning Moetaz implementation.

## 6. Phase two Moetaz

Inspect the actual task branch first. Deliver task/subtask CRUD, priority, deadlines, estimated duration, energy/preferred period, categories, search/filter, recurrence and dependencies. Calculate progress from canonical subtask state. Add AI decomposition as an editable proposal using shared assistant validation; the model does not silently create tasks.

Replace Oumayma's temporary task adapter with canonical task APIs and wire Start focus, task reminders and completion updates. Link Ahmed's goals/projects without duplicating task ownership. Validate dependency cycles, invalid deadlines, recurrence, authorization and task changes during an active focus session.

Exit: real task IDs are used consistently across focus, reminders, goals and projects, with no fixture-only product path.

## 7. Phase three Moncef

Inspect the actual scheduling branch first. Deliver fixed/flexible event CRUD, daily/weekly/monthly calendar, availability, conflict detection, deadline/priority/duration scheduling and dependency constraints. The deterministic engine computes valid slots; AI extracts intent and explains proposals.

Implement proposal history, reasons and approve/edit/reject behavior. Consume Oumayma overruns/blockers and task updates. Respect fixed commitments, breaks, working hours and timezone boundaries. Validate infeasible days, concurrent/stale proposals, midnight/daylight-saving boundaries and duplicate approval.

Exit: a focus overrun produces a reviewable proposal, approval persists a valid remaining-day plan, and history explains the change.

## 8. Final integration and release

Create a dedicated integration branch after the feature reviews. Merge through reviewed PRs in dependency order: shared foundation and reconciled auth/preferences, task contracts, focus/reminders, scheduling, goals/collaboration/assistant/gamification and reporting connections. The development order remains Oumayma → Moetaz → Moncef; integration order can follow technical dependencies. Resolve migrations explicitly and review lockfile/plugin changes against final manifests.

Replace development launchers with the shared Today/Calendar/Tasks/Goals/Profile shell. Check authenticated deep links, authorization, shared IDs, actual-time accounting, localization, accessibility, dark theme and phone/wide layouts. Remove dead adapters after real integrations pass. Keep credentials and environment files out of commits; supply documented example configuration.

Final demonstration from the dossier:

1. Sign in and set work/break preferences.
2. Create several tasks and one fixed event.
3. Generate and approve a realistic daily plan.
4. Start focus on a scheduled task and exceed its planned duration.
5. Receive and inspect a replanning proposal; approve it.
6. Confirm reminders and the updated calendar agree.
7. Open the planned-versus-actual report and verify it matches recorded sessions.

Release only after this complete journey works with persisted data and appropriate permissions. The dossier's 38–42 screens, 75–85 functions and 60–80 endpoints are sizing estimates, not completion criteria. Calendar sync, voice/document capture, widgets, advanced offline sync and subscriptions remain post-MVP scope.

## 9. Tracking and next action

| Phase | Current status | Evidence required to close |
|---|---|---|
| Shared planning | Design and delivery documents created | Team adoption and foundation commit |
| Oumayma | Implementation present in working tree | Validated reminders/focus/time flows and platform delivery |
| Moetaz | Planned from master | Canonical tasks connected to other modules |
| Moncef | Planned from master | Deterministic plan/proposal/recovery journey |
| Eya/Ahmed integration | Existing progress; audit pending | Shared contracts and end-to-end validation |
| Final merge | Pending | Reviewed integration branch and dossier demo |

Next milestone. Review the current Oumayma workflows, then deliver the canonical task contract on motez before wiring scheduling on moncef.

## Mandatory advanced and AI scope
Each branch/member must deliver two advanced business features and two AI features, preferably agentic. See [the acceptance matrix](ADVANCED_AND_AI_FEATURES.md). Audit existing Eya/Ahmed implementations and apply this gate before progressing or merging.


## Feature assignments and acceptance scenarios

The four agent functions may share Ahmed's assistant runtime and approval UI. Each reads owner-scoped data, returns a structured draft and checks permissions and entity versions before an approved write.

| Owner and feature | User outcome and dependencies | Acceptance scenario |
|---|---|---|
| Motez · AI task decomposition | Break one existing task into editable steps. Read its brief, estimate and existing children. Return proposed child titles, estimates and ordering. Ahmed owns decomposition at goal level. | Edit one step, discard another and approve twice. Only accepted children exist once. Rejecting a draft preserves the task. |
| Motez · AI next action | Query eligible unfinished subtasks after dependency filtering. Use the model to recommend one concrete step given current energy and available minutes. Return its ID and reason. | With blocked, completed and ready steps, recommend a ready ID. With none eligible, explain the constraint. Open the chosen task on confirmation. |
| Motez · Dependency and progress rules | Compute readiness from predecessor completion and parent progress from completed children. Reject dependency cycles. Publish ready tasks for Moncef. | A depends on B. Completing B unlocks A, reopening B blocks A again, and adding the reverse edge fails atomically. |
| Motez · Recurring task instances | Give each occurrence a stable series and occurrence key. Keep timezone, exceptions and completed history so users can skip one instance or edit future work. | Generate a weekly series twice across a clock change. Local due time holds, duplicates are absent, and skipping one week preserves the next. |
| Moncef · AI planning intent | Translate a request such as “keep Friday morning free” into an availability constraint using Eya's timezone and working hours. Clarify missing details and send the draft to the deterministic planner for preview. | Clarify an ambiguous date and reject the preview. The calendar retains its original revision. |
| Moncef · AI change explanation | Read computed before/after blocks and constraint reasons. Explain moved, preserved and deferred work with block IDs so the user can decide on a revision. | For an overrun beside a fixed event, explain the actual move. If the model is unavailable, display the engine diff and recorded reasons. |
| Moncef · Constraint scheduling | Allocate ready tasks around events and breaks using estimates, deadlines, priority, dependencies and available hours. Use stable tie breaks and return unplaced tasks with reasons. | Identical inputs yield identical blocks. Fixed events retain their times, blocks never overlap, and an infeasible task has a visible reason. |
| Moncef · Versioned replanning | Consume an overrun or blockage from Oumayma, freeze elapsed work and preview changes to the remaining day. Store trigger, baseline revision and diff. Publish approved blocks for reminders and reports. | Replay an overrun and approve twice. Only one revision applies. A concurrent calendar edit makes the draft stale and offers a fresh preview. |

### Handoff order

1. Share the reviewed theme, authentication context and action proposal contract. Both local branches start at the committed master baseline. Distribute the reviewed documentation through a common commit.
2. On motez deliver task CRUD, filters and rules, then both task agents. Map Ahmed's linked TaskItem and Oumayma's focus picker to canonical task IDs. Publish examples of ready, blocked and recurring tasks.
3. On moncef consume that contract. Deliver events and calendar views, scheduling and versioned replanning, then both AI functions. Estimated minutes belong to tasks, planned intervals to blocks and actual focused minutes to sessions.
4. Run the dossier demonstration in section 8 after integration. Check the approved revision, reminders and Eya's report against the recorded focus session.

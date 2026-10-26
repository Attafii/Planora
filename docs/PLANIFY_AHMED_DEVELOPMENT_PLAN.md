# Planify — Ahmed's feature and view development plan

Date: 13 October 2026  
Owner: Ahmed  
Scope: goals, milestones, collaboration, agentic assistant, gamification  
Status: implementation plan; screens and services are not implemented yet

## 1. Understanding the product and current repository

Planify is an adaptive daily productivity app built around capture, planning, execution, recovery and reflection. A dedicated backend should enforce scheduling and authorization; the AI interprets intent and proposes actions. Users approve consequential changes before those changes reach persisted product data.

The attached DAYPILOT_PRODUCT_SPEC.md is product reference material. The name is Planify, as instructed by Ahmed. Its instructions for coding assistants do not expand this request into implementation or authorize work on teammates' modules.

Current repository findings:

- `lib/main.dart` launches the original Flutter counter demo.
- `lib/app/` and `lib/core/` contain named architecture placeholders, but all their Dart files are empty.
- There are no feature screens, domain models, controllers, repositories or backend files in this checkout.
- `pubspec.yaml` contains Flutter and Cupertino Icons; routing, application state and networking choices are not configured.
- `test/widget_test.dart` is the generated counter test.
- Brand assets exist under `assets/branding/`. The latest guideline board includes the approved logo, sampled colors and Manrope/Inter typography.
- Fonts and logo are not registered as Flutter assets. Application metadata still uses the starter names.

The immediate need is a small working foundation and Ahmed's connected feature flows. Branded screenshots alone would not complete the features.

## 2. Ownership and integration boundaries

| Ahmed owns | Required integration | Teammate's ownership |
|---|---|---|
| Goal and milestone CRUD; links between goals and tasks | Task summaries, task creation/detail navigation, completion changes | Moetaz: tasks and subtasks |
| Goal decomposition proposal and approval UI | Validated task creation; task constraints and dependencies | Moetaz: task data and decomposition services |
| Shared projects, invitations, project permissions, assignments, comments and activity | Task records and assigned-task updates | Moetaz: task editing and task status |
| Assistant conversation, tool orchestration, action preview, approval and action history | Planning/replanning tool result and proposal navigation | Moncef: scheduling engine, calendar and planning UI |
| Assistant entry to blocker and reminder tools; achievement events | Focus/session/reminder events and notification deep links | Oumayma: focus, reminders and notifications |
| Feature access for the current user; achievements entry | Authenticated identity, timezone, language, privacy/AI preferences | Eya: authentication, profile, preferences and analytics |

Ahmed implements the UI and behavior of his modules, plus their backend contracts and services where backend ownership is assigned to him. Shared infrastructure needs a coordinated owner. No second authentication flow, task editor, scheduling algorithm, focus timer or analytics dashboard is needed inside these modules.

## 3. Brand translated into mobile UI

### Source and visual direction

Use the supplied logo in `assets/branding/identity-source/approved-logo.png` and the latest `planify-brand-guidelines.png` as the reference. Keep the original wordmark and symbol proportions. Extract an intact signet for compact use; do not recreate it with text or icons.

The interface should communicate calm direction and manageable progress. Translate the logo's rounded bars into restrained progress indicators and its endpoint into selected-state markers. Give each screen a clear primary action and generous spacing.

### Proposed application tokens

| Token | Value | UI role |
|---|---|---|
| Ink | `#011133` | Main text, primary buttons, navigation |
| Route blue | `#0174FB` | Active indicators, links with verified contrast, selected borders |
| Endpoint teal | `#01C0C2` | Progress accents and positive supporting graphics |
| Momentum violet | `#4C58FC` | Assistant/proposal accents and achievement illustrations |
| Paper | `#FAF9F6` | Main page background |
| Surface | `#FFFFFF` | Forms, sheets and content surfaces |
| Outline / secondary text | Neutral values chosen against the background | Boundaries and hierarchy; verify contrast |

The four brand colors are sampled from the approved logo; they supersede the earlier exploratory board's approximate swatches. Error and warning colors are additional semantic UI tokens, not new brand colors. Always pair them with text and icons.

Use navy for the primary CTA. Reserve the gradient for the intact logo, assistant cover detail or a small success graphic. Blue and teal need contrast verification before use as small text or behind white labels. Achievement status, priority, permissions and errors must remain understandable without color.

### Type, spacing and components

- Manrope 600: page titles 28–32 logical pixels; section titles 20–24.
- Inter 400/500/600: body 16, secondary text 14, labels 12–14, controls 16. These mobile sizes adapt the editorial brand hierarchy.
- 8-unit spacing rhythm; 20–24 page padding; 16–24 between related sections; 32 between major sections.
- Minimum 48 logical-pixel tap targets, readable text scaling and screen-reader labels.
- Rounded controls with restrained 12–16 corner radii; capsules only for chips and progress bars. Avoid putting every item inside a floating card.
- Fine dividers, minimal shadow, clear loading/error states and a stable action area above the keyboard.
- Light theme first. Support the shared theme setting through semantic tokens; do not add a separate theme preference owned by Ahmed.
- Register only production logo/icon/font assets in Flutter. Large guideline PNGs, rendering scripts and mockup source files stay outside the app asset bundle.

Reusable components: goal row, milestone row, linked-task summary, project row, member row, role chip, invitation state, activity entry, comment thread, assistant message, action proposal, before/after change, achievement badge, progress meter, empty state, retry state and confirmation dialog.

## 4. Navigation

Final app navigation remains Today / Calendar / Tasks / Goals / Profile, with a global assistant action.

- Ahmed supplies the Goals route and its descendants.
- A Projects entry from Goals opens collaboration; shared goals link to their project workspace.
- The assistant opens as a full page and can carry context from the current goal or project.
- Achievements are accessible through Eya's Profile route. Goal completion can also link directly to the relevant achievement.
- Invitations enter through a link or Oumayma's notification deep link. Authentication resumes that route after login.
- Task rows open Moetaz's task details. Planning proposals open Moncef's planning review. Focus actions open Oumayma's session flow.
- During isolated development, use a clearly labeled local feature launcher and demo identity. It is a temporary development entry, not a replacement product navigation scheme.

All routes require stable entity IDs. Authorization failures return useful feature states rather than exposing private content.

## 5. Complete page inventory: 17 reusable pages

Create/edit variants share one page. Tabs are states of their parent page. Supporting sheets are listed separately.

### Goals and milestones — 4 pages

| ID / proposed route | Layout and content | Main behavior | Required states |
|---|---|---|---|
| G01 `/goals` | Title, Personal/Shared filter, search, active goals with progress and target date; compact Projects entry | Create goal, open goal, filter by status/visibility | Loading; empty first goal; no search results; error/retry |
| G02 `/goals/new` or `/goals/:id/edit` | Focused form: title, description, start/target dates, personal/shared visibility, authorized project association | Validate and save; warn about unsaved edits | Invalid dates/title; saving; server validation; permission loss |
| G03 `/goals/:id` | Goal title/status, meaningful progress, milestone list, related tasks and shared members; context actions | Add/edit milestones; link tasks; open task; update/delete goal with confirmation; request decomposition | No milestones/tasks; read-only shared goal; unavailable linked task; progress refresh |
| G04 `/goals/:id/decomposition` | Concise AI rationale, editable milestone/task proposal, estimates, dependencies, warnings and selection controls | Edit/select/reject suggestions; commit only after approval | Generating; essential clarification; AI unavailable; invalid proposal; applying; confirmed/failed result |

Goal progress is supplied by the backend. Agree how milestone completion, task completion, cancelled tasks and unlinked goals contribute before treating a frontend formula as authoritative.

### Collaboration — 6 pages

| ID / proposed route | Layout and content | Main behavior | Required states |
|---|---|---|---|
| C01 `/projects` | Owned/joined project list, member preview, concise progress and invitation entry | Create/open project; view pending invitations | Empty; loading; invitation pending; error |
| C02 `/projects/new` or `/projects/:id/edit` | Name, description and project options permitted by the final contract | Create/update project; preserve form on failure | Invalid form; saving; conflict; unauthorized edit |
| C03 `/projects/:id` | Workspace tabs: Overview, Tasks, Discussion, Activity. Overview contains shared goals and lightweight team progress | Link/open tasks; assign where allowed; comment/mention; inspect activity; open member management | Empty project/tasks/thread/activity; pagination; read-only role; member access revoked |
| C04 `/projects/:id/members` | Searchable member list with explicit owner/admin/collaborator/viewer labels | Invite; change permitted roles; remove member with confirmation | Role restrictions; last-owner safeguard; failed update; stale membership |
| C05 `/projects/:id/invitations` | Authorized invitation list: pending, accepted, rejected, expired, revoked | Create/copy invitation link; invite by email; revoke pending invitation | Invalid email; already a member; duplicate invitation; expiry; failure |
| C06 `/invitations/:token` | Project/sender summary limited to safe invitation information, offered role and expiry | Accept/reject; authenticate and resume when needed | Valid; expired; revoked; already handled; wrong account; access denied |

Task detail/editing remains in Moetaz's module. Team progress here is project-level completion and blockers; advanced analytics remain outside this UI scope. Use refresh/pagination first; live updates are an optional later enhancement.

### Agentic assistant — 4 pages

| ID / proposed route | Layout and content | Main behavior | Required states |
|---|---|---|---|
| A01 `/assistant/conversations` | Recent conversations with title/context and new conversation action | Start/open conversation; resume prior context | Empty; loading; pagination; error |
| A02 `/assistant/conversations/:id` | Message thread, goal/project context chip, input area, concise suggestion chips and visible proposal cards | Send prompt; answer clarification; request cancellation when supported; open review | Sending; waiting; clarification; AI disabled/unavailable; retry; cancelled result |
| A03 `/assistant/proposals/:id` | Action list, affected records, before/after values, reasons, risk, warnings and preview | Edit/select actions if the backend supports it; approve/reject; open domain planning preview | Validated pending; expired/stale; invalid; applying; partial result if supported; confirmed success/failure |
| A04 `/assistant/actions` | Filters for pending, approved, rejected, executed and failed; timestamp and outcome summaries | Inspect action details; navigate to confirmed affected records | Empty; pagination; denied action; failed tool call; inaccessible record |

Agent states should distinguish proposal approval from execution completion. The UI must not say “created” until the backend confirms creation. Read-only assistant requests can return answers directly; mutations use the approval flow.

### Gamification — 3 pages

| ID / proposed route | Layout and content | Main behavior | Required states |
|---|---|---|---|
| R01 `/achievements` | Current level, transparent progress, planning/focus streak, unlocked and upcoming badge list | Open badge; explain streak/level rules; open challenges | No achievements; loading; no activity data; rest-day explanation |
| R02 `/achievements/:id` | Large restrained badge, criteria, verified progress, earned date where applicable | Explain next eligible action; navigate to the relevant existing module | Locked; in progress; earned; unavailable criteria data |
| R03 `/challenges` | Available/active/completed challenges with criteria, period and progress | Open challenge; join/leave if rules permit; inspect completion | None available; active; complete; expired; error |

Ship basic achievements in the academic MVP. Streaks, levels and challenges remain in the complete ownership plan but follow verified event tracking. Point thresholds, rest-day policy, eligibility and repeatability are product rules to settle before coding. Do not reward task creation alone, punish approved rest days or add public leaderboards by default.

## 6. Supporting sheets and dialogs — 10 reusable surfaces

1. **Milestone editor:** create/edit title, description, order and dates; show linked-task effects.
2. **Linked-task picker:** search authorized task summaries, select/link/unlink, open the owner's create-task route.
3. **Invite composer:** email or invitation link, allowed role, expiry and share/copy outcome.
4. **Role editor:** allowed role changes, permission explanation and backend validation feedback.
5. **Task assignment picker:** project task, permitted assignee(s), current assignment and save result.
6. **Comment composer:** add/edit text, authorized member mentions and useful failure recovery.
7. **Action detail:** validated arguments, reason, approval/execution timestamps, tool result and audit ID.
8. **Challenge detail:** eligibility, criteria, progress, time window and join/leave control.
9. **Streak and level explanation:** server-defined criteria, timezone, rest-day policy and next milestone.
10. **Shared confirmation dialog:** goal/project deletion, member removal, invitation revocation and other consequential changes. Name the affected entity and any known consequences.

Destructive confirmation is separate from unsaved-edit confirmation. The backend remains authoritative about permissions and cascade effects.

## 7. Development sequence and completion gates

| Milestone | Work | Completion gate |
|---|---|---|
| 0. Foundation and contracts | Shared theme tokens; font/logo registration; Ahmed route entry; common states; typed repository interfaces; team integration contracts | Ahmed's feature launcher displays branded routes and honest fixture states without pretending a backend exists |
| 1. Goals and milestones | G01–G03; milestone editor; task-link picker; create/update/delete, progress display and permissions | A user creates a goal, adds milestones, links authorized tasks and sees persisted changes after reopening |
| 2. Collaboration | C01–C06; assignment, role and comment surfaces; activity and basic team progress | Two accounts complete invitation/assignment/comment flows; a viewer cannot mutate project data |
| 3. Assistant approval foundation | A01–A04; structured proposal UI; approval/rejection history; start with one validated tool | A proposal changes no product records before approval; approval executes once and displays the backend-confirmed outcome |
| 4. Goal decomposition and domain tools | G04; goal/milestone/task tools; integrate planning/replanning previews with Moncef | A revision-plan request yields editable tasks/milestones and a validated planning proposal; locked commitments are protected by the planning service |
| 5. Basic achievements, then full gamification | R01–R02 and server-derived achievement events first; R03, streaks and levels after rules are defined | Eligible real completion events unlock a badge once; duplicate events do not award duplicate progress |
| 6. Final integration and polish | Shared navigation, authenticated deep links, permission changes, localization, accessibility and relevant flow checks | Ahmed's demonstration scenario works with the team's real services and all critical empty/error states |

Build each module through fixture-backed UI, real repository integration and complete user flow. Fixture-backed pages are an intermediate deliverable; backend-dependent functionality is not complete until validated against real endpoints.

The first implementation slice should be Milestone 0 plus G01–G03. AI and gamification become more useful after goals, tasks, projects and reliable activity data exist.

## 8. Suggested Flutter organization

Keep the existing `app/` and `core/` locations. Fill shared files in coordination with the team. Add Ahmed's modules using a small, repeated structure:

```text
lib/
  app/
    app.dart
    router/app_router.dart
    theme/{app_colors,app_text_styles,app_theme}.dart
  core/
    network/                 # shared authenticated API access
    services/                # shared storage and notification interfaces
    errors/
    widgets/                 # states, dialogs and common controls
  features/
    goals/
      models/
      data/                  # repository contract and implementations
      presentation/          # pages, controllers and local widgets
    collaboration/
      models/
      data/
      presentation/
    assistant/
      models/
      data/
      presentation/
    gamification/
      models/
      data/
      presentation/
```

Use the team's chosen state management and router consistently. Keep network calls outside widgets. Use simple typed models and controllers first; avoid adding layers or packages without a concrete need. Backend framework and LLM provider remain team decisions.

## 9. Data and API contracts

### Entities required by the spec

Goal, Milestone, Project, ProjectMember, TaskAssignment, Invitation, Comment, ActivityLog, AgentConversation, AgentAction, Achievement and UserAchievement.

Needed shared references: current authenticated user, task summaries, task status, project authorization, planning proposal, user availability/preferences, focus events and verified productivity metrics.

Proposed additional DTOs, not existing spec entities: GamificationSummary, Challenge, UserChallenge, and a structured ActionBatch/Proposal result if multiple actions need shared approval.

### Endpoints already outlined in the specification

- Goals: `GET/POST /goals`, `PATCH/DELETE /goals/{goalId}`, `POST /goals/{goalId}/ai-decomposition`.
- Projects: `POST /projects`, `POST /projects/{projectId}/invitations`, `GET /projects/{projectId}/members`, `PATCH /projects/{projectId}/members/{memberId}`, `POST /projects/{projectId}/comments`.
- Assistant: `POST /assistant/messages`, `GET /assistant/actions/{actionId}`, `POST /assistant/actions/{actionId}/approve`, `POST /assistant/actions/{actionId}/reject`.

These are outlined contracts, not implemented endpoints in this repository.

### Missing contract coverage to agree before connecting views

| Area | Proposed contract capability |
|---|---|
| Goals | Goal detail; milestone CRUD/reordering; authorized task link/unlink; progress summary; accepted decomposition result |
| Projects | Project list/detail/update/delete; tasks and progress; assignment operations; member removal/leave rules; paginated comments/activity |
| Invitations | List; safe token lookup; accept/reject/revoke; expiry; duplicate protection; authentication/account binding |
| Assistant | Conversation list/detail/history; pending action list; proposal retrieval/version; structured validation; cancellation support; batch approval behavior |
| Gamification | Achievement catalogue and user progress; summary; streak/level rules; challenge list/detail/join/leave |

Use consistent IDs, server timestamps, timezone semantics, pagination, error codes and validation payloads. Approval requests need idempotency, authorization and stale-proposal checks. Decide whether a batch is atomic or supports partial execution; the UI must represent the chosen behavior accurately.

### Security and business rules to preserve

- Backend authorization checks every goal/project/assistant resource; hiding a button is insufficient.
- Invitations disclose only the minimum safe information before acceptance. Expired or revoked tokens cannot grant membership.
- Members can only assign/edit tasks within their permitted project scope. Protect ownership continuity when changing roles or removing members.
- AI tool arguments and referenced IDs are validated. Keep LLM provider secrets on the backend.
- The assistant delegates schedule creation to Moncef's deterministic engine; it does not invent final calendar times.
- Revalidate context and permissions at execution time. Repeated approval must not create duplicate records.
- Preserve messages and draft forms after recoverable failures. Do not silently queue consequential offline actions.
- Record proposal, approval, rejection, execution and failure separately in the action/audit history.
- Use meaningful completion events for achievements. Avoid awarding from unverified client counters.

## 10. Common states and accessibility

Every list supports loading, empty, results, failed load/retry and pagination where needed. Every mutation distinguishes unsaved, saving, confirmed success and rejected/failed execution.

Feature-specific states include archived/unavailable goals; inaccessible linked tasks; expired invitations; changed roles; AI disabled; invalid or stale proposals; insufficient scheduling capacity returned by the planning service; failed tools; no achievement data; and offline access.

Keep recoveries specific: “Retry”, “Edit proposal”, “Request a new invitation”, “Choose another member”, “Open task” or “Return to projects”. Avoid generic toasts as the only explanation.

Respect text scaling, keyboard access, safe areas, scrollable forms and reduced motion. Give progress meters numeric labels. Make role and achievement states readable in words. Follow shared localization resources; prepare English/French copy and layouts that can accommodate longer translations.

## 11. Verification planned for implementation

Use meaningful checks for the actual rules and flows:

- Goal/milestone validation and progress contract handling.
- Repository error mapping and stale-record behavior.
- Owner/admin/collaborator/viewer authorization using separate accounts.
- Invitation expiry, revocation, account binding and repeat acceptance.
- Task assignment permissions and resulting activity entries.
- No database mutation before AI approval; rejection changes no product records.
- Invalid AI arguments, inaccessible IDs, stale proposals, repeated approval, execution failure and the agreed batch behavior.
- Achievement event deduplication, timezone boundaries and the agreed rest-day/level/challenge rules.
- Navigation to teammates' real modules, resumed invitation links, screen-reader labels and large-text layouts.

The backend enforces rules; frontend checks cover useful feedback and accurate representation. Mock data cannot validate server authorization or real AI execution.

## 12. Ahmed's demonstration flow

1. Enter through the team's authenticated app.
2. Create a revision goal and add milestones.
3. Link tasks from Moetaz's module.
4. Ask the assistant to prepare four chapters before Friday, with at most two hours per day.
5. Review/edit the structured proposal and inspect Moncef's validated scheduling result.
6. Reject one proposal to demonstrate that no records are created.
7. Approve the revised proposal and display confirmed created records and action history.
8. Create a shared project, invite a second user and assign an existing task.
9. Add a member mention and show the relevant activity entry.
10. Complete eligible work through the task/focus modules, then show updated goal progress and a verified achievement.

## 13. Decisions that affect feasibility

Resolve these at the relevant milestone rather than blocking all UI planning:

- Shared router/state-management ownership and authenticated session interface.
- Dedicated backend framework, endpoint ownership and the initial LLM provider.
- Goal/milestone progress calculation and task-link rules.
- Invitation email delivery, deep-link host and account-binding behavior.
- Which roles may assign tasks; whether multiple assignees are allowed; owner-transfer/removal policy.
- Single-action versus batch approval, atomicity and cancellation semantics.
- Streak eligibility, rest days, levels, challenge rules and basic achievement thresholds.
- Shared theme/language preferences and final translation ownership.

Recommended MVP sequence: complete goals/milestones, basic project collaboration, assistant approval and basic achievements. Then expand the same views to full conversations/history, richer decomposition, streaks, levels and challenges. This reaches all Ahmed-owned functionality without requiring him to implement the other four teammates' modules.

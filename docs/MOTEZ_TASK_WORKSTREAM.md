# Task planning and recommendations

Open **My tasks** from Today. Task breakdown uses the existing authenticated task agent with Cloud AI enabled and confirmation before sharing task context. Review, edit, reorder, remove or add steps before saving. A cancelled or failed request makes no task changes. A failed save leaves the draft open.

A task is ready when its prerequisites are complete and it has an unfinished action it can start. Reopening a prerequisite can block its dependents again. Missing prerequisite references from older snapshots block the affected task and can be removed in its editor.

Daily and weekly tasks use date-based occurrence IDs. Edit an individual date or apply changes from that date onward. A future edit keeps completed history, skipped dates and other individual edits. Turn on **Show skipped** to restore a skipped occurrence. The current task editor supports date and future scopes. Calendar scheduling continues to read the same task store.

**Find my next action** works offline. It filters completed, blocked and skipped work by available time and energy. It suggests the earliest due eligible action, then the closest fit for the time available, with stable task IDs breaking ties. Defaults are 30 minutes and medium energy. Changing those inputs recalculates suggestions. Dismissing a suggestion only affects the open review. Optional AI can choose from the same eligible actions after confirmation.

Task writes use Eya's account-scoped task snapshots, offline queue and conflict review. The JSON snapshot has an optional `occurrenceOverride` flag for individual edits. Older snapshots without it remain readable; differing editable fields identify older exceptions. The API endpoints and database schema are unchanged. See [session and sync](EYA_SESSION_AND_SYNC.md) for synchronization and retry behavior.

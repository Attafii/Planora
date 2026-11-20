# Planify design identity

## Direction

Planify helps people see their day, choose a task, focus, and recover when plans change. Use the existing path-shaped Planify symbol with evergreen, mint, and amber. Let the selected date, next action, or active focus timer establish the hierarchy on each screen.

- TaskFlow informed the task overview, progress summary, and soft grouping. [Daily planner design](https://dribbble.com/shots/27300940-Task-Management-Daily-Planner-App-UI)
- Qudra informed the calendar and dated agenda, with visual cues for different types of activity. [Calendar design](https://dribbble.com/shots/27347612-Task-Schedule-Mobile-App-UI-Calendar-Planner-App-Qudra)

## Theme and components

The Flutter theme in `lib/app/theme/account_theme.dart` supplies shared surface and state colors. Use Manrope for display headings and Inter for body text and controls. Prefer semantic ThemeData roles in new screens so labels, surfaces, and status cues remain legible in both appearances.

| Role | Light | Dark |
| --- | --- | --- |
| Workspace background | Warm cream `#F7F7EE` | Evergreen `#11211C` |
| Primary text | Pine `#193530` | Warm cream `#F7F7EE` |
| Primary action | Pine `#193530` | Mint `#93E3BA` |
| Selected container | Pale mint `#DDF1E5` | Green `#244B40` |
| Supporting accent | Amber `#C98851` | Amber `#C98851` |

Use the logo painter for theme-aware color. Reserve radial gradients for the task summary and gradient shaders for the brand mark. Use short transitions with immediate updates when reduced motion is active. Include visible status text and clear accessible labels on icon buttons.

## Navigation

The mobile workspace opens on Today, with the current or next scheduled activity, task list, day timeline and daily check-in. A translucent rounded bottom dock stays within the safe area and keeps Today, Calendar, Focus, Assistant and More within thumb reach. Tasks and Calendar share personal planning data. Focus groups its timer, reminders, and time log. The Assistant opens conversations, proposals, and action history. More links to goals, projects, rewards, challenges, and preferences. Account settings provide System, Light and Dark appearance choices.

Use recognizable create and edit actions. Keep scheduling and AI changes in review until the user approves them. Show the result, any deferred work, and the reason when a plan changes.

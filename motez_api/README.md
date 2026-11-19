# Planify task module

Run Flutter from the repository root. Tasks open on launch in this branch and persist locally on the device. Prerequisites point to individual task IDs. A parent with subtasks completes when all of its steps and prerequisites complete.

Recurring deadlines are calendar dates. Daily and weekly occurrences appear from 30 days back through 60 days ahead. Open one to edit it, edit this and future occurrences, or skip it. The series and occurrence date identify saved history and exceptions. Calendar integration can consume the task model through TaskStore.

## AI setup

Use Node.js 22 or later. Copy the example environment file to a local .env inside motez_api. Set AI_API_KEY and AI_MODEL for an OpenAI-compatible provider that supports function tools and JSON mode. Start the service from the repository root.

```sh
node --env-file=motez_api/.env motez_api/server.mjs
flutter run -d chrome
```

For Android emulator, run Flutter with `--dart-define=TASK_AI_URL=http://10.0.2.2:5141`. The default is localhost. The helper service is for local development. Deploy behind the shared authenticated Planify API before using a hosted environment.

On task detail, choose **Draft subtasks with AI**, edit or discard suggestions, then save. On the task list, choose **Find my next action** and enter your available time and energy. The app filters eligible work before contacting the model and opens the selected task only after confirmation.

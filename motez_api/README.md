# Planify task module

Start the [integrated Planify app](../docs/PLANIFY_INTEGRATION.md) and open **My tasks** from Today. Personal tasks persist on the device and sync through the account API. Prerequisites point to individual task IDs. A parent with subtasks completes when all of its steps and prerequisites complete. See [task planning and recommendations](../docs/MOTEZ_TASK_WORKSTREAM.md) for workflow details.

Recurring deadlines are calendar dates. Daily and weekly occurrences appear from 30 days back through 60 days ahead. Open one to edit it, edit this and future occurrences, or skip it. The series and occurrence date identify saved history and exceptions. Calendar integration can consume the task model through TaskStore.

## AI setup

For the integrated app, use Node.js 22.17 or later and configure `AI_API_KEY` and `AI_MODEL` in `backend/.env`. The provider must support the OpenAI-compatible function tools and JSON responses used by the task agent. Set `AI_BASE_URL` for an alternate compatible provider. Start the shared backend with `npm --prefix backend start` and enable Cloud AI in the signed-in account’s Privacy settings.

For standalone adapter development, `node --env-file=motez_api/.env motez_api/server.mjs` starts a loopback helper on port 5141. The integrated app uses the authenticated account API for task proposals.

On task detail, choose **Draft subtasks with AI**, edit or discard suggestions, then save. On the task list, choose **Find my next action** and enter your available time and energy. The app filters eligible work before contacting the model and opens the selected task only after confirmation.

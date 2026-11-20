# Oumayma AI agents

Local development service for the focus coach and natural-language reminder agent. Requires Node 22+ and an OpenAI-compatible Chat Completions provider supporting function tools and JSON mode. The two agents perform bounded read-tool calls before proposing an action. Flutter previews the action, validates constraints again, and applies it only after approval. API keys never enter the Flutter bundle.

Copy `.env.example` to `.env`, set `AI_API_KEY`, `AI_MODEL` and optionally `AI_BASE_URL`, then run from this directory:

```sh
node --env-file=.env server.mjs
```

For Chrome use the default `http://localhost:5140`. Android emulator: `flutter run --dart-define=AI_API_URL=http://10.0.2.2:5140`. iOS simulator uses localhost. This service deliberately binds to host loopback for development. Physical devices and production require an authenticated HTTPS backend deployment; do not expose this unauthenticated development service to a network.

The user sees a disclosure before generation. Only their request, recent duration/interruption statistics and upcoming reminder times/recurrence are sent; notes and task/session titles from history are excluded. Requests have size bounds, provider timeouts and a tool-step limit. Action validation rejects unsupported kinds, invalid durations and past/remote reminder dates. No fallback output is presented as AI.

`node --test server.test.mjs` checks validation and the explicit unconfigured state. Live provider generation has not been tested because model credentials were not supplied.

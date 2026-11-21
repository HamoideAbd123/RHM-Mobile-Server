# Flutter client architecture

**Status:** modularized on branch `bootstrap/import-flutter-client-2026-11-20`; CI run [#134](https://github.com/HamoideAbd123/RHM-Mobile-Server/actions/runs/44945841695) passed.

## Goals and constraints

This refactor organizes the existing Flutter client around clear feature boundaries while preserving current runtime behavior.

- Keep Flutter/Dart and the existing backend API contracts.
- Keep the private RHM core authoritative for FastAPI, Uvicorn, PostgreSQL, Next.js, credentials and business logic.
- Do not copy backend code, provider secrets, tokens, database files or signing material into the public mobile repository.
- Keep one application UI and one chat lifecycle/state owner.
- Avoid introducing a state-management framework or dependencies solely to move code between files.
- Keep compatibility exports for existing import paths.

## Source layout

~~~text
mobile/lib/
├── main.dart                         # Startup/bootstrap only
├── app/
│   └── rhm_app.dart                  # App shell, theme persistence, MaterialApp
├── features/
│   └── chat/
│       ├── chat_screen.dart          # ChatScreen + lifecycle/state owner + build
│       ├── chat_screen_storage.dart  # Secure preferences, draft and pending-turn journal
│       ├── chat_screen_updates.dart  # App/server update polling and Android token sync
│       ├── chat_screen_connection.dart # Connect, verify, providers and projects
│       ├── chat_screen_conversations.dart # History, CRUD, pagination and send
│       ├── chat_screen_voice.dart    # Recognition, TTS and message actions
│       └── chat_screen_navigation.dart # Sidebar, activity/more destinations and routing
├── conversation/
│   ├── chat_message.dart
│   ├── chat_message_bubble.dart
│   ├── chat_composer.dart
│   └── suggestion_chip.dart
├── app_version_footer.dart
├── api_client.dart                   # Authenticated loopback transport facade
├── api_models.dart                   # Shared DTO model surface
├── api_client/
│   ├── providers_chat.dart
│   ├── server_updates.dart
│   ├── notifications.dart
│   ├── app_updates.dart
│   ├── mcp.dart
│   ├── conversations.dart
│   └── workspace.dart
├── workspace_screens.dart            # Compatibility export
├── workspace_shared.dart
├── workspace/
│   ├── projects_screen.dart
│   ├── tasks_screen.dart
│   ├── memories_screen.dart
│   ├── agent_screen.dart
│   ├── audit_screen.dart
│   ├── devices_screen.dart
│   └── voice_diagnostics_screen.dart
├── rhm_theme.dart
└── rhm_primary_navigation.dart
~~~

Other app surfaces (settings, MCP, notifications, Android runtime, control center and app/server update screens) remain in their existing dedicated files. They were not moved simply to create more folders.

## Responsibilities and dependency direction

| Module | Owns | Must not own |
|---|---|---|
| main.dart | Flutter binding, background-notification bootstrap and runApp | Chat state, API requests, navigation logic |
| app/rhm_app.dart | Global theme mode, root MaterialApp and app-wide direction | Conversation/network behavior |
| features/chat/chat_screen.dart | ChatScreen widget, controllers, lifecycle observer, state fields and widget composition | HTTP request construction or server contract parsing |
| Chat feature parts | Cohesive operations grouped by persistence, updates, connection, conversation, voice and navigation | A second lifecycle owner or independent copy of chat state |
| conversation widgets | Rendering and user input; callbacks supplied by the chat screen | API calls, secure-storage access, server orchestration |
| api_client.dart | Loopback URL/token validation, request headers, timeout, redirect policy, decode/error boundary and client lifecycle | Widget state, BuildContext or navigation |
| api_client/ | Endpoint methods grouped by backend domain | Direct UI access to raw HTTP transport |
| api_models.dart | Typed API request/response DTOs and shared exception type | Network transport or UI state |
| workspace/ | Domain-specific workspace screens | Duplicated API contract/transport |
| rhm_theme.dart | Semantic colors, typography, spacing, radius, motion and touch tokens | Feature business logic |

The allowed dependency direction is:

~~~text
main.dart
  -> app/rhm_app.dart
      -> features/chat/chat_screen.dart
          -> conversation widgets
          -> feature-specific chat operations
              -> RhmApiClient facade/domain methods
                  -> existing FastAPI routes on loopback
~~~

Widgets receive values and callbacks. Only the API client owns HTTP transport, bearer headers, redirects, timeouts and error decoding. The client continues to target the same-device loopback API and the existing bearer-token contract.

## Chat state ownership decision

ChatScreen remains the single stateful owner of its text controllers, scroll controller, speech/TTS objects, API client, pending-turn state, conversation/project selection and lifecycle observer.

Its behavior-heavy methods are organized in same-library Dart part files using feature-specific extensions. This is deliberate:

- It avoids copying private state or creating a second controller with subtly different lifecycle semantics.
- It preserves the existing text, speech, scroll and pending-turn objects.
- It allows feature code to be split and reviewed independently while preserving the private implementation boundary.
- Mutations from feature parts use the state-owned update helper rather than calling the protected State.setState method directly.
- Static secure-storage keys and the storage instance are referenced through their defining state type.

Do not split this ownership again just to adopt a new library. A separate controller/state-management layer is a future feature-driven change only if there is a clear testability or concurrency need and a migration plan with regression coverage.

## Compatibility surfaces

- workspace_screens.dart exports the new per-domain workspace screen files so existing imports remain valid.
- api_client.dart exports api_models.dart and declares the API domain modules as library parts. Existing code continues to import api_client.dart.
- main.dart remains the normal Flutter entry point used by the generated Android host and CI.
- No route name, API method contract, model payload, package ID or database schema changed.

## UI/UX invariants

- Four primary phone destinations: Chat, Projects, Activity and More.
- Adaptive NavigationRail for wide/tablet layouts.
- Theme tokens match the web design semantics with contrast-aware mobile text.
- Android touch targets use the approved minimum sizes.
- Arabic RTL is the default surface; message content direction is selected from the actual text for Arabic/English/code mixes.
- Composer saves drafts after a short typing pause and flushes on app background. Project association and a pending/next draft are preserved.
- Loading, connection, unauthorized, offline and error states must stay explicit. Unsupported backend actions must not be shown as active controls.
- Text scaling, keyboard insets, scrolling and reduced-motion behavior remain acceptance concerns on real hardware.

## Verification

The GitHub Actions CI run [#134](https://github.com/HamoideAbd123/RHM-Mobile-Server/actions/runs/44945841695) passed:

- Flutter unit/widget tests.
- Flutter static analysis.
- Generated Android host preparation and dependency resolution.
- Android ARM64 debug APK build.
- Debug package identity check (com.rhm.rhm_mobile.debug).
- Upload of the debug test artifact.

Automated CI does not replace Huawei Android 10 acceptance. The remaining phone checklist is in STATUS.md and ROADMAP.md.

# RHM Mobile refactor report

**Date:** 2026-11-21  
**Repository:** [HamoideAbd123/RHM-Mobile-Server](https://github.com/HamoideAbd123/RHM-Mobile-Server)  
**Branch:** `bootstrap/import-flutter-client-2026-11-20`  
**Verified code commit:** `cc4b621074ae9e0be81b01163c22a5c3a10f330d`  
**PR:** [#2 — open and unmerged](https://github.com/HamoideAbd123/RHM-Mobile-Server/pull/2)

## Objective

Organize the existing Flutter client around clear feature boundaries, improve maintainability and UI reliability, and preserve the existing app behavior and server contracts. Work was restricted to the public mobile repository.

## Work completed

### 1. App bootstrap and application shell

- Reduced `mobile/lib/main.dart` to a small Flutter/bootstrap entry.
- Moved root `MaterialApp`, global themes, theme-mode persistence and app-level direction into `mobile/lib/app/rhm_app.dart`.
- Kept `ChatScreen` as the application home surface.

### 2. Chat feature decomposition

Moved 45 behavior methods from the previous large chat implementation into six responsibility-focused same-library feature modules:

| Module | Responsibility |
|---|---|
| `chat_screen_storage.dart` | Secure preferences, composer draft, pending-turn journal and discard confirmation |
| `chat_screen_updates.dart` | App/server update checks, background notification polling and Android health-token sync |
| `chat_screen_connection.dart` | Restore/configure/verify connection, provider/model refresh and project loading |
| `chat_screen_conversations.dart` | Restore/list/open/create/rename/delete conversations, pagination and send |
| `chat_screen_voice.dart` | Speech recognition, TTS, stop-speaking and message copy/speak actions |
| `chat_screen_navigation.dart` | Workspace routing, sidebar, activity and More surfaces |

The stateful owner, lifecycle observer, text/scroll controllers, speech objects and pending-turn state remain in `chat_screen.dart`. This avoids changing ownership or recreating long-lived objects while splitting implementation by domain.

### 3. Reusable conversation widgets

Extracted the message model, Markdown message bubble, composer, suggestion chip and app-version footer into dedicated files. Added focused widget tests for:

- Assistant and user message rendering, RTL direction, Markdown, copy and speak actions.
- Composer text, recording, send and stop-speaking callbacks, plus disabled-send behavior during a pending request.

### 4. API client decomposition

- Kept `RhmApiClient` as the stable public facade and authenticated HTTP transport owner.
- Split endpoint methods into seven domain modules: provider/chat, server updates, notifications, app updates, MCP, conversations and workspace.
- Moved typed request/response DTOs to `api_models.dart` and re-exported them from `api_client.dart`.
- Preserved loopback URL validation, bearer authentication, redirect blocking, timeouts, response decoding and typed error handling.
- Did not change routes, request payloads, response payloads or server-side validation.

### 5. Workspace decomposition

Split workspace screens into projects, tasks, memories, agents, audit, registered devices and voice diagnostics modules. Shared loading/error/empty helpers were placed in `workspace_shared.dart`. The former `workspace_screens.dart` path remains a compatibility export.

### 6. UI/UX and reliability

- Retained four primary destinations and adaptive navigation.
- Kept shared semantic theme/design tokens and light/dark/system theme selection.
- Improved secure composer draft autosave with a short debounce and a background flush.
- Preserved project context and a newly composed draft while a previous turn is in progress.
- Added live-region semantics for connection/status messages and adaptive message width for wider screens.
- Maintained Android touch-target and contrast considerations.

## Verification result

CI run [#134](https://github.com/HamoideAbd123/RHM-Mobile-Server/actions/runs/44945841695) completed successfully on commit `cc4b621074ae9e0be81b01163c22a5c3a10f330d`:

| Check | Result |
|---|---|
| Flutter unit and widget tests | Passed |
| Flutter static analysis | Passed |
| Android ARM64 debug APK build | Passed |
| Debug package identity check | Passed |
| Artifact upload | Passed |

Artifact details:

- Name: `rhm-mobile-android-arm64-debug`
- Size: 63,403,642 bytes (about 60.5 MiB)
- Debug package ID: `com.rhm.rhm_mobile.debug`
- SHA-256: `fd86fcab3fdb897f5c0b1b90b0d4ea7e17ea70389a15053587eb7a412ae5b043`
- Expires: 2026-12-05 20:27 UTC

This APK is for testing only. It is not production-signed and is not a replacement for `com.rhm.rhm_mobile`.

## Scope intentionally unchanged

- Private FastAPI/Uvicorn backend and application logic.
- PostgreSQL schema, data, migrations and database access.
- Next.js/web interface.
- Provider credentials, API tokens and private operational configuration.
- Existing API routes and request/response contracts.
- Production signing identity and production release workflow.
- PR merge state and `main` branch.

## Remaining acceptance work

1. Install the debug package as a separate test build on the Huawei handset; do not use it as a production in-place update.
2. Test conversation history, create/rename/delete, draft autosave/restoration, project context and interrupted-turn recovery against the existing server.
3. Test Arabic/English mixed content, RTL/LTR, keyboard insets, scrolling, long Markdown, code blocks and tables.
4. Test microphone permissions, recognition quality, TTS voice selection and stop-speaking on the handset.
5. Test update discovery, notification navigation, connection persistence and theme persistence.
6. Verify Termux/Android runtime startup, background/screen-off/reboot recovery, battery policy, authenticated health and preservation of PostgreSQL/app data.
7. Build a production-signed APK using the existing private signing secrets, verify package identity and signer fingerprint, then test data-preserving upgrade behavior.

## Architecture decision to keep

The current structure is the stable baseline for this client. Do not perform another broad rewrite or introduce Bloc/Riverpod solely for style. New capabilities should be added inside the relevant feature module, with tests and an API-contract review. Revisit state ownership only when a concrete concurrency/testability requirement justifies a separately reviewed migration.

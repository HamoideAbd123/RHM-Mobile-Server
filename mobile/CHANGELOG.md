# RHM Mobile changelog

## 0.1.7+8 — 2026-11-07

- Added a dedicated connection-health action in the app bar.
- Added explicit connected / not-confirmed connection state; the status indicator no longer appears healthy before the backend confirms readiness.
- Connection checks preserve saved URL and token when the backend is temporarily unavailable.
- Added regression tests for HTTP authentication failures and malformed health responses.
- Update failures now show safe server/validation details; unexpected installer failures suggest checking Android install permission and storage.
- Added a target-phone checklist for Arabic/English voice, connection recovery, and the full update-install flow.
- Retained authenticated update discovery, SHA-256 verification, and Android's explicit install confirmation.

- Removed the top-bar three-dots action that previously disconnected RHM and deleted the saved access token.
- Connection settings reuse the saved bearer token when the user leaves the token field empty; app startup no longer requires manual token entry after a successful save.
- Secure-storage read failures are non-destructive (`resetOnError: false`); the app no longer deletes URL/token entries after a failed read.
- Rebuilt the navigation drawer as a scrollable panel and removed nonfunctional Projects/Tasks/Memory/Agents placeholders.
- Enabled dependable touch scrolling for chat messages and keyboard dismissal while scrolling.
- Recognition now defaults to Android's device-managed speech service instead of forcing offline mode; offline-only recognition remains selectable.
- Voice output prefers a matching local voice and falls back to another matching Android voice when no local voice is installed.

## Mobile workspace integration — 2026-11-07

- Replaced temporary `/mobile/chat` message submission with persistent backend conversations and paginated message history.
- Added server-backed conversation list, selection, automatic first-message title, rename, confirmed deletion, and UUID idempotency keys for message turns.
- Added working Projects, Tasks, Memory and Agent screens backed by existing FastAPI endpoints.
- Added task status/priority update API with validation and audit events; mobile task status controls use the new route.
- Added confirmed conversation deletion with cascading message removal and an audit event.
- Added memory editing to the mobile memory manager; creation, search and confirmed deletion remain available.
- Agent screen uses the existing read-only AgentLoop allow-list and clearly communicates its restricted permissions.
- Added project detail view showing project-scoped open tasks and related memories.
- Added API-contract tests for conversations, pagination, idempotent send, workspace resources and task updates.
- Target-device acceptance tests remain required for Android 10 storage, voice-engine quality, restart persistence and end-to-end navigation.

- Added GitHub-flavored Markdown rendering for assistant replies (headings, emphasis, lists, tables, blockquotes and code blocks) while keeping responses selectable.
- Replaced placeholder mobile navigation with real Project, Task, Memory, Agent, Audit and registered-Device screens backed by authenticated RHM APIs.
- Added project selection for new conversations and project association/filtering for tasks and saved memories.
- Added a persistent pending-turn journal (request ID, prompt, conversation, project and model routing) so an interrupted send can be retried without accidental duplicate turns.
- Persisted provider/model and speech preferences across app restarts.
- Added device listing and confirmed revocation; audit events are shown read-only. Device pairing is not exposed in this client yet.
- Added API-client tests for projects, tasks, project memories, devices, audit and confirmed destructive operations, plus Markdown widget rendering tests.

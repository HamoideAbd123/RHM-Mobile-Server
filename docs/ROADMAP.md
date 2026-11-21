# RHM Mobile Server roadmap

**Target:** one RHM Android client with a recoverable local runtime host, while preserving the private RHM core as the source of truth.

## Flutter client and UI/UX refactor — completed on the current work branch

- [x] Keep Flutter as the single mobile UI and Kotlin as the Android lifecycle/service layer.
- [x] Separate the application entry point and root application shell.
- [x] Organize the chat screen into storage/preferences, updates, connection, conversations, voice and navigation modules while preserving one lifecycle/state owner.
- [x] Extract message, composer, suggestion and version-footer widgets.
- [x] Split the API client into an authenticated transport facade and domain endpoint modules.
- [x] Separate API DTO models from the HTTP transport facade.
- [x] Split workspace screens into projects, tasks, memories, agents, audit, devices and voice diagnostics modules, retaining a compatibility export.
- [x] Keep existing backend request/response contracts, token boundary, database and private-core ownership unchanged.
- [x] Polish draft autosave, app-background draft flush, project context retention, semantic status announcements and adaptive message layout.
- [x] Maintain shared semantic theme tokens, light/dark/system theme selection, four primary navigation destinations and adaptive tablet navigation.
- [x] Add focused widget tests for message bubbles and the composer.
- [x] Pass Flutter tests, static analysis, Android ARM64 debug build, debug package identity check and artifact upload in CI run [#134](https://github.com/HamoideAbd123/RHM-Mobile-Server/actions/runs/44945841695).

Architecture and delivery records:
- [Flutter client architecture](FLUTTER_CLIENT_ARCHITECTURE.md)
- [Refactor report](REFACTOR_REPORT.md)
- [Verified status](STATUS.md)

## Android runtime-host implementation — source complete, device acceptance pending

- [x] Add a foreground service and opt-in boot receiver.
- [x] Preserve the private RHM Core as the source of truth for backend, database and secrets.
- [x] Use the existing `rhm.cli server-update supervise` entrypoint via a fixed Termux RUN_COMMAND allow-list rather than a duplicate Uvicorn launcher.
- [x] Start an existing offline PostgreSQL cluster only when Debian cluster tools are present; do not create, reset or migrate a database.
- [x] Add authenticated FastAPI health polling via Android Keystore-protected Bearer token.
- [x] Add bounded recovery with exponential backoff; distinguish API downtime from missing/invalid authentication.
- [x] Expose recovery diagnostics in Flutter.
- [x] Validate Linux process start-time and command identity before PID status/stop operations.

## Source review and merge gates

- [ ] Review the full PR #2 diff and resolve the existing base-branch divergence.
- [ ] Merge PR #2 only after explicit owner approval. It remains open and unmerged.
- [ ] Keep the private core, production secrets, database and web UI outside this public mobile PR.

## Device acceptance: Huawei Android 10

- [ ] Complete one-time Termux config and RUN_COMMAND authorization.
- [ ] Verify authenticated health, invalid-token behavior and Start/Stop/Restart.
- [ ] Verify backend and supervisor crash recovery.
- [ ] Verify PostgreSQL data is preserved and existing clusters are never recreated.
- [ ] Verify Next.js at loopback port 3000 when its production build exists.
- [ ] Reboot and verify boot receiver, foreground notification and hands-off startup.
- [ ] Check Huawei auto-launch/battery policy and screen-off behavior.
- [ ] Test chat history, new chat, rename/delete confirmation, draft restore, project context and interrupted-turn recovery.
- [ ] Test Arabic/English RTL/LTR, keyboard scrolling, long messages and text scaling.
- [ ] Test speech recognition, TTS, permissions, offline behavior and stop-speaking.
- [ ] Confirm conversations, memory, projects, settings, tokens and PostgreSQL rows are preserved.

## Signed release and end-to-end use

- [ ] Use the existing protected signing identity in the private-core release workflow.
- [ ] Verify production package ID `com.rhm.rhm_mobile` and certificate fingerprint against a trusted installed APK.
- [ ] Publish a signed ARM64 artifact with SHA-256 only after signer comparison and acceptance.
- [ ] Install the signed release and verify data/settings preservation.
- [ ] Verify app chat and local web chat without manually launching Uvicorn, Next.js or Termux.

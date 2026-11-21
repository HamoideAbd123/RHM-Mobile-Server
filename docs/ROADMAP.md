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

## Independent Android app update manager — implementation CI passed; device and release acceptance pending

- [x] Move Android app release discovery away from the private Core FastAPI update proxy.
- [x] Read stable release metadata directly from the fixed `HamoideAbd123/RHM-Mobile-Server` GitHub Releases endpoint without sending an RHM bearer token.
- [x] Allowlist the exact release page, tag, APK asset and SHA-256 asset URLs.
- [x] Replace in-memory APK buffering with streamed file download and byte-progress callbacks.
- [x] Resume interrupted APK transfers using HTTP Range; restart safely when the server ignores Range.
- [x] Enforce the APK/checksum size limits, validate the APK ZIP header and verify SHA-256 before installation.
- [x] Add explicit download cancellation and a progress dialog; retain incomplete parts only for later resume.
- [x] Hand the verified APK to Android's installer; Android remains responsible for signature continuity and user approval.
- [x] Check releases on app launch and during foreground/resume intervals without requiring the local backend.
- [x] Schedule a best-effort 12-hour WorkManager check with a network-connected constraint and a dedicated app-update notification.
- [x] Declare `REQUEST_INSTALL_PACKAGES` and add a CI manifest-permission assertion for sideloaded updates.
- [x] Pass the Flutter tests, static analysis, ARM64 debug build, package identity and install/notification permission assertions in [CI run #44953230929](https://github.com/HamoideAbd123/RHM-Mobile-Server/actions/runs/44953230929).
- [ ] Complete on-device update tests on Huawei Android 10: Wi-Fi loss/resume, checksum rejection, installer approval, update-in-place and data preservation.
- [ ] Enable signed production publication only after the original package ID and certificate fingerprint are verified. Never create a replacement keystore.

The updater is independent of Core server updates. `/server-update/*` continues to manage the local Python/Next.js runtime only.

## Source review and merge gates

- [ ] Reconcile the existing import PR #2 with the current `main` head, re-run CI on the reconciled branch, and merge after all checks pass.
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

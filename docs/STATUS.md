# RHM Mobile Server — verified status

**Status date:** 2026-11-21  
**Work branch:** `bootstrap/update-manager-independent-2026-11-21`  
**Verified code commit:** `a0294c5582d64d8b2ec318975266ff29e3775625`  
**Private core:** `HamoideAbd123/rhm-personal-ai-core` (authoritative backend)  
**Public mobile:** `HamoideAbd123/RHM-Mobile-Server` (Android/Flutter integration)

## Current CI verification

GitHub Actions run [#44953230929](https://github.com/HamoideAbd123/RHM-Mobile-Server/actions/runs/44953230929) completed successfully on code commit `a0294c5582d64d8b2ec318975266ff29e3775625`.

- Flutter unit/widget tests: **passed**.
- Flutter static analysis: **passed**.
- Generated Android host preparation and dependency resolution: **passed**.
- Android ARM64 debug APK build: **passed**.
- Debug package identity verification: **passed** (`com.rhm.rhm_mobile.debug`).
- Manifest assertions for `REQUEST_INSTALL_PACKAGES` and `POST_NOTIFICATIONS`: **passed**.
- Artifact upload: **passed**.

Uploaded artifact: `rhm-mobile-android-arm64-debug`, ID `14726368838`, size **63,426,873 bytes** (about 60.5 MiB). Artifact archive SHA-256: `1d068588ecd0b9fb3a51f20bf2f8e4228442b72dc71dbf87c73cccdfb51c8de5`. It expires on **2026-12-05 21:52 UTC**.

This is a **debug/test APK**, not a production update. Its package ID is `com.rhm.rhm_mobile.debug`; it cannot update the production package `com.rhm.rhm_mobile`.

## Independent Android app updater — 2026-11-21

- The updater has been moved off the private Core FastAPI proxy and now reads the fixed public mobile repository's GitHub Releases API.
- The implementation includes exact repository/tag/asset URL validation, streamed APK download, resumable Range requests, cancellation, byte progress, size/APK-header/SHA-256 verification, Android installer handoff, foreground checks, and a best-effort 12-hour WorkManager notification check.
- This updater does not use the saved RHM server URL or RHM bearer token.
- Flutter tests, static analysis, ARM64 debug build, package identity, manifest permissions and artifact upload passed in [Actions run #44953230929](https://github.com/HamoideAbd123/RHM-Mobile-Server/actions/runs/44953230929). The uploaded APK is debug-only and is not a production update.
- Huawei physical-device acceptance, exact installed release certificate comparison and a data-preserving in-place install remain required.
- GitHub's latest stable release endpoint returned HTTP 404 on 2026-11-21: this repository has no stable release yet. No app version bump, production-signed APK, GitHub release or mobile release tag has been created.

## Flutter refactor completed on this branch

- Root `mobile/lib/main.dart` is now a small startup/bootstrap entry; the app shell is in `app/rhm_app.dart`.
- Chat behavior is split into six same-library feature modules: storage/preferences, update polling, connection/bootstrap, conversations, voice and navigation.
- Chat message model, Markdown message bubble, composer, suggestion chip and app-version footer are separate widgets/modules.
- `RhmApiClient` remains the authenticated loopback transport facade; endpoint methods are organized by provider/chat, server updates, notifications, MCP, conversations and workspace. App APK updates no longer use a `RhmApiClient` endpoint.
- API DTO models are separated into `api_models.dart`, re-exported from `api_client.dart`.
- Workspace screens are split by domain: projects, tasks, memories, agents, audit, devices and voice diagnostics. `workspace_screens.dart` remains as a compatibility export.
- Shared semantic theme tokens, four primary navigation destinations, adaptive wide-screen navigation and Android touch-target rules are maintained.
- Composer drafts are debounced, flushed on app background, and retain project context and a next draft while a turn is in progress.

Detailed references:
- [Flutter client architecture](FLUTTER_CLIENT_ARCHITECTURE.md)
- [Refactor report](REFACTOR_REPORT.md)

## Runtime and data boundary

- The private RHM core remains authoritative for FastAPI, Uvicorn, PostgreSQL, Next.js, business logic, provider credentials and private operational configuration.
- The public mobile repository contains the Flutter client and Kotlin Android runtime-host integration only.
- The client continues to use the existing same-device loopback API at `127.0.0.1:8000` with the existing bearer-token contract.
- This Flutter refactor did not change backend routes, API payloads, database schemas, migrations, provider routing, web UI or private signing material.
- No provider key, API token file, private environment file, database dump or signing key was copied into this public repository.

## GitHub review boundary

- PR #2 remains open and unmerged: https://github.com/HamoideAbd123/RHM-Mobile-Server/pull/2
- The updater implementation is on `bootstrap/update-manager-independent-2026-11-21`, derived from `bootstrap/import-flutter-client-2026-11-20`.
- No merge to `main` has been performed yet; PR #2 still requires branch reconciliation and a final green CI run.
- PR #2 has existing base-branch divergence and remains an explicit review/merge decision for the owner.

## Remaining acceptance gates

1. Install the debug/test APK only as a separate test build where package identity permits; do not use it as a production update.
2. On the Huawei Android 10 handset, verify chat history, new conversations, rename/delete confirmations, long messages, Arabic/English direction, keyboard scrolling and draft restoration.
3. Verify project context and pending-turn recovery through real server responses and an interrupted request.
4. Verify voice recognition, speech output, stop-speaking, permission denial and offline behavior on the target handset.
5. Verify connection settings, provider/model changes, theme persistence, update discovery and notification navigation.
6. Verify Termux RUN_COMMAND, authenticated health, bounded supervisor recovery, screen-off and reboot behavior on the handset. CI does not prove Android/EMUI lifecycle behavior.
7. Produce a production-signed ARM64 APK through the protected private-core signing workflow, then compare signer fingerprint and production package identity before any in-place installation.
8. Confirm existing conversations, memory, projects, settings, credentials and PostgreSQL rows remain intact after the signed update.

## Signing and release policy

- Existing signing secrets remain only in the private RHM core repository.
- Do not create or upload a new signing key for this public repository.
- The Core cleanup PR #47 removed `.github/workflows/mobile-server-signed-build.yml` along with the duplicated Flutter source. That signing workflow must be restored or replaced in Core; it should check out this public repository at a reviewed ref and use the existing private keystore secrets without copying app source back into Core.
- The previous private signing workflow uploaded an Actions artifact only; it did not publish a GitHub Release in this mobile repository. A release publisher therefore needs an authorized cross-repository release credential, or the signed APK and checksum must be uploaded manually to a GitHub Release.
- A production release requires the existing signing identity, production package ID `com.rhm.rhm_mobile`, a mandatory signer-fingerprint comparison and a tested data-preserving upgrade.

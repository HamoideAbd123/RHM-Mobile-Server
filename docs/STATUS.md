# RHM Mobile Server — verified status

**Status date:** 2026-11-22  
**Work branch:** `main` (standalone updater merged; release candidate version bump merged)  
**Updater implementation merge:** `927dc2d8708ba951fad90bf845ed871060680ab3`  
**Release candidate version commit:** `64b8551b9b50737f9876c0452322ed8ad7102292`  
**Private core:** `HamoideAbd123/rhm-personal-ai-core` (authoritative backend)  
**Public mobile:** `HamoideAbd123/RHM-Mobile-Server` (Android/Flutter integration)

## Current CI verification

The merged `main` commit `927dc2d8708ba951fad90bf845ed871060680ab3` passed GitHub Actions run [#44954608077](https://github.com/HamoideAbd123/RHM-Mobile-Server/actions/runs/44954608077), completed 2026-11-21 22:08:50 UTC:

- Flutter unit/widget tests: **passed**.
- Flutter static analysis: **passed**.
- Generated Android host preparation and dependency resolution: **passed**.
- Android ARM64 debug APK build: **passed**.
- Debug package identity verification: **passed** (`com.rhm.rhm_mobile.debug`).
- Manifest permission assertions: **passed**.
- Test APK artifact upload: **passed**.

Earlier reconciled PR-head runs #44954297365 and #44954292974 also passed the same pipeline. Their artifacts are debug-only and expire after 14 days.

The post-merge run confirms the final merged code builds. It does not prove a production-signed APK or an in-place upgrade of the currently installed app.

## Independent Android app updater — 2026-11-21/22

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

## GitHub review and main CI

- App-import PR #2 was merged on 2026-11-21 at 22:02:08 UTC: https://github.com/HamoideAbd123/RHM-Mobile-Server/pull/2\n- Release-candidate PR #3 was merged on 2026-11-22: https://github.com/HamoideAbd123/RHM-Mobile-Server/pull/3. Its PR-head CI run #44955284229 passed.
- Merge commit: `927dc2d8708ba951fad90bf845ed871060680ab3`.
- GitHub Actions on the merged `main` commit completed successfully: [run #44954608077](https://github.com/HamoideAbd123/RHM-Mobile-Server/actions/runs/44954608077).
- Passed on that run: Flutter unit/widget tests, static analysis, ARM64 debug APK build, debug package identity verification, Android permission assertions and artifact upload.
- The current `main` documentation commit is `c4a4da30e049844dfff04d377b0721a3182cf214`.
- Core cleanup PR #47 removed the duplicate Flutter source. A fresh check confirmed `mobile/pubspec.yaml` is absent from Core `main`; the canonical Flutter source is this repository.

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

- Production signing secrets must remain only in the private Core repository.
- The private signing workflow proposal PR #45 was merged into Core on 2026-11-20, but a subsequent Core cleanup removed the workflow file. A current inspection of Core `main` found no signing workflow, so a protected signing workflow still needs to be restored/replaced there.
- The public mobile CI currently builds only a debug APK with application ID `com.rhm.rhm_mobile.debug`.
- The app now declares release candidate version `0.1.11+12`; intended production application ID remains `com.rhm.rhm_mobile`. The production signer fingerprint and compatibility with the APK installed on the Huawei phone have not yet been verified.
- No stable GitHub Release exists in this mobile repository. The updater correctly reports that no stable release has been published.
- Do not create a release tag or publish the debug APK as a phone update. A production release requires the original signing identity, verified certificate fingerprint, signed ARM64 APK, SHA-256 sidecar and a successful update-in-place/data-preservation test.

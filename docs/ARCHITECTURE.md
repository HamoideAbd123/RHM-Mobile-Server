# RHM Mobile Server architecture

**Document status:** accepted system direction. The Flutter client refactor is implemented and CI-verified on the current work branch; native runtime behavior still requires physical-device acceptance.

## 1. System boundary

The repository separates the mobile client from the existing RHM application server.

| Layer | Responsibility | Current state |
|---|---|---|
| Flutter client | Chat UI, conversations, projects, tasks, memory, agent, audit, devices, voice UI and settings | Imported and modularized; Flutter tests, analysis and ARM64 debug CI pass on the current work branch |
| Kotlin Android host | Foreground monitor, notification, opt-in boot request, Flutter method channel, authenticated health and fixed Termux bridge | Implemented in the branch; Huawei/EMUI device acceptance remains open |
| Python runtime | Existing RHM business logic, FastAPI routes, provider routing, agents and MCP gateway | Remains in the private core repository |
| Uvicorn | ASGI HTTP server for the existing FastAPI application | Existing server; not replaced |
| Database | Persistent RHM records and migrations | Remains with the existing backend during transition |
| Model providers | LLM inference and provider credentials | Server-side only; never bundled in APK |

**Key decision:** Kotlin is the Android lifecycle/runtime supervisor, not a replacement backend. FastAPI remains the API application and Uvicorn remains the ASGI server unless a future measured design proves a better arrangement.

## 2. Current connection mode

The imported Flutter client connects to the same-device loopback endpoint:

```text
http://127.0.0.1:8000
```

Every protected request uses the existing RHM bearer token. The server's local API boundary must remain enabled. Do not bind this profile to `0.0.0.0`, expose port 8000 to the LAN, or put the bearer token in app assets, source control, logs, or screenshots.

The backend and its database are not part of this repository. This avoids a second source of truth and prevents accidental publication of operational data.

## 3. Intended standalone topology

The target design is one installed RHM Android application:

1. Flutter is the single user interface.
2. A Kotlin foreground service owns the Android-facing lifecycle and user-visible service notification.
3. A bounded runtime manager starts, monitors and stops the Python runtime.
4. The existing Python package starts the same FastAPI application under Uvicorn on loopback.
5. Flutter talks to that local API using the existing contracts and authentication boundary.
6. Persistent application data lives in an explicitly selected, durable database location with tested backup and restore.

No duplicate Flutter application or second API implementation should be introduced.

## 4. Python runtime feasibility gate

Do not choose an embedded Python product or database implementation by assumption. Run a compatibility proof on ARM64 using the actual RHM dependency set.

The proof must establish:

- a supported way to package the required Python interpreter and runtime files inside the Android app;
- availability or reproducible builds of every required native wheel for Android ARM64 (not merely Linux aarch64 wheels);
- compatibility of FastAPI, Uvicorn, Pydantic, SQLAlchemy, database drivers, cryptography and any other native dependencies;
- whether the current PostgreSQL deployment can remain external or whether a separately reviewed SQLite migration is required;
- durable filesystem paths, app update behavior, backup/restore, permissions and recovery after process restart;
- memory, storage, CPU, battery and startup time on the target Huawei Android 10 device.

A Python distribution strategy that works on desktop Linux is not proof that its native extensions work on Android/Bionic. If a dependency cannot be packaged safely, document the gap and decide whether to replace that dependency, keep the interim Termux runtime, or postpone standalone mode. Do not silently rewrite business logic.

## 5. Android lifecycle policy

A foreground service is the primary candidate for an ongoing, user-visible local server. It must show an accurate persistent notification and provide explicit start/stop controls. A boot receiver may request recovery only where the target Android version permits it; it is not a promise that the app can restart itself in every state.

Android 12+ restricts starting foreground services from the background. Android 14+ enforces foreground-service type permissions. Android 15 adds further restrictions to some foreground-service launches from boot receivers. Android 16 changes job quotas, including jobs created by WorkManager. Device manufacturers can impose additional battery restrictions. The user can force-stop the app, and Android may terminate processes under resource pressure.

Therefore the product requirement is **highly resilient and recoverable**, not “cannot ever stop”. Every recovery path must be tested on the target device, and the UI must show whether the server is actually healthy rather than inferring readiness from a running notification.

Official platform guidance:
- [Android services overview](https://developer.android.com/develop/background-work/services)
- [Launch a foreground service](https://developer.android.com/develop/background-work/services/fgs/launch)
- [Foreground-service changes by Android version](https://developer.android.com/develop/background-work/services/fgs/changes)
- [Background-start restrictions](https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start)
- [Background optimization and power restrictions](https://developer.android.com/topic/performance/background-optimization)

## 6. Security and process boundaries

- The Python process inherits only the minimum required environment.
- Provider credentials and the GitHub release-read token remain server-side.
- The Android bearer token is stored with Android secure storage; never store it in a plain preference, resource, build log, or manifest.
- The local API remains loopback-bound and authenticated.
- The runtime manager accepts only fixed, reviewed commands and paths. It must not accept arbitrary shell commands from Flutter, network input, MCP output, or model output.
- Logs redact authorization headers, tokens, environment secrets, prompts where sensitive, and database connection strings.
- Updates use the same application ID and signing identity; an update must not erase app data.
- Database migration, rollback and backup are separate controlled operations. An app update must not silently replace or recreate user data.

## 7. Failure and recovery model

The runtime manager should track at least: stopped, starting, healthy, degraded, stopping and failed. Health is determined by an authenticated local health check, not merely by PID existence.

On an unexpected runtime exit, use bounded restart attempts with exponential backoff and a visible error state. Avoid a tight restart loop. Preserve logs and last known exit information. If health cannot be restored, keep the app usable for diagnostics and present a safe recovery action.

The first implementation should prefer correctness and recoverability over aggressive polling or keeping unnecessary wake locks. Battery and memory behavior must be measured on the actual phone.


## 8. Implemented Android runtime-host boundary

The Android runtime-host code in the mobile branch is an integration layer around the existing private RHM runtime. It is not an embedded Python distribution and does not replace FastAPI or Uvicorn.

Implemented integration components include:

- Kotlin foreground `RhmRuntimeService` with a user-visible notification and explicit service actions.
- Opt-in boot receiver that reads the persisted owner preference and requests monitor/service startup where Android permits it.
- Typed Flutter method-channel operations for status, start, stop, restart, autostart and diagnostics.
- Fixed Termux RUN_COMMAND allow-list (`start`, `stop`, `restart`, `status`); the bridge does not expose arbitrary shell execution.
- Authenticated FastAPI `GET /mobile/health` monitoring with a token protected by Android Keystore AES-GCM.
- Distinct healthy, unavailable, unauthorized, missing-token and invalid-response states. Missing/invalid credentials do not trigger restart loops.
- Bounded recovery/backoff for repeated health failures; the existing private `rhm.cli server-update supervise` command remains responsible for starting the FastAPI/Uvicorn and Next.js runtime.
- Termux PID checks verify process start time and expected command identity before status/stop actions.

**Acceptance status:** source and CI checks are not a substitute for a real Huawei Android 10 test. Boot delivery, foreground-service policy, Termux permission, screen-off, battery restrictions, process recovery and PostgreSQL/data preservation remain physical-device gates.

## 9. Debug and release application identity

- Intended production application ID: `com.rhm.rhm_mobile`.
- CI debug application ID: `com.rhm.rhm_mobile.debug`.
- CI verifies the debug application ID before uploading the ARM64 artifact.
- Debug APK uses debug signing and is not an in-place update for the installed production release.
- Production updates require the existing protected signing key, matching signer fingerprint and an explicit data-preservation test. No new signing key is generated in this repository.

## 10. Special-use foreground service decision gate

The runtime service currently declares `specialUse` and the `FOREGROUND_SERVICE_SPECIAL_USE` permission, together with a manifest subtype explanation. This is a candidate classification for user-started local-server monitoring when no standard service category fits; it is not a blanket approval. Before a production release, validate the actual workload and Google Play policy (if distributed through Play), and revisit this if the workload changes to sync, media, camera, microphone or another category.

Official guidance:
- [Foreground-service types and special use](https://developer.android.com/develop/background-work/services/fgs/service-types)
- [Foreground-service launch requirements](https://developer.android.com/develop/background-work/services/fgs/launch)
- [Android 15 background-start changes](https://developer.android.com/about/versions/15/behavior-changes-15)

## 11. Flutter client internal architecture

The Flutter client source organization, dependency boundaries, state ownership and compatibility exports are documented in [Flutter client architecture](FLUTTER_CLIENT_ARCHITECTURE.md). The detailed work log and verification record are in [Refactor report](REFACTOR_REPORT.md).

The client remains a Flutter application with the existing API surface. No state-management framework or additional runtime package was introduced for this refactor. The chat screen's lifecycle and state owner remain in one Dart library; feature-specific extension parts keep implementation modules smaller without moving controllers, pending-turn state, voice objects or lifecycle observers across ownership boundaries.

## 12. Independent Android application updates

The Flutter updater is a separate client-side subsystem. It is not part of the RHM FastAPI server-update manager and it does not use the authenticated loopback API client.

- Release metadata is read from the fixed public GitHub Releases API for this repository.
- The parser accepts only stable semantic-version tags and the exact APK and SHA-256 asset names from the matching release.
- Download URLs must belong to the same repository and release tag. Redirected asset responses are restricted to HTTPS GitHub release asset hosts.
- APK bytes are streamed to app temporary storage. An interrupted partial file can be resumed with an HTTP Range request; size, APK ZIP header and SHA-256 are checked before installation.
- A foreground check is performed on app launch and periodically while active. WorkManager performs a best-effort 12-hour background check under a network-connected constraint and posts one notification per newly discovered version.
- The Android package installer owns the final install step. Its package signature check remains the authenticity gate for in-place updates; SHA-256 is an integrity check, not a replacement for signing.

The updater cannot install silently. Production release creation remains blocked until the established `com.rhm.rhm_mobile` application ID and original signing certificate are verified and the private signing workflow can publish signed APKs to this repository.

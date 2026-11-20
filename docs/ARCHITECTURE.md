# RHM Mobile Server architecture

**Document status:** accepted direction; native-runtime implementation is not yet complete.

## 1. System boundary

The repository separates the mobile client from the existing RHM application server.

| Layer | Responsibility | Current state |
|---|---|---|
| Flutter client | Chat UI, conversations, projects, tasks, memory, agent, audit, devices, voice UI and settings | Imported from the private core repository |
| Kotlin Android host | Android lifecycle, foreground-service entry point, notification, boot/restart policy, native process manager and Flutter bridge | Planned; not implemented in this baseline |
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

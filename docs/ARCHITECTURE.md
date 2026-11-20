# RHM Android Runtime Architecture

## Decision

Extend the **existing Flutter RHM application**. Do not create a second user-facing app and do not replace FastAPI/Uvicorn with a Kotlin HTTP server.

## Runtime layers

1. Flutter UI: existing screens, navigation, chat, settings and API client.
2. Kotlin Android host: foreground service, notification channel, boot receiver, battery-optimization guidance, lifecycle handling, and a narrow MethodChannel/EventChannel bridge.
3. Python runtime: existing RHM FastAPI application served by Uvicorn. The runtime packaging method is an explicit feasibility decision.
4. Persistence: existing RHM database and files, with a tested backup/restore path before any data migration.

## Runtime options

- **Milestone A — hybrid proof:** Kotlin service supervises the existing supported Termux/Debian runtime. This validates Android lifecycle and supervision but is not standalone.
- **Milestone B — standalone feasibility:** evaluate an embedded Python distribution for Android ARM64 and every native dependency used by RHM. Do not assume Chaquopy or another embedding tool supports the complete dependency set.
- **Database:** PostgreSQL is not automatically portable as an embedded Android service. Evaluate an Android-compatible storage architecture without silently replacing production data. Keep the existing backend database contract until a migration is designed and tested.

## Service behavior

- Use an Android Foreground Service with a persistent notification for user-visible ongoing work.
- Handle Android 10 background-start restrictions and boot behavior explicitly.
- Provide explicit Start / Stop / Restart controls and health state.
- Use bounded restart backoff; avoid tight crash loops.
- Record process exit codes, startup failures and health-check outcomes without logging secrets.
- Bind to 127.0.0.1 by default. LAN access is opt-in and authenticated.
- Android/OEM battery management can still stop the service; never promise 100% uptime.

## Data and security invariants

- Never delete or overwrite existing RHM data during install/update.
- Never bundle production API tokens or database credentials in the APK.
- Keep signing credentials in GitHub Actions secrets, not Git history.
- Public repository contents must contain no user data, tokens, private keys or production configuration.
- Verify update artifacts with SHA-256 and retain a rollback path.

## Open technical gates

1. Confirm the exact source branch/commit and Flutter package identity.
2. Audit Android Gradle, Kotlin, manifest, minSdk/targetSdk and plugin compatibility.
3. Inventory Python dependencies and native wheels for Android ARM64.
4. Decide database runtime and durable storage.
5. Prove foreground service lifecycle on Android 10 / Huawei EMUI.
6. Prove clean install, update, backup and restore.

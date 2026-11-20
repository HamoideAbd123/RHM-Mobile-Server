# Implementation Roadmap

Status is intentionally evidence-based. A stage is complete only when its acceptance checks have passed.

| Stage | Scope | Exit criteria | Status |
|---|---|---|---|
| 0 | Repository initialization and architecture | Public repo, architecture and security boundaries documented | In progress |
| 1 | Source audit and import | Existing Flutter app and Android host imported without losing history or secrets | Blocked on source transfer strategy |
| 2 | Baseline CI | Flutter analyze/tests and Android debug APK build run reproducibly | Not started |
| 3 | Kotlin host integration | Foreground service, notification and Flutter bridge compile and pass tests | Not started |
| 4 | Runtime proof | Existing FastAPI/Uvicorn starts and health-checks under chosen Android runtime | Not started |
| 5 | Supervisor | Bounded restart, logs, health status and explicit controls verified | Not started |
| 6 | Persistence and security | Data backup/restore, token handling and update integrity verified | Not started |
| 7 | Device validation | Screen-off, app-background, reboot, low-memory and Huawei battery tests pass | Not started |
| 8 | Release | Signed APK, SHA-256, changelog and install instructions published | Not started |

## Build strategy

Use GitHub-hosted standard Ubuntu runners for compilation and tests; do not compile on the Huawei Y9 Prime unless a fallback is required. Public-repository standard runner usage is subject to GitHub's current Actions terms and fair-use limits; storage and other paid services are separate.

## Immediate next steps

1. Import the existing Flutter mobile project from the RHM core repository after choosing a safe source-mirroring method.
2. Compare the source repository's mobile manifest, Gradle configuration, Kotlin host, package dependencies and tests.
3. Add CI only after paths and toolchain versions are confirmed.
4. Build a debug APK and run static checks before attempting runtime integration.
5. Publish no APK until it is installable and its checksum is recorded.

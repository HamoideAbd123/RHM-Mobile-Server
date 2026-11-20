# RHM Mobile Server — Status Report

**Date:** 2026-11-20  
**Repository:** HamoideAbd123/RHM-Mobile-Server  
**Working branch:** feat/android-background-runtime-2026-11-20  
**Baseline commit:** 28db6c9ed3909fdde58bffd4bb92b130ae8aaa2b

## Confirmed

- New repository exists, is public, and allows the connected GitHub integration to write.
- Default branch is `main`; repository was empty at discovery.
- Initial README was committed to `main`.
- Feature branch `feat/android-background-runtime-2026-11-20` was created.
- Existing RHM source repository is `HamoideAbd123/rhm-personal-ai-core`, currently private.
- Its default branch contains `mobile/`, an existing Flutter application with `android/`, `lib/`, `test/`, `pubspec.yaml`, and mobile documentation.
- Source `mobile/pubspec.yaml` declares app version `0.1.10+11`, Dart >=3.13 and Flutter >=3.47.
- The mobile app already includes server URL/token persistence, authenticated API calls, conversations, projects, tasks, memory, audit, devices, agent and update-proxy UI according to its README.
- The source `mobile/android/` directory currently exposes Android template files (manifest, app Gradle and network security templates), not a complete checked-in Gradle scaffold.
- Source mobile documentation describes a same-device FastAPI/Uvicorn server on loopback `127.0.0.1:8000`, authenticated by the existing RHM bearer token. It explicitly warns not to expose this endpoint to LAN/Internet.
- The source app does not currently bundle a Python backend. The requested embedded background server is therefore a new integration milestone, not a feature already present in the APK.

## Completed in this session

- Initialized README with project purpose, architecture boundary and security rules.
- Created feature branch `feat/android-background-runtime-2026-11-20`.
- Added `docs/ARCHITECTURE.md`, `docs/ROADMAP.md` and this status report.
- Kept the original RHM repository unchanged.

## Not yet completed

- Flutter source import/mirroring.
- Kotlin foreground service and Flutter platform-channel integration.
- Python runtime packaging or Android compatibility proof.
- GitHub Actions workflow in this new repository.
- Flutter tests / Dart analysis in this new repository.
- Android debug or release APK from this new repository.
- Physical-device validation.
- Notion documentation sync.

## Blocking issue

A public GitHub Actions workflow cannot simply check out the private RHM core repository using the public repository's default token. We must either deliberately mirror the mobile source into this public repository (after scanning for secrets and personal data), or configure a narrowly scoped read-only credential through GitHub Actions secrets. Do not make the private source public just to make CI work.

The source mobile project also has an explicit modern toolchain requirement (Flutter >=3.47 / Dart >=3.13). The workflow must pin a compatible SDK and must not assume an older runner image will build it.

## Release status

**No APK exists from this repository yet. Do not install or advertise an APK until a successful workflow artifact or release is confirmed.**

## Next required decision

Keep the RHM core repository private and mirror only the reviewed mobile app source into this public repository. This preserves the backend and its secrets while allowing GitHub-hosted builds of the mobile client. The mirror must be reviewed for credentials, private URLs, user data and environment-specific paths before the first public push.

# RHM Mobile Server

Android integration workspace for the existing RHM mobile client and the future phone-hosted RHM runtime.

## Current repository contents

- `mobile/`: the Flutter Android client transferred from the private RHM core repository.
- `scripts/prepare_android_project.sh`: creates the Android host project from Flutter's current scaffold and applies the checked-in manifest/network-security configuration.
- `.github/workflows/mobile-ci.yml`: runs Flutter tests and analysis, then builds an ARM64 debug APK for CI verification.
- `docs/`: architecture, API boundary, release/signing constraints, roadmap and verified project status.

The Flutter client is an interface to the existing RHM FastAPI backend. **This import does not yet embed Python, run Uvicorn as an Android-managed service, or make the phone-hosted server permanently available.** Those are later engineering milestones with separate compatibility and device acceptance tests.

## Existing architecture decision

- Flutter remains the single mobile UI; no duplicate Android app is being created.
- Kotlin/Android will own lifecycle integration and service orchestration when the native runtime phase begins.
- The existing Python/FastAPI/Uvicorn backend remains the application server until an Android-compatible runtime is proven.
- The backend, database, model-provider keys and private operational configuration stay in [the private RHM core repository](https://github.com/HamoideAbd123/rhm-personal-ai-core).

See [Architecture](docs/ARCHITECTURE.md), [Roadmap](docs/ROADMAP.md), and [Status](docs/STATUS.md).

## Flutter version and local checks

The current `mobile/pubspec.yaml` declares package version `0.1.10+11`, Dart 3.13 or newer, and Flutter 3.47 or newer.

From the repository root:

```sh
cd mobile
flutter pub get
flutter test
flutter analyze
```

## Prepare and build Android ARM64

The project scaffold uses the existing private CI organization prefix `com.rhm` with project name `rhm_mobile` to retain the established `com.rhm.rhm_mobile` application ID. Verify the installed APK's actual application ID and signing certificate before any release. The repository stores Android manifest/network-security templates rather than generated Gradle scaffolding. The script preserves Flutter's current Gradle DSL and applies only the required minSdk/desugaring settings. Generate the Android host project with:

```sh
./scripts/prepare_android_project.sh
cd mobile/build/rhm_mobile
flutter pub get
flutter test
flutter analyze
flutter build apk --debug --target-platform android-arm64
```

The debug APK is a CI/test artifact only. Do not distribute it as an update to an already installed signed RHM release.

The GitHub Actions workflow performs the same preparation and publishes an ARM64 debug artifact when checks pass. A signed release workflow is intentionally not enabled yet: it must use the exact existing RHM Android signing identity to preserve in-place update compatibility. See [Release and signing](docs/RELEASE_AND_SIGNING.md).

## Connect to the current RHM backend

For the current same-phone setup, the app connects to:

```text
http://127.0.0.1:8000
```

The user supplies the server's existing `RHM_API_TOKEN` through the app's connection settings. The app stores the token with Android secure storage. The token and model-provider credentials must never be copied into this repository or embedded in the APK.

The backend must remain bound to loopback for this local-only mode. Do not expose port 8000 to Wi-Fi or the public Internet. Remote access requires a separately designed HTTPS/authentication boundary and threat review.

See [API contract](docs/API_CONTRACT.md) and [Security policy](SECURITY.md).

## Update compatibility

The imported app has an authenticated in-app update client that currently talks to update-proxy routes on the private RHM backend. Those routes currently read private-repository release metadata. Before publishing APK releases from this repository, the backend's allow-listed release source and asset validation must be deliberately migrated to this repository. Do not assume that a GitHub release in this public repository will automatically appear in the installed app.

## Important limitations

- Android does not guarantee that a process or service runs forever. Foreground-service rules, user force-stop, battery policies, memory pressure and manufacturer-specific controls still apply.
- The app's current backend and model generation are not offline. Local networking to loopback does not make a cloud model available without Internet.
- The Python runtime and database strategy for a standalone Android installation are not selected. They must be proven on ARM64 with the real dependency set before implementation.
- No Kotlin foreground service, boot receiver, Python runtime bundle, or production-signed APK is included in this first import.
- This repository has no `LICENSE` file yet. Do not assume that public visibility grants permission to reuse or redistribute the code; select a license deliberately before accepting external contributions.

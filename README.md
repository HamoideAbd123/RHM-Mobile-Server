# RHM Mobile Server

Android integration workspace for the existing RHM mobile client and the future phone-hosted RHM runtime.

## Current repository contents

- `mobile/`: the Flutter Android client transferred from the private RHM core repository.
- `scripts/prepare_android_project.sh`: creates the Android host project from Flutter's current scaffold and applies the checked-in manifest/network-security configuration.
- `.github/workflows/mobile-ci.yml`: runs Flutter tests and analysis, then builds an ARM64 debug APK for CI verification.
- `docs/`: architecture, API boundary, release/signing constraints, roadmap and verified project status.

The Flutter client is an interface to the existing RHM FastAPI backend. The Android host now contains a Kotlin foreground service, an opt-in boot receiver, a narrow Termux RUN_COMMAND bridge, authenticated FastAPI health monitoring, and bounded recovery of the existing RHM server supervisor. This integration is awaiting CI and physical Huawei device acceptance; it is not yet a proven always-on deployment.

## Existing architecture decision

- Flutter remains the single mobile UI; no duplicate Android app is being created.
- Kotlin/Android owns foreground lifecycle, notification, boot request, health monitoring and fixed Termux operations; the private RHM Python supervisor remains responsible for Uvicorn and Next.js process lifecycle.
- The existing Python/FastAPI/Uvicorn backend remains the application server until an Android-compatible runtime is proven.
- The backend, database, model-provider keys and private operational configuration stay in [the private RHM core repository](https://github.com/HamoideAbd123/rhm-personal-ai-core).

See [Architecture](docs/ARCHITECTURE.md), [Roadmap](docs/ROADMAP.md), and [Status](docs/STATUS.md).

## Flutter client structure

The Flutter client is organized by responsibility rather than concentrated in the application entry file:

- `mobile/lib/main.dart` is the startup/bootstrap entry point.
- `app/rhm_app.dart` owns the application shell and global theme selection.
- `features/chat/` contains the chat screen and separates its behavior into storage, connection, conversation, update, voice and navigation modules.
- `conversation/` contains reusable message, composer and suggestion widgets.
- `api_client.dart` is the authenticated loopback HTTP facade; endpoint operations are grouped by domain under `api_client/`.
- `api_models.dart` is the shared DTO model surface.
- `workspace/` contains the individual project, task, memory, agent, audit, device and voice-diagnostics screens. `workspace_screens.dart` remains a compatibility export.

See [Flutter client architecture](docs/FLUTTER_CLIENT_ARCHITECTURE.md) and the [refactor report](docs/REFACTOR_REPORT.md).

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

The debug APK is a CI/test artifact only and uses the package ID `com.rhm.rhm_mobile.debug`; the intended release ID remains `com.rhm.rhm_mobile`. Do not distribute it as an update to an already installed signed RHM release.

The GitHub Actions workflow performs the same preparation and publishes an ARM64 debug artifact when checks pass. A signed release workflow is intentionally not enabled yet: it must use the exact existing RHM Android signing identity to preserve in-place update compatibility. See [Release and signing](docs/RELEASE_AND_SIGNING.md).

## Connect to the current RHM backend

For the current same-phone setup, the app connects to:

```text
http://127.0.0.1:8000
```

The user supplies the server's existing `RHM_API_TOKEN` through the app's connection settings. The app stores the token with Android secure storage. The token and model-provider credentials must never be copied into this repository or embedded in the APK.

The backend must remain bound to loopback for this local-only mode. Do not expose port 8000 to Wi-Fi or the public Internet. Remote access requires a separately designed HTTPS/authentication boundary and threat review.

See [API contract](docs/API_CONTRACT.md) and [Security policy](SECURITY.md).

## Independent Android app updates

App release discovery and APK delivery are owned by the Flutter update manager and this repository's GitHub Releases. They do not depend on the RHM FastAPI service, its saved URL, its bearer token, or its availability.

The app checks the latest stable release at the fixed GitHub API endpoint for `HamoideAbd123/RHM-Mobile-Server`. It accepts only the exact `app-release.apk` and `app-release.apk.sha256` assets attached to that repository's matching release tag. Downloads are streamed to a temporary file, can resume through HTTP Range requests, and are rejected unless the final size and SHA-256 match the release metadata. The verified APK is handed to Android's package installer; Android still requires the user to approve installation.

WorkManager performs a best-effort background release check every 12 hours when network connectivity is available. A foreground check runs on app launch, on resume according to the six-hour interval, and when the user taps the update action. Android may defer background work, and notification permission must be allowed.

A SHA-256 checksum detects corruption but is not a substitute for trusted Android signing. A production release must retain the existing application ID `com.rhm.rhm_mobile` and the existing signing certificate. Never place the private signing key in this public repository. See [Release and signing](docs/RELEASE_AND_SIGNING.md).

## Important limitations

- Android does not guarantee that a process or service runs forever. Foreground-service rules, user force-stop, battery policies, memory pressure and manufacturer-specific controls still apply.
- The app's current backend and model generation are not offline. Local networking to loopback does not make a cloud model available without Internet.
- The Python runtime and database strategy for a standalone Android installation are not selected. They must be proven on ARM64 with the real dependency set before implementation.
- Kotlin now launches the existing RHM supervisor via a one-time configured Termux bridge and attempts bounded recovery when authenticated FastAPI health remains unavailable. Termux/Debian remains the runtime; Python is not embedded in the APK. No successful Huawei reboot/soak test or production-signed APK is included yet.
- This repository has no `LICENSE` file yet. Do not assume that public visibility grants permission to reuse or redistribute the code; select a license deliberately before accepting external contributions.


## Android runtime host (integration milestone)

Open **إعدادات RHM → مضيف Android المحلي**. After one-time Termux configuration and permission grant, enable **تشغيل Backend بعد إقلاع الهاتف**. This starts the foreground manager immediately and stores the boot preference. On Android 13+, notification permission must be granted.

The notification reports the authenticated state of `GET /mobile/health` on `127.0.0.1:8000`. Missing or rejected credentials are reported separately and do not cause restart loops. When configured, the manager uses only fixed Termux actions (`start`, `stop`, `restart`, `status`) to launch the private core's existing `rhm.cli server-update supervise` command.

The test APK is deliberately isolated under `com.rhm.rhm_mobile.debug`; it must not replace the existing `com.rhm.rhm_mobile` installation.

Foreground-service type `specialUse` is currently declared for this local runtime manager. Reassess it against the actual workload, target SDK and distribution channel before a production release:
- [Foreground-service types](https://developer.android.com/develop/background-work/services/fgs/service-types)
- [Android 15 behavior changes](https://developer.android.com/about/versions/15/behavior-changes-15)


### Termux runtime setup and acceptance boundary

The first-time setup is documented in [Termux integration](docs/TERMUX_INTEGRATION.md). It requires enabling Termux external commands and granting RHM the RUN_COMMAND permission once. Android then starts the foreground manager after boot when the owner-enabled preference is active. The existing private RHM supervisor manages FastAPI and Next.js; an existing PostgreSQL cluster may be started where Debian cluster tools support it.

The manager checks authenticated FastAPI health every 20 seconds and requests a bounded supervisor restart after repeated failures. It does not treat a missing/invalid token as a server crash. The Next.js frontend starts only when its existing production build is present; do not build it on every boot.

This code has not yet passed on-device Huawei Android 10 reboot, screen-off, server-crash, PostgreSQL preservation, or chat smoke tests. It is therefore an implementation under test, not a claim of proven persistent operation. See [Status](docs/STATUS.md) and [Roadmap](docs/ROADMAP.md).

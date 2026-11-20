# RHM Mobile Server roadmap

**Baseline:** Flutter client import and project separation.  
**Target:** one RHM app on Android, with an app-managed local backend where Android and Python compatibility permit it.

## Phase 0 — Repository separation and reproducible mobile baseline

- [x] Inspect both repositories and confirm the public target is separate from the private core.
- [x] Inspect the complete Flutter source tree and Android templates on the private repository's `main`.
- [x] Exclude private local environment paths from the public import.
- [x] Transfer the Flutter source, tests, package manifest and Android templates to this repository.
- [x] Add a repeatable Android project preparation script.
- [x] Add a mobile-only GitHub Actions workflow for Flutter tests, analysis and ARM64 debug compilation.
- [x] Document API, architecture, security, signing and outstanding limitations.
- [ ] Get a green CI run on the import pull request.
- [ ] Review and merge the import pull request after the CI and diff are reviewed.

## Phase 1 — Build and API contract stabilization

- Verify the public repository CI on a clean GitHub-hosted runner.
- Reconcile the package manifest version (`0.1.10+11`) with the existing changelog, release tags and installed-device version.
- Verify every mobile screen against the current private FastAPI API contract.
- Add a contract test strategy that can run without exposing private backend secrets.
- Record the current installed APK's application ID, signing certificate fingerprint and version code before any release attempt.
- Keep the in-app update source on the private backend until the cross-repository release proxy has been reviewed and changed.

## Phase 2 — Android native host foundation (Kotlin)

- Add Kotlin sources to the existing Flutter Android host; do not create a second Android app.
- Define a typed Flutter method-channel contract for start, stop, status, logs and user-visible errors.
- Add the foreground service, notification channel and explicit user start/stop actions.
- Declare only the foreground-service type and permissions that match the actual runtime workload and target SDK.
- Add lifecycle tests for activity recreation, service disconnection, notification actions and duplicate start requests.
- Add boot recovery only after validating the current Android version's restrictions; do not rely on a boot receiver as an unconditional restart mechanism.

## Phase 3 — Python-on-Android feasibility proof

- Inventory the backend's direct and transitive Python dependencies.
- Classify native extensions and verify Android/Bionic ARM64 build availability.
- Prototype the smallest supported Python runtime inside a separate branch/build artifact.
- Start the unmodified FastAPI application and Uvicorn on loopback from the prototype.
- Measure cold start, RSS memory, CPU, storage and battery while idle and under a bounded request load.
- Decide database compatibility and durable storage only after testing.
- Publish a written go/no-go decision; preserve Termux as the working fallback until the prototype passes.

## Phase 4 — Runtime supervision and data safety

- Implement a fixed-command runtime supervisor with health checks, bounded restarts and backoff.
- Persist runtime state and logs in app-private storage.
- Define backup, restore and export before migrating existing data.
- Add schema-version checks and an explicit migration/rollback policy.
- Verify app upgrade and downgrade behavior without deleting the existing database.
- Keep user approval for destructive recovery or data reset.

## Phase 5 — Resilience and target-device acceptance

- Test on the Huawei Y9 Prime / Android 10 first.
- Test screen-off behavior, app backgrounding, low-memory recovery, network loss, process death, reboot, app update and user force-stop.
- Provide clear instructions for Android/Huawei battery settings where applicable; never hide the notification or misrepresent service state.
- Test resource ceilings suitable for a low-memory device.
- Test a modern Android version as well, because current Android foreground-service restrictions are stricter than Android 10.
- Treat the system as resilient but not immortal: Android and the device owner retain control over stopping it.

## Phase 6 — Release and cross-repository integration

- Preserve the existing package ID and permanent signing key.
- Configure release signing only through protected repository Actions secrets.
- Build and publish an ARM64 signed APK, plus checksum and concise changelog, after acceptance.
- Update the private backend's release proxy to read the approved release assets from this public mobile repository.
- Verify checksum, signing continuity, user-confirmed installation and data preservation.
- Add release notes and record the tested device, Android version, APK SHA-256 and signing fingerprint.

## Completion criteria

The project is not complete until the same Flutter app launches the Android-managed runtime, the original FastAPI application responds locally, existing user data survives supported upgrades, recovery paths pass target-device tests, and release signing/update behavior is verified. A foreground service or green CI badge alone does not satisfy this definition.

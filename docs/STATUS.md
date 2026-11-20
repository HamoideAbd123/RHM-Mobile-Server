# RHM Mobile Server — verified status

**Status date:** 2026-11-20  
**Work branch:** bootstrap/import-flutter-client-2026-11-20  
**Private core:** HamoideAbd123/rhm-personal-ai-core (authoritative backend)  
**Public mobile:** HamoideAbd123/RHM-Mobile-Server (Android/Flutter integration)

## Verified baseline

- The public mobile repository contains the transferred Flutter client and Kotlin Android host templates.
- The private RHM core remains authoritative for FastAPI, Uvicorn, PostgreSQL, Next.js, application logic, configuration and secrets.
- A previous public CI run produced an ARM64 debug APK, but the latest CI run failed in a Flutter settings widget test because the required `onOpenAndroidRuntime` callback was missing. The test has now been corrected in this branch; CI must be rerun before claiming a passing build.
- The current PR remains open. No repository main branch has been modified or merged by this work.

## Runtime architecture decision

The Android runtime must launch the **existing private RHM server supervisor**, not a standalone Uvicorn command:

```text
Android BOOT_COMPLETED
  -> Kotlin RhmBootReceiver
  -> Kotlin RhmRuntimeService (foreground notification)
  -> Termux RUN_COMMAND (fixed allow-listed action)
  -> Debian PRoot
  -> existing .venv Python
  -> rhm.cli server-update supervise
       -> FastAPI/Uvicorn on 127.0.0.1:8000
       -> Next.js production frontend on 127.0.0.1:3000 (when a valid production build exists)
       -> existing PostgreSQL cluster (start existing offline cluster when pg_ctlcluster is available)
```

This reuses `rhm/server_supervisor.py` and `rhm/frontend_runtime.py` from the private core. The supervisor already restarts an exited backend process and maintains the Next.js frontend. Kotlin adds authenticated FastAPI health monitoring and restarts the whole supervisor when the endpoint remains unavailable.

## Implemented in this branch (CI/device verification still required)

- Kotlin foreground service polls `GET /mobile/health` every 20 seconds using the token encrypted by Android Keystore (AES-GCM).
- Health states are distinct: healthy, unauthorized, token missing, invalid response, unavailable.
- A rejected or missing token does **not** trigger process restarts.
- When health is unavailable, Kotlin applies bounded recovery: initial-start failures require five consecutive failed checks; an already healthy server requires two. Recovery delay increases through 30, 60, 120 and 300 seconds.
- Recovery count, last recovery time/action and health state are exposed to Flutter.
- Enabling Backend autostart now starts the foreground manager immediately and persists the boot preference. Boot receiver starts when either monitor or backend autostart is enabled.
- Manual Backend stop disables backend autostart to prevent the monitor from immediately relaunching a deliberately stopped service.
- Termux wrapper now invokes the existing RHM server supervisor (backend + frontend), starts existing offline PostgreSQL clusters when PostgreSQL cluster tools exist, and validates PID plus Linux process start time and command identity before status/stop operations.
- Flutter settings test now supplies the required Android runtime callback.
- No arbitrary shell command or model-generated command is accepted by the Android bridge.

## Remaining acceptance gates

1. Run public CI: Flutter tests, analysis, Kotlin/Android compilation, ARM64 debug build and package identity check.
2. Review and merge PR #2 only after CI and source review are clean.
3. Install the updated Termux wrapper and configure the real Debian checkout path in `~/.config/rhm-runtime.conf`.
4. Verify Termux RUN_COMMAND permission and `allow-external-apps=true`.
5. On Huawei Android 10, verify Start/Stop/Restart, authenticated health, invalid-token behavior, server crash recovery and supervisor/frontend recovery.
6. Verify existing PostgreSQL rows, RHM conversations, memory, projects, settings and credentials remain unchanged.
7. Enable Backend autostart and reboot the handset; verify service notification and FastAPI health without manually opening Termux.
8. Verify the local Next.js production frontend at `127.0.0.1:3000`. It requires an existing successful production build in the private core checkout; the supervisor does not silently overwrite/build the frontend on every boot.
9. Build a signed ARM64 release from the public mobile source using the **existing signing secrets held only in the private core repository**. Verify package ID and signer fingerprint before installing.
10. Run on-device chat and web smoke tests; record screenshots/logs and the exact tested APK SHA-256.

## Signing and release

- Existing signing secrets are configured only in the private RHM core repository and are not readable through this workflow.
- Do not copy signing keys or passwords into this public repository.
- A dedicated private-core workflow is required to check out the public mobile source and sign it using the existing protected secrets. It must output a signed artifact without publishing secrets or generating a new key.
- The earlier test APK has the separate debug package identity `com.rhm.rhm_mobile.debug`; it is not a signed production update and cannot be upgraded in place using the production package identity.
- No signed release or certificate-matched update is claimed until the private signing workflow and on-device signer comparison pass.

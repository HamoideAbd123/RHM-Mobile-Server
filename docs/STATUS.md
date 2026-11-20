# RHM Mobile Server — verified status

**Status date:** 2026-11-20  
**Work branch:** bootstrap/import-flutter-client-2026-11-20

## Verified baseline

- The public mobile repository contains the transferred Flutter client and Android integration templates.
- The private RHM core remains authoritative for FastAPI, Uvicorn, PostgreSQL, application logic, secrets and backend releases.
- Baseline commit 419c4ce passed GitHub Actions tests, static analysis, ARM64 debug build, package identity check and artifact upload.

## Changes in this work

- Review findings fixed in commit 7e31d19: installer result checked, quiet-hour notifications deferred rather than marked seen, Android host screen exposed from offline settings, IPv6 loopback rejected, Android minSdk raised to 24.
- Kotlin RUN_COMMAND bridge added for fixed Termux actions.
- Android Keystore AES-GCM token store added for authenticated FastAPI monitoring.
- Foreground monitor checks GET /mobile/health with Bearer authentication instead of treating TCP reachability as health.
- Termux wrapper and feasibility/data-protection documentation added.

## Remaining work

- Run CI for the latest Kotlin/Flutter integration and fix build/test findings.
- Install the wrapper and validate start/stop/restart on the Huawei Android 10 phone.
- Verify authenticated healthy and unauthorized states on device.
- Verify process cleanup, boot startup, Huawei battery policy and PostgreSQL data preservation.
- Prove complete Python dependency compatibility before an embedded-runtime attempt.
- Migrate the private backend update proxy to read releases from the public mobile repository.
- Confirm the installed app signing certificate, then configure protected signing secrets for a production build.

## Release and security

- CI debug APKs are test artifacts only, not production updates.
- No signing key or credential was generated, copied or committed.
- No database files, environment variables, provider keys, API tokens or private reports were copied into this public repository.

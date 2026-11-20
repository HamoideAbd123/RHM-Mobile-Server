# RHM Mobile Server roadmap

**Target:** after one-time setup, Android boots the existing RHM server runtime automatically; the owner only opens the RHM app or local web UI to chat.

## Completed in the current working branch (pending CI/device acceptance)

- [x] Keep Flutter as the single mobile UI and Kotlin as the Android lifecycle/service layer.
- [x] Add a foreground service and boot receiver for the Android 10+ host.
- [x] Preserve the private RHM Core as the source of truth for backend, database and secrets.
- [x] Replace standalone Uvicorn launch with the existing `rhm.cli server-update supervise` entrypoint, which supervises FastAPI and Next.js.
- [x] Start an existing offline PostgreSQL cluster at runtime when Debian's `pg_lsclusters` / `pg_ctlcluster` tools are available.
- [x] Add authenticated FastAPI health polling via Android Keystore-protected Bearer token.
- [x] Add bounded Kotlin recovery with exponential backoff; distinguish API downtime from missing/invalid authentication.
- [x] Expose recovery diagnostics in Flutter.
- [x] Make Backend autostart enablement start the manager immediately and persist a boot-time start request.
- [x] Fix the boot preference interaction so backend autostart remains effective even when standalone monitor autostart is disabled.
- [x] Add Linux process start-time and command-identity checks to Termux PID management.
- [x] Fix the current failing Flutter settings test callback.

## CI and source-review gates

- [ ] Run Flutter unit/widget tests and static analysis on the updated branch.
- [ ] Compile the generated Android host (including Kotlin sources) and build ARM64 debug APK.
- [ ] Review automated code findings and all final diffs.
- [ ] Merge the public mobile PR only after the gates pass.

## Device acceptance: Huawei Android 10

- [ ] Complete one-time Termux config and RUN_COMMAND authorization.
- [ ] Verify PostgreSQL starts without creating or resetting any cluster or database.
- [ ] Verify FastAPI health and chat requests against the existing data.
- [ ] Verify Next.js frontend at loopback port 3000 when its production build exists.
- [ ] Kill the backend process and verify supervisor recovery.
- [ ] Kill the supervisor and verify Kotlin detects health loss and restarts it.
- [ ] Reboot Huawei and verify boot receiver, persistent notification and hands-off startup.
- [ ] Check Huawei auto-launch/battery settings and screen-off behavior.
- [ ] Confirm chats, memory, projects, settings, tokens and PostgreSQL rows are preserved.

## Signed release and end-to-end use

- [ ] Add a private-core workflow that checks out a selected public mobile ref and signs with the existing Android keystore secrets.
- [ ] Verify package ID `com.rhm.rhm_mobile` and signer fingerprint against a trusted production APK.
- [ ] Publish or deliver a signed ARM64 artifact with SHA-256 only after signing verification.
- [ ] Install the release APK and preserve data/settings.
- [ ] Verify app chat and local web chat without manually launching Uvicorn, Next.js, or Termux.

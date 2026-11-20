# RHM Mobile Server roadmap

**Baseline:** Flutter client import and Android service foundation.  
**Target:** one RHM Android app managing the existing phone-hosted backend, while keeping the private RHM core as source of truth.

## Completed
- [x] Create public mobile repository and separate app from private RHM core.
- [x] Import existing Flutter source without moving backend, database or secrets.
- [x] Add reproducible Flutter tests, analysis and ARM64 debug APK CI.
- [x] Add Android foreground monitor and opt-in boot receiver.
- [x] Fix review items for installer result, quiet-hour notifications, offline Android host access, IPv6 loopback and Android API floor.
- [x] Add fixed-action Termux RUN_COMMAND bridge.
- [x] Add Android-Keystore encrypted token storage and authenticated FastAPI health polling.
- [x] Document PostgreSQL preservation and embedded-Python feasibility.

## Remaining: device runtime
- [ ] Validate Termux setup and permission on the Huawei Android 10 handset.
- [ ] Verify start, stop and restart control of the real Uvicorn process.
- [ ] Verify valid-token and invalid-token health states.
- [ ] Validate boot startup, foreground notification, power policy and process recovery.
- [ ] Confirm PostgreSQL rows, conversations, memory and settings remain unchanged.
- [ ] Decide embedded Python only after testing the real dependencies on ARM64.

## Remaining: release and update
- [ ] Migrate private backend update proxy source to public RHM-Mobile-Server releases.
- [ ] Confirm signing certificate of the installed production app.
- [ ] Configure protected signing secrets and build a signed release APK.
- [ ] Verify in-place update preserves app data, settings, credentials and chat history.

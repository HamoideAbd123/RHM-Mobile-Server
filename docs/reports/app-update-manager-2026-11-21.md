# RHM Android app update manager — implementation report

**Date:** 2026-11-21  
**Repository:** `HamoideAbd123/RHM-Mobile-Server`  
**Implementation branch:** `bootstrap/update-manager-independent-2026-11-21`  
**Merged into:** `main` via PR #2  
**Merge commit:** `927dc2d8708ba951fad90bf845ed871060680ab3`

## Objective

Make the Flutter APK update lifecycle independent of the local RHM FastAPI server while retaining a strict integrity check, a user-approved Android installation path, and the existing server-runtime updater as a separate feature.

## Implemented

1. **Independent release discovery**
   - Reads `/repos/HamoideAbd123/RHM-Mobile-Server/releases/latest` directly from GitHub.
   - Does not use the RHM loopback API, saved server URL, bearer token, or private Core update proxy.
   - Accepts stable semantic-version releases only and requires a release page and both expected asset names from the same repository and tag.

2. **Safe APK download**
   - Streams APK bytes to an app-private temporary file instead of buffering the complete APK in memory.
   - Reports download progress, supports cancellation, and resumes interrupted downloads with HTTP Range.
   - Restarts from byte zero when the origin does not honor a Range request.
   - Enforces APK/checksum size limits and validates the APK ZIP header.

3. **Integrity and install handoff**
   - Downloads and validates the SHA-256 sidecar.
   - Computes SHA-256 over the downloaded APK and rejects/deletes a mismatching file.
   - Opens Android's package installer only after the APK passes the checks.
   - Declares `REQUEST_INSTALL_PACKAGES`. Android still asks the user to approve installation and enforces signing-certificate continuity; SHA-256 is not a substitute for APK signing.

4. **Automatic checks and notifications**
   - Performs a foreground check on app launch and during the foreground/resume interval.
   - Schedules a best-effort WorkManager check every 12 hours when network connectivity is available.
   - Uses a dedicated app-update notification channel and deduplicates notifications per discovered version.
   - The background app-update task executes before any server URL/token lookup, so it remains usable while the local server is offline.

5. **Separation from server updates**
   - Removed the app APK update-proxy extension from the authenticated `RhmApiClient`.
   - Preserved `/server-update/*` and the server notification polling path for the Python/Next.js runtime.
   - Updated the chat update flow and Control Center update flow to use the standalone updater.

## Verification evidence

GitHub Actions [run #44953230929](https://github.com/HamoideAbd123/RHM-Mobile-Server/actions/runs/44953230929) completed successfully:

- Flutter tests: passed.
- Flutter static analysis: passed.
- Generated Android host preparation and dependency resolution: passed.
- ARM64 debug APK build: passed.
- Debug application ID check: passed (`com.rhm.rhm_mobile.debug`).
- Manifest permission assertions (`REQUEST_INSTALL_PACKAGES`, `POST_NOTIFICATIONS`): passed.
- Artifact upload: passed.

Artifact: `rhm-mobile-android-arm64-debug` (ID `14726368838`, 63,426,873 bytes). Archive SHA-256: `1d068588ecd0b9fb3a51f20bf2f8e4228442b72dc71dbf87c73cccdfb51c8de5`. Expires **2026-12-05 21:52 UTC**.

The artifact is a **debug APK** with package ID `com.rhm.rhm_mobile.debug`. It is not suitable for updating the installed production package.

## Remaining production gates

- The new public mobile repository currently has no stable GitHub Release: `GET /releases/latest` returned HTTP 404 on 2026-11-21.
- The existing production package ID `com.rhm.rhm_mobile` and the exact signing certificate fingerprint must be verified against a trusted installed production APK.
- The existing signing key must remain in a protected private signing workflow. The cleanup PR #47 removed the previous `.github/workflows/mobile-server-signed-build.yml`; it must be restored or replaced in Core without restoring a Flutter source copy. The old workflow uploaded only an Actions artifact, so publishing a GitHub Release here also requires an authorized cross-repository release credential or a manual upload. Do not generate a replacement keystore or store signing secrets in this public repository.
- A signed APK must be published as the release's `app-release.apk` asset with `app-release.apk.sha256`.
- Huawei Android 10 device tests remain outstanding: interruption/resume on real connectivity, checksum rejection, install-source permission, signature continuity, update-in-place, and preservation of chat history, credentials, preferences and local data.
- No production version bump, stable GitHub Release or release Tag was created. Creating a tag now would falsely label a debug build as a production phone release.

## Merge status

The updater implementation was merged into `main` through app-import PR #2 on 2026-11-21 at 22:02:08 UTC. Merge commit: `927dc2d8708ba951fad90bf845ed871060680ab3`. The push and pull-request CI checks on the reconciled PR head both passed: runs #44954292974 and #44954297365.


## Single-source ownership check

The cleanup PR [Core #47](https://github.com/HamoideAbd123/rhm-personal-ai-core/pull/47) was merged on 2026-11-21. A follow-up read of Core `main` confirmed that `mobile/pubspec.yaml` is absent. The mobile repository is the sole source for Flutter application code; Core retains backend API contracts only.

# Android releases and signing continuity

## Current state

The updater release candidate declares package version `0.1.11+12` (version name `0.1.11`, version code `12`). The previously published Core release remains `0.1.10+11`. The private source workflow generates the Android project using `--org com.rhm --project-name rhm_mobile`, which yields the expected application ID `com.rhm.rhm_mobile`; this is the project build configuration to preserve. The exact ID and signer fingerprint still must be checked against the APK installed on the target phone before publishing an update. The private source workflow previously built a signed ARM64 release using four repository Actions secrets:

- `RHM_ANDROID_KEYSTORE_BASE64`
- `RHM_ANDROID_STORE_PASSWORD`
- `RHM_ANDROID_KEY_PASSWORD`
- `RHM_ANDROID_KEY_ALIAS`

Those values are not readable through this workflow, and they have not been copied to the public repository. No new signing key has been generated.

## Why this matters

Android in-place updates require the installed app and the new APK to have the same application identity and an accepted signing lineage. A new, unrelated keystore can make the APK fail to update an existing installation. Therefore:

- Never generate a new keystore merely to make CI green.
- Do not use the debug key for a public release.
- Confirm the existing package ID and certificate fingerprint before release.
- Add the existing signing material only through protected GitHub Actions secrets in the target repository, with access tightly restricted.
- Never paste or upload keystore bytes or passwords into chat, issues, commits or artifacts.

## Current CI output

The public workflow runs unit/widget tests and static analysis, then creates an **ARM64 debug APK** as a short-lived CI artifact. This proves compile viability only; it is not a release candidate and is not compatible with the existing signing identity by default.

## Release checklist

1. Confirm the package ID of the currently installed trusted RHM APK.
2. Obtain the existing permanent keystore from the user's protected backup location (not from the public repository).
3. Verify the certificate fingerprint against the installed APK or a recorded trusted value.
4. Configure the four secrets in this repository's Actions settings.
5. Add a protected release workflow that fails closed when any signing secret is missing.
6. Sign the release APK with the existing key, generate SHA-256, run installation/update tests on a copy/test device, and verify data preservation.
7. Only then publish a matching `vX.Y.Z` GitHub Release.

## Independent app update path

The Android application updater now reads the latest stable release directly from the fixed public repository `HamoideAbd123/RHM-Mobile-Server`. It does not depend on the private FastAPI backend, an API token, or the server's `/mobile/updates/*` routes.

The Flutter client validates the release page and exact asset URLs, requires one `app-release.apk` and one `app-release.apk.sha256` asset, checks the APK's declared size, streams the APK to temporary storage, supports resuming interrupted transfers with HTTP Range, and verifies the SHA-256 digest before invoking Android's installer. WorkManager runs a best-effort 12-hour background check and posts a notification for a newly discovered stable version. Android still requires the user to approve installation.

SHA-256 is an integrity check and the checksum is delivered by the same release source. It does not independently authenticate who published the release. The original Android APK signing certificate is the authenticity and update-compatibility control: Android must reject an APK signed by an unrelated key. Do not install a release build over the existing app until the package ID and signer fingerprint are verified.

The signing workflow must remain private. It should check out this public repository at a reviewed immutable commit or protected release tag, run tests and analysis, build ARM64, verify `com.rhm.rhm_mobile`, verify the expected certificate SHA-256 fingerprint, and upload the signed APK plus checksum to a GitHub Release in this repository using a narrowly scoped publishing credential. Never move the keystore or passwords into this public repository. The existing private-core workflow proposal in [private PR #45](https://github.com/HamoideAbd123/rhm-personal-ai-core/pull/45) has not yet produced a signed artifact; confirm it is still suitable before relying on it.

## Debug package isolation

CI now adds `.debug` to the debug build application ID, producing `com.rhm.rhm_mobile.debug` while leaving the intended release ID `com.rhm.rhm_mobile` unchanged. The workflow inspects the APK manifest with Android `aapt` and fails if the debug package name is not exact. This allows a development build to be installed side-by-side without replacing the existing release installation. It does not prove the release signing key is available or that a future signed build can update the installed app.


## Private signing workflow for public mobile source — 2026-11-20

A private workflow proposal is available in [private PR #45](https://github.com/HamoideAbd123/rhm-personal-ai-core/pull/45). It checks out a selected public RHM-Mobile-Server branch, runs Flutter tests and analysis, and builds an ARM64 production APK using the existing private repository secrets. The APK remains a private Actions artifact.

The first workflow run and retry failed before runner allocation and before any step executed; no signed artifact was produced. This is not evidence of a signing-key mismatch or Gradle failure. Do not move signing secrets to the public repository. Re-run after private GitHub Actions runner execution is available.

The workflow prints the signer SHA-256 fingerprint. Configure the non-secret private repository variable `RHM_ANDROID_CERT_SHA256` to enforce a fingerprint check. Before installing over any existing production app, compare the APK application ID and certificate fingerprint against a trusted previous production APK or the installed app's known certificate. A debug APK with `.debug` package identity is not an in-place release update.

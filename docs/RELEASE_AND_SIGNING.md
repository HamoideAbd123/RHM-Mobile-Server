# Android releases and signing continuity

## Current state

The imported app manifest declares package version `0.1.10+11`. The private source workflow previously built a signed ARM64 release using four repository Actions secrets:

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

## Update proxy migration

The current app asks the private FastAPI backend for update metadata and assets. The backend's GitHub token and release-source allowlist are currently associated with the private core repository. Before the public repository starts publishing app releases, update and test the private backend's update proxy to read this repository and only its approved stable APK/checksum assets. Keep the credential server-side and read-only.

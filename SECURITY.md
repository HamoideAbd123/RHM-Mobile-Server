# Security policy

## Never commit

- `.env` or environment dumps.
- RHM bearer tokens, model-provider keys, GitHub tokens, cookies or authorization headers.
- Android keystores, private keys, key passwords or `key.properties`.
- Production database files, user conversations, memory exports or personal backups.
- Device-local paths or account-specific configuration copied from private operational notes.

## Mobile client rules

- Use Android secure storage for the bearer token.
- Do not place secrets in Dart constants, assets, Gradle files, manifest metadata or build logs.
- Disable app backup for protected credential state unless a reviewed backup/restore design is introduced.
- Disable redirect following on authenticated API requests so the bearer token is not forwarded to another host.
- Keep loopback-only HTTP separate from any future remote profile.
- Keep model-provider and GitHub release credentials on the backend.
- Treat API responses, tool outputs and model-generated text as untrusted input.

## Runtime rules

- Kotlin runtime control must accept only fixed, reviewed operations; never expose an arbitrary shell interface.
- Start, stop, restart and diagnostic actions must be explicit and auditable.
- Redact secret values and sensitive prompt content from logs.
- Preserve user data during app updates. Database reset and destructive repair require explicit user approval and verified backups.
- A runtime health indicator must represent a successful authenticated health check, not merely a live process.

## Public repository rules

- Review generated artifacts before uploading them.
- Do not publish unsigned/debug builds as production updates.
- Preserve the existing Android application ID and signing identity for in-place updates.
- A public repository does not imply an open-source license; add a license only after making that decision.


## Android foreground monitor

- The foreground monitor starts only through an explicit app action or the user's enabled boot preference.
- The ongoing notification must remain visible and report only the actual TCP probe result.
- The boot preference defaults to false. Do not silently enable it.
- On Android 13+, the app requires notification permission before starting or enabling boot monitoring.
- The current service probes only `127.0.0.1:8000`; it never sends an API token in its monitor probe.
- No Termux permission, Termux configuration change, arbitrary command execution, root or stealth behavior is implemented.
- The `specialUse` foreground-service classification must be re-evaluated against the actual workload and distribution policy before release.
- The CI debug APK has a distinct `.debug` application ID and must not be treated as a release update.

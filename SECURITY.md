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

- The foreground service starts through an explicit app action or the user's enabled backend/monitor boot preference.
- The ongoing notification must remain visible and report the authenticated FastAPI health state, not merely a live TCP port.
- The boot preference defaults to false. Do not silently enable it.
- On Android 13+, the app requires notification permission before starting or enabling boot monitoring.
- The Kotlin service sends the RHM bearer token only to `http://127.0.0.1:8000/mobile/health`, disables HTTP redirects, and distinguishes authentication failures from server unavailability.
- The native health token is encrypted with AES-GCM using an Android Keystore key. The Flutter app's existing secure-storage token remains authoritative.
- The manifest requests `com.termux.permission.RUN_COMMAND`. The owner must explicitly grant it in Android settings and enable `allow-external-apps=true` in Termux before the bridge works.
- The Termux bridge accepts only the fixed operations `start`, `stop`, `restart`, and `status`; it never accepts arbitrary shell strings, model output, or user-supplied paths.
- The wrapper invokes the fixed owner-installed script and the existing private RHM supervisor. It must validate the configured private checkout path and process identity before control operations.
- Manual Backend stop disables backend boot autostart so the health monitor does not relaunch a service the owner deliberately stopped.
- No root, stealth, process hiding, or Android security bypass is implemented.
- The `specialUse` foreground-service classification must be re-evaluated against the actual workload and distribution policy before release.
- The CI debug APK has a distinct `.debug` application ID and must not be treated as a release update.


## Termux command bridge and health-monitor boundary

- Android declares `com.termux.permission.RUN_COMMAND`; the permission is not granted automatically by the app.
- Termux owner configuration `allow-external-apps=true` is also required. This setting and the Android permission are one-time owner-approved setup steps.
- The MethodChannel exposes only fixed method names and the Termux controller only sends four allow-listed actions. Do not add general command execution.
- The wrapper reads an owner-maintained config file inside Termux. The app cannot set or override the Debian path.
- Kotlin polls only the fixed same-device endpoint `/mobile/health` with the RHM bearer token; redirects are disabled. Do not change this to a remote URL or follow redirects.
- A healthy result proves the authenticated FastAPI health route responds. It does not prove PostgreSQL queries, provider availability, chat completion, or frontend health.
- Recovery is rate-limited and does not restart on HTTP 401/403 or missing credentials.
- The foreground-service type is declared as `specialUse`; reassess platform and distribution requirements before public-store release.

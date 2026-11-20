# Termux-managed RHM server supervisor

**Purpose:** one-time Termux integration, then the Android foreground service starts and supervises the existing RHM runtime after boot.

## Runtime launched by Android

The Termux wrapper invokes the existing private-core command:

```bash
.venv/bin/python -m rhm.cli server-update supervise --host 127.0.0.1 --port 8000
```

This is intentional. Do not replace it with a raw Uvicorn command: the existing private supervisor owns FastAPI/Uvicorn and the Next.js frontend lifecycle. It restarts an exited API process, periodically checks the frontend, and attempts to restore unhealthy frontend state. PostgreSQL is an existing prerequisite; the wrapper attempts to start already-configured offline Debian clusters using `pg_ctlcluster --skip-systemctl-redirect` when those utilities exist. It never initializes, drops, migrates or resets a database.

## One-time owner setup

1. Install Termux from a trusted compatible distribution and install the Debian PRoot environment already used by RHM.
2. In Termux, enable the documented external-app command setting in `~/.termux/termux.properties`:

   ```properties
   allow-external-apps=true
   ```

   Reload Termux settings or restart Termux.
3. Grant RHM the Android permission `com.termux.permission.RUN_COMMAND` in Android app permissions.
4. Install the fixed wrapper from this repository as `$HOME/.local/bin/rhm-runtime-control` and make it executable:

   ```bash
   mkdir -p ~/.config ~/.local/bin ~/.local/state/rhm
   chmod 700 ~/.config ~/.local/bin ~/.local/state/rhm
   cp /path/to/RHM-Mobile-Server/scripts/termux/rhm-runtime-control.sh ~/.local/bin/rhm-runtime-control
   chmod 700 ~/.local/bin/rhm-runtime-control
   ```

5. Create the owner-only configuration. Set the path to the **existing private RHM checkout inside Debian**, not the public mobile repository:

   ```bash
   cat > ~/.config/rhm-runtime.conf <<'EOF'
   RHM_TERMUX_DISTRO=debian
   RHM_DEBIAN_PROJECT=/root/rhm-phase2
   EOF
   chmod 600 ~/.config/rhm-runtime.conf
   ```

   Change the example project path only when the real private checkout uses a different path. Do not place API tokens, provider keys or passwords in this file.
6. Open RHM once, confirm its saved server URL and API token work, and synchronize the token to Android Keystore. Then open **Settings → النظام المحلي → مضيف Android المحلي**, enable **تشغيل Backend بعد إقلاع الهاتف**, and grant the notification permission if Android requests it. This toggle starts the foreground manager and requests the backend immediately.
7. On Huawei, allow RHM and Termux to auto-launch and set battery handling to a mode that does not aggressively stop their background activity. These manufacturer settings are required for best-effort boot recovery.

## Controls

RHM can send only four fixed operations to the Termux wrapper: `start`, `stop`, `restart`, and `status`. No shell command, project path, or user/model-generated text is passed to Termux.

The wrapper records a protected PID and Linux process start time, then validates both the start time and the expected supervisor command before reporting or signalling the process. This prevents a stale PID from being mistaken for an unrelated process after PID reuse.

## Health and recovery

- Kotlin calls `GET http://127.0.0.1:8000/mobile/health` every 20 seconds with the token encrypted by Android Keystore.
- Only HTTP 200 plus the expected loopback health JSON is marked healthy.
- HTTP 401/403 or a missing token is reported as an authentication/configuration problem and does not cause restarts.
- An initially unavailable backend must fail five checks before the external recovery path runs; a backend that was healthy and then goes unavailable needs two failed checks.
- External recovery backoff is 30, 60, 120, then 300 seconds. The private Python supervisor separately handles backend process exits and Next.js frontend maintenance.
- The Android notification remains visible while the foreground service runs.

## What still requires on-device acceptance

- The exact Termux version and RUN_COMMAND permission behavior on Huawei Android 10.
- Whether the Debian PostgreSQL cluster can start cleanly from this PRoot environment.
- Whether the private checkout's Next.js production build is present and healthy on port 3000. Existing production build output is required; this wrapper deliberately does not run a memory-heavy build on every boot.
- Boot receiver and foreground-service survival under Huawei battery management.
- Full data-preservation and real chat/browser tests.

## Safety and data preservation

- FastAPI and Next.js remain loopback-bound by default. This does not expose the server to Wi-Fi or the Internet.
- PostgreSQL's existing cluster, data directory and schema are preserved. No destructive database command is included.
- No backend secrets or signing material are copied into the public mobile repository.
- Android does not guarantee an app can run forever after force-stop, reboot before first unlock, severe memory pressure or manufacturer battery intervention.

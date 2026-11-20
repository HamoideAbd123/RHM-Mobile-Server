# Termux-managed Python backend integration

**Status:** Kotlin command bridge and wrapper added; hardware acceptance remains open.

## Scope

RHM sends only four fixed actions to an owner-installed Termux wrapper: start, stop, restart, status. Flutter/model text is never accepted as a shell command or arbitrary path. The wrapper launches the existing Python backend from Debian PRoot and binds Uvicorn to 127.0.0.1:8000.

This is a Termux-assisted phone runtime, not an embedded Python interpreter inside the APK. Existing FastAPI routes, business logic and PostgreSQL remain unchanged.

## One-time owner setup

In Termux, create the owner-only config:

```bash
mkdir -p ~/.config ~/.local/bin ~/.local/state/rhm
chmod 700 ~/.config ~/.local/bin ~/.local/state/rhm
cat > ~/.config/rhm-runtime.conf <<'EOF'
RHM_TERMUX_DISTRO=debian
RHM_DEBIAN_PROJECT=/root/rhm-review
EOF
chmod 600 ~/.config/rhm-runtime.conf
```

Set RHM_DEBIAN_PROJECT to the actual checkout path inside Debian. Do not put tokens or provider keys in this file.

Copy scripts/termux/rhm-runtime-control.sh from this repository to $HOME/.local/bin/rhm-runtime-control, then run chmod 700 ~/.local/bin/rhm-runtime-control.

Prerequisites:
- Grant RHM the Android permission com.termux.permission.RUN_COMMAND in App Info → RHM → Permissions / Additional permissions.
- In Termux ~/.termux/termux.properties, the owner must deliberately set allow-external-apps=true, then reload settings or restart Termux.
- RUN_COMMAND is a meaningful trust boundary because it permits external apps to execute commands in Termux's context. Grant it only to software you trust.
- Termux documents that Android 10 background execution is affected by background-start and device battery policies. Verify on the exact Huawei handset.

Open مضيف Android المحلي inside RHM and select Start Backend. The app sends one fixed action and checks GET /mobile/health with the saved Bearer token.

## Backend expectations

Debian must contain the existing private RHM checkout, .venv/bin/uvicorn, rhm/api/main.py, protected environment/token files, and existing PostgreSQL service. The wrapper does not create, migrate, reset, copy or back up the database.

## Authenticated health

Kotlin stores a copy of the accepted Bearer token encrypted using AES-GCM with an Android Keystore key. It polls GET /mobile/health over loopback with redirects disabled. A successful result means FastAPI accepted the token and returned the expected status. It does not prove PostgreSQL, providers, MCP, agents or Next.js are healthy.

## Limitations

- Termux can reject commands until RUN_COMMAND and allow-external-apps are enabled.
- The first wrapper tracks the PRoot launcher PID and requests its termination. Verify that Uvicorn also exits before relying on Stop.
- Android may stop apps because of force-stop, memory pressure, battery policy or manufacturer rules. No 100% uptime guarantee is possible.
- Boot startup is opt-in and depends on RHM foreground-service and Termux behavior.
- This integration does not embed Python or replace Termux.

## Acceptance checklist

- [ ] Termux install and RUN_COMMAND permission are detected.
- [ ] Start launches Uvicorn on loopback only.
- [ ] Authenticated health is true only after HTTP 200 plus expected JSON.
- [ ] Invalid token shows unauthorized, never healthy.
- [ ] Stop ends the actual Uvicorn process and health becomes unavailable.
- [ ] Restart returns FastAPI health to healthy.
- [ ] Foreground notification remains accurate.
- [ ] Startup after reboot occurs only when explicitly enabled.
- [ ] Huawei Android 10 battery/process behavior is verified manually.
- [ ] PostgreSQL rows and RHM user data remain unchanged.

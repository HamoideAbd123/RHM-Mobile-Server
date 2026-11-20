#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail
umask 077
readonly STATE_DIR="$HOME/.local/state/rhm"
readonly CONFIG_FILE="$HOME/.config/rhm-runtime.conf"
readonly PID_FILE="$STATE_DIR/backend.pid"
readonly LOG_FILE="$STATE_DIR/backend.log"
readonly PROOT_DISTRO="$PREFIX/bin/proot-distro"
fail() { printf 'RHM runtime control: %s\n' "$1" >&2; exit 1; }
[[ -r "$CONFIG_FILE" ]] || fail "Missing $CONFIG_FILE"
# Owner-maintained config only; never populate it from app/model text.
# shellcheck disable=SC1090
source "$CONFIG_FILE"
DISTRO="${RHM_TERMUX_DISTRO:-debian}"
PROJECT="${RHM_DEBIAN_PROJECT:-/root/rhm-review}"
[[ "$DISTRO" =~ ^[A-Za-z0-9._-]+$ ]] || fail "Invalid distro name"
[[ "$PROJECT" == /* && "$PROJECT" =~ ^/[A-Za-z0-9_./-]+$ ]] || fail "Invalid project path"
[[ "$PROJECT" != *"/../"* && "$PROJECT" != */.. ]] || fail "Parent path segments are not allowed"
[[ -x "$PROOT_DISTRO" ]] || fail "proot-distro is not installed"
mkdir -p "$STATE_DIR"
chmod 700 "$STATE_DIR"
pid_is_running() {
  [[ -s "$PID_FILE" ]] || return 1
  local pid
  pid="$(cat "$PID_FILE")"
  [[ "$pid" =~ ^[0-9]+$ ]] || return 1
  kill -0 "$pid" 2>/dev/null
}
start_backend() {
  if pid_is_running; then printf 'already_running\n'; return 0; fi
  rm -f "$PID_FILE"
  "$PROOT_DISTRO" login "$DISTRO" -- /bin/bash -lc \
    'test -x "$1/.venv/bin/uvicorn" && test -f "$1/rhm/api/main.py"' \
    rhm-runtime "$PROJECT" || fail "Backend project or virtual environment is not ready"
  nohup "$PROOT_DISTRO" login "$DISTRO" -- /bin/bash -lc \
    'cd "$1" && exec "$1/.venv/bin/uvicorn" rhm.api.main:app --host 127.0.0.1 --port 8000 --no-access-log' \
    rhm-runtime "$PROJECT" >>"$LOG_FILE" 2>&1 </dev/null &
  local pid=$!
  printf '%s\n' "$pid" >"$PID_FILE"
  chmod 600 "$PID_FILE"
  sleep 1
  if kill -0 "$pid" 2>/dev/null; then printf 'start_requested pid=%s\n' "$pid"; return 0; fi
  rm -f "$PID_FILE"
  fail "Backend launcher exited; inspect the private Termux log"
}
stop_backend() {
  if ! pid_is_running; then rm -f "$PID_FILE"; printf 'already_stopped\n'; return 0; fi
  local pid
  pid="$(cat "$PID_FILE")"
  kill -TERM "$pid" 2>/dev/null || true
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    kill -0 "$pid" 2>/dev/null || break
    sleep 1
  done
  if kill -0 "$pid" 2>/dev/null; then kill -KILL "$pid" 2>/dev/null || true; fi
  rm -f "$PID_FILE"
  printf 'stop_requested\n'
}
case "${1:-}" in
  start) start_backend ;;
  stop) stop_backend ;;
  restart) stop_backend; start_backend ;;
  status)
    if pid_is_running; then printf 'launcher_running pid=%s\n' "$(cat "$PID_FILE")"
    else rm -f "$PID_FILE"; printf 'launcher_stopped\n'
    fi ;;
  *) fail "Allowed actions: start, stop, restart, status" ;;
esac

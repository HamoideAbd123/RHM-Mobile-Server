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
PROJECT="${RHM_DEBIAN_PROJECT:-}"
[[ "$DISTRO" =~ ^[A-Za-z0-9._-]+$ ]] || fail "Invalid distro name"
[[ -n "$PROJECT" ]] || fail "Set RHM_DEBIAN_PROJECT to the existing RHM checkout inside Debian"
[[ "$PROJECT" == /* && "$PROJECT" =~ ^/[A-Za-z0-9_./-]+$ ]] || fail "Invalid project path"
[[ "$PROJECT" != *"/../"* && "$PROJECT" != */.. ]] || fail "Parent path segments are not allowed"
[[ -x "$PROOT_DISTRO" ]] || fail "proot-distro is not installed"

mkdir -p "$STATE_DIR"
chmod 700 "$STATE_DIR"

proc_start_ticks() {
  local pid="$1"
  [[ -r "/proc/$pid/stat" ]] || return 1
  awk '{print $22}' "/proc/$pid/stat" 2>/dev/null
}

pid_is_rhm_launcher() {
  [[ -s "$PID_FILE" ]] || return 1
  local pid saved_ticks current_ticks command_line
  read -r pid saved_ticks < "$PID_FILE" || return 1
  [[ "$pid" =~ ^[0-9]+$ && "$saved_ticks" =~ ^[0-9]+$ ]] || return 1
  kill -0 "$pid" 2>/dev/null || return 1

  current_ticks="$(proc_start_ticks "$pid")" || return 1
  [[ "$current_ticks" == "$saved_ticks" ]] || return 1

  command_line="$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null || true)"
  [[ "$command_line" == *"$PROJECT"* ]] || return 1
  [[ "$command_line" == *"rhm.api.main:app"* ]] || return 1
  [[ "$command_line" == *"proot"* ]] || return 1
}

start_backend() {
  if pid_is_rhm_launcher; then
    read -r pid _ < "$PID_FILE"
    printf 'already_running pid=%s\n' "$pid"
    return 0
  fi
  rm -f "$PID_FILE"

  "$PROOT_DISTRO" login "$DISTRO" -- /bin/bash -lc \
    'test -x "$1/.venv/bin/uvicorn" && test -f "$1/rhm/api/main.py"' \
    rhm-runtime "$PROJECT" || fail "Backend project or virtual environment is not ready"

  nohup "$PROOT_DISTRO" login "$DISTRO" -- /bin/bash -lc \
    'cd "$1" && exec "$1/.venv/bin/uvicorn" rhm.api.main:app --host 127.0.0.1 --port 8000 --no-access-log' \
    rhm-runtime "$PROJECT" >>"$LOG_FILE" 2>&1 </dev/null &
  local pid=$!
  local start_ticks=""
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    if kill -0 "$pid" 2>/dev/null; then
      start_ticks="$(proc_start_ticks "$pid" || true)"
      if [[ -n "$start_ticks" ]]; then
        printf '%s %s\n' "$pid" "$start_ticks" > "$PID_FILE"
        chmod 600 "$PID_FILE"
        if pid_is_rhm_launcher; then
          printf 'start_requested pid=%s\n' "$pid"
          return 0
        fi
        rm -f "$PID_FILE"
      fi
    else
      break
    fi
    sleep 1
  done

  rm -f "$PID_FILE"
  fail "Could not verify the RHM launcher process; inspect the Termux log"
}

stop_backend() {
  if ! pid_is_rhm_launcher; then
    rm -f "$PID_FILE"
    printf 'already_stopped_or_stale_pid\n'
    return 0
  fi

  local pid
  read -r pid _ < "$PID_FILE"
  kill -TERM "$pid" 2>/dev/null || true
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    pid_is_rhm_launcher || break
    sleep 1
  done

  if pid_is_rhm_launcher; then
    kill -KILL "$pid" 2>/dev/null || true
  fi
  rm -f "$PID_FILE"
  printf 'stop_requested\n'
}

case "${1:-}" in
  start) start_backend ;;
  stop) stop_backend ;;
  restart) stop_backend; start_backend ;;
  status)
    if pid_is_rhm_launcher; then
      read -r pid _ < "$PID_FILE"
      printf 'launcher_running pid=%s\n' "$pid"
    else
      rm -f "$PID_FILE"
      printf 'launcher_stopped\n'
    fi
    ;;
  *) fail "Allowed actions: start, stop, restart, status" ;;
esac

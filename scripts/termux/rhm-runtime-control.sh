#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail
umask 077

readonly STATE_DIR="$HOME/.local/state/rhm"
readonly CONFIG_FILE="$HOME/.config/rhm-runtime.conf"
readonly PID_FILE="$STATE_DIR/server-supervisor.pid"
readonly LOG_FILE="$STATE_DIR/server-supervisor.log"
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

pid_is_rhm_supervisor() {
  [[ -s "$PID_FILE" ]] || return 1
  local pid saved_ticks current_ticks command_line
  read -r pid saved_ticks < "$PID_FILE" || return 1
  [[ "$pid" =~ ^[0-9]+$ && "$saved_ticks" =~ ^[0-9]+$ ]] || return 1
  kill -0 "$pid" 2>/dev/null || return 1

  current_ticks="$(proc_start_ticks "$pid")" || return 1
  [[ "$current_ticks" == "$saved_ticks" ]] || return 1

  command_line="$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null || true)"
  [[ "$command_line" == *"$PROJECT"* ]] || return 1
  [[ "$command_line" == *"rhm.cli"* ]] || return 1
  [[ "$command_line" == *"server-update supervise"* ]] || return 1
  [[ "$command_line" == *"proot"* ]] || return 1
}

start_backend() {
  if pid_is_rhm_supervisor; then
    read -r pid _ < "$PID_FILE"
    printf 'already_running pid=%s\n' "$pid"
    return 0
  fi
  rm -f "$PID_FILE"

  "$PROOT_DISTRO" login "$DISTRO" -- /bin/bash -lc \
    'test -x "$1/.venv/bin/python" && test -f "$1/rhm/cli.py" && test -f "$1/rhm/server_supervisor.py"' \
    rhm-runtime "$PROJECT" || fail "RHM Python environment or server supervisor is missing"

  nohup "$PROOT_DISTRO" login "$DISTRO" -- /bin/bash -lc \
    'set -e; cd "$1"; if command -v pg_lsclusters >/dev/null 2>&1 && command -v pg_ctlcluster >/dev/null 2>&1; then while read -r version cluster port status owner data_dir log_file; do if [[ "$status" != "online" ]]; then pg_ctlcluster --skip-systemctl-redirect "$version" "$cluster" start; fi; done < <(pg_lsclusters --no-header); fi; exec "$1/.venv/bin/python" -m rhm.cli server-update supervise --host 127.0.0.1 --port 8000' \
    rhm-runtime "$PROJECT" >>"$LOG_FILE" 2>&1 </dev/null &
  local pid=$!
  local start_ticks=""
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    if kill -0 "$pid" 2>/dev/null; then
      start_ticks="$(proc_start_ticks "$pid" || true)"
      if [[ -n "$start_ticks" ]]; then
        printf '%s %s\n' "$pid" "$start_ticks" > "$PID_FILE"
        chmod 600 "$PID_FILE"
        if pid_is_rhm_supervisor; then
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
  fail "Could not verify the RHM supervisor process; inspect the Termux log"
}

stop_backend() {
  if ! pid_is_rhm_supervisor; then
    rm -f "$PID_FILE"
    printf 'already_stopped_or_stale_pid\n'
    return 0
  fi

  local pid
  read -r pid _ < "$PID_FILE"
  kill -TERM "$pid" 2>/dev/null || true
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    pid_is_rhm_supervisor || break
    sleep 1
  done

  if pid_is_rhm_supervisor; then
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
    if pid_is_rhm_supervisor; then
      read -r pid _ < "$PID_FILE"
      printf 'supervisor_running pid=%s\n' "$pid"
    else
      rm -f "$PID_FILE"
      printf 'supervisor_stopped\n'
    fi
    ;;
  *) fail "Allowed actions: start, stop, restart, status" ;;
esac

#!/usr/bin/env bash
set -u

HOME_DIR="${HOME:-$(getent passwd "$(id -u)" | cut -d: -f6)}"
USER_NAME="${USER:-$(id -un)}"
QS_CFG_DIR="$HOME_DIR/.config/quickshell"
FOCUS_DAEMON="$HOME_DIR/.config/hypr/scripts/quickshell/archtools/focus_daemon.py"

log() {
  printf '[reload] %s\n' "$*"
}

find_bin() {
  local name="$1"
  command -v "$name" 2>/dev/null || true
}

HYPRCTL_BIN="$(find_bin hyprctl)"
QS_BIN="$(find_bin qs)"
AWWW_BIN="$(find_bin awww)"
AWWW_DAEMON_BIN="$(find_bin awww-daemon)"
HYPRSUNSET_BIN="$(find_bin hyprsunset)"
WL_PASTE_BIN="$(find_bin wl-paste)"
CLIPHIST_BIN="$(find_bin cliphist)"
PYTHON3_BIN="$(find_bin python3)"
POLKIT_BIN="/usr/lib/polkit-kde-authentication-agent-1"

cmd_running() {
  local needle="$1"
  local line

  while IFS= read -r line; do
    [[ "$line" == *"$needle"* ]] && return 0
  done < <(ps -u "$USER_NAME" -o args= 2>/dev/null)

  return 1
}

normalize_path() {
  local path="$1"

  if [[ -z "$path" ]]; then
    return 1
  fi

  if command -v realpath >/dev/null 2>&1; then
    realpath -m -- "$path" 2>/dev/null || printf '%s\n' "$path"
    return 0
  fi

  if command -v readlink >/dev/null 2>&1; then
    readlink -f -- "$path" 2>/dev/null || printf '%s\n' "$path"
    return 0
  fi

  printf '%s\n' "$path"
}

paths_equal() {
  local left right

  left="$(normalize_path "$1")"
  right="$(normalize_path "$2")"

  [[ "$left" == "$right" ]]
}

qs_process_config() {
  local -n argv_ref="$1"
  local i arg

  for ((i = 1; i < ${#argv_ref[@]}; i++)); do
    arg="${argv_ref[i]}"

    case "$arg" in
      -p|--path|-c|--config)
        if (( i + 1 < ${#argv_ref[@]} )); then
          printf '%s\n' "${argv_ref[i + 1]}"
          return 0
        fi
        return 1
        ;;
      -p=*|--path=*|-c=*|--config=*)
        printf '%s\n' "${arg#*=}"
        return 0
        ;;
    esac
  done

  return 1
}

qs_process_matches() {
  local target_config="$1"
  shift

  local -a argv=("$@")
  local exe_name config_path

  [[ ${#argv[@]} -gt 0 ]] || return 1

  exe_name="${argv[0]##*/}"
  [[ "$exe_name" == "qs" || "$exe_name" == "quickshell" ]] || return 1

  # Ignore short-lived qs IPC client calls: they are not daemon instances.
  [[ "${argv[1]:-}" == "ipc" ]] && return 1

  if ! config_path="$(qs_process_config argv)"; then
    config_path=""
  fi

  if [[ -z "$target_config" ]]; then
    [[ -z "$config_path" ]] && return 0
    paths_equal "$config_path" "$QS_CFG_DIR"
    return $?
  fi

  [[ -n "$config_path" ]] || return 1
  paths_equal "$config_path" "$target_config"
}

qs_running() {
  local target_config="$1"
  local pid

  while IFS= read -r pid; do
    local -a argv=()

    [[ "$pid" =~ ^[0-9]+$ ]] || continue
    [[ -r "/proc/$pid/cmdline" ]] || continue

    mapfile -d '' -t argv < "/proc/$pid/cmdline"
    [[ ${#argv[@]} -gt 0 ]] || continue

    if qs_process_matches "$target_config" "${argv[@]}"; then
      return 0
    fi
  done < <(ps -u "$USER_NAME" -o pid= 2>/dev/null)

  return 1
}

start_detached() {
  if [[ $# -eq 0 ]]; then
    return 1
  fi

  nohup "$@" >/dev/null 2>&1 </dev/null &
}

ensure_running() {
  local label="$1"
  local needle="$2"
  shift 2

  if [[ $# -eq 0 ]]; then
    log "skip $label: empty command"
    return 0
  fi

  if cmd_running "$needle"; then
    log "already running: $label"
    return 0
  fi

  start_detached "$@"
  sleep 0.15

  if cmd_running "$needle"; then
    log "started: $label"
  else
    log "failed to start: $label"
  fi
}

ensure_qs_running() {
  local label="$1"
  local config_path="$2"
  shift 2

  if [[ $# -eq 0 ]]; then
    log "skip $label: empty command"
    return 0
  fi

  if qs_running "$config_path"; then
    log "already running: $label"
    return 0
  fi

  start_detached "$@"
  sleep 0.25

  if qs_running "$config_path"; then
    log "started: $label"
  else
    log "failed to start: $label"
  fi
}

if [[ -n "$HYPRCTL_BIN" ]]; then
  "$HYPRCTL_BIN" reload
  sleep 0.2
else
  log "hyprctl not found"
fi

# Quickshell instances
if [[ -n "$QS_BIN" ]]; then
  ensure_qs_running "qs main" "" "$QS_BIN" -d
  ensure_qs_running "qs overview" "$QS_CFG_DIR/overview" "$QS_BIN" -c "$QS_CFG_DIR/overview" -d
  ensure_qs_running "qs launcher" "$QS_CFG_DIR/launcher" "$QS_BIN" -c "$QS_CFG_DIR/launcher" -d
  ensure_qs_running "qs gamelauncher" "$QS_CFG_DIR/gamelauncher" "$QS_BIN" -c "$QS_CFG_DIR/gamelauncher" -d
else
  log "qs not found"
fi

# Other autostart processes to keep alive
if [[ -n "$PYTHON3_BIN" && -f "$FOCUS_DAEMON" ]]; then
  ensure_running "focus daemon" "$PYTHON3_BIN $FOCUS_DAEMON" "$PYTHON3_BIN" "$FOCUS_DAEMON"
fi

if [[ -n "$AWWW_DAEMON_BIN" ]]; then
  ensure_running "awww-daemon" "$AWWW_DAEMON_BIN" "$AWWW_DAEMON_BIN"
fi

if [[ -n "$HYPRSUNSET_BIN" ]]; then
  ensure_running "hyprsunset" "$HYPRSUNSET_BIN" "$HYPRSUNSET_BIN"
fi

if [[ -n "$WL_PASTE_BIN" && -n "$CLIPHIST_BIN" ]]; then
  ensure_running "cliphist watcher" "$WL_PASTE_BIN --watch $CLIPHIST_BIN store" "$WL_PASTE_BIN" --watch "$CLIPHIST_BIN" store
fi

if [[ -x "$POLKIT_BIN" ]]; then
  ensure_running "polkit agent" "$POLKIT_BIN" "$POLKIT_BIN"
fi

# hypridle intentionally not checked here

# If awww is installed but not initialized, initialize it.
if [[ -n "$AWWW_BIN" ]]; then
  if ! "$AWWW_BIN" query >/dev/null 2>&1; then
    "$AWWW_BIN" init >/dev/null 2>&1 || true
    sleep 0.05
  fi
fi

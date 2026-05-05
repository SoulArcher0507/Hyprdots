#!/usr/bin/env bash
set -u

WATCHER_NAME="org.kde.StatusNotifierWatcher"
WATCHER_PATH="/StatusNotifierWatcher"
WATCHER_IFACE="org.kde.StatusNotifierWatcher"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell"
LOG_FILE="$CACHE_DIR/tray-watchdog.log"

mkdir -p "$CACHE_DIR"

log() {
  printf '%s %s\n' "$(date '+%F %T')" "$*" >>"$LOG_FILE"
}

watcher_ready() {
  busctl --user get-property "$WATCHER_NAME" "$WATCHER_PATH" "$WATCHER_IFACE" IsStatusNotifierHostRegistered >/dev/null 2>&1
}

watcher_owner() {
  busctl --user call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus GetNameOwner s "$WATCHER_NAME" 2>/dev/null |
    awk -F'"' '/^s / { print $2 }'
}

wait_for_watcher() {
  local timeout="${1:-20}"
  local elapsed=0

  while ! watcher_ready; do
    if (( elapsed >= timeout )); then
      log "watcher wait timed out after ${timeout}s"
      return 1
    fi
    sleep 1
    elapsed=$((elapsed + 1))
  done
}

registered_items() {
  busctl --user get-property "$WATCHER_NAME" "$WATCHER_PATH" "$WATCHER_IFACE" RegisteredStatusNotifierItems 2>/dev/null |
    grep -o '"[^"]*"' |
    tr -d '"'
}

connection_pid() {
  local service="$1"

  busctl --user call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus GetConnectionUnixProcessID s "$service" 2>/dev/null |
    awk '/^u / { print $2 }'
}

pid_matches() {
  local pid="$1"
  local pattern="$2"

  [[ -r "/proc/$pid/cmdline" ]] || return 1
  tr '\0' ' ' <"/proc/$pid/cmdline" | grep -Eiq "$pattern"
}

app_running() {
  local pattern="$1"

  pgrep -af "$pattern" >/dev/null 2>&1
}

app_has_tray_item() {
  local pattern="$1"
  local item service pid

  while IFS= read -r item; do
    [[ -n "$item" ]] || continue
    service="${item%%/*}"
    pid="$(connection_pid "$service")"
    [[ -n "$pid" ]] || continue

    if pid_matches "$pid" "$pattern"; then
      return 0
    fi
  done < <(registered_items)

  return 1
}

restart_app() {
  local name="$1"
  local match_pattern="$2"
  shift 2

  if ! app_running "$match_pattern"; then
    return 0
  fi

  if app_has_tray_item "$match_pattern"; then
    return 0
  fi

  log "$name is running without a tray item; restarting it after watcher change"
  pkill -TERM -f "$match_pattern" >/dev/null 2>&1 || true
  sleep 2

  if app_running "$match_pattern"; then
    pkill -KILL -f "$match_pattern" >/dev/null 2>&1 || true
    sleep 1
  fi

  launch_detached "$@"
}

shell_join() {
  local arg quoted out=""

  for arg in "$@"; do
    printf -v quoted '%q' "$arg"
    out+="${out:+ }$quoted"
  done

  printf '%s' "$out"
}

launch_detached() {
  local command_string

  if command -v hyprctl >/dev/null 2>&1 && [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    command_string="$(shell_join "$@")"
    hyprctl dispatch exec "$command_string" >/dev/null 2>&1 && return 0
  fi

  nohup "$@" >/dev/null 2>&1 &
}

recover_known_apps() {
  wait_for_watcher 10 || return 0
  sleep 2

  restart_app "Vesktop" "/usr/lib/vesktop/app\\.asar|(^|[[:space:]/])vesktop([[:space:]]|$)" vesktop
  restart_app "Element" "/usr/lib/element/app\\.asar|(^|[[:space:]/])element-desktop([[:space:]]|$)" element-desktop
}

watch_loop() {
  local last_owner=""
  local owner=""

  log "tray watchdog started"

  while true; do
    owner="$(watcher_owner)"
    if [[ -n "$owner" && "$owner" != "$last_owner" ]]; then
      log "watcher owner changed: ${last_owner:-none} -> $owner"
      last_owner="$owner"
      recover_known_apps
    fi
    sleep 5
  done
}

case "${1:-}" in
  wait)
    shift
    wait_for_watcher "${1:-20}"
    ;;
  launch)
    shift
    timeout="${1:-20}"
    shift || true
    wait_for_watcher "$timeout" || true
    exec "$@"
    ;;
  recover)
    recover_known_apps
    ;;
  watch)
    watch_loop
    ;;
  *)
    printf 'Usage: %s {wait [timeout]|launch timeout command [args...]|recover|watch}\n' "$0" >&2
    exit 2
    ;;
esac

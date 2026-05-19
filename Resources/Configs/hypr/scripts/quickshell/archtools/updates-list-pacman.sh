#!/usr/bin/env bash
set -euo pipefail

has() { command -v "$1" >/dev/null 2>&1; }

PACMAN_LOCK_WAIT_SECONDS="${ARCHTOOLS_PACMAN_LOCK_WAIT_SECONDS:-45}"
[[ "$PACMAN_LOCK_WAIT_SECONDS" =~ ^[0-9]+$ ]] || PACMAN_LOCK_WAIT_SECONDS=45
CHECKUPDATES_MAX_AGE_SECONDS="${ARCHTOOLS_CHECKUPDATES_MAX_AGE_SECONDS:-900}"
[[ "$CHECKUPDATES_MAX_AGE_SECONDS" =~ ^[0-9]+$ ]] || CHECKUPDATES_MAX_AGE_SECONDS=900

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell/archtools"
CHECKUPDATES_DB="${ARCHTOOLS_CHECKUPDATES_DB:-$CACHE_DIR/checkupdates-db}"
CHECKUPDATES_STAMP="$CACHE_DIR/checkupdates-db.stamp"
CHECKUPDATES_LOCK_DIR="$CACHE_DIR/checkupdates-db.lock"
CHECKUPDATES_LOCK_HELD=0

pacman_db_path() {
  local dbpath=""
  if has pacman-conf; then
    dbpath="$(pacman-conf DBPath 2>/dev/null || true)"
  fi
  [[ -n "$dbpath" ]] || dbpath="/var/lib/pacman/"
  printf '%s\n' "${dbpath%/}"
}

wait_for_lock_file() {
  local lock_file="$1"
  local waited=0

  while [[ -e "$lock_file" ]]; do
    if (( waited >= PACMAN_LOCK_WAIT_SECONDS )); then
      printf 'Timed out waiting for pacman database lock: %s\n' "$lock_file" >&2
      return 1
    fi

    sleep 1
    waited=$((waited + 1))
  done
}

wait_for_pacman_lock() {
  wait_for_lock_file "$(pacman_db_path)/db.lck"
}

db_is_fresh() {
  [[ -f "$CHECKUPDATES_STAMP" ]] || return 1

  local stamp now age
  stamp="$(stat -c %Y "$CHECKUPDATES_STAMP" 2>/dev/null || echo 0)"
  now="$(date +%s)"
  age=$((now - stamp))

  (( age >= 0 && age <= CHECKUPDATES_MAX_AGE_SECONDS ))
}

acquire_checkupdates_lock() {
  local waited=0
  mkdir -p "$CACHE_DIR"

  while ! mkdir "$CHECKUPDATES_LOCK_DIR" 2>/dev/null; do
    if (( waited >= PACMAN_LOCK_WAIT_SECONDS )); then
      printf 'Timed out waiting for ArchTools checkupdates cache lock\n' >&2
      return 1
    fi

    sleep 1
    waited=$((waited + 1))
  done

  CHECKUPDATES_LOCK_HELD=1
}

release_checkupdates_lock() {
  if (( CHECKUPDATES_LOCK_HELD )); then
    rmdir "$CHECKUPDATES_LOCK_DIR" 2>/dev/null || true
    CHECKUPDATES_LOCK_HELD=0
  fi
}

run_checkupdates() {
  if ! wait_for_pacman_lock; then
    return 1
  fi
  if ! acquire_checkupdates_lock; then
    return 1
  fi
  trap release_checkupdates_lock EXIT

  local args=("--nocolor")
  local sync_db=1
  if db_is_fresh; then
    args+=("--nosync")
    sync_db=0
  fi

  local out status
  out="$(CHECKUPDATES_DB="$CHECKUPDATES_DB" checkupdates "${args[@]}" 2>/dev/null)" && status=0 || status=$?
  if (( sync_db )) && [[ "$status" == "0" || "$status" == "2" ]]; then
    touch "$CHECKUPDATES_STAMP" 2>/dev/null || true
  fi
  release_checkupdates_lock
  trap - EXIT

  case "$status" in
    0|2)
      printf '%s\n' "$out"
      return 0
      ;;
    *)
      return "$status"
      ;;
  esac
}

if command -v checkupdates >/dev/null 2>&1; then
  run_checkupdates | awk '{print $1}' | sort -u
  exit 0
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp"/{local,cache}
ln -s /var/lib/pacman/local "$tmp/local" 2>/dev/null || true

wait_for_pacman_lock
pacman -Sy --dbpath "$tmp" --logfile /dev/null >/dev/null 2>&1 || true

pacman -Qu --dbpath "$tmp" 2>/dev/null | awk '{print $1}' | sort -u || true

exit 0

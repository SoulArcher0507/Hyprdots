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

run_limited() {
  local seconds="$1"
  shift

  if has timeout; then
    timeout "$seconds" "$@"
  else
    "$@"
  fi
}

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

run_checkupdates_cached() {
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

  CHECKUPDATES_DB="$CHECKUPDATES_DB" run_limited 20s checkupdates "${args[@]}" 2>/dev/null
  local status=$?
  if (( sync_db )) && [[ "$status" == "0" || "$status" == "2" ]]; then
    touch "$CHECKUPDATES_STAMP" 2>/dev/null || true
  fi

  release_checkupdates_lock
  trap - EXIT
  return "$status"
}

repo_count() {
  if has checkupdates; then
    ( run_checkupdates_cached || true ) | wc -l
    return
  fi

  wait_for_pacman_lock

  if has yay; then
    ( run_limited 8s yay  -Qu --repo --color never 2>/dev/null || true ) | wc -l
    return
  fi
  if has paru; then
    ( run_limited 8s paru -Qu --repo --color never 2>/dev/null || true ) | wc -l
    return
  fi

  tmp="$(mktemp -d)"
  ( run_limited 8s pacman -Sy  --dbpath "$tmp" --logfile /dev/null >/dev/null 2>&1 || true )
  ( run_limited 8s pacman -Sup --dbpath "$tmp" 2>/dev/null || true ) | wc -l
  rm -rf "$tmp"
}



aur_count() {
  if has yay;    then ( run_limited 8s yay   -Qua --color never 2>/dev/null || true ) | wc -l; return; fi
  if has paru;   then ( run_limited 8s paru  -Qua --color never 2>/dev/null || true ) | wc -l; return; fi
  if has pikaur; then ( run_limited 8s pikaur -Qua --nocolor    2>/dev/null || true ) | wc -l; return; fi
  echo 0
}

flatpak_count() {
  command -v flatpak >/dev/null 2>&1 || { echo 0; return; }
  local s u
  s=$({ run_limited 4s flatpak --system remote-ls --updates --columns=ref 2>/dev/null || true; } | wc -l)
  u=$({ run_limited 4s flatpak --user   remote-ls --updates --columns=ref 2>/dev/null || true; } | wc -l)
  echo $((s + u))
}



p="$(repo_count)"
a="$(aur_count)"
f="$(flatpak_count)"
t=$(( p + a + f ))
printf '{"pacman":%s,"aur":%s,"flatpak":%s,"total":%s}
' "$p" "$a" "$f" "$t"

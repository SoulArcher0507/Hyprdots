#!/usr/bin/env bash
set -euo pipefail

has() { command -v "$1" >/dev/null 2>&1; }

PACMAN_LOCK_WAIT_SECONDS="${ARCHTOOLS_PACMAN_LOCK_WAIT_SECONDS:-45}"
[[ "$PACMAN_LOCK_WAIT_SECONDS" =~ ^[0-9]+$ ]] || PACMAN_LOCK_WAIT_SECONDS=45

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
      return 75
    fi

    sleep 1
    waited=$((waited + 1))
  done
}

wait_for_pacman_lock() {
  wait_for_lock_file "$(pacman_db_path)/db.lck"
}

run_aur_helper() {
  local out status

  set +e
  out="$("$@" 2>&1)"
  status=$?
  set -e

  if (( status == 0 )); then
    printf '%s\n' "$out"
    return 0
  fi

  if (( status == 1 )) && [[ -z "$out" ]]; then
    return 0
  fi

  printf '%s\n' "$out" >&2
  return "$status"
}

if command -v yay >/dev/null 2>&1; then
  wait_for_pacman_lock
  run_aur_helper yay -Qua --color never | awk '{print $1}' | sort -u
  exit 0
fi

if command -v paru >/dev/null 2>&1; then
  wait_for_pacman_lock
  run_aur_helper paru -Qua --color never | awk '{print $1}' | sort -u
  exit 0
fi

if command -v pikaur >/dev/null 2>&1; then
  wait_for_pacman_lock
  run_aur_helper pikaur -Qua --nocolor | awk '{print $1}' | sort -u
  exit 0
fi

exit 0

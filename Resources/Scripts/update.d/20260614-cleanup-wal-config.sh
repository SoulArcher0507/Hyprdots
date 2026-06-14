#!/bin/bash
set -euo pipefail

if [[ -n "${SUDO_USER-}" ]]; then
  TARGET_USER="$SUDO_USER"
else
  TARGET_USER="$USER"
fi

TARGET_HOME="$(eval echo "~$TARGET_USER")"
CONFIG_DIR="$TARGET_HOME/.config"
LEGACY_WAL_DIR="$CONFIG_DIR/wal"
MATUGEN_DIR="$CONFIG_DIR/matugen"

run_target_cmd() {
  if [[ $EUID -eq 0 ]]; then
    sudo -H -u "$TARGET_USER" env HOME="$TARGET_HOME" USER="$TARGET_USER" LOGNAME="$TARGET_USER" SUDO_USER="$TARGET_USER" "$@"
  else
    "$@"
  fi
}

if ! run_target_cmd test -e "$LEGACY_WAL_DIR"; then
  echo "Legacy wal config not present."
  exit 0
fi

if ! run_target_cmd test -d "$MATUGEN_DIR"; then
  echo "Matugen config not present, leaving legacy wal config untouched."
  exit 0
fi

run_target_cmd rm -rf -- "$LEGACY_WAL_DIR"
echo "Removed legacy wal config: $LEGACY_WAL_DIR"

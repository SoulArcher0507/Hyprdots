#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
SOURCE_STATIC="$REPO_ROOT/Resources/Wallpapers/Static"

if [[ -n "${SUDO_USER-}" ]]; then
  TARGET_USER="$SUDO_USER"
else
  TARGET_USER="$USER"
fi

TARGET_HOME="$(eval echo "~$TARGET_USER")"
TARGET_STATIC="$TARGET_HOME/Pictures/Wallpapers/Static"

run_target_cmd() {
  if [[ $EUID -eq 0 ]]; then
    sudo -H -u "$TARGET_USER" env HOME="$TARGET_HOME" USER="$TARGET_USER" LOGNAME="$TARGET_USER" SUDO_USER="$TARGET_USER" "$@"
  else
    "$@"
  fi
}

if [[ ! -d "$SOURCE_STATIC" ]]; then
  echo "Static wallpaper source not found: $SOURCE_STATIC"
  exit 0
fi

run_target_cmd mkdir -p "$TARGET_STATIC"
run_target_cmd rsync -a "$SOURCE_STATIC/" "$TARGET_STATIC/"

while IFS= read -r -d '' categorized_file; do
  file_name="$(basename "$categorized_file")"
  old_root_file="$TARGET_STATIC/$file_name"

  if [[ -f "$old_root_file" ]]; then
    run_target_cmd rm -f -- "$old_root_file"
  fi
done < <(find "$TARGET_STATIC" -mindepth 2 -type f -print0)

echo "Static wallpapers synchronized and root-level duplicates removed."

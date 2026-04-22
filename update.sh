#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo "=== Theme Update Selection ==="

THEME_SCRIPTS=()
while IFS= read -r -d '' f; do
  THEME_SCRIPTS+=("$f")
done < <(find "$SCRIPT_DIR/Themes" -mindepth 2 -maxdepth 2 -name "*-update.sh" -print0 | sort -z)

if [[ ${#THEME_SCRIPTS[@]} -eq 0 ]]; then
  echo "No theme update scripts found in $SCRIPT_DIR/Themes"
  exit 1
fi

THEME_LABELS=()
for f in "${THEME_SCRIPTS[@]}"; do
  label="$(basename "$(dirname "$f")")/$(basename "$f")"
  THEME_LABELS+=("$label")
done

echo "Update scripts available:"
for i in "${!THEME_LABELS[@]}"; do
  echo "  [$((i+1))] ${THEME_LABELS[$i]}"
done
echo ""

PS3="Insert theme number: "
select LABEL in "${THEME_LABELS[@]}"; do
  if [[ -n "$LABEL" ]]; then
    IDX=$((REPLY-1))
    SCRIPT_PATH="${THEME_SCRIPTS[$IDX]}"
    echo ""
    echo "Updating with: $SCRIPT_PATH"
    bash "$SCRIPT_PATH"
    break
  else
    echo "Not a valid choice."
    echo ""
    for i in "${!THEME_LABELS[@]}"; do
      echo "  [$((i+1))] ${THEME_LABELS[$i]}"
    done
    echo ""
  fi
done


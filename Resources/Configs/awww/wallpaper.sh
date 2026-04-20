#!/usr/bin/env bash

set -Eeuo pipefail

WALL_DIR="${HOME}/Pictures/Wallpapers"
ACTIVE_DIR="${WALL_DIR}/active"
mkdir -p "$ACTIVE_DIR"

log() { printf '[wallpaper] %s\n' "$*" >&2; }

if [[ $# -lt 1 ]]; then
  echo "Using: $0 /path/to/image" >&2
  exit 2
fi

PAPER_INPUT="$1"
if command -v readlink >/dev/null 2>&1; then
  PAPER="$(readlink -f -- "$PAPER_INPUT" || printf '%s' "$PAPER_INPUT")"
else
  case "$PAPER_INPUT" in
    /*) PAPER="$PAPER_INPUT" ;;
     *) PAPER="${PWD}/${PAPER_INPUT}" ;;
  esac
fi

[[ -f "$PAPER" ]] || { echo "File not found: $PAPER" >&2; exit 1; }

log "Applying wallpaper: $PAPER"

# --- awww ---
TRANSITION="any"
TRANSITION_FPS=60
TRANSITION_DURATION=1.0
TRANSITION_BEZIER=".43,1.19,1,.4"

if ! command -v awww >/dev/null 2>&1; then
  echo "Error: 'awww' not found in PATH." >&2
  exit 1
fi

awww img "$PAPER" \
    -t "$TRANSITION" \
    --transition-fps "$TRANSITION_FPS" \
    --transition-duration "$TRANSITION_DURATION" \
    --transition-bezier "$TRANSITION_BEZIER" \
    >/dev/null 2>&1 || true

(
  cp -f -- "$PAPER" "$ACTIVE_DIR/active.jpg" 2>/dev/null || true
) >/dev/null 2>&1 &

if command -v magick >/dev/null 2>&1; then
  (
    magick "$PAPER" \
      -resize 75% \
      -blur "50x30" \
      "$ACTIVE_DIR/active_blur.jpg" \
      2>/dev/null || true
  ) >/dev/null 2>&1 &

  (
    magick "$PAPER" \
      -gravity Center \
      -extent 1:1 \
      "$ACTIVE_DIR/active_square.jpg" \
      2>/dev/null || true
  ) >/dev/null 2>&1 &
fi

(
  if [[ -x "$HOME/.config/wal/colors.sh" ]]; then
    "$HOME/.config/wal/colors.sh" "$PAPER" || true
  elif command -v wal >/dev/null 2>&1; then
    wal -i "$PAPER" -n -q || true
  fi
) >/dev/null 2>&1 &



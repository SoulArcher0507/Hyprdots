#!/usr/bin/env bash

set -Eeuo pipefail

WALL_DIR="${HOME}/Pictures/Wallpapers"
ACTIVE_DIR="${WALL_DIR}/active"
SYNC_COLORS="${WALLPAPER_SYNC_COLORS:-0}"
FRAME_TS="${WALLPAPER_FRAME_TIMESTAMP:-00:00:01}"
AWWW_RESIZE="${WALLPAPER_AWWW_RESIZE:-crop}"
MPVPAPER_OUTPUT="${WALLPAPER_MPVPAPER_OUTPUT:-ALL}"
MPVPAPER_OPTS="${WALLPAPER_MPVPAPER_OPTS:-no-audio loop-file=inf panscan=1 video-align-x=0 video-align-y=0}"
PID_DIR="${XDG_RUNTIME_DIR:-$HOME/.cache}"
MPVPAPER_PID_FILE="$PID_DIR/hyprdots-mpvpaper.pid"
mkdir -p "$ACTIVE_DIR"

log() { printf '[wallpaper] %s\n' "$*" >&2; }

lower_ext() {
  local name="${1##*/}"
  local ext="${name##*.}"
  [[ "$name" == "$ext" ]] && return 1
  printf '%s' "${ext,,}"
}

is_dynamic_wallpaper() {
  local file="$1" ext mime frames
  ext="$(lower_ext "$file" || true)"
  case "$ext" in
    mp4|mkv|mov|webm|avi|m4v|ogv|ogg|flv|wmv|mpg|mpeg|gif|apng)
      return 0
      ;;
  esac

  if [[ "$ext" == "webp" ]] && command -v magick >/dev/null 2>&1; then
    frames="$(magick identify -format '%n\n' "$file" 2>/dev/null | head -n 1 || true)"
    [[ "$frames" =~ ^[0-9]+$ && "$frames" -gt 1 ]] && return 0
  fi

  if command -v file >/dev/null 2>&1; then
    mime="$(file -b --mime-type -- "$file" 2>/dev/null || true)"
    [[ "$mime" == video/* ]] && return 0
  fi

  return 1
}

stop_mpvpaper() {
  local pid
  if [[ -f "$MPVPAPER_PID_FILE" ]]; then
    pid="$(<"$MPVPAPER_PID_FILE")"
    if [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
    fi
    rm -f "$MPVPAPER_PID_FILE"
  fi
}

apply_static_wallpaper() {
  stop_mpvpaper

  if ! command -v awww >/dev/null 2>&1; then
    echo "Error: 'awww' not found in PATH." >&2
    exit 1
  fi

  awww img "$PAPER" \
      --resize "$AWWW_RESIZE" \
      -t "$TRANSITION" \
      --transition-fps "$TRANSITION_FPS" \
      --transition-duration "$TRANSITION_DURATION" \
      --transition-bezier "$TRANSITION_BEZIER" \
      >/dev/null 2>&1 || true
}

apply_dynamic_wallpaper() {
  if ! command -v mpvpaper >/dev/null 2>&1; then
    echo "Error: 'mpvpaper' not found in PATH." >&2
    exit 1
  fi

  stop_mpvpaper
  mkdir -p "$PID_DIR"
  mpvpaper -o "$MPVPAPER_OPTS" "$MPVPAPER_OUTPUT" "$PAPER" >/dev/null 2>&1 &
  printf '%s\n' "$!" >"$MPVPAPER_PID_FILE"
}

extract_frame() {
  local source="$1" target="$2" ext

  if is_dynamic_wallpaper "$source"; then
    ext="$(lower_ext "$source" || true)"
    if [[ "$ext" =~ ^(gif|apng|webp)$ ]] && command -v magick >/dev/null 2>&1; then
      magick "$source[0]" -auto-orient "$target" 2>/dev/null && return 0
    fi

    if ! command -v ffmpeg >/dev/null 2>&1; then
      echo "Error: 'ffmpeg' not found in PATH." >&2
      exit 1
    fi

    ffmpeg -y -v error -ss "$FRAME_TS" -i "$source" -frames:v 1 "$target" 2>/dev/null \
      || ffmpeg -y -v error -i "$source" -frames:v 1 "$target" 2>/dev/null
  else
    cp -f -- "$source" "$target"
  fi
}

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

TRANSITION="any"
TRANSITION_FPS=60
TRANSITION_DURATION=1.0
TRANSITION_BEZIER=".43,1.19,1,.4"
COLOR_SOURCE="$PAPER"
IS_DYNAMIC=0

if is_dynamic_wallpaper "$PAPER"; then
  IS_DYNAMIC=1
  COLOR_SOURCE="$ACTIVE_DIR/active.jpg"
  extract_frame "$PAPER" "$COLOR_SOURCE"
  apply_dynamic_wallpaper
else
  apply_static_wallpaper
fi

if [[ "$IS_DYNAMIC" -eq 0 ]]; then
  (
    cp -f -- "$PAPER" "$ACTIVE_DIR/active.jpg" 2>/dev/null || true
  ) >/dev/null 2>&1 &
fi

if command -v magick >/dev/null 2>&1; then
  (
    magick "$COLOR_SOURCE" \
      -resize 75% \
      -blur "50x30" \
      "$ACTIVE_DIR/active_blur.jpg" \
      2>/dev/null || true
  ) >/dev/null 2>&1 &

  (
    magick "$COLOR_SOURCE" \
      -gravity Center \
      -extent 1:1 \
      "$ACTIVE_DIR/active_square.jpg" \
      2>/dev/null || true
  ) >/dev/null 2>&1 &
fi

run_dynamic_colors() {
  if [[ -x "$HOME/.config/wal/colors.sh" ]]; then
    "$HOME/.config/wal/colors.sh" "$PAPER" || true
  elif command -v wal >/dev/null 2>&1; then
    wal -i "$COLOR_SOURCE" -n -q || true
  fi
}

if [[ "$SYNC_COLORS" == "1" ]]; then
  run_dynamic_colors
else
  (
    run_dynamic_colors
  ) >/dev/null 2>&1 &
fi

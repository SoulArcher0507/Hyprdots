#!/usr/bin/env bash

ACTION="${1:-show}"
VALUE="${2:-10}"

CACHE_DIR="$HOME/.cache/quickshell"
STATE_FILE="$CACHE_DIR/brightness-overlay.json"
TRIGGER_FILE="$CACHE_DIR/brightness-overlay.trigger"

icon_for() {
    local pct="$1"
    if (( pct > 66 )); then
        printf '󰃠'
    elif (( pct > 33 )); then
        printf '󰃟'
    else
        printf '󰃞'
    fi
}

label_for() {
    local pct="$1"
    if (( pct == 0 )); then
        printf 'Dark'
    elif (( pct < 34 )); then
        printf 'Dim'
    elif (( pct < 80 )); then
        printf 'Glow'
    else
        printf 'Bright'
    fi
}

write_state() {
    mkdir -p "$CACHE_DIR"

    local raw pct icon label available

    if raw="$(brightnessctl -m 2>/dev/null)"; then
        pct="$(printf '%s\n' "$raw" | awk -F, '{gsub(/%/, "", $4); print int($4)}')"
        pct="${pct:-0}"
        icon="$(icon_for "$pct")"
        label="$(label_for "$pct")"
        available=true
    else
        pct=0
        icon='󰃞'
        label='No Device'
        available=false
    fi

    printf '{"available":%s,"percent":%s,"icon":"%s","label":"%s"}\n' \
        "$available" "$pct" "$icon" "$label" > "$STATE_FILE"
}

show_overlay() {
    mkdir -p "$CACHE_DIR"
    touch "$TRIGGER_FILE"
    qs ipc --any-display -p "$HOME/.config/quickshell" call brightnessoverlay show >/dev/null 2>&1 || true
}

case "$ACTION" in
    inc)
        brightnessctl -q set +"$VALUE"% >/dev/null 2>&1 || true
        ;;
    dec)
        brightnessctl -q set "$VALUE"%- >/dev/null 2>&1 || true
        ;;
    set)
        brightnessctl -q set "$VALUE"% >/dev/null 2>&1 || true
        ;;
    show)
        ;;
esac

write_state
show_overlay

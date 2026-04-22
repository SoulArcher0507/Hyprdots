#!/usr/bin/env bash
set -euo pipefail

CONTROL="$HOME/.config/hypr/scripts/quickshell/brightness/brightness_control.sh"
STATE_FILE="${XDG_RUNTIME_DIR:-/tmp}/brightness_auto_power.state"

LOW_BATTERY_THRESHOLD=30
LOW_BRIGHTNESS=35
AC_BRIGHTNESS=100
POLL_SECONDS=15

BAT_DIR=""
AC_DIR=""

detect_power_supply() {
    for d in /sys/class/power_supply/*; do
        [[ -f "$d/type" ]] || continue
        t="$(<"$d/type")"

        case "$t" in
            Battery)
                [[ -z "$BAT_DIR" ]] && BAT_DIR="$d"
                ;;
            Mains|USB|USB_C)
                [[ -f "$d/online" && -z "$AC_DIR" ]] && AC_DIR="$d"
                ;;
        esac
    done

    [[ -n "$BAT_DIR" ]] || exit 1
    [[ -n "$AC_DIR" ]] || exit 1
}

apply_mode_if_changed() {
    local mode="$1"
    local target="${2:-}"
    local prev=""

    [[ -f "$STATE_FILE" ]] && prev="$(<"$STATE_FILE")"

    if [[ "$prev" != "$mode" ]]; then
        if [[ -n "$target" ]]; then
            bash "$CONTROL" set "$target"
        fi
        printf '%s' "$mode" > "$STATE_FILE"
    fi
}

main_loop() {
    while true; do
        local capacity online
        capacity="$(<"$BAT_DIR/capacity")"
        online="$(<"$AC_DIR/online")"

        if [[ "$online" == "1" ]]; then
            apply_mode_if_changed "ac" "$AC_BRIGHTNESS"
        elif (( capacity <= LOW_BATTERY_THRESHOLD )); then
            apply_mode_if_changed "low_battery" "$LOW_BRIGHTNESS"
        else
            apply_mode_if_changed "battery_normal"
        fi

        sleep "$POLL_SECONDS"
    done
}

detect_power_supply
main_loop

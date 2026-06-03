#!/usr/bin/env bash

set -euo pipefail

profile="${HYPRDOTS_DEVICE_PROFILE:-${HYPRDOTS_PROFILE:-}}"

normalize_profile() {
    case "${1,,}" in
        pc|desktop)
            printf 'desktop\n'
            ;;
        laptop|notebook|portable)
            printf 'laptop\n'
            ;;
        *)
            return 1
            ;;
    esac
}

detect_profile() {
    local normalized chassis_type supply supply_type

    if normalized="$(normalize_profile "$profile" 2>/dev/null)"; then
        printf '%s\n' "$normalized"
        return 0
    fi

    chassis_type="$(cat /sys/class/dmi/id/chassis_type 2>/dev/null || true)"
    case "$chassis_type" in
        8|9|10|14|30|31|32)
            printf 'laptop\n'
            return 0
            ;;
        3|4|5|6|7|13|15|16|35|36)
            printf 'desktop\n'
            return 0
            ;;
    esac

    if [[ -e /proc/acpi/button/lid/LID/state || -e /proc/acpi/button/lid/LID0/state ]]; then
        printf 'laptop\n'
        return 0
    fi

    for supply in /sys/class/power_supply/*; do
        [[ -e "$supply" ]] || continue
        supply_type="$(cat "$supply/type" 2>/dev/null || true)"
        if [[ "$supply_type" == "Battery" || "$(basename "$supply")" == BAT* ]]; then
            printf 'laptop\n'
            return 0
        fi
    done

    printf 'desktop\n'
}

detect_profile

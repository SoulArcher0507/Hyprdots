#!/usr/bin/env bash
set -euo pipefail

RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/hypr-${UID}}"
STATE_DIR="$RUNTIME_DIR/laptop_charge_boost"
LOCK_FILE="$RUNTIME_DIR/laptop_charge_boost.lock"

POLL_SECONDS="${LAPTOP_CHARGE_BOOST_POLL_SECONDS:-2}"
LOW_BATTERY_THRESHOLD="${LAPTOP_CHARGE_BOOST_LOW_THRESHOLD:-30}"
LOW_BRIGHTNESS="${LAPTOP_CHARGE_BOOST_LOW_BRIGHTNESS:-30}"
LOW_NOTIFY_THRESHOLD="${LAPTOP_CHARGE_BOOST_NOTIFY_LOW_THRESHOLD:-15}"
CRITICAL_NOTIFY_THRESHOLD="${LAPTOP_CHARGE_BOOST_NOTIFY_CRITICAL_THRESHOLD:-5}"
CHARGE_BRIGHTNESS="${LAPTOP_CHARGE_BOOST_BRIGHTNESS:-100}"

BAT_DIRS=()
AC_DIRS=()

detect_power_supply() {
    local dir type

    shopt -s nullglob
    for dir in /sys/class/power_supply/*; do
        [[ -r "$dir/type" ]] || continue
        type="$(<"$dir/type")"

        case "$type" in
            Battery)
                BAT_DIRS+=("$dir")
                ;;
            Mains|USB|USB_C|USB_PD|USB_DCP|USB_CDP|USB_ACA|Wireless)
                [[ -r "$dir/online" ]] && AC_DIRS+=("$dir")
                ;;
        esac
    done
    shopt -u nullglob

    # Desktop machines silently do nothing
    (( ${#BAT_DIRS[@]} > 0 )) || exit 0
}

is_plugged_in() {
    local dir online status

    for dir in "${AC_DIRS[@]}"; do
        [[ -r "$dir/online" ]] || continue
        online="$(<"$dir/online")"
        [[ "$online" == "1" ]] && return 0
    done

    if (( ${#AC_DIRS[@]} == 0 )); then
        for dir in "${BAT_DIRS[@]}"; do
            [[ -r "$dir/status" ]] || continue
            status="$(<"$dir/status")"
            [[ "$status" == "Charging" || "$status" == "Full" ]] && return 0
        done
    fi

    return 1
}

battery_capacity() {
    local dir capacity min_capacity=""

    for dir in "${BAT_DIRS[@]}"; do
        [[ -r "$dir/capacity" ]] || continue
        capacity="$(<"$dir/capacity")"
        [[ "$capacity" =~ ^[0-9]+$ ]] || continue

        if [[ -z "$min_capacity" || "$capacity" -lt "$min_capacity" ]]; then
            min_capacity="$capacity"
        fi
    done

    printf '%s\n' "${min_capacity:-100}"
}

charge_active() {
    [[ -f "$STATE_DIR/charge.active" ]]
}

low_battery_active() {
    [[ -f "$STATE_DIR/low_battery.active" ]]
}

save_brightness_to() {
    local target_file="$1"

    command -v brightnessctl >/dev/null 2>&1 || return 0
    brightnessctl get > "$target_file" 2>/dev/null || true
}

restore_brightness_from() {
    local source_file="$1"
    local previous

    command -v brightnessctl >/dev/null 2>&1 || return 0
    [[ -s "$source_file" ]] || return 0

    previous="$(<"$source_file")"
    [[ -n "$previous" ]] || return 0
    brightnessctl -q set "$previous" >/dev/null 2>&1 || true
}

set_brightness_percent() {
    local percent="$1"

    command -v brightnessctl >/dev/null 2>&1 || return 0
    brightnessctl -q set "${percent}%" >/dev/null 2>&1 || true
}

clear_low_battery_state() {
    rm -f "$STATE_DIR/low_battery.active" "$STATE_DIR/low_battery.brightness" "$STATE_DIR/low_battery.power_profile"
}

clear_battery_notification_state() {
    rm -f "$STATE_DIR/notify.low" "$STATE_DIR/notify.critical"
}

send_battery_notification() {
    local urgency="$1"
    local title="$2"
    local body="$3"

    command -v notify-send >/dev/null 2>&1 || return 0
    notify-send -a "Battery" -i battery-caution -u "$urgency" "$title" "$body" >/dev/null 2>&1 || true
}

notify_low_battery_levels() {
    local capacity="$1"

    mkdir -p "$STATE_DIR"

    if (( capacity <= CRITICAL_NOTIFY_THRESHOLD )); then
        if [[ ! -f "$STATE_DIR/notify.critical" ]]; then
            send_battery_notification critical "Batteria critica" "La batteria e al ${capacity}%."
            date +%s > "$STATE_DIR/notify.critical"
        fi
    elif (( capacity <= LOW_NOTIFY_THRESHOLD )); then
        if [[ ! -f "$STATE_DIR/notify.low" ]]; then
            send_battery_notification normal "Batteria scarica" "La batteria e al ${capacity}%."
            date +%s > "$STATE_DIR/notify.low"
        fi
    fi
}

activate_charge_boost() {
    mkdir -p "$STATE_DIR"
    clear_battery_notification_state

    if ! charge_active; then
        if low_battery_active; then
            if [[ -s "$STATE_DIR/low_battery.brightness" ]]; then
                cp "$STATE_DIR/low_battery.brightness" "$STATE_DIR/charge.brightness"
            else
                save_brightness_to "$STATE_DIR/charge.brightness"
            fi

            clear_low_battery_state
        else
            save_brightness_to "$STATE_DIR/charge.brightness"
        fi

        date +%s > "$STATE_DIR/charge.active"

        set_brightness_percent "$CHARGE_BRIGHTNESS"
    fi
}

deactivate_charge_boost() {
    charge_active || return 0

    restore_brightness_from "$STATE_DIR/charge.brightness"
    rm -f "$STATE_DIR/charge.active" "$STATE_DIR/charge.brightness" "$STATE_DIR/charge.power_profile"
}

activate_low_battery_mode() {
    mkdir -p "$STATE_DIR"

    if ! low_battery_active; then
        save_brightness_to "$STATE_DIR/low_battery.brightness"
        date +%s > "$STATE_DIR/low_battery.active"

        set_brightness_percent "$LOW_BRIGHTNESS"
    fi
}

deactivate_low_battery_mode() {
    low_battery_active || return 0

    restore_brightness_from "$STATE_DIR/low_battery.brightness"
    clear_low_battery_state
}

main_loop() {
    local capacity

    while true; do
        if is_plugged_in; then
            activate_charge_boost
        else
            deactivate_charge_boost

            capacity="$(battery_capacity)"
            if (( capacity <= LOW_BATTERY_THRESHOLD )); then
                activate_low_battery_mode
            else
                deactivate_low_battery_mode
                clear_battery_notification_state
            fi

            notify_low_battery_levels "$capacity"
        fi

        sleep "$POLL_SECONDS"
    done
}

mkdir -p "$RUNTIME_DIR" "$STATE_DIR"
exec 9>"$LOCK_FILE"
flock -n 9 || exit 0

detect_power_supply
main_loop

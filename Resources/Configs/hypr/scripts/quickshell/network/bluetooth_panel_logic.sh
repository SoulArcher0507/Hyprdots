#!/usr/bin/env bash

SCAN_LOG="$HOME/.cache/bt_scan.log"
PID_FILE="$HOME/.cache/bt_scan_pid"
CACHE_DIR="/tmp/quickshell_network_cache"
mkdir -p "$CACHE_DIR"
mkdir -p "$(dirname "$SCAN_LOG")"

is_scan_running() {
    if [ ! -f "$PID_FILE" ]; then
        return 1
    fi

    local pid
    pid=$(cat "$PID_FILE" 2>/dev/null)
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        return 0
    fi

    rm -f "$PID_FILE"
    return 1
}

stop_scan() {
    if is_scan_running; then
        kill "$(cat "$PID_FILE")" 2>/dev/null
    fi
    bluetoothctl scan off >/dev/null 2>&1
    rm -f "$PID_FILE"
}

start_scan() {
    if ! bluetoothctl show | grep -q "Powered: yes"; then
        bluetoothctl power on >/dev/null 2>&1
        sleep 0.5
    fi

    if is_scan_running; then
        return 0
    fi

    (
        bluetoothctl scan off >/dev/null 2>&1
        bluetoothctl --timeout 12 scan on > "$SCAN_LOG" 2>&1
        bluetoothctl scan off >/dev/null 2>&1
        rm -f "$PID_FILE"
    ) &
    echo "$!" > "$PID_FILE"
}

remove_dev() {
    local mac="$1"
    [ -z "$mac" ] && return 1

    stop_scan
    rm -f "$CACHE_DIR/bt_stat_${mac//:/_}" 2>/dev/null
    bluetoothctl disconnect "$mac" >/dev/null 2>&1
    bluetoothctl remove "$mac"
}

get_icon() {
    local type=$(echo "$1" | tr '[:upper:]' '[:lower:]')
    local name=$(echo "$2" | tr '[:upper:]' '[:lower:]')
    if [[ "$type" == *"headset"* ]] || [[ "$type" == *"headphone"* ]] || [[ "$name" == *"headphone"* ]] || [[ "$name" == *"buds"* ]] || [[ "$name" == *"pods"* ]]; then echo "🎧"
    elif [[ "$type" == *"audio"* ]] || [[ "$type" == *"speaker"* ]] || [[ "$type" == *"card"* ]] || [[ "$name" == *"speaker"* ]]; then echo "蓼"
    elif [[ "$type" == *"phone"* ]] || [[ "$name" == *"phone"* ]] || [[ "$name" == *"iphone"* ]] || [[ "$name" == *"android"* ]]; then echo ""
    elif [[ "$type" == *"mouse"* ]] || [[ "$name" == *"mouse"* ]]; then echo ""
    elif [[ "$type" == *"keyboard"* ]] || [[ "$name" == *"keyboard"* ]]; then echo ""
    elif [[ "$type" == *"controller"* ]] || [[ "$name" == *"controller"* ]]; then echo ""
    else echo ""
    fi
}

is_bluetooth_identifier() {
    local value="$1"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"

    if [ -z "$value" ]; then
        return 0
    fi

    local lower compact
    lower=$(echo "$value" | tr '[:upper:]' '[:lower:]')
    case "$lower" in
        "(unknown)"|"unknown"|"n/a"|"null")
            return 0
            ;;
    esac

    if [[ "$value" =~ ^([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}$ ]]; then
        return 0
    fi
    if [[ "$value" =~ ^([[:xdigit:]]{2}[-_]){5}[[:xdigit:]]{2}$ ]]; then
        return 0
    fi

    compact=$(echo "$value" | tr -d ':_[:space:]-')
    if [[ "$compact" =~ ^[[:xdigit:]]{12}$ ]]; then
        return 0
    fi

    return 1
}

get_device_name() {
    local mac="$1"
    local fallback="$2"
    local info alias name

    info=$(bluetoothctl info "$mac" 2>/dev/null)
    alias=$(echo "$info" | sed -n 's/^[[:space:]]*Alias:[[:space:]]*//p' | head -n1)
    name=$(echo "$info" | sed -n 's/^[[:space:]]*Name:[[:space:]]*//p' | head -n1)

    if ! is_bluetooth_identifier "$alias"; then
        printf '%s\n' "$alias"
        return
    fi
    if ! is_bluetooth_identifier "$name"; then
        printf '%s\n' "$name"
        return
    fi
    if ! is_bluetooth_identifier "$fallback"; then
        printf '%s\n' "$fallback"
        return
    fi
}

get_audio_profile() {
    local mac="$1"
    local mac_us=$(echo "$mac" | tr ':' '_')

    local active=$(pactl list cards 2>/dev/null | grep -i -A 20 "Name:.*$mac_us" | grep -i "Active Profile:" | head -n 1 | cut -d: -f2 | xargs)

    if [[ -z "$active" || "$active" == "off" ]]; then echo "None"; return; fi

    local desc="Connected"
    if [[ "$active" == *"a2dp"* ]]; then desc="Hi-Fi (A2DP)"; fi
    if [[ "$active" == *"headset"* || "$active" == *"hfp"* ]]; then desc="Headset (HFP)"; fi

    echo "$desc"
}

get_status() {
    power="off"
    if bluetoothctl show | grep -q "Powered: yes"; then power="on"; fi

    connected_json="[]"
    devices_json="[]"
    scanning="false"

    if [ "$power" == "on" ]; then
        paired_macs=$(bluetoothctl devices Paired | cut -d ' ' -f 2)
        mapfile -t connected_info_lines < <(bluetoothctl devices Connected)

        if [ ${#connected_info_lines[@]} -eq 0 ]; then
            start_scan
        fi
        if is_scan_running; then scanning="true"; fi

        mapfile -t devices < <(bluetoothctl devices)

        connected_list_objs=()
        paired_list_objs=()
        discovered_list_objs=()

        connected_macs=$(echo "${connected_info_lines[@]}" | awk '{for(i=1;i<=NF;i++) if($i~/^([0-9A-F]{2}:){5}[0-9A-F]{2}$/) print $i}')

        for c_line in "${connected_info_lines[@]}"; do
            if [ -z "$c_line" ]; then continue; fi
            connected_mac=$(echo "$c_line" | cut -d ' ' -f 2)
            CACHE_FILE="$CACHE_DIR/bt_stat_${connected_mac//:/_}"

            if [ -f "$CACHE_FILE" ]; then
                source "$CACHE_FILE"
            else
                line_name=$(echo "$c_line" | cut -d ' ' -f 3-)
                name=$(get_device_name "$connected_mac" "$line_name")
                if is_bluetooth_identifier "$name"; then
                    continue
                fi
                info=$(bluetoothctl info "$connected_mac")
                icon_type=$(echo "$info" | grep "Icon:" | cut -d: -f2 | xargs)
                icon=$(get_icon "$icon_type" "$name")
                profile=$(get_audio_profile "$connected_mac")

                echo "CACHE_NAME=\"$name\"" > "$CACHE_FILE"
                echo "CACHE_ICON=\"$icon\"" >> "$CACHE_FILE"
                echo "CACHE_PROFILE=\"$profile\"" >> "$CACHE_FILE"

                CACHE_NAME="$name"
                CACHE_ICON="$icon"
                CACHE_PROFILE="$profile"
            fi

            if is_bluetooth_identifier "$CACHE_NAME"; then
                continue
            fi

            bat=$(bluetoothctl info "$connected_mac" | awk '/Battery Percentage:/ {gsub(/.*\(/,""); gsub(/\).*/,""); print}')
            [ -z "$bat" ] && bat=$(bluetoothctl info "$connected_mac" | grep -i "Battery Percentage" | awk '{print $NF}' | tr -d '()')
            [ -z "$bat" ] || [ "$bat" == "?" ] && bat="0"

            obj=$(jq -n -c \
                --arg id "$connected_mac" \
                --arg name "$CACHE_NAME" \
                --arg mac "$connected_mac" \
                --arg icon "$CACHE_ICON" \
                --arg bat "$bat" \
                --arg profile "$CACHE_PROFILE" \
                '{id: $id, name: $name, mac: $mac, icon: $icon, battery: $bat, profile: $profile, known: true}')
            connected_list_objs+=("$obj")
            continue
        done

        if [ ${#connected_list_objs[@]} -gt 0 ]; then
            connected_json=$(printf '%s\n' "${connected_list_objs[@]}" | jq -s -c '.')
        fi

        for line in "${devices[@]}"; do
            if [ -z "$line" ]; then continue; fi
            mac=$(echo "$line" | cut -d ' ' -f 2)

            if echo "$connected_macs" | grep -qxF "$mac"; then continue; fi

            line_name=$(echo "$line" | cut -d ' ' -f 3-)
            name=$(get_device_name "$mac" "$line_name")
            if is_bluetooth_identifier "$name"; then continue; fi

            icon=$(get_icon "unknown" "$name")

            if echo "$paired_macs" | grep -qxF "$mac"; then
                action="Connect"
                obj=$(jq -n -c --arg id "$mac" --arg name "$name" --arg mac "$mac" --arg icon "$icon" --arg action "$action" '{id: $id, name: $name, mac: $mac, icon: $icon, action: $action, known: true}')
                paired_list_objs+=("$obj")
            else
                action="Pair"
                obj=$(jq -n -c --arg id "$mac" --arg name "$name" --arg mac "$mac" --arg icon "$icon" --arg action "$action" '{id: $id, name: $name, mac: $mac, icon: $icon, action: $action, known: false}')
                discovered_list_objs+=("$obj")
            fi
        done

        all_objs=("${paired_list_objs[@]}" "${discovered_list_objs[@]}")
        if [ ${#all_objs[@]} -gt 0 ]; then
            devices_json=$(printf '%s\n' "${all_objs[@]}" | jq -s -c '.')
        fi
        if [ -z "$devices_json" ]; then devices_json="[]"; fi
    fi

    jq -n -c \
        --arg power "$power" \
        --argjson scanning "$scanning" \
        --argjson connected "${connected_json}" \
        --argjson devices "${devices_json:-[]}" \
        '{power: $power, scanning: $scanning, connected: $connected, devices: $devices}'
}

toggle_power() {
    if bluetoothctl show | grep -q "Powered: yes"; then
        bluetoothctl power off
    else
        bluetoothctl power on
    fi
    sleep 0.5
}

connect_dev() {
    local mac="$1"
    stop_scan
    if ! bluetoothctl info "$mac" 2>/dev/null | grep -q "Paired: yes"; then
        bluetoothctl pair "$mac" > /dev/null 2>&1
    fi
    bluetoothctl trust "$mac" > /dev/null 2>&1
    bluetoothctl connect "$mac"
}

disconnect_dev() {
    local mac="$1"
    # Remove cache so a fresh connect regenerates the profile
    rm -f "/tmp/quickshell_network_cache/bt_stat_${mac//:/_}" 2>/dev/null
    bluetoothctl disconnect "$mac"
}

cmd="$1"
case $cmd in
    --status) get_status ;;
    --toggle) toggle_power ;;
    --scan) start_scan ;;
    --connect) connect_dev "$2" ;;
    --disconnect) disconnect_dev "$2" ;;
    --remove) remove_dev "$2" ;;
esac

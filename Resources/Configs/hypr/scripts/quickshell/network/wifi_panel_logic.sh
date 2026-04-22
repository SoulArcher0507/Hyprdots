#!/usr/bin/env bash

ETH_IFACE=""
ETH_IP=""
ETH_CONNECTED="false"
ETH_LINE=$(nmcli -t -f DEVICE,TYPE,STATE,CONNECTION device 2>/dev/null | grep ':ethernet:connected:' | head -n1)
if [[ -n "$ETH_LINE" ]]; then
    ETH_CONNECTED="true"
    ETH_IFACE=$(echo "$ETH_LINE" | cut -d: -f1)
    ETH_NAME=$(echo "$ETH_LINE" | cut -d: -f4)
    ETH_IP=$(ip -4 addr show dev "$ETH_IFACE" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n1)
    [ -z "$ETH_IP" ] && ETH_IP="No IP"
fi

POWER=$(nmcli radio wifi 2>/dev/null)
[ -z "$POWER" ] && POWER="disabled"

if [[ "$POWER" == "disabled" ]]; then
    ETH_JSON="null"
    if [[ "$ETH_CONNECTED" == "true" ]]; then
        ETH_JSON=$(jq -n \
            --arg iface "$ETH_IFACE" \
            --arg name "${ETH_NAME:-Wired}" \
            --arg ip "$ETH_IP" \
            '{iface: $iface, name: $name, ip: $ip}')
    fi
    echo $(jq -n \
        --arg power "off" \
        --argjson ethernet "${ETH_JSON:-null}" \
        '{power: $power, connected: null, networks: [], ethernet: $ethernet}')
    exit 0
fi

get_icon() {
    local signal=$1
    if [[ $signal -ge 80 ]]; then echo "󰤨";
    elif [[ $signal -ge 60 ]]; then echo "󰤥";
    elif [[ $signal -ge 40 ]]; then echo "󰤢";
    elif [[ $signal -ge 20 ]]; then echo "󰤟";
    else echo "󰤯"; fi
}

CACHE_DIR="/tmp/quickshell_network_cache"
mkdir -p "$CACHE_DIR"

WIFI_CONN_INFO=$(nmcli -t -f DEVICE,TYPE,STATE,CONNECTION device 2>/dev/null | grep ":wifi:connected" | head -n1)

CONNECTED_JSON="null"

if [[ -n "$WIFI_CONN_INFO" ]]; then
    WIFI_IFACE=$(echo "$WIFI_CONN_INFO" | cut -d: -f1)
    SSID=$(nmcli -t -f GENERAL.CONNECTION device show "$WIFI_IFACE" 2>/dev/null | cut -d: -f2)
    [ -z "$SSID" ] && SSID=$(echo "$WIFI_CONN_INFO" | cut -d: -f4-)
    
    DETAILS=$(nmcli -t -f active,ssid,signal,security device wifi list --rescan no 2>/dev/null | grep "^yes" | head -n1)
    if [[ -z "$DETAILS" ]]; then
        DETAILS=$(nmcli -t -f active,ssid,signal,security device wifi list --rescan no 2>/dev/null | grep ":$SSID:" | head -n1)
    fi

    if [[ -n "$DETAILS" ]]; then
        SIGNAL=$(echo "$DETAILS" | rev | cut -d: -f2 | rev)
        SECURITY=$(echo "$DETAILS" | rev | cut -d: -f1 | rev)
    else
        SIGNAL="100"
        SECURITY="Unknown"
    fi

    icon=$(get_icon "$SIGNAL")
    SAFE_SSID="${SSID//[^a-zA-Z0-9]/_}"
    CACHE_FILE="$CACHE_DIR/wifi_$SAFE_SSID"

    IP=""
    FREQ=""
    if [ -f "$CACHE_FILE" ]; then
        source "$CACHE_FILE"
    fi

    if [ -z "$IP" ] || [ "$IP" == "No IP" ] || [ -z "$FREQ" ] || [ "$FREQ" == "Unknown" ]; then
        IP=$(ip -4 addr show dev "$WIFI_IFACE" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n1)
        [ -z "$IP" ] && IP="No IP"

        FREQ=$(iw dev "$WIFI_IFACE" link 2>/dev/null | awk '/freq:/{print $2}')
        if [ -z "$FREQ" ]; then
            FREQ=$(iw dev "$WIFI_IFACE" info 2>/dev/null | awk '/channel/{gsub(/[()]/,"",$NF); print $(NF-1)}')
        fi
        [ -n "$FREQ" ] && FREQ="${FREQ} MHz" || FREQ="Unknown"

        echo "IP=\"$IP\"" > "$CACHE_FILE"
        echo "FREQ=\"$FREQ\"" >> "$CACHE_FILE"
    fi

    CONNECTED_JSON=$(jq -n \
                  --arg id "$SSID" \
                  --arg ssid "$SSID" \
                  --arg icon "$icon" \
                  --arg signal "$SIGNAL" \
                  --arg security "$SECURITY" \
                  --arg ip "$IP" \
                  --arg freq "$FREQ" \
                  '{id: $id, ssid: $ssid, icon: $icon, signal: $signal, security: $security, ip: $ip, freq: $freq}')
fi

KNOWN_CONNECTIONS=$(nmcli -t -f NAME connection show 2>/dev/null)

NETWORKS_JSON=$(nmcli -t -f active,ssid,signal,security device wifi list --rescan no 2>/dev/null | \
    awk -F: '!seen[$2]++ && $2 != "" && $1 != "yes" {print $2":"$3":"$4}' | \
    head -n 24 | \
    while IFS=':' read -r ssid signal security; do
        icon=$(get_icon "$signal")
        is_known="false"
        if echo "$KNOWN_CONNECTIONS" | grep -qxF "$ssid"; then
            is_known="true"
        fi
        jq -n \
           --arg id "$ssid" \
           --arg ssid "$ssid" \
           --arg icon "$icon" \
           --arg signal "$signal" \
           --arg security "$security" \
           --argjson known "$is_known" \
           '{id: $id, ssid: $ssid, icon: $icon, signal: $signal, security: $security, known: $known}'
    done | jq -s '.')

ETH_JSON="null"
if [[ "$ETH_CONNECTED" == "true" ]]; then
    ETH_JSON=$(jq -n \
        --arg iface "$ETH_IFACE" \
        --arg name "${ETH_NAME:-Wired}" \
        --arg ip "$ETH_IP" \
        '{iface: $iface, name: $name, ip: $ip}')
fi

echo $(jq -n \
       --arg power "on" \
       --argjson connected "${CONNECTED_JSON:-null}" \
       --argjson networks "${NETWORKS_JSON:-[]}" \
       --argjson ethernet "${ETH_JSON:-null}" \
       '{power: $power, connected: $connected, networks: $networks, ethernet: $ethernet}')

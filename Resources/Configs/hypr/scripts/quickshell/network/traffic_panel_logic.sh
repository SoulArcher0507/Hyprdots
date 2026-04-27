#!/usr/bin/env bash

set -uo pipefail

CACHE_DIR="/tmp/quickshell_network_cache"
STATE_FILE="$CACHE_DIR/network_traffic_state.json"
mkdir -p "$CACHE_DIR"

now_ms() {
    date +%s%3N
}

pick_iface() {
    local iface

    iface=$(nmcli -t -f DEVICE,TYPE,STATE device 2>/dev/null | awk -F: '$2=="ethernet" && $3 ~ /^connected/ {print $1; exit}')
    if [[ -n "$iface" ]]; then
        printf '%s\n' "$iface"
        return
    fi

    nmcli -t -f DEVICE,TYPE,STATE device 2>/dev/null | awk -F: '$2=="wifi" && $3 ~ /^connected/ {print $1; exit}'
}

iface=$(pick_iface)
if [[ -z "$iface" ]] || [[ ! -r "/sys/class/net/$iface/statistics/rx_bytes" ]] || [[ ! -r "/sys/class/net/$iface/statistics/tx_bytes" ]]; then
    jq -nc '{iface:"", down_bps:0, up_bps:0}'
    exit 0
fi

rx_bytes=$(<"/sys/class/net/$iface/statistics/rx_bytes")
tx_bytes=$(<"/sys/class/net/$iface/statistics/tx_bytes")
current_ts=$(now_ms)
down_bps=0
up_bps=0

if [[ -f "$STATE_FILE" ]]; then
    prev_iface=$(jq -r '.iface // ""' "$STATE_FILE" 2>/dev/null)
    prev_rx=$(jq -r '.rx_bytes // 0' "$STATE_FILE" 2>/dev/null)
    prev_tx=$(jq -r '.tx_bytes // 0' "$STATE_FILE" 2>/dev/null)
    prev_ts=$(jq -r '.ts_ms // 0' "$STATE_FILE" 2>/dev/null)
    prev_down=$(jq -r '.down_bps // 0' "$STATE_FILE" 2>/dev/null)
    prev_up=$(jq -r '.up_bps // 0' "$STATE_FILE" 2>/dev/null)

    if [[ "$prev_iface" == "$iface" ]] && [[ "$prev_rx" =~ ^[0-9]+$ ]] && [[ "$prev_tx" =~ ^[0-9]+$ ]] && [[ "$prev_ts" =~ ^[0-9]+$ ]]; then
        delta_ms=$((current_ts - prev_ts))
        if (( delta_ms > 0 && delta_ms <= 15000 )); then
            delta_rx=$((rx_bytes - prev_rx))
            delta_tx=$((tx_bytes - prev_tx))
            if (( delta_rx < 0 )); then delta_rx=0; fi
            if (( delta_tx < 0 )); then delta_tx=0; fi
            down_bps=$((delta_rx * 1000 / delta_ms))
            up_bps=$((delta_tx * 1000 / delta_ms))
        fi
    fi
fi

jq -nc \
    --arg iface "$iface" \
    --argjson rx_bytes "$rx_bytes" \
    --argjson tx_bytes "$tx_bytes" \
    --argjson ts_ms "$current_ts" \
    --argjson down_bps "$down_bps" \
    --argjson up_bps "$up_bps" \
    '{iface:$iface, rx_bytes:$rx_bytes, tx_bytes:$tx_bytes, ts_ms:$ts_ms, down_bps:$down_bps, up_bps:$up_bps}' > "$STATE_FILE"

jq -nc \
    --arg iface "$iface" \
    --argjson down_bps "$down_bps" \
    --argjson up_bps "$up_bps" \
    '{iface:$iface, down_bps:$down_bps, up_bps:$up_bps}'

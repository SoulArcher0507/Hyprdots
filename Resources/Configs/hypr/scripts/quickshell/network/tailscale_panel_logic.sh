#!/usr/bin/env bash

set -uo pipefail

inactive_json() {
    jq -nc '{active:false}'
}

format_ping() {
    local value="$1"
    awk -v value="$value" 'BEGIN {
        if (value == "" || value == 0) {
            print "";
        } else if (value < 10) {
            printf "%.1f ms", value;
        } else {
            printf "%.0f ms", value;
        }
    }'
}

command -v tailscale >/dev/null 2>&1 || {
    inactive_json
    exit 0
}

STATUS_JSON=$(tailscale status --json 2>/dev/null) || {
    inactive_json
    exit 0
}

BACKEND_STATE=$(jq -r '.BackendState // ""' <<< "$STATUS_JSON")
TS_IP=$(jq -r '(.TailscaleIPs // [])[0] // ""' <<< "$STATUS_JSON")
SELF_ONLINE=$(jq -r '.Self.Online // false' <<< "$STATUS_JSON")

if [[ "$BACKEND_STATE" != "Running" || -z "$TS_IP" || "$SELF_ONLINE" != "true" ]]; then
    inactive_json
    exit 0
fi

HOSTNAME=$(jq -r '.Self.HostName // "this-device"' <<< "$STATUS_JSON")
TAILNET=$(jq -r '.CurrentTailnet.Name? // .CurrentTailnet.MagicDNSSuffix? // .MagicDNSSuffix // ""' <<< "$STATUS_JSON")
ONLINE_PEERS=$(jq -r '[.Peer // {} | to_entries[] | select(.value.Online == true)] | length' <<< "$STATUS_JSON")
TOTAL_PEERS=$(jq -r '[.Peer // {} | to_entries[]] | length' <<< "$STATUS_JSON")
EXIT_NODE=$(jq -r '
    [.Peer // {} | to_entries[] | select((.value.ExitNode == true) or (.value.ExitNodeOption == true)) | .value.HostName][0] // ""
' <<< "$STATUS_JSON")

PING_TARGET=$(jq -r '
    [.Peer // {} | to_entries[] | select(.value.Online == true) |
        (.value.DNSName // .value.HostName // (.value.TailscaleIPs[0] // ""))]
    | map(select(. != ""))[0] // ""
' <<< "$STATUS_JSON")

PING_TEXT=""
RELAY_TEXT=""
PING_OUTPUT=""
if [[ -n "$PING_TARGET" ]]; then
    PING_OUTPUT=$(tailscale ping --c=1 --timeout=2s "$PING_TARGET" 2>/dev/null || true)
    PING_VALUE=$(sed -nE 's/.* in ([0-9.]+)ms.*/\1/p; s/.*time=([0-9.]+)ms.*/\1/p' <<< "$PING_OUTPUT" | head -n1)
    PING_TEXT=$(format_ping "$PING_VALUE")
    RELAY_TEXT=$(sed -nE 's/.* via ([^ ]+) in .*/\1/p' <<< "$PING_OUTPUT" | head -n1)
fi

if [[ -z "$PING_TEXT" ]]; then
    PING_TEXT="No peer ping"
fi

if [[ -n "$EXIT_NODE" ]]; then
    ROUTE_TEXT="Exit: $EXIT_NODE"
elif [[ -n "$RELAY_TEXT" ]]; then
    ROUTE_TEXT="$RELAY_TEXT"
else
    ROUTE_TEXT="$TS_IP"
fi

PEER_TEXT="$ONLINE_PEERS/$TOTAL_PEERS peers"
if [[ "$TOTAL_PEERS" == "0" ]]; then
    PEER_TEXT="No peers"
fi

SUMMARY="Tailscale $PING_TEXT"
DETAIL="$PEER_TEXT | $ROUTE_TEXT"

jq -nc \
    --argjson active true \
    --arg hostname "$HOSTNAME" \
    --arg ip "$TS_IP" \
    --arg tailnet "$TAILNET" \
    --arg ping "$PING_TEXT" \
    --arg relay "$RELAY_TEXT" \
    --arg peers "$PEER_TEXT" \
    --arg route "$ROUTE_TEXT" \
    --arg summary "$SUMMARY" \
    --arg detail "$DETAIL" \
    '{active:$active, hostname:$hostname, ip:$ip, tailnet:$tailnet, ping:$ping, relay:$relay, peers:$peers, route:$route, summary:$summary, detail:$detail}'

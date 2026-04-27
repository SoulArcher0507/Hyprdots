#!/usr/bin/env bash

set -uo pipefail

inactive_json() {
    jq -nc \
        --arg backend "${1:-Stopped}" \
        '{active:false, backend:$backend, self:{hostname:"Tailscale", ip:"", online:false}, peers:[], online_count:0, offline_count:0, total_count:0, exit_node:"", message:"Tailscale is not connected"}'
}

format_bytes() {
    awk -v value="${1:-0}" 'BEGIN {
        split("B KiB MiB GiB TiB", units, " ");
        idx = 1;
        while (value >= 1024 && idx < 5) {
            value /= 1024;
            idx++;
        }
        if (value >= 100 || idx == 1)
            printf "%.0f %s", value, units[idx];
        else
            printf "%.1f %s", value, units[idx];
    }'
}

status_json() {
    command -v tailscale >/dev/null 2>&1 || {
        inactive_json "Missing"
        return 0
    }

    local raw backend ts_ip online hostname os peers online_count offline_count total_count exit_node exit_node_id rx_total tx_total
    raw=$(tailscale status --json 2>/dev/null) || {
        inactive_json "Unavailable"
        return 0
    }

    backend=$(jq -r '.BackendState // "Unknown"' <<< "$raw")
    ts_ip=$(jq -r '(.TailscaleIPs // [])[0] // ""' <<< "$raw")
    online=$(jq -r '.Self.Online // false' <<< "$raw")

    if [[ "$backend" != "Running" || -z "$ts_ip" || "$online" != "true" ]]; then
        inactive_json "$backend"
        return 0
    fi

    hostname=$(jq -r '.Self.HostName // "this-device"' <<< "$raw")
    os=$(jq -r '.Self.OS // ""' <<< "$raw")
    peers=$(jq -c '
        [.Peer // {} | to_entries[] |
            .key as $id |
            .value |
            {
                id: $id,
                name: (.HostName // .DNSName // $id),
                dns: ((.DNSName // "") | sub("\\.$"; "")),
                ip: ((.TailscaleIPs // [])[0] // ""),
                os: (.OS // ""),
                online: (.Online // false),
                active: (.Active // false),
                last_seen: (.LastSeen // ""),
                relay: (.Relay // ""),
                rx_bytes: (.RxBytes // 0),
                tx_bytes: (.TxBytes // 0),
                exit_node: (.ExitNode // false),
                exit_node_option: (.ExitNodeOption // false),
                tags: ((.Tags // []) | join(", "))
            }
        ] | sort_by((.online | not), (.name | ascii_downcase))
    ' <<< "$raw")
    online_count=$(jq -r '[.[] | select(.online == true)] | length' <<< "$peers")
    total_count=$(jq -r 'length' <<< "$peers")
    offline_count=$((total_count - online_count))
    exit_node=$(jq -r '[.[] | select(.exit_node == true) | .name][0] // ""' <<< "$peers")
    exit_node_id=$(jq -r '[.[] | select(.exit_node == true) | (.dns // .ip // .id)][0] // ""' <<< "$peers")
    rx_total=$(jq -r '[.[].rx_bytes] | add // 0' <<< "$peers")
    tx_total=$(jq -r '[.[].tx_bytes] | add // 0' <<< "$peers")

    jq -nc \
        --argjson active true \
        --arg backend "$backend" \
        --arg hostname "$hostname" \
        --arg ip "$ts_ip" \
        --arg os "$os" \
        --argjson peers "$peers" \
        --argjson online_count "$online_count" \
        --argjson offline_count "$offline_count" \
        --argjson total_count "$total_count" \
        --arg exit_node "$exit_node" \
        --arg exit_node_id "$exit_node_id" \
        --arg rx_text "$(format_bytes "$rx_total")" \
        --arg tx_text "$(format_bytes "$tx_total")" \
        '{active:$active, backend:$backend, self:{hostname:$hostname, ip:$ip, os:$os, online:true}, peers:$peers, online_count:$online_count, offline_count:$offline_count, total_count:$total_count, exit_node:$exit_node, exit_node_id:$exit_node_id, rx_text:$rx_text, tx_text:$tx_text, message:""}'
}

ping_peer() {
    local target="$1" output ping route
    if [[ -z "$target" ]]; then
        jq -nc '{ok:false, summary:"No device selected", detail:"Select a peer before pinging"}'
        return 1
    fi

    output=$(tailscale ping --c=1 --timeout=3s "$target" 2>&1) || true
    ping=$(sed -nE 's/.* in ([0-9.]+)ms.*/\1 ms/p; s/.*time=([0-9.]+)ms.*/\1 ms/p' <<< "$output" | head -n1)
    route=$(sed -nE 's/.* via ([^ ]+) in .*/\1/p' <<< "$output" | head -n1)

    if [[ -n "$ping" ]]; then
        jq -nc --arg summary "Ping $ping" --arg detail "${route:-Tailscale path}" '{ok:true, summary:$summary, detail:$detail}'
    else
        jq -nc --arg detail "$(printf '%s\n' "$output" | awk 'NF {print; exit}')" '{ok:false, summary:"Ping failed", detail:$detail}'
        return 1
    fi
}

copy_value() {
    local value="$1"
    if [[ -z "$value" ]]; then
        jq -nc '{ok:false, summary:"Nothing to copy", detail:"No address is available"}'
        return 1
    fi

    if command -v wl-copy >/dev/null 2>&1; then
        printf '%s' "$value" | wl-copy
    elif command -v xclip >/dev/null 2>&1; then
        printf '%s' "$value" | xclip -selection clipboard
    elif command -v xsel >/dev/null 2>&1; then
        printf '%s' "$value" | xsel --clipboard --input
    else
        jq -nc --arg detail "$value" '{ok:false, summary:"Clipboard unavailable", detail:$detail}'
        return 1
    fi

    jq -nc --arg detail "$value" '{ok:true, summary:"Copied", detail:$detail}'
}

netcheck_json() {
    local output derp udp ipv4 ipv6 mapping
    output=$(tailscale netcheck --format=json 2>&1) || {
        jq -nc --arg detail "$(printf '%s\n' "$output" | awk 'NF {print; exit}')" '{ok:false, summary:"Netcheck failed", detail:$detail}'
        return 1
    }

    derp=$(jq -r '.PreferredDERP // .preferredDERP // ""' <<< "$output")
    udp=$(jq -r '.UDP // .udp // false' <<< "$output")
    ipv4=$(jq -r '.IPv4 // .ipv4 // false' <<< "$output")
    ipv6=$(jq -r '.IPv6 // .ipv6 // false' <<< "$output")
    mapping=$(jq -r '.MappingVariesByDestIP // .mappingVariesByDestIP // false' <<< "$output")

    jq -nc \
        --arg summary "Netcheck complete" \
        --arg detail "DERP ${derp:-?} | UDP $udp | IPv4 $ipv4 | IPv6 $ipv6 | Varies $mapping" \
        '{ok:true, summary:$summary, detail:$detail}'
}

run_action() {
    local action="${1:-}"
    shift || true

    case "$action" in
        --status|"")
            status_json
            ;;
        --up)
            tailscale up >/tmp/quickshell_tailscale_action.log 2>&1 && jq -nc '{ok:true, summary:"Tailscale connected", detail:"Backend is starting"}' || jq -nc --rawfile err /tmp/quickshell_tailscale_action.log '{ok:false, summary:"Tailscale up failed", detail:$err}'
            ;;
        --down)
            tailscale down >/tmp/quickshell_tailscale_action.log 2>&1 && jq -nc '{ok:true, summary:"Tailscale disconnected", detail:"VPN stopped"}' || jq -nc --rawfile err /tmp/quickshell_tailscale_action.log '{ok:false, summary:"Tailscale down failed", detail:$err}'
            ;;
        --ping)
            ping_peer "${1:-}"
            ;;
        --copy)
            copy_value "${1:-}"
            ;;
        --netcheck)
            netcheck_json
            ;;
        --set-exit-node)
            local target="${1:-}"
            if [[ -z "$target" ]]; then
                jq -nc '{ok:false, summary:"No exit node", detail:"Select an exit-node capable device"}'
                return 1
            fi
            tailscale set --exit-node="$target" >/tmp/quickshell_tailscale_action.log 2>&1 && jq -nc '{ok:true, summary:"Exit node enabled", detail:"Traffic will use the selected node"}' || jq -nc --rawfile err /tmp/quickshell_tailscale_action.log '{ok:false, summary:"Exit node failed", detail:$err}'
            ;;
        --clear-exit-node)
            tailscale set --exit-node= >/tmp/quickshell_tailscale_action.log 2>&1 && jq -nc '{ok:true, summary:"Exit node cleared", detail:"Default routing restored"}' || jq -nc --rawfile err /tmp/quickshell_tailscale_action.log '{ok:false, summary:"Clear exit failed", detail:$err}'
            ;;
        *)
            jq -nc --arg detail "$action" '{ok:false, summary:"Unknown action", detail:$detail}'
            return 1
            ;;
    esac
}

run_action "$@"

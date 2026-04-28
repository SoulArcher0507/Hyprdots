#!/usr/bin/env bash

set -uo pipefail

ACTION_RESULT_FILE="${TMPDIR:-/tmp}/quickshell_vpn_action_result.json"

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
        (.ExitNodeStatus.ID // "") as $exit_id |
        (((.ExitNodeStatus.TailscaleIPs // [])[0] // "") | split("/")[0]) as $exit_ip |
        [.Peer // {} | to_entries[] |
            .key as $id |
            .value |
            (((.TailscaleIPs // [])[0] // "") == $exit_ip) as $matches_exit_ip |
            ((.ID // "") == $exit_id) as $matches_exit_id |
            {
                id: $id,
                name: (.HostName // .DNSName // $id),
                dns: ((.DNSName // "") | sub("\\.$"; "")),
                ip: ((.TailscaleIPs // [])[0] // ""),
                cur_addr: (.CurAddr // ""),
                os: (.OS // ""),
                online: (.Online // false),
                active: (.Active // false),
                last_seen: (.LastSeen // ""),
                relay: (.Relay // ""),
                peer_relay: (.PeerRelay // ""),
                rx_bytes: (.RxBytes // 0),
                tx_bytes: (.TxBytes // 0),
                exit_node: ((.ExitNode // false) or ($matches_exit_id and $exit_id != "") or ($matches_exit_ip and $exit_ip != "")),
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
    if [[ -z "$exit_node" ]]; then
        exit_node=$(jq -r '(.ExitNodeStatus.ID // "") as $id | (((.ExitNodeStatus.TailscaleIPs // [])[0] // "") | split("/")[0]) as $ip | if $id != "" then $id elif $ip != "" then $ip else "" end' <<< "$raw")
        exit_node_id="$exit_node"
    fi
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

    local err_file detail
    err_file=$(mktemp "${TMPDIR:-/tmp}/quickshell-vpn-copy.XXXXXX") || {
        jq -nc '{ok:false, summary:"Copy failed", detail:"Unable to create temp file"}'
        return 1
    }

    if command -v wl-copy >/dev/null 2>&1; then
        printf '%s' "$value" | wl-copy >/dev/null 2>"$err_file" || {
            detail=$(<"$err_file")
            rm -f "$err_file"
            jq -nc --arg detail "${detail:-wl-copy failed}" '{ok:false, summary:"Copy failed", detail:$detail}'
            return 1
        }
    elif command -v xclip >/dev/null 2>&1; then
        printf '%s' "$value" | xclip -selection clipboard >/dev/null 2>"$err_file" || {
            detail=$(<"$err_file")
            rm -f "$err_file"
            jq -nc --arg detail "${detail:-xclip failed}" '{ok:false, summary:"Copy failed", detail:$detail}'
            return 1
        }
    elif command -v xsel >/dev/null 2>&1; then
        printf '%s' "$value" | xsel --clipboard --input >/dev/null 2>"$err_file" || {
            detail=$(<"$err_file")
            rm -f "$err_file"
            jq -nc --arg detail "${detail:-xsel failed}" '{ok:false, summary:"Copy failed", detail:$detail}'
            return 1
        }
    else
        rm -f "$err_file"
        jq -nc --arg detail "$value" '{ok:false, summary:"Clipboard unavailable", detail:$detail}'
        return 1
    fi

    rm -f "$err_file"
    jq -nc --arg detail "$value" '{ok:true, summary:"Copied", detail:$detail}'
}

netcheck_json() {
    local output err_file err derp udp ipv4 ipv6 mapping nearest global4 global6
    err_file=$(mktemp "${TMPDIR:-/tmp}/quickshell-vpn-netcheck.XXXXXX") || {
        jq -nc '{ok:false, summary:"Netcheck failed", detail:"Unable to create temp file"}'
        return 1
    }
    output=$(tailscale netcheck --format=json 2>"$err_file") || {
        err=$(<"$err_file")
        rm -f "$err_file"
        jq -nc --arg detail "$(printf '%s\n' "${err:-$output}" | awk 'NF {print; exit}')" '{ok:false, summary:"Netcheck failed", detail:$detail}'
        return 1
    }
    rm -f "$err_file"

    if ! jq -e . >/dev/null 2>&1 <<< "$output"; then
        jq -nc --arg detail "$(printf '%s\n' "$output" | awk 'NF {print; seen++} seen == 2 {exit}')" '{ok:true, summary:"Netcheck complete", detail:$detail}'
        return 0
    fi

    derp=$(jq -r '.PreferredDERP // .preferredDERP // .NearestDERP // .nearestDERP // ""' <<< "$output")
    nearest=$(jq -r '.NearestDERP // .nearestDERP // ""' <<< "$output")
    udp=$(jq -r '.UDP // .udp // "?"' <<< "$output")
    ipv4=$(jq -r '.IPv4 // .ipv4 // "?"' <<< "$output")
    ipv6=$(jq -r '.IPv6 // .ipv6 // "?"' <<< "$output")
    global4=$(jq -r '.GlobalV4 // .globalV4 // ""' <<< "$output")
    global6=$(jq -r '.GlobalV6 // .globalV6 // ""' <<< "$output")
    mapping=$(jq -r '.MappingVariesByDestIP // .mappingVariesByDestIP // "?"' <<< "$output")

    jq -nc \
        --arg summary "Netcheck complete" \
        --arg detail "DERP ${derp:-${nearest:-?}} | UDP $udp | IPv4 $ipv4${global4:+ $global4} | IPv6 $ipv6${global6:+ $global6} | Varies $mapping" \
        '{ok:true, summary:$summary, detail:$detail}'
}

resolve_exit_node_target() {
    local target="$1" raw resolved
    if [[ -z "$target" ]]; then
        return 1
    fi
    if [[ "$target" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ || "$target" == *:* ]]; then
        printf '%s' "$target"
        return 0
    fi

    raw=$(tailscale status --json 2>/dev/null) || {
        printf '%s' "$target"
        return 0
    }
    resolved=$(jq -r --arg target "$target" '
        [.Peer // {} | to_entries[] |
            .key as $id |
            .value |
            select(
                $id == $target or
                (.HostName // "") == $target or
                ((.DNSName // "") | sub("\\.$"; "")) == $target or
                ((.TailscaleIPs // [])[0] // "") == $target
            ) |
            ((.TailscaleIPs // [])[0] // "")
        ][0] // ""
    ' <<< "$raw")
    printf '%s' "${resolved:-$target}"
}

exit_node_candidates() {
    local target="$1" raw
    if [[ -z "$target" ]]; then
        return 1
    fi

    raw=$(tailscale status --json 2>/dev/null) || {
        printf '%s\n' "$target"
        return 0
    }

    jq -r --arg target "$target" '
        def clean_dns: sub("\\.$"; "");
        [
            .Peer // {} | to_entries[] |
            .key as $id |
            .value |
            select(
                $id == $target or
                (.HostName // "") == $target or
                ((.DNSName // "") | clean_dns) == $target or
                ((.TailscaleIPs // [])[0] // "") == $target or
                ((.TailscaleIPs // [])[1] // "") == $target
            ) |
            (.HostName // empty),
            ((.DNSName // "") | clean_dns),
            ((.TailscaleIPs // [])[0] // empty),
            $id
        ] | .[] | select(. != "")' <<< "$raw" | awk '!seen[$0]++'
}

needs_privilege_retry() {
    local err="$1"
    grep -Eqi 'access denied|permission denied|operation not permitted|not authorized|must be root|operator' <<< "$err"
}

run_tailscale_set() {
    local label="$1" success="$2"
    shift 2
    local err

    if tailscale set "$@" >/tmp/quickshell_tailscale_action.log 2>&1; then
        jq -nc --arg summary "$success" --arg detail "$label" '{ok:true, summary:$summary, detail:$detail}'
        return 0
    fi

    err=$(< /tmp/quickshell_tailscale_action.log)
    if needs_privilege_retry "$err"; then
        if command -v sudo >/dev/null 2>&1 && sudo -n tailscale set "$@" >/tmp/quickshell_tailscale_action.log 2>&1; then
            jq -nc --arg summary "$success" --arg detail "$label" '{ok:true, summary:$summary, detail:$detail}'
            return 0
        fi
        if command -v pkexec >/dev/null 2>&1 && pkexec tailscale set "$@" >/tmp/quickshell_tailscale_action.log 2>&1; then
            jq -nc --arg summary "$success" --arg detail "$label" '{ok:true, summary:$summary, detail:$detail}'
            return 0
        fi
        err=$(< /tmp/quickshell_tailscale_action.log)
        jq -nc --arg detail "${err:-Tailscale needs operator/root privileges for this change}" '{ok:false, summary:"Permission required", detail:$detail}'
        return 1
    fi

    jq -nc --arg detail "$err" '{ok:false, summary:"Exit node failed", detail:$detail}'
    return 1
}

exit_node_applied() {
    local target="$1" raw
    sleep 0.8
    raw=$(tailscale status --json 2>/dev/null) || return 0
    jq -e --arg target "$target" '
        def clean_dns: sub("\\.$"; "");
        (.ExitNodeStatus.ID // "") as $exit_id |
        (((.ExitNodeStatus.TailscaleIPs // [])[0] // "") | split("/")[0]) as $exit_ip |
        [.Peer // {} | to_entries[] |
            .key as $id |
            .value |
            (((.TailscaleIPs // [])[0] // "") == $exit_ip) as $matches_exit_ip |
            ((.ID // "") == $exit_id) as $matches_exit_id |
            select(
                (.ExitNode // false) == true or
                ($matches_exit_id and $exit_id != "") or
                ($matches_exit_ip and $exit_ip != "")
            ) |
            select(
                $target == "" or
                $id == $target or
                (.ID // "") == $target or
                (.HostName // "") == $target or
                ((.DNSName // "") | clean_dns) == $target or
                ((.TailscaleIPs // [])[0] // "") == $target or
                ((.TailscaleIPs // [])[1] // "") == $target
            )
        ] | length > 0
    ' <<< "$raw" >/dev/null 2>&1
}

set_exit_node_with_candidates() {
    local requested="$1" candidate output rc detail
    while IFS= read -r candidate; do
        [[ -z "$candidate" ]] && continue;
        output=$(run_tailscale_set "$candidate" "Exit node enabled" --exit-node="$candidate")
        rc=$?
        if [[ "$rc" -eq 0 ]]; then
            if exit_node_applied "$candidate"; then
                printf '%s\n' "$output"
                return 0
            fi
            detail="Command succeeded with $candidate, but status did not report it as active"
            continue
        fi
        detail=$(jq -r '.detail // ""' <<< "$output" 2>/dev/null)
        if ! grep -Eqi 'no node found|does not exist|unknown node|invalid value' <<< "$detail"; then
            printf '%s\n' "$output"
            return "$rc"
        fi
    done < <(exit_node_candidates "$requested")

    jq -nc --arg detail "${detail:-$requested}" '{ok:false, summary:"Exit node not applied", detail:$detail}'
    return 1
}

write_action_result() {
    local payload="$1"
    if jq -e . >/dev/null 2>&1 <<< "$payload"; then
        printf '%s\n' "$payload" > "$ACTION_RESULT_FILE"
    else
        jq -nc --arg detail "$payload" '{ok:false, summary:"Action failed", detail:$detail}' > "$ACTION_RESULT_FILE"
    fi
}

reopen_vpn_popup() {
    if command -v qs >/dev/null 2>&1; then
        qs ipc call vpn open >/dev/null 2>&1 || true
    fi
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
        --set-exit-node-reopen)
            sleep 0.45
            result=$(run_action --set-exit-node "${1:-}")
            local rc=$?
            write_action_result "$result"
            reopen_vpn_popup
            return "$rc"
            ;;
        --clear-exit-node-reopen)
            sleep 0.45
            result=$(run_action --clear-exit-node)
            local rc=$?
            write_action_result "$result"
            reopen_vpn_popup
            return "$rc"
            ;;
        --set-exit-node)
            local target="${1:-}"
            if [[ -z "$target" ]]; then
                jq -nc '{ok:false, summary:"No exit node", detail:"Select an exit-node capable device"}'
                return 1
            fi
            set_exit_node_with_candidates "$target"
            ;;
        --clear-exit-node)
            run_tailscale_set "Default routing restored" "Exit node cleared" --exit-node=
            ;;
        *)
            jq -nc --arg detail "$action" '{ok:false, summary:"Unknown action", detail:$detail}'
            return 1
            ;;
    esac
}

run_action "$@"

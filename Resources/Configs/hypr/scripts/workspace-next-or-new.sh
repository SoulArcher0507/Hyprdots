#!/usr/bin/env bash
set -euo pipefail

active_workspace="$(hyprctl activeworkspace -j 2>/dev/null || true)"
workspaces="$(hyprctl workspaces -j 2>/dev/null || true)"

focus_workspace_selector() {
    hyprctl dispatch "hl.dsp.focus({ workspace = \"$1\" })"
}

focus_workspace_id() {
    hyprctl dispatch "hl.dsp.focus({ workspace = $1 })"
}

if [[ -z "$active_workspace" || -z "$workspaces" ]]; then
    focus_workspace_selector "r+1"
    exit 0
fi

active_id="$(jq -r '.id // empty' <<<"$active_workspace" 2>/dev/null || true)"
windows="$(jq -r '.windows // 0' <<<"$active_workspace" 2>/dev/null || printf '0')"
monitor="$(jq -r '.monitor // .monitorName // .monitor_name // empty' <<<"$active_workspace" 2>/dev/null || true)"
monitor_id="$(jq -r '.monitorID // .monitorId // .monitor_id // empty' <<<"$active_workspace" 2>/dev/null || true)"

if ! [[ "$active_id" =~ ^[0-9]+$ && "$windows" =~ ^[0-9]+$ ]]; then
    focus_workspace_selector "r+1"
    exit 0
fi

workspace_ids_for_monitor='
    [
        .[]
        | select(.id > 0)
        | select(
            ($monitor != "" and ((.monitor // "") == $monitor))
            or ($monitor_id != "" and (((.monitorID // .monitorId // .monitor_id // "") | tostring) == $monitor_id))
        )
        | select((.windows // 0) > 0)
        | .id
    ]
    | sort
'

first_occupied="$(
    jq -r \
        --arg monitor "$monitor" \
        --arg monitor_id "$monitor_id" \
        "$workspace_ids_for_monitor | first // empty" \
        <<<"$workspaces" 2>/dev/null || true
)"

next_occupied="$(
    jq -r \
        --arg monitor "$monitor" \
        --arg monitor_id "$monitor_id" \
        --argjson active_id "$active_id" \
        "$workspace_ids_for_monitor | map(select(. > \$active_id)) | first // empty" \
        <<<"$workspaces" 2>/dev/null || true
)"

if [[ "$windows" =~ ^[0-9]+$ ]] && (( windows == 0 )); then
    if [[ "$first_occupied" =~ ^[0-9]+$ ]]; then
        focus_workspace_id "$first_occupied"
    else
        focus_workspace_selector "r+1"
    fi
elif [[ "$next_occupied" =~ ^[0-9]+$ ]]; then
    focus_workspace_id "$next_occupied"
else
    focus_workspace_selector "r+1"
fi

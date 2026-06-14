#!/usr/bin/env bash

set -euo pipefail

OUTPUT_NAME="${SUNSHINE_TABLET_OUTPUT:-SUNSHINE-TABLET}"
WIDTH="${SUNSHINE_TABLET_WIDTH:-2304}"
HEIGHT="${SUNSHINE_TABLET_HEIGHT:-1440}"
REFRESH="${SUNSHINE_TABLET_REFRESH:-90}"
SCALE="${SUNSHINE_TABLET_SCALE:-1}"
POSITION="${SUNSHINE_TABLET_POSITION:-auto-right}"
FALLBACK_MONITOR="${SUNSHINE_TABLET_FALLBACK_MONITOR:-eDP-1}"
ACTIVE_WALLPAPER="${SUNSHINE_TABLET_WALLPAPER:-$HOME/Pictures/Wallpapers/active/active.jpg}"
AWWW_RESIZE="${WALLPAPER_AWWW_RESIZE:-crop}"
MODE="${WIDTH}x${HEIGHT}@${REFRESH}"
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
REFRESH_PID_FILE="${SUNSHINE_TABLET_REFRESH_PID_FILE:-$RUNTIME_DIR/sunshine-tablet-display-refresh.pid}"
STABILIZE_DELAYS="${SUNSHINE_TABLET_STABILIZE_DELAYS:-0.05 0.15 0.35 0.8 1.6 3 5}"
TABLET_WORKSPACES="${SUNSHINE_TABLET_WORKSPACES:-5 6 7 8 9 10}"

usage() {
    printf 'Usage: %s start|stop|restart|refresh-wallpaper|stabilize|status\n' "$0" >&2
}

ensure_hypr_env() {
    if [[ -z "${XDG_RUNTIME_DIR:-}" ]]; then
        export XDG_RUNTIME_DIR="$RUNTIME_DIR"
    fi

    if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
        return 0
    fi

    local instance_dir
    for instance_dir in "$XDG_RUNTIME_DIR"/hypr/*; do
        [[ -S "$instance_dir/.socket.sock" ]] || continue
        export HYPRLAND_INSTANCE_SIGNATURE="${instance_dir##*/}"
        return 0
    done

    printf 'No Hyprland instance socket found.\n' >&2
    return 1
}

hypr_json() {
    local output

    if ! output="$(hyprctl -j "$@" 2>&1)"; then
        printf '%s\n' "$output" >&2
        return 1
    fi

    if ! jq -e . >/dev/null 2>&1 <<<"$output"; then
        printf 'hyprctl returned non-JSON output: %s\n' "$output" >&2
        return 1
    fi

    printf '%s\n' "$output"
}

monitor_state() {
    local monitors

    monitors="$(hypr_json monitors)" || return 2
    jq -e --arg name "$OUTPUT_NAME" '.[] | select(.name == $name)' >/dev/null <<<"$monitors" && return 0
    return 1
}

wait_for_monitor() {
    local tries="${1:-30}"

    while (( tries > 0 )); do
        if monitor_state; then
            return 0
        else
            case "$?" in
                1) ;;
                *) return 1 ;;
            esac
        fi

        sleep 0.1
        tries=$((tries - 1))
    done

    return 1
}

resolve_fallback_monitor() {
    local fallback

    fallback="$(hypr_json monitors | jq -r --arg preferred "$FALLBACK_MONITOR" --arg output "$OUTPUT_NAME" '
        (map(select(.name == $preferred)) | first | .name) //
        (map(select(.name != $output and (.name | startswith("HEADLESS-") | not))) | first | .name) //
        (map(select(.name != $output)) | first | .name) //
        empty
    ')"

    [[ -n "$fallback" ]] || return 1
    printf '%s\n' "$fallback"
}

configure_monitor() {
    local output_lua mode_lua position_lua

    output_lua="$(lua_quote "$OUTPUT_NAME")"
    mode_lua="$(lua_quote "$MODE")"
    position_lua="$(lua_quote "$POSITION")"

    if hyprctl eval "hl.monitor({ output = ${output_lua}, mode = ${mode_lua}, position = ${position_lua}, scale = ${SCALE} })" >/dev/null 2>&1; then
        return 0
    fi

    hyprctl keyword monitor "$OUTPUT_NAME,${MODE},${POSITION},${SCALE}" >/dev/null
}

apply_current_wallpaper() {
    local wallpaper=""

    command -v awww >/dev/null 2>&1 || return 0

    if [[ -f "$ACTIVE_WALLPAPER" ]]; then
        wallpaper="$ACTIVE_WALLPAPER"
    elif [[ -f "$HOME/Pictures/Wallpapers/active/awww-current.jpg" ]]; then
        wallpaper="$HOME/Pictures/Wallpapers/active/awww-current.jpg"
    fi

    if [[ -n "$wallpaper" ]]; then
        awww img "$wallpaper" \
            --outputs "$OUTPUT_NAME" \
            --resize "$AWWW_RESIZE" \
            -t none \
            >/dev/null 2>&1 || true
    else
        awww restore --outputs "$OUTPUT_NAME" >/dev/null 2>&1 || true
    fi
}

refresh_once() {
    ensure_hypr_env

    if monitor_state; then
        configure_monitor
        apply_current_wallpaper
        configure_monitor
    else
        case "$?" in
            1) return 0 ;;
            *) return 1 ;;
        esac
    fi
}

stabilize_display() {
    local delay

    ensure_hypr_env

    for delay in $STABILIZE_DELAYS; do
        sleep "$delay"

        if monitor_state; then
            configure_monitor
            apply_current_wallpaper
            configure_monitor
        else
            case "$?" in
                1) return 0 ;;
                *) return 1 ;;
            esac
        fi
    done
}

cancel_stabilize() {
    local pid=""

    [[ -f "$REFRESH_PID_FILE" ]] || return 0

    pid="$(<"$REFRESH_PID_FILE")"
    if [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null; then
        kill "$pid" 2>/dev/null || true
    fi

    rm -f "$REFRESH_PID_FILE"
}

schedule_stabilize() {
    mkdir -p "$RUNTIME_DIR"
    cancel_stabilize

    (
        trap 'rm -f "$REFRESH_PID_FILE"' EXIT
        stabilize_display
    ) >/dev/null 2>&1 &

    printf '%s\n' "$!" >"$REFRESH_PID_FILE"
}

refresh_wallpaper() {
    refresh_once

    if monitor_state; then
        schedule_stabilize
    else
        case "$?" in
            1) return 0 ;;
            *) return 1 ;;
        esac
    fi
}

lua_quote() {
    local value="$1"

    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    printf '"%s"\n' "$value"
}

move_workspaces_to_fallback() {
    local fallback workspace

    fallback="$(resolve_fallback_monitor)" || return 0

    while IFS= read -r workspace; do
        [[ -n "$workspace" ]] || continue
        move_workspace_to_monitor "$workspace" "$fallback"
    done < <(hypr_json workspaces | jq -r --arg output "$OUTPUT_NAME" '
        .[]
        | select(.monitor == $output and .id > 0)
        | .id
    ')
}

move_workspace_to_monitor() {
    local workspace="$1"
    local monitor="$2"
    local monitor_lua

    [[ "$workspace" =~ ^[0-9]+$ ]] || return 0

    monitor_lua="$(lua_quote "$monitor")"
    hyprctl eval "hl.dispatch(hl.dsp.workspace.move({ workspace = ${workspace}, monitor = ${monitor_lua} }))" >/dev/null 2>&1 || true
}

focus_monitor() {
    local monitor="$1"
    local monitor_lua

    monitor_lua="$(lua_quote "$monitor")"
    hyprctl eval "hl.dispatch(hl.dsp.focus({ monitor = ${monitor_lua} }))" >/dev/null 2>&1 || true
}

focus_workspace() {
    local workspace="$1"

    [[ "$workspace" =~ ^[0-9]+$ ]] || return 0
    hyprctl eval "hl.dispatch(hl.dsp.focus({ workspace = ${workspace} }))" >/dev/null 2>&1 || true
}

set_workspace_rule() {
    local workspace="$1"
    local monitor="$2"
    local persistent="$3"
    local workspace_lua monitor_lua

    workspace_lua="$(lua_quote "$workspace")"
    monitor_lua="$(lua_quote "$monitor")"

    if hyprctl eval "hl.workspace_rule({ workspace = ${workspace_lua}, monitor = ${monitor_lua}, persistent = ${persistent} })" >/dev/null 2>&1; then
        return 0
    fi

    hyprctl keyword workspace "$workspace,monitor:$monitor,persistent:$persistent" >/dev/null || true
}

set_tablet_workspace_rules() {
    local workspace

    for workspace in $TABLET_WORKSPACES; do
        [[ "$workspace" =~ ^[0-9]+$ ]] || continue
        set_workspace_rule "$workspace" "$OUTPUT_NAME" true
    done
}

clear_tablet_workspace_rules() {
    local fallback workspace

    fallback="$(resolve_fallback_monitor)" || return 0

    for workspace in $TABLET_WORKSPACES; do
        [[ "$workspace" =~ ^[0-9]+$ ]] || continue
        set_workspace_rule "$workspace" "$fallback" false
    done
}

move_tablet_workspaces_to_output() {
    local workspace

    for workspace in $TABLET_WORKSPACES; do
        [[ "$workspace" =~ ^[0-9]+$ ]] || continue
        move_workspace_to_monitor "$workspace" "$OUTPUT_NAME"
    done
}

focus_tablet_default_workspace() {
    local default_workspace="" focused_monitor=""

    for default_workspace in $TABLET_WORKSPACES; do
        [[ "$default_workspace" =~ ^[0-9]+$ ]] && break
        default_workspace=""
    done

    [[ -n "$default_workspace" ]] || return 0

    focused_monitor="$(hypr_json monitors | jq -r 'map(select(.focused)) | first | .name // empty')" || focused_monitor=""

    focus_monitor "$OUTPUT_NAME"
    focus_workspace "$default_workspace"

    if [[ -n "$focused_monitor" && "$focused_monitor" != "$OUTPUT_NAME" ]]; then
        focus_monitor "$focused_monitor"
    fi
}

start_display() {
    ensure_hypr_env

    if monitor_state; then
        :
    else
        case "$?" in
            1)
                hyprctl output create headless "$OUTPUT_NAME" >/dev/null
                wait_for_monitor 40 || {
                    printf 'Created %s, but Hyprland did not report it as active.\n' "$OUTPUT_NAME" >&2
                    return 1
                }
                ;;
            *)
                return 1
                ;;
        esac
    fi

    refresh_wallpaper
    set_tablet_workspace_rules
    move_tablet_workspaces_to_output
    focus_tablet_default_workspace
}

stop_display() {
    ensure_hypr_env
    cancel_stabilize

    if monitor_state; then
        :
    else
        case "$?" in
            1) return 0 ;;
            *) return 1 ;;
        esac
    fi

    move_workspaces_to_fallback
    clear_tablet_workspace_rules
    hyprctl output remove "$OUTPUT_NAME" >/dev/null || true
}

case "${1:-}" in
    start)
        start_display
        ;;
    stop)
        stop_display
        ;;
    restart)
        stop_display
        start_display
        ;;
    refresh-wallpaper)
        refresh_wallpaper
        ;;
    stabilize)
        stabilize_display
        ;;
    status)
        ensure_hypr_env
        if monitor_state; then
            printf '%s active\n' "$OUTPUT_NAME"
        else
            case "$?" in
                1)
                    printf '%s inactive\n' "$OUTPUT_NAME"
                    ;;
                *)
                    exit 1
                    ;;
            esac
        fi
        ;;
    *)
        usage
        exit 2
        ;;
esac

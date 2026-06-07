#!/usr/bin/env bash

set -o pipefail

PROGRESS_FILE="$HOME/.cache/quickshell/archtools_update.jsonl"
LOG_FILE="$HOME/.cache/quickshell/archtools_update.log"
ERROR_FILE="$HOME/.cache/quickshell/archtools_update_error.log"
LOCK_FILE="$HOME/.cache/quickshell/archtools_update.lock"
CANCEL_FILE="$HOME/.cache/quickshell/archtools_update.cancel"
PID_FILE="$HOME/.cache/quickshell/archtools_update.pid"
CURRENT_CMD_PID_FILE="$HOME/.cache/quickshell/archtools_update.current-pid"
CURRENT_CMD_PGID_FILE="$HOME/.cache/quickshell/archtools_update.current-pgid"
CURRENT_CMD_SID_FILE="$HOME/.cache/quickshell/archtools_update.current-sid"
CURRENT_CMD_ARGS_FILE="$HOME/.cache/quickshell/archtools_update.current-args"
MAX_ERROR_LINES="${ARCHTOOLS_UPDATE_MAX_ERROR_LINES:-40}"
PROGRESS_MAX_LINES="${ARCHTOOLS_UPDATE_PROGRESS_MAX_LINES:-200}"
PROGRESS_MAX_BYTES="${ARCHTOOLS_UPDATE_PROGRESS_MAX_BYTES:-65536}"
AUR_BUILD_JOBS="${ARCHTOOLS_AUR_BUILD_JOBS:-}"
PACMAN_CANCEL_GRACE_SECONDS="${ARCHTOOLS_PACMAN_CANCEL_GRACE_SECONDS:-45}"
PROGRESS_HEARTBEAT_SECONDS="${ARCHTOOLS_UPDATE_PROGRESS_HEARTBEAT_SECONDS:-2}"

[[ "$MAX_ERROR_LINES" =~ ^[0-9]+$ ]] && (( MAX_ERROR_LINES > 0 )) || MAX_ERROR_LINES=40
[[ "$PROGRESS_MAX_LINES" =~ ^[0-9]+$ ]] && (( PROGRESS_MAX_LINES > 0 )) || PROGRESS_MAX_LINES=200
[[ "$PROGRESS_MAX_BYTES" =~ ^[0-9]+$ ]] && (( PROGRESS_MAX_BYTES > 0 )) || PROGRESS_MAX_BYTES=65536
[[ "$PACMAN_CANCEL_GRACE_SECONDS" =~ ^[0-9]+$ ]] && (( PACMAN_CANCEL_GRACE_SECONDS > 0 )) || PACMAN_CANCEL_GRACE_SECONDS=45
[[ "$PROGRESS_HEARTBEAT_SECONDS" =~ ^[0-9]+$ ]] && (( PROGRESS_HEARTBEAT_SECONDS > 0 )) || PROGRESS_HEARTBEAT_SECONDS=2

if [[ -z "$AUR_BUILD_JOBS" ]]; then
    cpu_count="$(nproc 2>/dev/null || echo 1)"
    if (( cpu_count > 4 )); then
        AUR_BUILD_JOBS=4
    elif (( cpu_count > 0 )); then
        AUR_BUILD_JOBS="$cpu_count"
    else
        AUR_BUILD_JOBS=1
    fi
fi

if [[ "$AUR_BUILD_JOBS" =~ ^[0-9]+$ ]] && (( AUR_BUILD_JOBS > 0 )); then
    export MAKEFLAGS="-j${AUR_BUILD_JOBS}"
    export CMAKE_BUILD_PARALLEL_LEVEL="$AUR_BUILD_JOBS"
    export NINJAFLAGS="-j${AUR_BUILD_JOBS}"
fi

FINISHED=0
CANCEL_WATCHER_PID=""
SUDO_KEEPALIVE_PID=""
cleanup() {
    local exit_code=$?
    if [[ "$FINISHED" == "0" ]]; then
        local err_msg="Update process was terminated unexpectedly (exit code $exit_code)."
        emit complete error "total=0" "errors=$err_msg"
        notify-send -a "ArchTools" -i software-update-urgent -u critical "⚠ Update Interrupted" "$err_msg"
        rm -f "$PROGRESS_FILE"
    fi
    if [[ -n "$CANCEL_WATCHER_PID" ]]; then
        kill "$CANCEL_WATCHER_PID" >/dev/null 2>&1 || true
    fi
    if [[ -n "$SUDO_KEEPALIVE_PID" ]]; then
        kill "$SUDO_KEEPALIVE_PID" >/dev/null 2>&1 || true
    fi
    rm -f "/tmp/quickshell_sudo_pass_$$" "/tmp/quickshell_askpass_$$" "/tmp/quickshell_auth_cancel_$$"
    rm -rf "/tmp/archtools_sudo_path_$$"
    rm -f "$PID_FILE" "$CURRENT_CMD_PID_FILE" "$CURRENT_CMD_PGID_FILE" "$CURRENT_CMD_SID_FILE" "$CURRENT_CMD_ARGS_FILE" "$CANCEL_FILE"
}
trap cleanup EXIT

has()   { command -v "$1" >/dev/null 2>&1; }

truncate_err() {
    printf '%s\n' "$1" | tail -n "$MAX_ERROR_LINES"
}

trim_progress_file() {
    [[ -f "$PROGRESS_FILE" ]] || return 0
    local size
    size=$(wc -c < "$PROGRESS_FILE" 2>/dev/null || echo 0)
    if (( size > PROGRESS_MAX_BYTES )); then
        local tmp="${PROGRESS_FILE}.$$"
        tail -n "$PROGRESS_MAX_LINES" "$PROGRESS_FILE" > "$tmp" 2>/dev/null && mv "$tmp" "$PROGRESS_FILE"
        rm -f "$tmp"
    fi
}

current_millis() {
    date +%s%3N 2>/dev/null || printf '%s000' "$(date +%s)"
}

progress_pacman=0
progress_aur=0
progress_flatpak=0
CURRENT_UPDATE_STAGE=""

clamp_percent() {
    local raw="${1:-0}"
    raw="${raw%%.*}"
    [[ "$raw" =~ ^[0-9]+$ ]] || raw=0
    (( raw < 0 )) && raw=0
    (( raw > 100 )) && raw=100
    printf '%s' "$raw"
}

get_stage_progress() {
    case "$1" in
        pacman)  printf '%s' "$progress_pacman" ;;
        aur)     printf '%s' "$progress_aur" ;;
        flatpak) printf '%s' "$progress_flatpak" ;;
        *)       printf '0' ;;
    esac
}

set_stage_progress() {
    local stage="$1" pct
    pct="$(clamp_percent "$2")"
    local current
    current="$(get_stage_progress "$stage")"
    (( pct < current )) && pct="$current"

    case "$stage" in
        pacman)  progress_pacman="$pct" ;;
        aur)     progress_aur="$pct" ;;
        flatpak) progress_flatpak="$pct" ;;
    esac
}

mark_requested_stages_complete() {
    case "$PROVIDER" in
        all)
            progress_pacman=100
            progress_aur=100
            progress_flatpak=100
            ;;
        pacman)  progress_pacman=100 ;;
        aur)     progress_aur=100 ;;
        flatpak) progress_flatpak=100 ;;
    esac
}

overall_progress() {
    case "$PROVIDER" in
        pacman)  printf '%s' "$progress_pacman" ;;
        aur)     printf '%s' "$progress_aur" ;;
        flatpak) printf '%s' "$progress_flatpak" ;;
        *)       printf '%s' $(( (progress_pacman + progress_aur + progress_flatpak) / 3 )) ;;
    esac
}

json_escape() {
    local val="$1"
    val="${val//\\/\\\\}"
    val="${val//\"/\\\"}"
    val="${val//$'\n'/\\n}"
    val="${val//$'\r'/}"
    printf '%s' "$val"
}

prepare_progress_for_emit() {
    local stage="$1" status="$2"
    case "$stage" in
        pacman|aur|flatpak)
            case "$status" in
                starting)
                    set_stage_progress "$stage" 2
                    ;;
                running)
                    set_stage_progress "$stage" 6
                    ;;
                done|success|skipped|error)
                    set_stage_progress "$stage" 100
                    ;;
            esac
            ;;
        complete)
            mark_requested_stages_complete
            ;;
    esac
}

append_progress_fields() {
    local stage="$1"
    printf ',"progress":%s' "$(overall_progress)"
    if [[ "$stage" == "pacman" || "$stage" == "aur" || "$stage" == "flatpak" ]]; then
        printf ',"stageProgress":%s' "$(get_stage_progress "$stage")"
    fi
    printf ',"progressPacman":%s,"progressAur":%s,"progressFlatpak":%s' "$progress_pacman" "$progress_aur" "$progress_flatpak"
}

emit_stage_progress() {
    local stage="$1" pct="$2" detail="${3:-}"
    [[ "$stage" == "pacman" || "$stage" == "aur" || "$stage" == "flatpak" ]] || return 0
    set_stage_progress "$stage" "$pct"

    local escaped_detail json
    escaped_detail="$(json_escape "$detail")"
    json="{\"stage\":\"$stage\",\"status\":\"running\",\"detail\":\"$escaped_detail\""
    json+="$(append_progress_fields "$stage")"
    json+="}"
    echo "$json" >> "$PROGRESS_FILE"
    trim_progress_file
}

last_percent_in_text() {
    local text="$1" pct="" scan="$1"
    while [[ "$scan" =~ ([0-9]{1,3})% ]]; do
        pct="${BASH_REMATCH[1]}"
        scan="${scan#*"${BASH_REMATCH[0]}"}"
    done
    [[ -n "$pct" ]] || return 1
    clamp_percent "$pct"
}

progress_from_record() {
    local stage="$1" record="$2" pct numerator denominator
    [[ -n "$stage" ]] || return 0

    if [[ "$stage" != "aur" && "$record" =~ \(([0-9]+)[[:space:]]*/[[:space:]]*([0-9]+)\) ]]; then
        numerator="${BASH_REMATCH[1]}"
        denominator="${BASH_REMATCH[2]}"
        if [[ "$denominator" =~ ^[0-9]+$ ]] && (( denominator > 0 && numerator <= denominator )); then
            pct=$(( numerator * 100 / denominator ))
            emit_stage_progress "$stage" "$pct" "$record"
            return 0
        fi
    fi

    if [[ "$record" =~ [Tt]otal|[Oo]verall|[Pp]rogress || "$stage" == "flatpak" ]]; then
        if pct="$(last_percent_in_text "$record")"; then
            emit_stage_progress "$stage" "$pct" "$record"
        fi
    fi
}

record_error_line() {
    local tmp="$1" line="$2" max_chars=4000
    if (( ${#line} > max_chars )); then
        line="${line:0:max_chars}... [truncated]"
    fi
    printf '%s\n' "$line" >> "$tmp"
    local line_count
    line_count="$(wc -l < "$tmp" 2>/dev/null || echo 0)"
    if (( line_count > MAX_ERROR_LINES )); then
        local trimmed="${tmp}.trim"
        tail -n "$MAX_ERROR_LINES" "$tmp" > "$trimmed" 2>/dev/null && mv "$trimmed" "$tmp"
        rm -f "$trimmed"
    fi
}

read_command_output() {
    local fifo="$1" tmp="$2" progress_stage="$3"
    local char="" record="" separator=""
    : > "$tmp"

    while IFS= read -r -N 1 char; do
        printf '%s' "$char" >> "$LOG_FILE"
        separator=""
        if [[ "$char" == $'\r' || "$char" == $'\n' ]]; then
            separator="$char"
            if [[ -n "$record" ]]; then
                record_error_line "$tmp" "$record"
                progress_from_record "$progress_stage" "$record"
            fi
            record=""
        else
            record+="$char"
            if (( ${#record} >= 4096 )); then
                printf '\n' >> "$LOG_FILE"
                record_error_line "$tmp" "$record"
                progress_from_record "$progress_stage" "$record"
                record=""
            fi
        fi
    done < "$fifo"

    if [[ -n "$record" ]]; then
        printf '\n' >> "$LOG_FILE"
        record_error_line "$tmp" "$record"
        progress_from_record "$progress_stage" "$record"
    fi
}

progress_heartbeat() {
    local cmd_pid="$1" stage="$2" floor="${3:-8}" cap="${4:-92}"
    local start now elapsed estimate detail
    [[ -n "$stage" ]] || return 0
    start="$(date +%s)"
    while kill -0 "$cmd_pid" >/dev/null 2>&1; do
        sleep "$PROGRESS_HEARTBEAT_SECONDS"
        kill -0 "$cmd_pid" >/dev/null 2>&1 || break
        now="$(date +%s)"
        elapsed=$(( now - start ))
        estimate=$(( floor + (elapsed * (cap - floor) / 120) ))
        (( estimate > cap )) && estimate="$cap"
        detail="Updating $stage..."
        emit_stage_progress "$stage" "$estimate" "$detail"
    done
}

quoted_command() {
    local quoted=""
    printf -v quoted '%q ' "$@"
    printf '%s' "${quoted% }"
}

run_bounded() {
    local tmp="/tmp/archtools_update_output_$$"
    local fifo="/tmp/archtools_update_fifo_$$"
    local cmd_pid=""
    local reader_pid=""
    local heartbeat_pid=""
    local cmd_status=0
    rm -f "$tmp"
    rm -f "$fifo"
    mkfifo "$fifo"
    {
        printf '$'
        printf ' %q' "$@"
        printf '\n'
    } >> "$LOG_FILE"

    read_command_output "$fifo" "$tmp" "$CURRENT_UPDATE_STAGE" &
    reader_pid=$!

    printf '%s\n' "$@" > "$CURRENT_CMD_ARGS_FILE"
    if has script; then
        local cmd_string
        cmd_string="$(quoted_command "$@")"
        if has setsid; then
            ( trap - INT QUIT TERM; exec setsid script -qefc "$cmd_string" /dev/null ) > "$fifo" 2>&1 &
        else
            ( trap - INT QUIT TERM; exec script -qefc "$cmd_string" /dev/null ) > "$fifo" 2>&1 &
        fi
    else
        if has setsid; then
            ( trap - INT QUIT TERM; exec setsid "$@" ) > "$fifo" 2>&1 &
        else
            ( trap - INT QUIT TERM; exec "$@" ) > "$fifo" 2>&1 &
        fi
    fi
    cmd_pid=$!
    echo "$cmd_pid" > "$CURRENT_CMD_PID_FILE"
    ps -o pgid= -p "$cmd_pid" 2>/dev/null | tr -d '[:space:]' > "$CURRENT_CMD_PGID_FILE" || true
    ps -o sid= -p "$cmd_pid" 2>/dev/null | tr -d '[:space:]' > "$CURRENT_CMD_SID_FILE" || true

    progress_heartbeat "$cmd_pid" "$CURRENT_UPDATE_STAGE" &
    heartbeat_pid=$!

    wait "$cmd_pid"
    cmd_status=$?
    if [[ -n "$heartbeat_pid" ]]; then
        kill "$heartbeat_pid" >/dev/null 2>&1 || true
        wait "$heartbeat_pid" 2>/dev/null || true
    fi
    wait "$reader_pid" 2>/dev/null || true
    rm -f "$fifo" "$CURRENT_CMD_PID_FILE" "$CURRENT_CMD_PGID_FILE" "$CURRENT_CMD_SID_FILE" "$CURRENT_CMD_ARGS_FILE"

    if [[ -f "$CANCEL_FILE" ]]; then
        finish_cancelled
    fi

    if [[ "$cmd_status" -eq 0 ]]; then
        printf '\n' >> "$LOG_FILE"
        rm -f "$tmp"
        return 0
    fi
    RUN_BOUNDED_OUTPUT="$(cat "$tmp" 2>/dev/null || true)"
    printf '\n[command exited with an error]\n\n' >> "$LOG_FILE"
    rm -f "$tmp"
    return 1
}


emit() {
    local stage="$1" status="$2"; shift 2
    prepare_progress_for_emit "$stage" "$status"

    local json="{\"stage\":\"$stage\",\"status\":\"$status\""
    local detail_text=""
    for kv in "$@"; do
        local key="${kv%%=*}" val="${kv#*=}"
        if [[ "$key" == "detail" ]]; then
            detail_text="$val"
        fi
        if [[ "$val" =~ ^[0-9]+$ ]]; then
            json+=",\"$key\":$val"
        else
            val="$(json_escape "$val")"
            json+=",\"$key\":\"$val\""
        fi
    done
    json+="$(append_progress_fields "$stage")"
    if [[ "$stage" == "complete" ]]; then
        json+=",\"finishedTimestamp\":$(current_millis)"
    fi
    json+="}"
    echo "$json"
    echo "$json" >> "$PROGRESS_FILE"
    if [[ -n "$detail_text" ]]; then
        printf '[%s/%s] %s\n' "$stage" "$status" "$detail_text" >> "$LOG_FILE"
    else
        printf '[%s/%s]\n' "$stage" "$status" >> "$LOG_FILE"
    fi
    trim_progress_file
}

finish_cancelled() {
    local err_msg="Update cancelled by user."
    local total=$(( ${count_pacman:-0} + ${count_aur:-0} + ${count_flatpak:-0} ))
    FINISHED=1
    emit complete error "total=$total" "pacman=${count_pacman:-0}" "aur=${count_aur:-0}" "flatpak=${count_flatpak:-0}" "errors=$err_msg"
    printf '\n[cancelled] %s\n' "$err_msg" >> "$LOG_FILE"
    notify-send -a "ArchTools" -i process-stop "Update Cancelled" "$err_msg"
    exit 130
}

abort_if_cancelled() {
    if [[ -f "$CANCEL_FILE" ]]; then
        finish_cancelled
    fi
}

trap finish_cancelled INT TERM QUIT

signal_process_tree() {
    local sig="$1"
    local pid="$2"
    local child
    [[ "$pid" =~ ^[0-9]+$ ]] || return 0

    if has pgrep; then
        while IFS= read -r child; do
            signal_process_tree "$sig" "$child"
        done < <(pgrep -P "$pid" 2>/dev/null || true)
    fi

    kill "-$sig" "$pid" >/dev/null 2>&1 || true
}

collect_process_tree() {
    local pid="$1"
    local child
    [[ "$pid" =~ ^[0-9]+$ ]] || return 0
    echo "$pid"

    if has pgrep; then
        while IFS= read -r child; do
            collect_process_tree "$child"
        done < <(pgrep -P "$pid" 2>/dev/null || true)
    fi
}

process_tree_has_pacman() {
    local pid="$1"
    local proc_name proc_args
    while IFS= read -r pid; do
        proc_name="$(ps -o comm= -p "$pid" 2>/dev/null | awk '{print $1}' || true)"
        proc_args="$(ps -o args= -p "$pid" 2>/dev/null || true)"
        if [[ "$proc_name" == "pacman" || "$proc_args" =~ (^|[[:space:]/])pacman([[:space:]]|$) ]]; then
            return 0
        fi
    done < <(collect_process_tree "$1")
    return 1
}

current_args_has_pacman() {
    grep -Fxq "pacman" "$CURRENT_CMD_ARGS_FILE" 2>/dev/null
}

process_still_alive() {
    local pid="$1"
    [[ "$pid" =~ ^[0-9]+$ ]] || return 1
    kill -0 "$pid" >/dev/null 2>&1
}

process_groups_have_pacman() {
    local pgid
    for pgid in "$@"; do
        [[ "$pgid" =~ ^[0-9]+$ ]] || continue
        if has pgrep && pgrep -g "$pgid" -x pacman >/dev/null 2>&1; then
            return 0
        fi
        if ps -eo pgid=,comm= 2>/dev/null | awk -v target="$pgid" '$1 == target && $2 == "pacman" { found = 1 } END { exit !found }'; then
            return 0
        fi
    done
    return 1
}

wait_for_pacman_cleanup() {
    local pid="$1"
    local seconds="$2"
    local elapsed=0
    shift 2
    while process_still_alive "$pid" || process_groups_have_pacman "$@"; do
        if (( elapsed >= seconds )); then
            return 1
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done
    return 0
}

append_unique_number() {
    local value="$1"
    local existing
    [[ "$value" =~ ^[0-9]+$ ]] || return 0
    shift
    for existing in "$@"; do
        [[ "$existing" == "$value" ]] && return 1
    done
    return 0
}

signal_current_command() {
    local current_pid="$1"
    local parent_pgid parent_sid pid pgid sid sig pacman_command
    local -a pids=()
    local -a pgids=()
    local -a sids=()
    [[ "$current_pid" =~ ^[0-9]+$ ]] || return 1
    pacman_command=0

    parent_pgid="$(ps -o pgid= -p "$$" 2>/dev/null | tr -d '[:space:]' || true)"
    parent_sid="$(ps -o sid= -p "$$" 2>/dev/null | tr -d '[:space:]' || true)"

    while IFS= read -r pid; do
        if append_unique_number "$pid" "${pids[@]}"; then
            pids+=("$pid")
        fi

        pgid="$(ps -o pgid= -p "$pid" 2>/dev/null | tr -d '[:space:]' || true)"
        if [[ "$pgid" =~ ^[0-9]+$ && "$pgid" != "$parent_pgid" ]] && append_unique_number "$pgid" "${pgids[@]}"; then
            pgids+=("$pgid")
        fi

        sid="$(ps -o sid= -p "$pid" 2>/dev/null | tr -d '[:space:]' || true)"
        if [[ "$sid" =~ ^[0-9]+$ && "$sid" != "$parent_sid" ]] && append_unique_number "$sid" "${sids[@]}"; then
            sids+=("$sid")
        fi
    done < <(collect_process_tree "$current_pid")

    pgid="$(cat "$CURRENT_CMD_PGID_FILE" 2>/dev/null | tr -d '[:space:]' || true)"
    if [[ "$pgid" =~ ^[0-9]+$ && "$pgid" != "$parent_pgid" ]] && append_unique_number "$pgid" "${pgids[@]}"; then
        pgids+=("$pgid")
    fi

    sid="$(cat "$CURRENT_CMD_SID_FILE" 2>/dev/null | tr -d '[:space:]' || true)"
    if [[ "$sid" =~ ^[0-9]+$ && "$sid" != "$parent_sid" ]] && append_unique_number "$sid" "${sids[@]}"; then
        sids+=("$sid")
    fi

    if current_args_has_pacman || process_tree_has_pacman "$current_pid"; then
        pacman_command=1
    fi

    printf '[cancel/debug] pid=%s pgids=%s sids=%s pacman=%s\n' "$current_pid" "${pgids[*]:-none}" "${sids[*]:-none}" "$pacman_command" >> "$LOG_FILE"

    for sig in INT TERM KILL; do
        for pgid in "${pgids[@]}"; do
            kill "-$sig" -- "-$pgid" >/dev/null 2>&1 || true
        done
        if has pkill; then
            for sid in "${sids[@]}"; do
                pkill "-$sig" -s "$sid" >/dev/null 2>&1 || true
            done
        fi
        for pid in "${pids[@]}"; do
            kill "-$sig" "$pid" >/dev/null 2>&1 || true
        done

        if [[ "$sig" == "INT" ]]; then
            if [[ "$pacman_command" == "1" ]]; then
                printf '[cancel/pacman] Sent SIGINT to pacman process group; waiting up to %ss for pacman cleanup.\n' "$PACMAN_CANCEL_GRACE_SECONDS" >> "$LOG_FILE"
                if wait_for_pacman_cleanup "$current_pid" "$PACMAN_CANCEL_GRACE_SECONDS" "${pgids[@]}"; then
                    return 0
                fi
                printf '[cancel/pacman] Pacman is still running after SIGINT grace period; leaving it alive to avoid corrupting the database lock.\n' >> "$LOG_FILE"
                return 0
            fi
            sleep 1
        elif [[ "$sig" == "TERM" ]]; then
            sleep 2
        fi
    done
}

start_cancel_watcher() {
    local parent_pid="$$"
    (
        cancel_announced=0
        while kill -0 "$parent_pid" >/dev/null 2>&1; do
            if [[ -f "$CANCEL_FILE" ]]; then
                if [[ "$cancel_announced" == "0" ]]; then
                    echo "{\"stage\":\"cancel\",\"status\":\"running\",\"detail\":\"Cancellation requested\"}" >> "$PROGRESS_FILE"
                    printf '[cancel/running] Cancellation requested\n' >> "$LOG_FILE"
                    cancel_announced=1
                fi
                if [[ -s "$CURRENT_CMD_PID_FILE" ]]; then
                    current_pid="$(cat "$CURRENT_CMD_PID_FILE" 2>/dev/null || true)"
                    signal_current_command "$current_pid"
                    kill -INT "$parent_pid" >/dev/null 2>&1 || true
                    exit 0
                else
                    if has pgrep; then
                        while IFS= read -r child_pid; do
                            [[ "$child_pid" =~ ^[0-9]+$ ]] || continue
                            kill -TERM "$child_pid" >/dev/null 2>&1 || true
                        done < <(pgrep -P "$parent_pid" 2>/dev/null || true)
                    fi
                    kill -INT "$parent_pid" >/dev/null 2>&1 || true
                fi
            fi
            sleep 0.2
        done
    ) &
    CANCEL_WATCHER_PID=$!
}

PROVIDER="all"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --provider) PROVIDER="$2"; shift 2 ;;
        *)          shift ;;
    esac
done

mkdir -p "$(dirname "$PROGRESS_FILE")"
exec 9>"$LOCK_FILE"
if has flock && ! flock -n 9; then
    : > "$PROGRESS_FILE"
    emit complete error "total=0" "errors=Another ArchTools update is already running"
    notify-send -a "ArchTools" -i software-update-urgent -u critical "⚠ Update Already Running" "Another ArchTools update is already running."
    FINISHED=1
    exit 1
fi

echo "{\"stage\":\"init\",\"status\":\"starting\",\"provider\":\"$PROVIDER\",\"pid\":$$}" > "$PROGRESS_FILE"
: > "$LOG_FILE"
printf 'ArchTools update started: provider=%s pid=%s\n\n' "$PROVIDER" "$$" >> "$LOG_FILE"
echo "$$" > "$PID_FILE"
rm -f "$CANCEL_FILE" "$CURRENT_CMD_PID_FILE" "$CURRENT_CMD_PGID_FILE" "$CURRENT_CMD_SID_FILE" "$CURRENT_CMD_ARGS_FILE"
start_cancel_watcher

count_pacman=0
count_aur=0
count_flatpak=0
errors=()

start_sudo_keepalive() {
    if [[ -n "$SUDO_KEEPALIVE_PID" ]] && kill -0 "$SUDO_KEEPALIVE_PID" >/dev/null 2>&1; then
        return 0
    fi

    (
        while true; do
            sleep 60
            sudo -n -v >/dev/null 2>&1 || exit 0
        done
    ) &
    SUDO_KEEPALIVE_PID=$!
}

validate_sudo_with_askpass() {
    printf '[auth] Validating sudo credentials...\n' >> "$LOG_FILE"
    if has timeout; then
        timeout 90 sudo -A -v 2>> "$LOG_FILE"
    else
        sudo -A -v 2>> "$LOG_FILE"
    fi
    local status=$?
    abort_if_cancelled
    if [[ "$status" -eq 0 ]]; then
        printf '[auth] Sudo credentials accepted.\n' >> "$LOG_FILE"
        start_sudo_keepalive
    else
        printf '[auth] Sudo validation failed with status %s.\n' "$status" >> "$LOG_FILE"
        emit auth error "detail=Authentication failed"
    fi
    return "$status"
}

ensure_sudo() {
    local stage="$1"
    if sudo -n true 2>/dev/null; then
        start_sudo_keepalive
        return 0
    fi
    if [[ -n "$SUDO_ASKPASS" ]] && [[ -f "$SUDO_ASKPASS" ]]; then
        validate_sudo_with_askpass
        return $?
    fi

    export SUDO_PASS_FILE="/tmp/quickshell_sudo_pass_$$"
    export SUDO_CANCEL_FILE="/tmp/quickshell_auth_cancel_$$"
    export SUDO_ASKPASS="/tmp/quickshell_askpass_$$"
    export CANCEL_FILE
    export PROGRESS_FILE
    
    cat << 'EOF' > "$SUDO_ASKPASS"
#!/bin/bash
emit_state() {
    local json="{\"stage\":\"auth\",\"status\":\"$1\",\"detail\":\"$2\"}"
    echo "$json" >> "$PROGRESS_FILE"
}

emit_state waiting_auth "Waiting for sudo authentication"

rm -f "$SUDO_PASS_FILE" "$SUDO_CANCEL_FILE"
touch "$SUDO_PASS_FILE"
chmod 600 "$SUDO_PASS_FILE"

open_auth_panel() {
    qs ipc call arch auth "$SUDO_PASS_FILE" >/dev/null 2>&1 || qs ipc call arch toggle >/dev/null 2>&1 || true
}

(
    action=$(notify-send -a "ArchTools" -u critical -A "open=Open Panel" "Admin Password Required" "Enter your password to continue updates.")
    if [[ "$action" == "open" ]]; then
        open_auth_panel
    fi
) &

open_auth_panel

for _ in $(seq 1 300); do
    if [[ -s "$SUDO_PASS_FILE" ]]; then
        emit_state running "Authentication received, continuing..."
        printf '%s\n' "$(cat "$SUDO_PASS_FILE")"
        rm -f "$SUDO_PASS_FILE" "$SUDO_CANCEL_FILE"
        exit 0
    fi
    if [[ -f "$SUDO_CANCEL_FILE" || -f "$CANCEL_FILE" ]]; then
        emit_state error "Authentication cancelled"
        rm -f "$SUDO_PASS_FILE" "$SUDO_CANCEL_FILE"
        exit 1
    fi
    sleep 0.2
done

emit_state error "Authentication timed out"
rm -f "$SUDO_PASS_FILE" "$SUDO_CANCEL_FILE"
exit 1
EOF
    chmod +x "$SUDO_ASKPASS"
    validate_sudo_with_askpass
    return $?
}

run_aur_bounded() {
    local helper="$1"
    shift
    local real_sudo wrapper_dir wrapper_path

    real_sudo="$(command -v sudo 2>/dev/null || true)"
    [[ -n "$real_sudo" ]] || real_sudo="/usr/bin/sudo"

    wrapper_dir="/tmp/archtools_sudo_path_$$"
    wrapper_path="$wrapper_dir/sudo"
    mkdir -p "$wrapper_dir"
    cat > "$wrapper_path" << EOF
#!/usr/bin/env bash
exec "$real_sudo" -A "\$@"
EOF
    chmod +x "$wrapper_path"

    PATH="$wrapper_dir:$PATH" run_bounded "$helper" "$@"
}


run_pacman() {
    if ! has pacman; then
        emit pacman skipped "detail=pacman not found"
        return 0
    fi

    emit pacman starting "detail=Checking pacman updates..."

    local before
    if has checkupdates; then
        before="$(checkupdates 2>/dev/null || true)"
    else
        before="$(pacman -Qu --quiet 2>/dev/null || true)"
    fi
    local n_before
    n_before=$(echo "$before" | grep -c . 2>/dev/null || echo 0)

    if [[ -z "$before" ]]; then
        emit pacman done "count=0" "detail=No pacman updates available"
        return 0
    fi

    emit pacman running "detail=Updating $n_before packages..."

    if ! ensure_sudo "pacman"; then
        errors+=("pacman: authentication failed")
        emit pacman error "detail=Authentication failed"
        return 1
    fi
    abort_if_cancelled

    CURRENT_UPDATE_STAGE="pacman"
    if ! run_bounded sudo -A pacman --noconfirm -Syu; then
        CURRENT_UPDATE_STAGE=""
        err_output="$(truncate_err "$RUN_BOUNDED_OUTPUT")"
        errors+=("pacman: $err_output")
        emit pacman error "detail=$err_output"
        return 1
    fi
    CURRENT_UPDATE_STAGE=""

    count_pacman=$n_before
    emit pacman done "count=$n_before" "detail=Updated $n_before packages"
}

run_aur() {
    local helper=""
    if   has yay;    then helper="yay"
    elif has paru;   then helper="paru"
    elif has pikaur; then helper="pikaur"
    else
        emit aur skipped "detail=No AUR helper found"
        return 0
    fi

    emit aur starting "detail=Checking AUR updates ($helper)..."

    local before
    case "$helper" in
        yay)    before="$($helper -Qua --quiet 2>/dev/null || true)" ;;
        paru)   before="$($helper -Qua --quiet 2>/dev/null || true)" ;;
        pikaur) before="$($helper -Qua 2>/dev/null | awk '{print $1}' || true)" ;;
    esac

    local n_before
    n_before=$(echo "$before" | grep -c . 2>/dev/null || echo 0)

    if [[ -z "$before" ]]; then
        emit aur done "count=0" "detail=No AUR updates available"
        return 0
    fi

    emit aur running "detail=Updating $n_before AUR packages..."

    if ! ensure_sudo "aur"; then
        return 1
    fi
    abort_if_cancelled

    local aur_status=0
    case "$helper" in
        yay)
            CURRENT_UPDATE_STAGE="aur"
            run_aur_bounded "$helper" -Sua --noconfirm --sudoflags "-A" --sudoloop
            aur_status=$?
            ;;
        paru)
            CURRENT_UPDATE_STAGE="aur"
            run_aur_bounded "$helper" -Sua --noconfirm --sudoflags "-A" --sudoloop
            aur_status=$?
            ;;
        pikaur)
            CURRENT_UPDATE_STAGE="aur"
            run_aur_bounded "$helper" -Sua --noconfirm
            aur_status=$?
            ;;
    esac
    CURRENT_UPDATE_STAGE=""

    if [[ "$aur_status" -ne 0 ]]; then
        err_output="$(truncate_err "$RUN_BOUNDED_OUTPUT")"
        errors+=("aur($helper): $err_output")
        emit aur error "detail=$err_output"
        return 1
    fi

    count_aur=$n_before
    emit aur done "count=$n_before" "detail=Updated $n_before AUR packages"
}

run_flatpak() {
    if ! has flatpak; then
        emit flatpak skipped "detail=flatpak not found"
        return 0
    fi

    emit flatpak starting "detail=Checking Flatpak updates..."

    local before
    before="$(flatpak remote-ls --updates --columns=application 2>/dev/null | awk 'NF' || true)"
    local n_before
    n_before=$(echo "$before" | grep -c . 2>/dev/null || echo 0)

    if [[ -z "$before" ]]; then
        emit flatpak done "count=0" "detail=No Flatpak updates available"
        return 0
    fi

    emit flatpak running "detail=Updating $n_before Flatpak apps..."

    CURRENT_UPDATE_STAGE="flatpak"
    if ! run_bounded flatpak update -y --noninteractive; then
        CURRENT_UPDATE_STAGE=""
        err_output="$(truncate_err "$RUN_BOUNDED_OUTPUT")"
        errors+=("flatpak: $err_output")
        emit flatpak error "detail=$err_output"
        return 1
    fi
    CURRENT_UPDATE_STAGE=""

    count_flatpak=$n_before
    emit flatpak done "count=$n_before" "detail=Updated $n_before Flatpak apps"
}


case "$PROVIDER" in
    all)
        run_pacman || true
        run_aur    || true
        run_flatpak || true
        ;;
    pacman)
        if ! has pacman; then
            emit pacman error "detail=pacman not found"
            errors+=("pacman not found")
        else
            emit pacman starting "detail=Checking pacman updates..."
            if has checkupdates; then
                pac_before="$(checkupdates 2>/dev/null || true)"
            else
                pac_before="$(pacman -Qu --quiet 2>/dev/null || true)"
            fi
            pac_n_before=$(echo "$pac_before" | grep -c . 2>/dev/null || echo 0)
            if [[ -z "$pac_before" ]]; then
                emit pacman done "count=0" "detail=No pacman updates available"
            else
                emit pacman running "detail=Updating $pac_n_before packages..."
                if ensure_sudo "pacman"; then
                    abort_if_cancelled
                    CURRENT_UPDATE_STAGE="pacman"
                    if ! run_bounded sudo -A pacman --noconfirm -Syu; then
                        CURRENT_UPDATE_STAGE=""
                        pac_err_output="$(truncate_err "$RUN_BOUNDED_OUTPUT")"
                        errors+=("pacman: $pac_err_output")
                        emit pacman error "detail=$pac_err_output"
                    fi
                    CURRENT_UPDATE_STAGE=""
                    if [[ ${#errors[@]} -eq 0 ]]; then
                        count_pacman=$pac_n_before
                        emit pacman done "count=$pac_n_before" "detail=Updated $pac_n_before packages"
                    fi
                else
                    errors+=("pacman: authentication failed")
                    emit pacman error "detail=Authentication failed"
                fi
            fi
        fi
        ;;
    aur)
        run_aur || true
        ;;
    flatpak)
        run_flatpak || true
        ;;
esac

total=$((count_pacman + count_aur + count_flatpak))

if [[ ${#errors[@]} -gt 0 ]]; then
    err_joined=""
    for e in "${errors[@]}"; do
        [[ -n "$err_joined" ]] && err_joined+=$'\n'
        err_joined+="$e"
    done
    emit complete error "total=$total" "pacman=$count_pacman" "aur=$count_aur" "flatpak=$count_flatpak" "errors=$err_joined"
    printf '%s\n' "$err_joined" > "$ERROR_FILE"
    
    notify_body="Provider: ${PROVIDER}"$'\n'"Updated: ${total} packages"$'\n'
    if [[ "$PROVIDER" == "all" ]]; then
        notify_body+="Pacman: ${count_pacman} | AUR: ${count_aur} | Flatpak: ${count_flatpak}"$'\n'
    fi
    notify_body+=$'\n'"Errors:"$'\n'"${err_joined}"$'\n\n'"Full error saved to: ${ERROR_FILE}"
    notify-send -a "ArchTools" -i software-update-urgent -u critical "⚠ Update Errors" "$notify_body"
else
    emit complete success "total=$total" "pacman=$count_pacman" "aur=$count_aur" "flatpak=$count_flatpak"
    
    notify_body="${total} packages updated"
    if [[ "$PROVIDER" == "all" ]]; then
        notify_body+="\nPacman: ${count_pacman} | AUR: ${count_aur} | Flatpak: ${count_flatpak}"
    fi
    notify-send -a "ArchTools" -i system-software-update "✓ Updates Complete" "$notify_body"
fi

FINISHED=1
( exec 9>&-; sleep 60 && rm -f "$PROGRESS_FILE" ) &
disown

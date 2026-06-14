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
AUR_REVIEW_DIR="$HOME/.cache/quickshell/archtools-aur-review"
AUR_REVIEW_FILE="$AUR_REVIEW_DIR/pkgbuild-diff.txt"
MAX_ERROR_LINES="${ARCHTOOLS_UPDATE_MAX_ERROR_LINES:-40}"
PROGRESS_MAX_LINES="${ARCHTOOLS_UPDATE_PROGRESS_MAX_LINES:-200}"
PROGRESS_MAX_BYTES="${ARCHTOOLS_UPDATE_PROGRESS_MAX_BYTES:-65536}"
AUR_BUILD_JOBS="${ARCHTOOLS_AUR_BUILD_JOBS:-}"
PACMAN_CANCEL_GRACE_SECONDS="${ARCHTOOLS_PACMAN_CANCEL_GRACE_SECONDS:-45}"

[[ "$MAX_ERROR_LINES" =~ ^[0-9]+$ ]] && (( MAX_ERROR_LINES > 0 )) || MAX_ERROR_LINES=40
[[ "$PROGRESS_MAX_LINES" =~ ^[0-9]+$ ]] && (( PROGRESS_MAX_LINES > 0 )) || PROGRESS_MAX_LINES=200
[[ "$PROGRESS_MAX_BYTES" =~ ^[0-9]+$ ]] && (( PROGRESS_MAX_BYTES > 0 )) || PROGRESS_MAX_BYTES=65536
[[ "$PACMAN_CANCEL_GRACE_SECONDS" =~ ^[0-9]+$ ]] && (( PACMAN_CANCEL_GRACE_SECONDS > 0 )) || PACMAN_CANCEL_GRACE_SECONDS=45

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
    rm -f "/tmp/quickshell_sudo_pass_$$" "/tmp/quickshell_sudo_cache_$$" "/tmp/quickshell_sudo_cache_ok_$$" "/tmp/quickshell_askpass_$$" "/tmp/quickshell_auth_cancel_$$"
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
PACMAN_TRANSACTION_SECTION=""
AUR_TRANSACTION_SECTION=""
AUR_EXPECTED_COUNT=0
AUR_BUILD_INDEX=0
declare -A AUR_BUILD_SEEN=()

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

weighted_percent() {
    local base="$1" span="$2" pct="$3" weighted
    pct="$(clamp_percent "$pct")"
    weighted=$(( base + (span * pct / 100) ))
    (( weighted > 99 )) && weighted=99
    printf '%s' "$weighted"
}

emit_weighted_stage_progress() {
    local stage="$1" base="$2" span="$3" pct="$4" detail="$5"
    emit_stage_progress "$stage" "$(weighted_percent "$base" "$span" "$pct")" "$detail"
}

record_fraction_percent() {
    local record="$1" mode="${2:-step}" numerator denominator pct completed
    if [[ "$record" =~ \(([0-9]+)[[:space:]]*/[[:space:]]*([0-9]+)\) ]]; then
        numerator="${BASH_REMATCH[1]}"
        denominator="${BASH_REMATCH[2]}"
        [[ "$denominator" =~ ^[0-9]+$ ]] && (( denominator > 0 )) || return 1

        if [[ "$mode" == "item" ]] && pct="$(last_percent_in_text "$record")"; then
            completed=$(( numerator > 0 ? numerator - 1 : 0 ))
            printf '%s' $(( (completed * 100 + pct) / denominator ))
            return 0
        fi

        if pct="$(last_percent_in_text "$record")"; then
            printf '%s' "$pct"
            return 0
        fi

        printf '%s' $(( numerator * 100 / denominator ))
        return 0
    fi
    return 1
}

transaction_section_var() {
    case "$1" in
        pacman) printf '%s' "PACMAN_TRANSACTION_SECTION" ;;
        aur)    printf '%s' "AUR_TRANSACTION_SECTION" ;;
        *)      return 1 ;;
    esac
}

get_transaction_section() {
    local var
    var="$(transaction_section_var "$1")" || return 1
    printf '%s' "${!var}"
}

set_transaction_section() {
    local var
    var="$(transaction_section_var "$1")" || return 1
    printf -v "$var" '%s' "$2"
}

progress_from_transaction_record() {
    local stage="$1" record="$2" profile="$3"
    local pct section
    local download_base download_span keys_base keys_span integrity_base integrity_span
    local load_base load_span conflicts_base conflicts_span disk_base disk_span
    local pre_base pre_span package_base package_span post_base post_span

    if [[ "$profile" == "aur" ]]; then
        download_base=58; download_span=4
        keys_base=62; keys_span=4
        integrity_base=66; integrity_span=4
        load_base=70; load_span=2
        conflicts_base=72; conflicts_span=2
        disk_base=74; disk_span=2
        pre_base=76; pre_span=3
        package_base=79; package_span=11
        post_base=90; post_span=8
    else
        download_base=12; download_span=24
        keys_base=36; keys_span=4
        integrity_base=40; integrity_span=8
        load_base=48; load_span=4
        conflicts_base=52; conflicts_span=4
        disk_base=56; disk_span=4
        pre_base=60; pre_span=4
        package_base=64; package_span=24
        post_base=88; post_span=10
    fi

    case "$record" in
        *":: Synchronizing package databases"*)
            set_transaction_section "$stage" "sync"
            emit_stage_progress "$stage" 2 "$record"
            return 0
            ;;
        *":: Starting full system upgrade"*)
            set_transaction_section "$stage" "prepare"
            emit_stage_progress "$stage" 8 "$record"
            return 0
            ;;
        *":: Retrieving packages"*|*"loading packages..."*)
            set_transaction_section "$stage" "download"
            emit_stage_progress "$stage" "$download_base" "$record"
            return 0
            ;;
        *"resolving dependencies..."*|*"looking for conflicting packages..."*)
            set_transaction_section "$stage" "prepare"
            emit_stage_progress "$stage" "$(( download_base > 4 ? download_base - 2 : 4 ))" "$record"
            return 0
            ;;
        *":: Running pre-transaction hooks"*)
            set_transaction_section "$stage" "pre_hooks"
            emit_stage_progress "$stage" "$pre_base" "$record"
            return 0
            ;;
        *":: Processing package changes"*)
            set_transaction_section "$stage" "package_changes"
            emit_stage_progress "$stage" "$package_base" "$record"
            return 0
            ;;
        *":: Running post-transaction hooks"*)
            set_transaction_section "$stage" "post_hooks"
            emit_stage_progress "$stage" "$post_base" "$record"
            return 0
            ;;
    esac

    section="$(get_transaction_section "$stage" 2>/dev/null || true)"

    if [[ "$section" == "sync" && "$record" =~ [KMGT]iB && "$record" == *"%"* ]]; then
        pct="$(last_percent_in_text "$record")" || return 1
        emit_weighted_stage_progress "$stage" 2 6 "$pct" "$record"
        return 0
    fi

    if [[ "$record" == *"checking keys in keyring"* ]]; then
        pct="$(record_fraction_percent "$record")" || return 1
        emit_weighted_stage_progress "$stage" "$keys_base" "$keys_span" "$pct" "$record"
        return 0
    fi
    if [[ "$record" == *"checking package integrity"* ]]; then
        pct="$(record_fraction_percent "$record")" || return 1
        emit_weighted_stage_progress "$stage" "$integrity_base" "$integrity_span" "$pct" "$record"
        return 0
    fi
    if [[ "$record" == *"loading package files"* ]]; then
        pct="$(record_fraction_percent "$record")" || return 1
        emit_weighted_stage_progress "$stage" "$load_base" "$load_span" "$pct" "$record"
        return 0
    fi
    if [[ "$record" == *"checking for file conflicts"* ]]; then
        pct="$(record_fraction_percent "$record")" || return 1
        emit_weighted_stage_progress "$stage" "$conflicts_base" "$conflicts_span" "$pct" "$record"
        return 0
    fi
    if [[ "$record" == *"checking available disk space"* ]]; then
        pct="$(record_fraction_percent "$record")" || return 1
        emit_weighted_stage_progress "$stage" "$disk_base" "$disk_span" "$pct" "$record"
        return 0
    fi
    if [[ "$record" =~ [[:space:]](installing|upgrading|downgrading|reinstalling|removing)[[:space:]] ]]; then
        pct="$(record_fraction_percent "$record" "item")" || return 1
        emit_weighted_stage_progress "$stage" "$package_base" "$package_span" "$pct" "$record"
        return 0
    fi
    if [[ "$section" == "pre_hooks" ]]; then
        pct="$(record_fraction_percent "$record")" || return 1
        emit_weighted_stage_progress "$stage" "$pre_base" "$pre_span" "$pct" "$record"
        return 0
    fi
    if [[ "$section" == "post_hooks" ]]; then
        pct="$(record_fraction_percent "$record")" || return 1
        emit_weighted_stage_progress "$stage" "$post_base" "$post_span" "$pct" "$record"
        return 0
    fi
    if [[ "$section" == "download" ]] && pct="$(record_fraction_percent "$record")"; then
        emit_weighted_stage_progress "$stage" "$download_base" "$download_span" "$pct" "$record"
        return 0
    fi
    if [[ "$section" == "download" && "$record" =~ [KMGT]iB && "$record" == *"%"* ]]; then
        pct="$(last_percent_in_text "$record")" || return 1
        emit_weighted_stage_progress "$stage" "$download_base" "$download_span" "$pct" "$record"
        return 0
    fi

    return 1
}

aur_build_subprogress() {
    local record="$1"
    case "$record" in
        *"Making package:"*)                  printf '2' ;;
        *"Checking runtime dependencies"*)    printf '8' ;;
        *"Checking buildtime dependencies"*)  printf '12' ;;
        *"Retrieving sources"*)               printf '18' ;;
        *"Validating source files"*)          printf '24' ;;
        *"Extracting sources"*)               printf '30' ;;
        *"Starting build"*)                   printf '42' ;;
        *"Entering fakeroot environment"*)    printf '56' ;;
        *"Starting package()"*)               printf '64' ;;
        *"Tidying install"*)                  printf '72' ;;
        *"Creating package"*)                 printf '86' ;;
        *"Finished making:"*)                 printf '100' ;;
        *)                                    return 1 ;;
    esac
}

progress_from_aur_build_record() {
    local record="$1" pkg="" subpct expected current_index completed_units pct

    if [[ "$record" =~ Making[[:space:]]+package:[[:space:]]+([^[:space:]]+) ]]; then
        pkg="${BASH_REMATCH[1]}"
        pkg="${pkg//[^A-Za-z0-9@._+-]/}"
        if [[ -n "$pkg" && -z "${AUR_BUILD_SEEN[$pkg]+x}" ]]; then
            AUR_BUILD_SEEN[$pkg]=1
            AUR_BUILD_INDEX=$(( AUR_BUILD_INDEX + 1 ))
        fi
    fi

    subpct="$(aur_build_subprogress "$record")" || return 1

    expected="$AUR_EXPECTED_COUNT"
    [[ "$expected" =~ ^[0-9]+$ ]] && (( expected > 0 )) || expected=1
    current_index="$AUR_BUILD_INDEX"
    [[ "$current_index" =~ ^[0-9]+$ ]] && (( current_index > 0 )) || current_index=1
    (( current_index > expected )) && current_index="$expected"

    completed_units=$(( (current_index - 1) * 100 + subpct ))
    pct=$(( completed_units / expected ))
    emit_weighted_stage_progress "aur" 6 52 "$pct" "$record"
    return 0
}

progress_from_record() {
    local stage="$1" record="$2" pct
    [[ -n "$stage" ]] || return 0

    if [[ "$stage" == "pacman" ]]; then
        if progress_from_transaction_record "pacman" "$record" "pacman"; then
            return 0
        fi
    elif [[ "$stage" == "aur" ]]; then
        if progress_from_aur_build_record "$record"; then
            return 0
        fi
        if progress_from_transaction_record "aur" "$record" "aur"; then
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

    wait "$cmd_pid"
    cmd_status=$?
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
        if [[ -n "${SUDO_CACHE_FILE:-}" && -s "$SUDO_CACHE_FILE" && -n "${SUDO_CACHE_OK_FILE:-}" ]]; then
            : > "$SUDO_CACHE_OK_FILE"
            chmod 600 "$SUDO_CACHE_OK_FILE" 2>/dev/null || true
        fi
        start_sudo_keepalive
    else
        rm -f "${SUDO_CACHE_FILE:-}" "${SUDO_CACHE_OK_FILE:-}"
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
    export SUDO_CACHE_FILE="/tmp/quickshell_sudo_cache_$$"
    export SUDO_CACHE_OK_FILE="/tmp/quickshell_sudo_cache_ok_$$"
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

if [[ -f "$SUDO_CACHE_OK_FILE" && -s "$SUDO_CACHE_FILE" ]]; then
    emit_state running "Using cached sudo authentication"
    printf '%s\n' "$(cat "$SUDO_CACHE_FILE")"
    exit 0
fi

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
        umask 077
        cp "$SUDO_PASS_FILE" "$SUDO_CACHE_FILE" 2>/dev/null || true
        chmod 600 "$SUDO_CACHE_FILE" 2>/dev/null || true
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
    PACMAN_TRANSACTION_SECTION=""
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

aur_review_build_dir() {
    local helper="$1" configured=""

    if [[ "$helper" == "yay" || "$helper" == "paru" ]]; then
        configured="$("$helper" -P -g 2>/dev/null | sed -n 's/^[[:space:]]*"buildDir":[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)"
    fi

    [[ -n "$configured" ]] || configured="${XDG_CACHE_HOME:-$HOME/.cache}/$helper"
    configured="${configured/#\~/$HOME}"
    printf '%s' "$configured"
}

find_cached_aur_dir() {
    local pkg="$1" build_dir="$2" srcinfo
    [[ -n "$pkg" && -d "$build_dir" ]] || return 1

    if [[ -d "$build_dir/$pkg/.git" || -f "$build_dir/$pkg/PKGBUILD" ]]; then
        printf '%s' "$build_dir/$pkg"
        return 0
    fi

    while IFS= read -r srcinfo; do
        if awk -F= -v pkg="$pkg" '
            $1 ~ /^[[:space:]]*pkgname[[:space:]]*$/ {
                value = $2
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
                if (value == pkg) found = 1
            }
            END { exit !found }
        ' "$srcinfo"; then
            dirname "$srcinfo"
            return 0
        fi
    done < <(find "$build_dir" -mindepth 2 -maxdepth 2 -name .SRCINFO -type f 2>/dev/null)

    return 1
}

aur_review_header() {
    local report_file="$1" title="$2"
    {
        printf '\n'
        printf '========================================================================\n'
        printf '%s\n' "$title"
        printf '========================================================================\n\n'
    } >> "$report_file"
}

append_cached_aur_diff() {
    local pkg="$1" dir="$2" report_file="$3"
    local base old_ref old_short remote_ref remote_short
    base="$(basename "$dir")"

    aur_review_header "$report_file" "Package: $pkg | AUR base: $base"
    {
        printf 'Cache: %s\n' "$dir"
        printf 'Mode: git diff from cached AUR checkout to fetched remote\n\n'
    } >> "$report_file"

    if ! git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        printf 'Could not read %s as a git checkout. Full cached PKGBUILD follows if present.\n\n' "$dir" >> "$report_file"
        if [[ -f "$dir/PKGBUILD" ]]; then
            sed 's/\x1b\[[0-9;]*m//g' "$dir/PKGBUILD" >> "$report_file"
            printf '\n' >> "$report_file"
        fi
        return 1
    fi

    old_ref="$(git -C "$dir" rev-parse --verify HEAD 2>/dev/null || true)"
    old_short="$(git -C "$dir" rev-parse --short HEAD 2>/dev/null || printf 'unknown')"

    if ! git -C "$dir" fetch --quiet --prune origin >> "$LOG_FILE" 2>&1; then
        printf 'Failed to fetch latest AUR git state for %s. Update is stopped so the package is not upgraded without review.\n' "$pkg" >> "$report_file"
        return 1
    fi

    remote_ref="$(git -C "$dir" rev-parse --verify refs/remotes/origin/HEAD 2>/dev/null || true)"
    [[ -n "$remote_ref" ]] || remote_ref="$(git -C "$dir" rev-parse --verify refs/remotes/origin/master 2>/dev/null || true)"
    [[ -n "$remote_ref" ]] || remote_ref="$(git -C "$dir" rev-parse --verify FETCH_HEAD 2>/dev/null || true)"

    if [[ -z "$old_ref" || -z "$remote_ref" ]]; then
        printf 'Could not resolve local or remote git revision for %s.\n' "$pkg" >> "$report_file"
        return 1
    fi

    remote_short="$(git -C "$dir" rev-parse --short "$remote_ref" 2>/dev/null || printf 'unknown')"
    {
        printf 'Old cached revision: %s\n' "$old_short"
        printf 'Fetched revision:    %s\n\n' "$remote_short"
    } >> "$report_file"

    if [[ "$old_ref" == "$remote_ref" ]]; then
        printf 'No git diff found between cached checkout and fetched remote for this AUR base.\n' >> "$report_file"
        return 0
    fi

    git -C "$dir" diff --no-color --no-ext-diff --find-renames "$old_ref..$remote_ref" -- . >> "$report_file" 2>> "$LOG_FILE"
    printf '\n' >> "$report_file"
}

append_remote_pkgbuild_snapshot() {
    local helper="$1" pkg="$2" report_file="$3"

    aur_review_header "$report_file" "Package: $pkg | no cached AUR checkout"
    {
        printf 'Mode: full remote PKGBUILD snapshot via %s -Gp\n' "$helper"
        printf 'There is no cached checkout to diff against, so review the whole PKGBUILD below.\n\n'
    } >> "$report_file"

    if TERM=dumb NO_COLOR=1 "$helper" -Gp "$pkg" >> "$report_file" 2>> "$LOG_FILE"; then
        printf '\n' >> "$report_file"
        return 0
    fi

    printf 'Failed to download/print remote PKGBUILD for %s.\n' "$pkg" >> "$report_file"
    return 1
}

prepare_aur_pkgbuild_review() {
    local helper="$1" before="$2" report_file="$3"
    local build_dir pkg cached_dir cache_key failures=0
    local -a packages=()
    local -A seen_review_dirs=()

    mkdir -p "$AUR_REVIEW_DIR"
    : > "$report_file"

    mapfile -t packages < <(printf '%s\n' "$before" | awk 'NF {print $1}' | sort -u)
    build_dir="$(aur_review_build_dir "$helper")"

    {
        printf 'ArchTools AUR PKGBUILD review\n'
        printf 'Generated: %s\n' "$(date -Iseconds)"
        printf 'Helper: %s\n' "$helper"
        printf 'Build/cache dir: %s\n' "$build_dir"
        printf 'Queued package count: %s\n\n' "${#packages[@]}"
        printf 'The AUR update is paused until the notification action is selected.\n'
        printf 'Review every package section before pressing Continua.\n'
    } >> "$report_file"

    for pkg in "${packages[@]}"; do
        abort_if_cancelled
        emit_stage_progress "aur" 4 "Preparing PKGBUILD review for $pkg..."

        cached_dir="$(find_cached_aur_dir "$pkg" "$build_dir" 2>/dev/null || true)"
        if [[ -n "$cached_dir" ]]; then
            cache_key="$cached_dir"
            if [[ -n "${seen_review_dirs[$cache_key]+x}" ]]; then
                aur_review_header "$report_file" "Package: $pkg"
                printf 'Already covered by cached AUR base: %s\n' "$(basename "$cached_dir")" >> "$report_file"
                continue
            fi
            seen_review_dirs[$cache_key]=1
            append_cached_aur_diff "$pkg" "$cached_dir" "$report_file" || failures=$((failures + 1))
        else
            append_remote_pkgbuild_snapshot "$helper" "$pkg" "$report_file" || failures=$((failures + 1))
        fi
    done

    if (( failures > 0 )); then
        {
            printf '\n'
            printf 'Review preparation failed for %s package(s). ArchTools will not continue the AUR update automatically.\n' "$failures"
        } >> "$report_file"
        return 1
    fi

    return 0
}

copy_aur_review_to_clipboard() {
    local report_file="$1"

    if has wl-copy; then
        wl-copy < "$report_file" 2>> "$LOG_FILE"
        return $?
    fi
    if has xclip; then
        xclip -selection clipboard < "$report_file" 2>> "$LOG_FILE"
        return $?
    fi
    if has xsel; then
        xsel --clipboard --input < "$report_file" 2>> "$LOG_FILE"
        return $?
    fi

    return 1
}

wait_for_aur_review_confirmation() {
    local package_count="$1" report_file="$2" clipboard_status="$3" package_summary="$4"
    local body action started_at ended_at elapsed empty_actions=0

    body="${package_count} AUR package(s) queued for update."
    if [[ -n "$package_summary" ]]; then
        body+=$'\n'"Packages: $package_summary"
    fi
    body+=$'\n'"$clipboard_status"
    body+=$'\n'"Report: $report_file"
    body+=$'\n\n'"The update is paused. Press Continua to run yay, or Ferma to cancel."

    emit_stage_progress "aur" 5 "Waiting for PKGBUILD review approval..."

    if ! has notify-send; then
        printf '[aur/review] notify-send not found; cannot request interactive approval.\n' >> "$LOG_FILE"
        return 1
    fi

    while true; do
        abort_if_cancelled
        started_at="$(date +%s)"
        action="$(notify-send -a "ArchTools" -i system-software-update -u critical -t 0 \
            -A "continue=Continua" \
            -A "stop=Ferma" \
            "AUR PKGBUILD review" "$body" 2>> "$LOG_FILE" || true)"
        ended_at="$(date +%s)"
        elapsed=$((ended_at - started_at))

        abort_if_cancelled
        case "$action" in
            continue)
                emit_stage_progress "aur" 6 "PKGBUILD review approved; starting yay..."
                return 0
                ;;
            stop)
                printf '[aur/review] User stopped the update from the PKGBUILD review notification.\n' >> "$LOG_FILE"
                touch "$CANCEL_FILE"
                finish_cancelled
                ;;
        esac

        if (( elapsed < 2 )); then
            empty_actions=$((empty_actions + 1))
        else
            empty_actions=0
        fi

        if (( empty_actions >= 3 )); then
            printf '[aur/review] Notification actions returned empty immediately; stopping for safety.\n' >> "$LOG_FILE"
            return 1
        fi

        sleep 1
    done
}

run_aur() {
    local helper=""
    local err_output="" review_clipboard_status="" review_package_summary=""
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

    emit aur running "detail=Preparing PKGBUILD review for $n_before AUR packages..."
    AUR_EXPECTED_COUNT="$n_before"
    AUR_BUILD_INDEX=0
    AUR_BUILD_SEEN=()
    AUR_TRANSACTION_SECTION=""
    review_package_summary="$(printf '%s\n' "$before" | awk '
        NF {
            count++
            if (count <= 8) {
                if (out != "") out = out ", "
                out = out $1
            }
        }
        END {
            if (count > 8) out = out ", ..."
            print out
        }
    ')"

    if ! prepare_aur_pkgbuild_review "$helper" "$before" "$AUR_REVIEW_FILE"; then
        err_output="Could not prepare AUR PKGBUILD review. See $AUR_REVIEW_FILE"
        errors+=("aur($helper): $err_output")
        emit aur error "detail=$err_output"
        notify-send -a "ArchTools" -i software-update-urgent -u critical "AUR Update Stopped" "$err_output"
        return 1
    fi

    if copy_aur_review_to_clipboard "$AUR_REVIEW_FILE"; then
        review_clipboard_status="PKGBUILD diff copied to clipboard."
    else
        review_clipboard_status="Could not copy to clipboard; open the report file instead."
        printf '[aur/review] Could not copy review report to clipboard.\n' >> "$LOG_FILE"
    fi

    if ! wait_for_aur_review_confirmation "$n_before" "$AUR_REVIEW_FILE" "$review_clipboard_status" "$review_package_summary"; then
        err_output="AUR update stopped before PKGBUILD review approval. See $AUR_REVIEW_FILE"
        errors+=("aur($helper): $err_output")
        emit aur error "detail=$err_output"
        notify-send -a "ArchTools" -i software-update-urgent -u critical "AUR Update Stopped" "$err_output"
        return 1
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
        run_pacman || true
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

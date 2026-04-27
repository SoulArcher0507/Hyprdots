#!/usr/bin/env bash

set -o pipefail

PROGRESS_FILE="$HOME/.cache/quickshell/archtools_update.jsonl"
LOCK_FILE="$HOME/.cache/quickshell/archtools_update.lock"
MAX_ERROR_LINES="${ARCHTOOLS_UPDATE_MAX_ERROR_LINES:-40}"
PROGRESS_MAX_LINES="${ARCHTOOLS_UPDATE_PROGRESS_MAX_LINES:-200}"
PROGRESS_MAX_BYTES="${ARCHTOOLS_UPDATE_PROGRESS_MAX_BYTES:-65536}"
AUR_BUILD_JOBS="${ARCHTOOLS_AUR_BUILD_JOBS:-}"

[[ "$MAX_ERROR_LINES" =~ ^[0-9]+$ ]] && (( MAX_ERROR_LINES > 0 )) || MAX_ERROR_LINES=40
[[ "$PROGRESS_MAX_LINES" =~ ^[0-9]+$ ]] && (( PROGRESS_MAX_LINES > 0 )) || PROGRESS_MAX_LINES=200
[[ "$PROGRESS_MAX_BYTES" =~ ^[0-9]+$ ]] && (( PROGRESS_MAX_BYTES > 0 )) || PROGRESS_MAX_BYTES=65536

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
cleanup() {
    local exit_code=$?
    if [[ "$FINISHED" == "0" ]]; then
        local err_msg="Update process was terminated unexpectedly (exit code $exit_code)."
        emit complete error "total=0" "errors=$err_msg"
        notify-send -a "ArchTools" -i software-update-urgent -u critical "⚠ Update Interrupted" "$err_msg"
        rm -f "$PROGRESS_FILE"
    fi
    rm -f "/tmp/quickshell_sudo_pass_$$" "/tmp/quickshell_askpass_$$" "/tmp/quickshell_auth_cancel_$$"
}
trap cleanup EXIT INT TERM QUIT

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

run_bounded() {
    local tmp="/tmp/archtools_update_output_$$"
    rm -f "$tmp"
    if "$@" 2>&1 | awk -v max_lines="$MAX_ERROR_LINES" -v max_chars=4000 '
        {
            line = $0
            if (length(line) > max_chars) {
                line = substr(line, 1, max_chars) "... [truncated]"
            }
            idx = NR % max_lines
            lines[idx] = line
        }
        END {
            start = NR > max_lines ? NR - max_lines + 1 : 1
            for (i = start; i <= NR; i++) {
                print lines[i % max_lines]
            }
        }
    ' > "$tmp"; then
        rm -f "$tmp"
        return 0
    fi
    RUN_BOUNDED_OUTPUT="$(cat "$tmp" 2>/dev/null || true)"
    rm -f "$tmp"
    return 1
}


emit() {
    local stage="$1" status="$2"; shift 2
    local json="{\"stage\":\"$stage\",\"status\":\"$status\""
    for kv in "$@"; do
        local key="${kv%%=*}" val="${kv#*=}"
        if [[ "$val" =~ ^[0-9]+$ ]]; then
            json+=",\"$key\":$val"
        else
            val="${val//\\/\\\\}"
            val="${val//\"/\\\"}"
            val="${val//$'\n'/\\n}"
            val="${val//$'\r'/}"
            json+=",\"$key\":\"$val\""
        fi
    done
    json+="}"
    echo "$json"
    echo "$json" >> "$PROGRESS_FILE"
    trim_progress_file
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
    echo "{\"stage\":\"complete\",\"status\":\"error\",\"total\":0,\"errors\":\"Another ArchTools update is already running\"}" > "$PROGRESS_FILE"
    notify-send -a "ArchTools" -i software-update-urgent -u critical "⚠ Update Already Running" "Another ArchTools update is already running."
    FINISHED=1
    exit 1
fi

echo "{\"stage\":\"init\",\"status\":\"starting\",\"provider\":\"$PROVIDER\",\"pid\":$$}" > "$PROGRESS_FILE"

count_pacman=0
count_aur=0
count_flatpak=0
errors=()


ensure_sudo() {
    local stage="$1"
    if sudo -n true 2>/dev/null; then
        return 0
    fi
    if [[ -n "$SUDO_ASKPASS" ]] && [[ -f "$SUDO_ASKPASS" ]]; then
        return 0
    fi

    export SUDO_PASS_FILE="/tmp/quickshell_sudo_pass_$$"
    export SUDO_CANCEL_FILE="/tmp/quickshell_auth_cancel_$$"
    export SUDO_ASKPASS="/tmp/quickshell_askpass_$$"
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

action=$(notify-send -a "ArchTools" -u critical -A "open=Open Panel" "Admin Password Required" "Click here to enter your password for updates.")
if [[ "$action" == "open" ]]; then
    qs ipc call arch auth "$SUDO_PASS_FILE" >/dev/null 2>&1 || qs ipc call arch toggle >/dev/null 2>&1 || true

    for _ in $(seq 1 300); do
        if [[ -s "$SUDO_PASS_FILE" ]]; then
            emit_state running "Authentication received, continuing..."
            cat "$SUDO_PASS_FILE"
            rm -f "$SUDO_PASS_FILE" "$SUDO_CANCEL_FILE"
            exit 0
        fi
        if [[ -f "$SUDO_CANCEL_FILE" ]]; then
            emit_state error "Authentication cancelled"
            rm -f "$SUDO_PASS_FILE" "$SUDO_CANCEL_FILE"
            exit 1
        fi
        sleep 0.2
    done
    
    emit_state error "Authentication timed out"
    rm -f "$SUDO_PASS_FILE" "$SUDO_CANCEL_FILE"
    exit 1
else
    emit_state error "Authentication cancelled"
    rm -f "$SUDO_PASS_FILE" "$SUDO_CANCEL_FILE"
    exit 1
fi
EOF
    chmod +x "$SUDO_ASKPASS"
    return 0
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
        return 1
    fi

    if has yay && [[ "$PROVIDER" == "all" ]]; then
        if ! run_bounded yay -Syu --noconfirm; then
            err_output="$(truncate_err "$RUN_BOUNDED_OUTPUT")"
            errors+=("pacman: $err_output")
            emit pacman error "detail=$err_output"
            return 1
        fi
        count_pacman=$n_before
        emit pacman done "count=$n_before" "detail=Updated $n_before packages"
        return 0
    elif has paru && [[ "$PROVIDER" == "all" ]]; then
        if ! run_bounded paru -Syu --noconfirm; then
            err_output="$(truncate_err "$RUN_BOUNDED_OUTPUT")"
            errors+=("pacman: $err_output")
            emit pacman error "detail=$err_output"
            return 1
        fi
        count_pacman=$n_before
        emit pacman done "count=$n_before" "detail=Updated $n_before packages"
        return 0
    else
        if ! run_bounded sudo -A pacman -Syu --noconfirm; then
            err_output="$(truncate_err "$RUN_BOUNDED_OUTPUT")"
            errors+=("pacman: $err_output")
            emit pacman error "detail=$err_output"
            return 1
        fi
    fi

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

    case "$helper" in
        yay)    run_bounded "$helper" -Sua --noconfirm ;;
        paru)   run_bounded "$helper" -Sua --noconfirm ;;
        pikaur) run_bounded "$helper" -Sua --noconfirm ;;
    esac

    if [[ $? -ne 0 ]]; then
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

    if ! run_bounded flatpak update -y --noninteractive; then
        err_output="$(truncate_err "$RUN_BOUNDED_OUTPUT")"
        errors+=("flatpak: $err_output")
        emit flatpak error "detail=$err_output"
        return 1
    fi

    count_flatpak=$n_before
    emit flatpak done "count=$n_before" "detail=Updated $n_before Flatpak apps"
}


case "$PROVIDER" in
    all)
        if has yay || has paru; then
            run_pacman || true
            aur_helper=""
            if has yay; then aur_helper="yay"; elif has paru; then aur_helper="paru"; fi
            if [[ -n "$aur_helper" ]]; then
                emit aur starting "detail=AUR handled by $aur_helper -Syu"
                emit aur done "count=0" "detail=Included in $aur_helper -Syu"
            fi
        else
            run_pacman || true
            run_aur    || true
        fi
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
                    if ! run_bounded sudo -A pacman -Syu --noconfirm; then
                        pac_err_output="$(truncate_err "$RUN_BOUNDED_OUTPUT")"
                        errors+=("pacman: $pac_err_output")
                        emit pacman error "detail=$pac_err_output"
                    fi
                    if [[ ${#errors[@]} -eq 0 ]]; then
                        count_pacman=$pac_n_before
                        emit pacman done "count=$pac_n_before" "detail=Updated $pac_n_before packages"
                    fi
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
    
    notify_body="Provider: ${PROVIDER}\nUpdated: ${total} packages\n"
    if [[ "$PROVIDER" == "all" ]]; then
        notify_body+="Pacman: ${count_pacman} | AUR: ${count_aur} | Flatpak: ${count_flatpak}\n"
    fi
    notify_body+="\nErrors:\n${err_joined}"
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
( sleep 60 && rm -f "$PROGRESS_FILE" ) &
disown

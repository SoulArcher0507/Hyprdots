#!/usr/bin/env bash

set -o pipefail

# Optimization: use all available cores for AUR compilation
export MAKEFLAGS="-j$(nproc)"


PROGRESS_FILE="$HOME/.cache/quickshell/archtools_update.jsonl"

FINISHED=0
cleanup() {
    local exit_code=$?
    if [[ "$FINISHED" == "0" ]]; then
        local err_msg="Update process was terminated unexpectedly (exit code $exit_code)."
        emit complete error "total=0" "errors=$err_msg"
        notify-send -a "ArchTools" -i software-update-urgent -u critical "⚠ Update Interrupted" "$err_msg"
        rm -f "$PROGRESS_FILE"
    fi
    rm -f "/tmp/quickshell_sudo_pass_$$" "/tmp/quickshell_askpass_$$"
}
trap cleanup EXIT INT TERM QUIT

has()   { command -v "$1" >/dev/null 2>&1; }

truncate_err() {
    echo "$1" | tail -n 10
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
}

PROVIDER="all"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --provider) PROVIDER="$2"; shift 2 ;;
        *)          shift ;;
    esac
done

mkdir -p "$(dirname "$PROGRESS_FILE")"
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
    export SUDO_ASKPASS="/tmp/quickshell_askpass_$$"
    export PROGRESS_FILE
    
    cat << 'EOF' > "$SUDO_ASKPASS"
#!/bin/bash
emit_state() {
    local json="{\"stage\":\"auth\",\"status\":\"$1\",\"detail\":\"$2\"}"
    echo "$json" >> "$PROGRESS_FILE"
}

emit_state waiting_auth "Waiting for sudo authentication"

action=$(notify-send -a "ArchTools" -u critical -A "open=Open Terminal" "Admin Password Required" "Click here to open a terminal and enter your password for updates.")
if [[ "$action" == "open" ]]; then
    hyprctl --batch "keyword windowrulev2 float,class:^(archtools_auth)$; keyword windowrulev2 center,class:^(archtools_auth)$; keyword windowrulev2 size 50% 50%,class:^(archtools_auth)$" >/dev/null 2>&1
    
    touch "$SUDO_PASS_FILE"
    chmod 600 "$SUDO_PASS_FILE"
    
    ask_cmd="read -s -p 'Admin Password: ' pass; echo -n \"\$pass\" > '$SUDO_PASS_FILE'"
    
    if command -v kitty >/dev/null 2>&1; then
        kitty --class archtools_auth bash -c "$ask_cmd"
    elif command -v alacritty >/dev/null 2>&1; then
        alacritty --class archtools_auth -e bash -c "$ask_cmd"
    elif command -v foot >/dev/null 2>&1; then
        foot -a archtools_auth bash -c "$ask_cmd"
    else
        xterm -class archtools_auth -e bash -c "$ask_cmd"
    fi
    
    emit_state running "Authentication successful, continuing..."
    cat "$SUDO_PASS_FILE"
    rm -f "$SUDO_PASS_FILE"
else
    emit_state error "Authentication cancelled"
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

    local err_output
    if has yay && [[ "$PROVIDER" == "all" ]]; then
        err_output="$(yay -Syu --noconfirm 2>&1)" || {
            err_output="$(truncate_err "$err_output")"
            errors+=("pacman: $err_output")
            emit pacman error "detail=$err_output"
            return 1
        }
        count_pacman=$n_before
        emit pacman done "count=$n_before" "detail=Updated $n_before packages"
        return 0
    elif has paru && [[ "$PROVIDER" == "all" ]]; then
        err_output="$(paru -Syu --noconfirm 2>&1)" || {
            err_output="$(truncate_err "$err_output")"
            errors+=("pacman: $err_output")
            emit pacman error "detail=$err_output"
            return 1
        }
        count_pacman=$n_before
        emit pacman done "count=$n_before" "detail=Updated $n_before packages"
        return 0
    else
        err_output="$(sudo -A pacman -Syu --noconfirm 2>&1)" || {
            err_output="$(truncate_err "$err_output")"
            errors+=("pacman: $err_output")
            emit pacman error "detail=$err_output"
            return 1
        }
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

    local err_output
    case "$helper" in
        yay)    err_output="$($helper -Sua --noconfirm 2>&1)" ;;
        paru)   err_output="$($helper -Sua --noconfirm 2>&1)" ;;
        pikaur) err_output="$($helper -Sua --noconfirm 2>&1)" ;;
    esac

    if [[ $? -ne 0 ]]; then
        err_output="$(truncate_err "$err_output")"
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

    local err_output
    err_output="$(flatpak update -y --noninteractive 2>&1)" || {
        err_output="$(truncate_err "$err_output")"
        errors+=("flatpak: $err_output")
        emit flatpak error "detail=$err_output"
        return 1
    }

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
                aur_before="$($aur_helper -Qua --quiet 2>/dev/null || true)"
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
                    pac_err_output="$(sudo -A pacman -Syu --noconfirm 2>&1)" || {
                        pac_err_output="$(truncate_err "$pac_err_output")"
                        errors+=("pacman: $pac_err_output")
                        emit pacman error "detail=$pac_err_output"
                    }
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

# The EXIT trap will handle removing the askpass files


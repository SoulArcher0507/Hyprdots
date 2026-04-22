#!/usr/bin/env bash

shopt -s nullglob

apps=()

resolve_icon() {
    local icon="$1"
    [[ -z "$icon" ]] && return

    if [[ "$icon" == /* ]]; then
        [[ -f "$icon" ]] && echo "$icon" && return
        return
    fi

    local dirs=()
    if [[ "$icon" == steam_icon_* ]]; then
        dirs+=(
            "$HOME/.local/share/icons/hicolor/scalable/apps"
            "$HOME/.local/share/icons/hicolor/256x256/apps"
            "$HOME/.local/share/icons/hicolor/128x128/apps"
            "$HOME/.local/share/icons/hicolor/64x64/apps"
            "$HOME/.local/share/icons/hicolor/48x48/apps"
            "$HOME/.local/share/icons/hicolor/32x32/apps"
            "$HOME/.local/share/icons/hicolor/24x24/apps"
            "$HOME/.local/share/icons/hicolor/22x22/apps"
            "$HOME/.local/share/icons/hicolor/16x16/apps"
        )
    fi

    dirs+=(
        "/usr/share/icons/Papirus/64x64/apps"
        "/usr/share/icons/Papirus/48x48/apps"
        "/usr/share/icons/Papirus/32x32/apps"
        "/usr/share/icons/Papirus/24x24/apps"
        "/usr/share/icons/Papirus/22x22/apps"
        "/usr/share/icons/Papirus-Dark/64x64/apps"
        "/usr/share/icons/Papirus-Dark/48x48/apps"
        "/usr/share/icons/kora/apps/scalable"
        "/usr/share/icons/kora-pgrey/apps/scalable"
        "/usr/share/icons/hicolor/scalable/apps"
        "/usr/share/icons/hicolor/256x256/apps"
        "/usr/share/icons/hicolor/128x128/apps"
        "/usr/share/icons/hicolor/64x64/apps"
        "/usr/share/icons/hicolor/48x48/apps"
        "/usr/share/icons/hicolor/32x32/apps"
        "/usr/share/icons/hicolor/24x24/apps"
        "/usr/share/icons/hicolor/22x22/apps"
        "/usr/share/icons/hicolor/16x16/apps"
        "/var/lib/flatpak/exports/share/icons/hicolor/scalable/apps"
        "/var/lib/flatpak/exports/share/icons/hicolor/256x256/apps"
        "/var/lib/flatpak/exports/share/icons/hicolor/128x128/apps"
        "/var/lib/flatpak/exports/share/icons/hicolor/64x64/apps"
        "/var/lib/flatpak/exports/share/icons/hicolor/48x48/apps"
        "/var/lib/flatpak/exports/share/icons/hicolor/32x32/apps"
        "/var/lib/flatpak/exports/share/icons/hicolor/24x24/apps"
        "/var/lib/flatpak/exports/share/icons/hicolor/22x22/apps"
        "/var/lib/flatpak/exports/share/icons/hicolor/16x16/apps"
        "$HOME/.local/share/icons/hicolor/scalable/apps"
        "$HOME/.local/share/icons/hicolor/256x256/apps"
        "$HOME/.local/share/icons/hicolor/128x128/apps"
        "$HOME/.local/share/icons/hicolor/64x64/apps"
        "$HOME/.local/share/icons/hicolor/48x48/apps"
        "$HOME/.local/share/icons/hicolor/32x32/apps"
        "$HOME/.local/share/icons/hicolor/24x24/apps"
        "$HOME/.local/share/icons/hicolor/22x22/apps"
        "$HOME/.local/share/icons/hicolor/16x16/apps"
        "/usr/share/pixmaps"
    )

    for d in "${dirs[@]}"; do
        for ext in svg png xpm; do
            [[ -f "$d/$icon.$ext" ]] && echo "$d/$icon.$ext" && return
        done
    done
}

json_escape() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\r'/}"
    s="${s//$'\t'/ }"
    printf '%s' "$s"
}

for f in /usr/share/applications/*.desktop "$HOME"/.local/share/applications/*.desktop /var/lib/flatpak/exports/share/applications/*.desktop "$HOME"/.local/share/flatpak/exports/share/applications/*.desktop; do
    [[ -f "$f" ]] || continue

    name="" exec_cmd="" icon="" comment="" nodisplay="" terminal="" in_section=""

    while IFS= read -r line; do
        if [[ "$line" == "["* ]]; then
            if [[ "$line" == "[Desktop Entry]" ]]; then
                in_section="desktop"
            else
                in_section=""
            fi
            continue
        fi
        [[ "$in_section" != "desktop" ]] && continue

        case "$line" in
            Name=*) [[ -z "$name" ]] && name="${line#Name=}" ;;
            Exec=*) [[ -z "$exec_cmd" ]] && exec_cmd="${line#Exec=}" ;;
            Icon=*) [[ -z "$icon" ]] && icon="${line#Icon=}" ;;
            Comment=*) [[ -z "$comment" ]] && comment="${line#Comment=}" ;;
            NoDisplay=true) nodisplay="true" ;;
            Terminal=true) terminal="true" ;;
        esac
    done < "$f"

    [[ "$nodisplay" == "true" ]] && continue
    [[ -z "$name" || -z "$exec_cmd" ]] && continue

    exec_clean="${exec_cmd}"
    exec_clean="${exec_clean//%[uUfFdDnNickvm]/}"
    exec_clean="${exec_clean%%[[:space:]]--[[:space:]]*}"
    exec_clean="${exec_clean%"${exec_clean##*[![:space:]]}"}"

    iconpath="$(resolve_icon "$icon")"

    apps+=("{\"name\":\"$(json_escape "$name")\",\"exec\":\"$(json_escape "$exec_clean")\",\"icon\":\"$(json_escape "$iconpath")\",\"comment\":\"$(json_escape "$comment")\"}")
done

printf '['
for i in "${!apps[@]}"; do
    (( i > 0 )) && printf ','
    printf '%s' "${apps[$i]}"
done
printf ']\n'

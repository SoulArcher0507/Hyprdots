#!/usr/bin/env bash

shopt -s nullglob

STEAM_DIR="$HOME/.local/share/Steam"
CACHE_DIR="$STEAM_DIR/appcache/librarycache"

get_library_paths() {
    local vdf="$STEAM_DIR/config/libraryfolders.vdf"
    [[ -f "$vdf" ]] || return
    grep -oP '"path"\s+"\K[^"]+' "$vdf"
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

find_cover() {
    local appid="$1"
    local cachedir="$CACHE_DIR/$appid"
    [[ -d "$cachedir" ]] || return

    local cover=""
    for ext in jpg png jpeg; do
        [[ -f "$cachedir/library_600x900.$ext" ]] && { echo "$cachedir/library_600x900.$ext"; return; }
        [[ -f "$cachedir/library_capsule.$ext" ]] && { echo "$cachedir/library_capsule.$ext"; return; }
    done
    for sub in "$cachedir"/*/; do
        [[ -d "$sub" ]] || continue
        for ext in jpg png jpeg; do
            [[ -f "${sub}library_600x900.$ext" ]] && { echo "${sub}library_600x900.$ext"; return; }
            [[ -f "${sub}library_capsule.$ext" ]] && { echo "${sub}library_capsule.$ext"; return; }
        done
    done
}

find_header() {
    local appid="$1"
    local cachedir="$CACHE_DIR/$appid"
    [[ -d "$cachedir" ]] || return

    for ext in jpg png jpeg; do
        [[ -f "$cachedir/library_header.$ext" ]] && { echo "$cachedir/library_header.$ext"; return; }
    done
    for sub in "$cachedir"/*/; do
        [[ -d "$sub" ]] || continue
        for ext in jpg png jpeg; do
            [[ -f "${sub}library_header.$ext" ]] && { echo "${sub}library_header.$ext"; return; }
            [[ -f "${sub}header.$ext" ]] && { echo "${sub}header.$ext"; return; }
        done
    done
}

games=()

for libpath in $(get_library_paths); do
    steamapps="$libpath/steamapps"
    [[ -d "$steamapps" ]] || continue

    for acf in "$steamapps"/appmanifest_*.acf; do
        [[ -f "$acf" ]] || continue

        appid=""
        name=""
        while IFS= read -r line; do
            case "$line" in
                *'"appid"'*) appid=$(echo "$line" | grep -oP '"\K[0-9]+(?="[^"]*$)') ;;
                *'"name"'*) name=$(echo "$line" | grep -oP '"name"\s+"\K[^"]+') ;;
            esac
        done < "$acf"

        [[ -z "$appid" || -z "$name" ]] && continue

        case "$name" in
            *"Steam Linux Runtime"*|*"Proton"*|*"Steamworks"*) continue ;;
        esac

        cover=$(find_cover "$appid")
        header=$(find_header "$appid")

        [[ -z "$cover" && -z "$header" ]] && continue

        games+=("{\"name\":\"$(json_escape "$name")\",\"appid\":\"$appid\",\"cover\":\"$(json_escape "$cover")\",\"header\":\"$(json_escape "$header")\"}")
    done
done

printf '['
for i in "${!games[@]}"; do
    (( i > 0 )) && printf ','
    printf '%s' "${games[$i]}"
done
printf ']\n'

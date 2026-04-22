#!/usr/bin/env bash

SEEK_FILE="/tmp/quickshell_music_seek_data"
LAST_PLAYER_FILE="/tmp/quickshell_music_last_player"

remember_player() {
    local player="$1"
    [ -n "$player" ] || return 0
    printf '%s\n' "$player" > "$LAST_PLAYER_FILE"
}

read_last_player() {
    if [ -f "$LAST_PLAYER_FILE" ]; then
        head -n 1 "$LAST_PLAYER_FILE"
    fi
}

list_players() {
    playerctl --list-all 2>/dev/null | awk 'NF && !seen[$0]++'
}

pick_active_player() {
    local player=""
    local status=""
    local paused_fallback=""
    local last_player=""
    local last_player_status=""

    last_player=$(read_last_player)

    while IFS= read -r player; do
        [ -n "$player" ] || continue

        status=$(playerctl -p "$player" status 2>/dev/null) || continue

        case "$status" in
            Playing)
                remember_player "$player"
                printf '%s\n' "$player"
                return 0
                ;;
            Paused)
                if [ -z "$paused_fallback" ]; then
                    paused_fallback="$player"
                fi
                ;;
        esac
    done < <(list_players)

    if [ -n "$last_player" ]; then
        last_player_status=$(playerctl -p "$last_player" status 2>/dev/null)
        if [ "$last_player_status" = "Playing" ] || [ "$last_player_status" = "Paused" ]; then
            printf '%s\n' "$last_player"
            return 0
        fi
    fi

    if [ -n "$paused_fallback" ]; then
        remember_player "$paused_fallback"
        printf '%s\n' "$paused_fallback"
        return 0
    fi

    rm -f "$LAST_PLAYER_FILE"
    return 1
}

command=$1
arg=$2
len_sec=$3
player_name=$4

if [ "$command" != "seek" ] && [ -z "$player_name" ]; then
    player_name="$arg"
fi
if [ -z "$player_name" ]; then
    player_name=$(pick_active_player)
fi
if [ -z "$player_name" ]; then exit 0; fi

remember_player "$player_name"

case $command in
    "seek")
        echo "$arg $len_sec $player_name" > "$SEEK_FILE"

        lock_file="/tmp/quickshell_music_seek_lock"

        if [ -f "$lock_file" ]; then
            exit 0
        fi

        touch "$lock_file"

        (
            sleep 0.05
            read -r final_arg final_len final_player < "$SEEK_FILE"

            if [ -n "$final_len" ] && [ "$final_len" != "0" ]; then
                target_sec=$(awk -v len="$final_len" -v perc="$final_arg" 'BEGIN { printf "%.2f", (len * perc) / 100 }')
                playerctl -p "$final_player" position "$target_sec"
            fi

            rm "$lock_file"
        ) &

        exit 0
        ;;

    "next")
        playerctl -p "$player_name" next ;;

    "prev")
        playerctl -p "$player_name" previous ;;

    "play-pause")
        playerctl -p "$player_name" play-pause ;;

esac

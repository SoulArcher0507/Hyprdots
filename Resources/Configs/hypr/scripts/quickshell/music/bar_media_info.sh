#!/usr/bin/env bash

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

ACTIVE_PLAYER=$(pick_active_player)

if [ -n "$ACTIVE_PLAYER" ]; then
    STATUS=$(playerctl -p "$ACTIVE_PLAYER" status 2>/dev/null)
else
    STATUS=""
fi

if [ "$STATUS" = "Playing" ] || [ "$STATUS" = "Paused" ]; then
    title=$(playerctl -p "$ACTIVE_PLAYER" metadata xesam:title 2>/dev/null)
    artist=$(playerctl -p "$ACTIVE_PLAYER" metadata xesam:artist 2>/dev/null)
    title=${title//$'\n'/ }
    artist=${artist//$'\n'/, }
    player_name=${ACTIVE_PLAYER%%.*}
    source=${player_name^}

    jq -n -c \
        --arg title "${title:-Media}" \
        --arg artist "$artist" \
        --arg status "$STATUS" \
        --arg source "$source" \
        --arg playerName "$ACTIVE_PLAYER" \
        '{
            active: true,
            title: $title,
            artist: $artist,
            status: $status,
            source: $source,
            playerName: $playerName
        }'
else
    jq -n -c '{
        active: false,
        title: "",
        artist: "",
        status: "Stopped",
        source: "",
        playerName: ""
    }'
fi

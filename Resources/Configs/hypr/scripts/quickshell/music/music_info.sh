#!/usr/bin/env bash
TMP_DIR="/tmp/eww_covers"
mkdir -p "$TMP_DIR"
PLACEHOLDER="$TMP_DIR/placeholder_blank.png"
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

if [ ! -f "$PLACEHOLDER" ]; then
    convert -size 500x500 xc:"#313244" "$PLACEHOLDER"
fi

ACTIVE_PLAYER=$(pick_active_player)

if [ -n "$ACTIVE_PLAYER" ]; then
    STATUS=$(playerctl -p "$ACTIVE_PLAYER" status 2>/dev/null)
else
    STATUS=""
fi

if [ "$STATUS" = "Playing" ] || [ "$STATUS" = "Paused" ]; then

    rawUrl=$(playerctl -p "$ACTIVE_PLAYER" metadata mpris:artUrl 2>/dev/null)
    title=$(playerctl -p "$ACTIVE_PLAYER" metadata xesam:title 2>/dev/null)
    artist=$(playerctl -p "$ACTIVE_PLAYER" metadata xesam:artist 2>/dev/null)

    idStr="${title:-unknown}-${artist:-unknown}"
    trackHash=$(echo "$idStr" | md5sum | cut -d" " -f1)

    finalArt="$TMP_DIR/${trackHash}_art.jpg"
    blurPath="$TMP_DIR/${trackHash}_blur.png"
    colorPath="$TMP_DIR/${trackHash}_grad.txt"
    textPath="$TMP_DIR/${trackHash}_text.txt"
    lockFile="$TMP_DIR/${trackHash}.lock"

    displayArt="$PLACEHOLDER"
    displayBlur="$PLACEHOLDER"
    displayGrad="linear-gradient(45deg, #cba6f7, #89b4fa, #f38ba8, #cba6f7)"
    displayText="#cdd6f4"

    if [ -f "$finalArt" ] && [ -s "$finalArt" ]; then
        displayArt="$finalArt"
        if [ -f "$blurPath" ]; then displayBlur="$blurPath"; fi
        if [ -f "$colorPath" ]; then displayGrad=$(cat "$colorPath"); fi
        if [ -f "$textPath" ]; then displayText=$(cat "$textPath"); fi
    else
        if [ ! -f "$lockFile" ] && [ -n "$rawUrl" ]; then
            touch "$lockFile"
            (
                if [[ "$rawUrl" == http* ]]; then
                    curl -s -L --max-time 10 -o "$finalArt" "$rawUrl"
                else
                    cleanPath=$(echo "$rawUrl" | sed 's/file:\/\///g')
                    if [ -f "$cleanPath" ]; then
                        cp "$cleanPath" "$finalArt"
                    else
                        cp "$PLACEHOLDER" "$finalArt"
                    fi
                fi

                if [ ! -s "$finalArt" ]; then
                    cp "$PLACEHOLDER" "$finalArt"
                fi

                isPlaceholder=$(convert "$finalArt" -format "%[hex:u.p{0,0}]" info: 2>/dev/null | cut -c1-6)

                if [[ "$isPlaceholder" == "313244" ]] || [[ -z "$isPlaceholder" ]]; then
                    cp "$finalArt" "$blurPath"
                else
                    convert "$finalArt" -blur 0x20 -brightness-contrast -30x-10 "$blurPath" 2>/dev/null

                    colors=$(convert "$finalArt" -resize 50x50 -alpha off +dither -quantize RGB -colors 3 -depth 8 -format "%c" histogram:info: 2>/dev/null | grep -E -o '#[0-9A-Fa-f]{6}' | head -n 3 | tr '\n' ' ')
                    read -r -a color_array <<< "$colors"

                    c1=${color_array[0]:-#cba6f7}
                    c2=${color_array[1]:-$c1}
                    c3=${color_array[2]:-$c1}

                    echo "linear-gradient(45deg, $c1, $c2, $c3, $c1)" > "$colorPath"

                    opp_raw=$(convert xc:"$c1" -alpha off -negate -depth 8 -format "%[hex:u]" info: 2>/dev/null | grep -E -o '[0-9A-Fa-f]{6}' | head -n 1)
                    if [ -n "$opp_raw" ]; then
                        echo "#$opp_raw" > "$textPath"
                    else
                        echo "#cdd6f4" > "$textPath"
                    fi
                fi

                rm "$lockFile"
                (cd "$TMP_DIR" && ls -1t | tail -n +21 | xargs -r rm 2>/dev/null)
            ) &
        fi
    fi

    metadata=$(playerctl -p "$ACTIVE_PLAYER" metadata --format '{{mpris:length}} {{position}}' 2>/dev/null)
    len_micro=$(echo "$metadata" | awk '{print $1}')
    pos_micro=$(echo "$metadata" | awk '{print $2}')

    if [ -z "$len_micro" ] || [ "$len_micro" -eq 0 ]; then len_micro=1000000; fi
    len_sec=$((len_micro / 1000000))
    pos_sec=$((pos_micro / 1000000))
    percent=$((pos_sec * 100 / len_sec))
    pos_str=$(printf "%02d:%02d" $((pos_sec/60)) $((pos_sec%60)))
    len_str=$(printf "%02d:%02d" $((len_sec/60)) $((len_sec%60)))
    time_str="${pos_str} / ${len_str}"

    player_raw="$ACTIVE_PLAYER"
    player_nice="${player_raw^}"

    sink_name=$(pactl get-default-sink 2>/dev/null)
    dev_icon="󰓃"; dev_name="Speaker"
    if [[ "$sink_name" == *"bluez"* ]]; then
        dev_icon="󰂯"
        readable_name=$(pactl list sinks | grep -A 20 "$sink_name" | grep -m 1 "Description:" | cut -d: -f2 | xargs)
        if [ -n "$readable_name" ]; then dev_name="$readable_name"; else dev_name="Bluetooth"; fi
    elif [[ "$sink_name" == *"usb"* ]]; then
        dev_icon="󰓃"; dev_name="USB Audio"
    elif [[ "$sink_name" == *"pci"* ]]; then
        dev_icon="󰓃"; dev_name="System"
    fi

    jq -n -c \
        --arg title "$title" \
        --arg artist "$artist" \
        --arg status "$STATUS" \
        --arg len "$len_sec" \
        --arg pos "$pos_sec" \
        --arg len_str "$len_str" \
        --arg pos_str "$pos_str" \
        --arg time_str "$time_str" \
        --arg percent "$percent" \
        --arg source "$player_nice" \
        --arg pname "$player_raw" \
        --arg blur "$displayBlur" \
        --arg grad "$displayGrad" \
        --arg txtColor "$displayText" \
        --arg devIcon "$dev_icon" \
        --arg devName "$dev_name" \
        --arg finalArt "$displayArt" \
        '{
            title: $title,
            artist: $artist,
            status: $status,
            length: $len,
            position: $pos,
            lengthStr: $len_str,
            positionStr: $pos_str,
            timeStr: $time_str,
            percent: $percent,
            source: $source,
            playerName: $pname,
            blur: $blur,
            grad: $grad,
            textColor: $txtColor,
            deviceIcon: $devIcon,
            deviceName: $devName,
            artUrl: $finalArt
        }'

else
    jq -n -c \
    --arg placeholder "$PLACEHOLDER" \
    '{
        title: "Not Playing",
        artist: "",
        status: "Stopped",
        percent: 0,
        lengthStr: "00:00",
        positionStr: "00:00",
        timeStr: "--:-- / --:--",
        source: "Offline",
        playerName: "",
        blur: $placeholder,
        grad: "linear-gradient(45deg, #cba6f7, #89b4fa, #f38ba8, #cba6f7)",
        textColor: "#cdd6f4",
        deviceIcon: "󰓃",
        deviceName: "Speaker",
        artUrl: $placeholder
    }'
fi

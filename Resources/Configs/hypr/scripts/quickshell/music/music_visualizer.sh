#!/usr/bin/env bash
set -u

bars="${CAVA_BARS:-72}"
fps="${CAVA_FPS:-18}"
range="${CAVA_RANGE:-100}"
tmp_conf="$(mktemp "${TMPDIR:-/tmp}/quickshell-music-cava.XXXXXX.conf")"

cleanup() {
    rm -f "$tmp_conf"
}
trap cleanup EXIT
trap 'cleanup; exit 0' INT TERM

write_config() {
    local method="$1"

    cat > "$tmp_conf" <<EOF
[general]
bars = $bars
framerate = $fps
autosens = 1
sensitivity = 110
lower_cutoff_freq = 50
higher_cutoff_freq = 12000

[input]
method = $method
source = auto

[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = $range
EOF
}

if command -v cava >/dev/null 2>&1; then
    if [ -n "${CAVA_INPUT_METHOD:-}" ]; then
        methods="$CAVA_INPUT_METHOD"
    else
        methods="pipewire pulse"
    fi

    for method in $methods; do
        write_config "$method"
        cava -p "$tmp_conf" 2>/dev/null
        sleep 0.2
    done
fi

zeros=""
for _ in $(seq 1 "$bars"); do
    zeros="${zeros}0;"
done

while true; do
    printf '%s\n' "$zeros"
    sleep 1
done

#!/usr/bin/env bash

set -uo pipefail

status_json() {
    jq -nc \
        --arg state "$1" \
        --arg headline "$2" \
        --arg subline "$3" \
        '{state:$state, headline:$headline, subline:$subline}'
}

format_number() {
    awk -v value="$1" 'BEGIN {
        if (value < 10)
            printf "%.2f", value;
        else if (value < 100)
            printf "%.1f", value;
        else
            printf "%.0f", value;
    }'
}

first_non_empty_line() {
    printf '%s\n' "$1" | awk 'NF { print; exit }'
}

run_official_speedtest() {
    local output ping down_mbps up_mbps

    output=$(speedtest --accept-license --accept-gdpr --format=json 2>&1) || {
        printf '%s\n' "$output"
        return 1
    }

    ping=$(jq -r '.ping.latency // 0' <<< "$output")
    down_mbps=$(jq -r '((.download.bandwidth // 0) * 8) / 1000000' <<< "$output")
    up_mbps=$(jq -r '((.upload.bandwidth // 0) * 8) / 1000000' <<< "$output")

    status_json "done" "Ping $(format_number "$ping") ms" "↓$(format_number "$down_mbps") ↑$(format_number "$up_mbps") Mbps"
}

run_speedtest_cli_json() {
    local cmd="$1"
    local output ping down_mbps up_mbps

    output=$($cmd --json --secure 2>&1) || {
        printf '%s\n' "$output"
        return 1
    }

    ping=$(jq -r '.ping // 0' <<< "$output")
    down_mbps=$(jq -r '(.download // 0) / 1000000' <<< "$output")
    up_mbps=$(jq -r '(.upload // 0) / 1000000' <<< "$output")

    status_json "done" "Ping $(format_number "$ping") ms" "↓$(format_number "$down_mbps") ↑$(format_number "$up_mbps") Mbps"
}

run_benchmark() {
    local result rc err_line

    if command -v speedtest >/dev/null 2>&1 && speedtest --help 2>&1 | grep -q -- '--accept-license'; then
        result=$(run_official_speedtest)
        rc=$?
    elif command -v speedtest >/dev/null 2>&1 && speedtest --help 2>&1 | grep -q -- '--json'; then
        result=$(run_speedtest_cli_json speedtest)
        rc=$?
    elif command -v speedtest-cli >/dev/null 2>&1; then
        result=$(run_speedtest_cli_json speedtest-cli)
        rc=$?
    else
        rc=1
        result="Install speedtest-cli or Ookla speedtest."
    fi

    if (( rc == 0 )); then
        printf '%s\n' "$result"
        return 0
    fi

    err_line=$(first_non_empty_line "$result")
    status_json "error" "Speedtest failed" "${err_line:-Unknown error}"
    return 1
}

case "${1:---run}" in
    --run)
        run_benchmark
        ;;
    --run-detached)
        cache_file="$2"
        mkdir -p "$(dirname "$cache_file")"
        status_json "running" "Speedtest running..." "Measuring download and upload" > "$cache_file"
        result=$(run_benchmark)
        echo "$result" > "$cache_file"
        
        state=$(jq -r '.state' <<< "$result")
        if [[ "$state" == "done" ]]; then
            headline=$(jq -r '.headline' <<< "$result")
            subline=$(jq -r '.subline' <<< "$result")
            notify-send -a "Network" -i network-wireless -u normal "Speedtest Complete" "$headline\n$subline"
        elif [[ "$state" == "error" ]]; then
            subline=$(jq -r '.subline' <<< "$result")
            notify-send -a "Network" -i network-error -u critical "Speedtest Failed" "$subline"
        fi
        ;;
    *)
        status_json "idle" "" ""
        ;;
esac

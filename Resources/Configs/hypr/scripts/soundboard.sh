#!/usr/bin/env bash
set -euo pipefail

# Soundboard routing script
# Routes a processed microphone and a dedicated soundboard output into a virtual microphone.
# Also mirrors the soundboard output to a selected headset or speaker device.

MIC_SOURCE="${MIC_SOURCE:-easyeffects_source}"
HEADSET_SINK="${HEADSET_SINK:-alsa_output.usb-Logitech_PRO_X_Wireless_Gaming_Headset-00.analog-stereo}"

MIX_SINK="Mix"
MONITOR_SINK="Monitor"
VIRTUAL_SOURCE="MicVirtuale"

MIX_DESCRIPTION="Mix_Stream_Mic"
MONITOR_DESCRIPTION="Soundboard_Monitor"
VIRTUAL_DESCRIPTION="Virtual_Mic"

unload_matching() {
  local pattern="$1"
  local ids=()

  mapfile -t ids < <(
    pactl list short modules | grep -F -- "$pattern" | awk '{print $1}' || true
  )

  for id in "${ids[@]}"; do
    pactl unload-module "$id" 2>/dev/null || true
  done
}

cleanup() {
  echo "Removing previous soundboard routing..."

  unload_matching "source_name=$VIRTUAL_SOURCE"
  unload_matching "source=$MIC_SOURCE sink=$MIX_SINK"
  unload_matching "source=$MONITOR_SINK.monitor sink=$MIX_SINK"
  unload_matching "source=$MONITOR_SINK.monitor sink=$HEADSET_SINK"
  unload_matching "sink_name=$MIX_SINK"
  unload_matching "sink_name=$MONITOR_SINK"
}

check_source() {
  local source="$1"

  pactl list short sources | awk '{print $2}' | grep -Fxq "$source"
}

check_sink() {
  local sink="$1"

  pactl list short sinks | awk '{print $2}' | grep -Fxq "$sink"
}

show_usage() {
  cat <<EOF
Usage:
  soundboard.sh          Start soundboard routing
  soundboard.sh --stop   Stop soundboard routing
  soundboard.sh --help   Show this help message

Environment variables:
  MIC_SOURCE     Processed microphone source to route into the virtual mic
                 Default: $MIC_SOURCE

  HEADSET_SINK   Output device used to monitor the soundboard
                 Default: $HEADSET_SINK

Recommended app setup:
  Voice app input      -> $VIRTUAL_DESCRIPTION
  Soundboard output    -> $MONITOR_DESCRIPTION
  System output        -> Real headset/speakers, not $MONITOR_DESCRIPTION
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  show_usage
  exit 0
fi

if [[ "${1:-}" == "--stop" ]]; then
  cleanup
  echo "Soundboard routing stopped."
  exit 0
fi

echo "Starting soundboard routing..."
echo "Microphone source: $MIC_SOURCE"
echo "Monitor output:    $HEADSET_SINK"

if ! check_source "$MIC_SOURCE"; then
  echo "Error: microphone source not found: $MIC_SOURCE"
  echo
  echo "Available sources:"
  pactl list short sources | awk '{print "  " $2}'
  exit 1
fi

if ! check_sink "$HEADSET_SINK"; then
  echo "Error: monitor output sink not found: $HEADSET_SINK"
  echo
  echo "Available sinks:"
  pactl list short sinks | awk '{print "  " $2}'
  exit 1
fi

cleanup

echo "Creating virtual mix sink..."
pactl load-module module-null-sink \
  sink_name="$MIX_SINK" \
  sink_properties=device.description="$MIX_DESCRIPTION" >/dev/null

echo "Creating dedicated soundboard sink..."
pactl load-module module-null-sink \
  sink_name="$MONITOR_SINK" \
  sink_properties=device.description="$MONITOR_DESCRIPTION" >/dev/null

echo "Routing processed microphone to virtual mix..."
pactl load-module module-loopback \
  source="$MIC_SOURCE" \
  sink="$MIX_SINK" \
  latency_msec=40 >/dev/null

echo "Routing soundboard output to virtual mix..."
pactl load-module module-loopback \
  source="$MONITOR_SINK.monitor" \
  sink="$MIX_SINK" \
  latency_msec=40 >/dev/null

echo "Creating virtual microphone source..."
pactl load-module module-remap-source \
  source_name="$VIRTUAL_SOURCE" \
  master="$MIX_SINK.monitor" \
  source_properties=device.description="$VIRTUAL_DESCRIPTION" >/dev/null

echo "Routing soundboard output to monitor device..."
pactl load-module module-loopback \
  source="$MONITOR_SINK.monitor" \
  sink="$HEADSET_SINK" \
  latency_msec=40 >/dev/null

echo
echo "Soundboard routing is active."
echo
echo "Use this setup:"
echo "  Voice app input      -> $VIRTUAL_DESCRIPTION"
echo "  Soundboard output    -> $MONITOR_DESCRIPTION"
echo "  System output        -> Real headset/speakers"
echo
echo "To stop it:"
echo "  $0 --stop"

#!/usr/bin/env bash
set -euo pipefail

# Load only if not loaded
load_module() {
    if ! pactl list short modules | grep -q "$2"; then
        pactl load-module "$1" "$2" "$3"
    else
        echo "Module $2 already loaded"
    fi
}

echo "Audio Soundboard Configuration..."

# Virtual sink
pactl load-module module-null-sink sink_name=Mix sink_properties=device.description="Mix_Stream_Mic"
pactl load-module module-null-sink sink_name=Monitor sink_properties=device.description="Soundboard_Monitor"

# 2. Mic link
pactl load-module module-loopback \
  source=easyeffects_source \
  sink=Mix \
  latency_msec=40

# 3. Virtual Mic 
pactl load-module module-remap-source \
  source_name=MicVirtuale \
  master=Mix.monitor \
  source_properties=device.description="Virtual_Mic"

pactl load-module module-loopback \
  source=Monitor.monitor \
  sink=alsa_output.usb-Logitech_PRO_X_Wireless_Gaming_Headset-00.analog-stereo \
  latency_msec=40

echo "Done."

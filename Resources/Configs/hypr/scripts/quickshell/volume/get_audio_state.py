#!/usr/bin/env python3
import subprocess
import json
import sys

def run_cmd(cmd):
    try:
        return subprocess.check_output(cmd, shell=True, stderr=subprocess.DEVNULL).decode('utf-8')
    except:
        return "[]"

def parse_pactl(output):
    try:
        return json.loads(output)
    except:
        return []

def get_valid_string(*args):
    """Safely return the first valid string that isn't 'null' or empty."""
    for arg in args:
        if arg and str(arg).strip().lower() not in ["null", "none", ""]:
            return str(arg)
    return ""

def get_pipewire_id(props):
    return get_valid_string(
        props.get("object.id"),
        props.get("object.serial"),
        props.get("pipewire.id")
    )

def get_data():
    sinks = parse_pactl(run_cmd("pactl -f json list sinks"))
    sources = parse_pactl(run_cmd("pactl -f json list sources"))
    sink_inputs = parse_pactl(run_cmd("pactl -f json list sink-inputs"))
    
    try:
        info = parse_pactl(run_cmd("pactl -f json info"))
        default_sink = info.get("default_sink_name", "")
        default_source = info.get("default_source_name", "")
    except:
        default_sink = ""
        default_source = ""

    def format_node(n, is_default=False, is_app=False):
        vol = 0
        if "volume" in n and isinstance(n["volume"], dict):
            if "front-left" in n["volume"]:
                vol = int(n["volume"]["front-left"].get("value_percent", "0%").strip("%"))
            elif "mono" in n["volume"]:
                vol = int(n["volume"]["mono"].get("value_percent", "0%").strip("%"))

        props = n.get("properties", {})
        
        if is_app:
            display_name = get_valid_string(props.get("application.name"), props.get("application.process.binary"), "Unknown App")
            sub_desc = get_valid_string(props.get("media.name"), props.get("window.title"), props.get("media.role"), "Audio Stream")
        else:
            display_name = get_valid_string(props.get("device.description"), n.get("name"), "Unknown Device")
            sub_desc = get_valid_string(n.get("name"), "Unknown")

        icon = get_valid_string(props.get("application.icon_name"), props.get("device.icon_name"), "audio-card")
        
        return {
            "id": str(n.get("index")),
            "name": sub_desc,
            "description": display_name,
            "volume": vol,
            "mute": bool(n.get("mute", False)),
            "is_default": bool(is_default),
            "icon": icon,
            "pipewire_id": get_pipewire_id(props),
            "pipewire_name": get_valid_string(props.get("node.name"), n.get("name"))
        }

    apps = []
    for s in sink_inputs:
        props = s.get("properties", {})
        if props.get("application.id") != "org.PulseAudio.pavucontrol":
            apps.append(format_node(s, is_app=True))

    real_sources = []
    for s in sources:
        name = s.get("name", "")
        props = s.get("properties", {})
        device_class = props.get("device.class", "")
        
        if name.endswith(".monitor"):
            continue
        if device_class == "monitor":
            continue
        if device_class == "filter":
            continue
        
        real_sources.append(s)

    out = {
        "outputs": [format_node(s, s.get("name") == default_sink) for s in sinks],
        "inputs": [format_node(s, s.get("name") == default_source) for s in real_sources],
        "apps": apps
    }
    
    print(json.dumps(out))

if __name__ == "__main__":
    get_data()

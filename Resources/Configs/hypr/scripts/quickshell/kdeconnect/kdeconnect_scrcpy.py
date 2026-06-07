#!/usr/bin/env python3

import os
import re
import shutil
import subprocess
import sys


def notify(summary, body, icon="kdeconnect"):
    if not shutil.which("notify-send"):
        return
    subprocess.Popen(
        ["notify-send", "--app-name=KDE Connect", "-i", icon, summary, body],
        start_new_session=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def normalize(value):
    return re.sub(r"[^a-z0-9]+", "", str(value or "").lower())


def adb_devices():
    adb = shutil.which("adb")
    if not adb:
        raise FileNotFoundError("adb was not found")

    result = subprocess.run(
        [adb, "devices", "-l"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    if result.returncode != 0:
        message = result.stderr.strip() or result.stdout.strip() or "adb devices failed"
        raise RuntimeError(message)

    devices = []
    for line in result.stdout.splitlines()[1:]:
        line = line.strip()
        if not line:
            continue

        parts = line.split()
        serial = parts[0]
        state = parts[1] if len(parts) > 1 else "unknown"
        attrs = {}
        for part in parts[2:]:
            if ":" not in part:
                continue
            key, value = part.split(":", 1)
            attrs[key] = value

        devices.append({"serial": serial, "state": state, "attrs": attrs})

    return devices


def device_label(device):
    attrs = device["attrs"]
    details = []
    for key in ("model", "device", "product"):
        value = attrs.get(key, "")
        if value and value not in details:
            details.append(value.replace("_", " "))

    label = " ".join(details).strip()
    return f"{device['serial']}  {label}".strip()


def score_device(device, kde_name):
    target = normalize(kde_name)
    if not target:
        return 0

    haystack = normalize(" ".join(device["attrs"].values()))
    if not haystack:
        return 0

    if target in haystack or haystack in target:
        return 100

    score = 0
    for token in re.findall(r"[a-z0-9]+", kde_name.lower()):
        if len(token) >= 3 and normalize(token) in haystack:
            score += 10
    return score


def choose_with_menu(devices):
    options = "\n".join(device_label(device) for device in devices)
    pickers = [
        (shutil.which("rofi"), ["-dmenu", "-p", "scrcpy"]),
        (shutil.which("wofi"), ["--dmenu", "-p", "scrcpy"]),
    ]

    for picker, args in pickers:
        if not picker:
            continue

        proc = subprocess.run(
            [picker] + args,
            input=options,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
        )
        selection = proc.stdout.strip()
        if not selection:
            return None

        serial = selection.split()[0]
        for device in devices:
            if device["serial"] == serial:
                return device

    return None


def choose_device(devices, kde_name):
    ready = [device for device in devices if device["state"] == "device"]
    unauthorized = [device for device in devices if device["state"] == "unauthorized"]

    if unauthorized:
        notify(
            "scrcpy waiting for permission",
            "Unlock the Android device and accept the USB/Wireless debugging prompt.",
            "dialog-warning",
        )

    if not ready:
        notify(
            "No ADB device found",
            "Enable USB debugging or Wireless debugging, then run adb connect/pair or plug the device over USB.",
            "dialog-warning",
        )
        return None

    serial_override = os.environ.get("HYPRDOTS_SCRCPY_SERIAL") or os.environ.get("SCRCPY_SERIAL")
    if serial_override:
        for device in ready:
            if device["serial"] == serial_override:
                return device

    if len(ready) == 1:
        return ready[0]

    scored = sorted(((score_device(device, kde_name), device) for device in ready), reverse=True, key=lambda item: item[0])
    if scored and scored[0][0] > 0 and (len(scored) == 1 or scored[0][0] > scored[1][0]):
        return scored[0][1]

    picked = choose_with_menu(ready)
    if picked:
        return picked

    notify(
        "Multiple ADB devices",
        "Set HYPRDOTS_SCRCPY_SERIAL or leave connected only the device you want to mirror.",
        "dialog-warning",
    )
    return None


def launch_scrcpy(serial, kde_name):
    scrcpy = shutil.which("scrcpy")
    if not scrcpy:
        raise FileNotFoundError("scrcpy was not found")

    title = "KDE Connect Screen"
    if kde_name:
        title += f" - {kde_name}"

    subprocess.Popen(
        [scrcpy, "--serial", serial, "--window-title", title],
        start_new_session=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def main():
    kde_name = sys.argv[2] if len(sys.argv) > 2 else ""

    try:
        device = choose_device(adb_devices(), kde_name)
        if not device:
            return 1
        launch_scrcpy(device["serial"], kde_name)
        return 0
    except Exception as exc:
        notify("scrcpy failed", str(exc), "dialog-error")
        print(str(exc), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())

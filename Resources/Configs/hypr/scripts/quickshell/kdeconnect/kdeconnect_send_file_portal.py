#!/usr/bin/env python3

import shutil
import subprocess
import sys
import time
import uuid
from pathlib import Path
from urllib.parse import unquote, urlparse

import gi

gi.require_version("Gio", "2.0")
gi.require_version("GLib", "2.0")
from gi.repository import Gio, GLib


def notify(summary, body, icon="kdeconnect"):
    if not shutil.which("notify-send"):
        return
    subprocess.Popen(
        ["notify-send", "--app-name=KDE Connect", "-i", icon, summary, body],
        start_new_session=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def file_path_from_uri(uri):
    parsed = urlparse(uri)
    if parsed.scheme != "file":
        raise ValueError(f"Unsupported portal URI: {uri}")
    return Path(unquote(parsed.path))


def open_files_with_portal(device_name):
    bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
    token = "qs_kdeconnect_" + uuid.uuid4().hex
    options = {
        "handle_token": GLib.Variant("s", token),
        "multiple": GLib.Variant("b", True),
        "modal": GLib.Variant("b", True),
        "filters": GLib.Variant("a(sa(us))", [("All files", [(0, "*")])]),
        "accept_label": GLib.Variant("s", "Send"),
    }

    response = {}
    title = f"Send file to {device_name}" if device_name else "Send file to KDE Connect"
    result = bus.call_sync(
        "org.freedesktop.portal.Desktop",
        "/org/freedesktop/portal/desktop",
        "org.freedesktop.portal.FileChooser",
        "OpenFile",
        GLib.Variant("(ssa{sv})", ("", title, options)),
        GLib.VariantType("(o)"),
        Gio.DBusCallFlags.NONE,
        -1,
        None,
    )
    request_path = result.unpack()[0]
    loop = GLib.MainLoop()

    def on_response(_connection, _sender, _path, _interface, _signal, params, _user_data):
        code, results = params.unpack()
        response["code"] = code
        response["results"] = results
        loop.quit()

    subscription = bus.signal_subscribe(
        "org.freedesktop.portal.Desktop",
        "org.freedesktop.portal.Request",
        "Response",
        request_path,
        None,
        Gio.DBusSignalFlags.NONE,
        on_response,
        None,
    )

    try:
        loop.run()
    finally:
        bus.signal_unsubscribe(subscription)

    if response.get("code") != 0:
        return []

    uris = response.get("results", {}).get("uris", [])
    if isinstance(uris, GLib.Variant):
        uris = uris.unpack()
    return [file_path_from_uri(uri) for uri in uris]


def send_file(device_id, path):
    busctl = shutil.which("busctl")
    if not busctl:
        raise FileNotFoundError("busctl was not found")

    subprocess.run(
        [
            busctl,
            "--user",
            "call",
            "--json=short",
            "org.kde.kdeconnect",
            f"/modules/kdeconnect/devices/{device_id}/share",
            "org.kde.kdeconnect.device.share",
            "shareUrl",
            "s",
            path.resolve().as_uri(),
        ],
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
        text=True,
    )


def main():
    if len(sys.argv) < 2:
        print("Usage: kdeconnect_send_file_portal.py DEVICE_ID [DEVICE_NAME]", file=sys.stderr)
        return 2

    device_id = sys.argv[1]
    device_name = sys.argv[2] if len(sys.argv) > 2 else ""

    try:
        time.sleep(0.18)
        paths = open_files_with_portal(device_name)
        if not paths:
            return 0

        sent = 0
        for path in paths:
            if not path.is_file():
                continue
            send_file(device_id, path)
            sent += 1

        notify("KDE Connect", f"Sent {sent} file(s) to {device_name or 'device'}.")
        return 0
    except Exception as exc:
        notify("KDE Connect send failed", str(exc), "dialog-error")
        print(str(exc), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())

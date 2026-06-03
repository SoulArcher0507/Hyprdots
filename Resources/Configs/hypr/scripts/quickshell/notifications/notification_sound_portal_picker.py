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


ALLOWED_EXTENSIONS = {"wav", "ogg", "oga", "mp3", "flac", "aac", "m4a"}


def notify(summary, body):
    if not shutil.which("notify-send"):
        return
    subprocess.Popen(
        ["notify-send", "--app-name=Notification Sounds", summary, body],
        start_new_session=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def reopen_popup():
    time.sleep(0.2)
    subprocess.Popen(
        ["qs", "ipc", "call", "notificationsound", "toggle"],
        start_new_session=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def file_path_from_uri(uri):
    parsed = urlparse(uri)
    if parsed.scheme != "file":
        raise ValueError(f"Unsupported portal URI: {uri}")
    return Path(unquote(parsed.path))


def open_files_with_portal():
    bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
    token = "qs_notification_sound_" + uuid.uuid4().hex
    filters = GLib.Variant(
        "a(sa(us))",
        [
            (
                "Audio files",
                [(0, "*.wav"), (0, "*.ogg"), (0, "*.oga"), (0, "*.mp3"), (0, "*.flac"), (0, "*.aac"), (0, "*.m4a")],
            ),
            ("All files", [(0, "*")]),
        ],
    )
    options = {
        "handle_token": GLib.Variant("s", token),
        "multiple": GLib.Variant("b", True),
        "modal": GLib.Variant("b", True),
        "filters": filters,
        "accept_label": GLib.Variant("s", "Import"),
    }

    response = {}

    result = bus.call_sync(
        "org.freedesktop.portal.Desktop",
        "/org/freedesktop/portal/desktop",
        "org.freedesktop.portal.FileChooser",
        "OpenFile",
        GLib.Variant("(ssa{sv})", ("", "Choose notification sounds", options)),
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
    return list(uris)


def import_sounds(uris, active_dir, alternatives_dir):
    active_dir.mkdir(parents=True, exist_ok=True)
    alternatives_dir.mkdir(parents=True, exist_ok=True)

    imported = []
    duplicates = []
    rejected = []

    for uri in uris:
        try:
            source = file_path_from_uri(uri)
            ext = source.suffix.lower().lstrip(".")
            if ext not in ALLOWED_EXTENSIONS or not source.is_file():
                rejected.append(source.name or uri)
                continue

            target = alternatives_dir / source.name
            active_target = active_dir / source.name
            if target.exists() or active_target.exists():
                duplicates.append(source.name)
                continue

            shutil.copy2(source, target)
            imported.append(source.name)
        except Exception as exc:
            rejected.append(str(exc))

    return imported, duplicates, rejected


def summarize(imported, duplicates, rejected):
    details = []
    if imported:
        details.append(f"Imported {len(imported)} file(s).")
    if duplicates:
        details.append(f"Skipped {len(duplicates)} duplicate(s).")
    if rejected:
        details.append(f"Rejected {len(rejected)} unsupported/missing file(s).")
    return " ".join(details) if details else "No file was imported."


def main():
    if len(sys.argv) != 3:
        print("Usage: notification_sound_portal_picker.py ACTIVE_DIR ALTERNATIVES_DIR", file=sys.stderr)
        return 2

    active_dir = Path(sys.argv[1])
    alternatives_dir = Path(sys.argv[2])

    try:
        time.sleep(0.18)
        uris = open_files_with_portal()
        if not uris:
            return 0

        imported, duplicates, rejected = import_sounds(uris, active_dir, alternatives_dir)
        notify("Notification sounds", summarize(imported, duplicates, rejected))
        return 0 if imported and not rejected else 1 if rejected else 0
    except Exception as exc:
        notify("Notification sound import failed", str(exc))
        print(str(exc), file=sys.stderr)
        return 1
    finally:
        reopen_popup()


if __name__ == "__main__":
    raise SystemExit(main())

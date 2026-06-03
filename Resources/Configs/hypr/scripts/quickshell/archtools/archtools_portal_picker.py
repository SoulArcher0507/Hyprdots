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


IMAGE_EXTENSIONS = {"png", "jpg", "jpeg", "webp", "gif"}
MEDIA_EXTENSIONS = IMAGE_EXTENSIONS | {"mp4", "webm", "mkv"}


def notify(summary, body, icon="preferences-system"):
    if not shutil.which("notify-send"):
        return
    subprocess.Popen(
        ["notify-send", "--app-name=ArchTools", "-i", icon, summary, body],
        start_new_session=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def force_hide_archtools():
    if not shutil.which("qs"):
        return
    subprocess.run(
        ["qs", "ipc", "call", "archtools", "forceHide"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )


def file_path_from_uri(uri):
    parsed = urlparse(uri)
    if parsed.scheme != "file":
        raise ValueError(f"Unsupported portal URI: {uri}")
    return Path(unquote(parsed.path))


def filters_for_mode(mode):
    if mode == "sddm-background":
        return (
            "Choose SDDM Image/Video",
            [
                ("Images and videos", [(0, "*.png"), (0, "*.jpg"), (0, "*.jpeg"), (0, "*.webp"), (0, "*.gif"), (0, "*.mp4"), (0, "*.webm"), (0, "*.mkv")]),
                ("All files", [(0, "*")]),
            ],
            MEDIA_EXTENSIONS,
        )
    if mode == "avatar":
        return (
            "Choose Profile Avatar",
            [
                ("Images", [(0, "*.png"), (0, "*.jpg"), (0, "*.jpeg"), (0, "*.webp"), (0, "*.gif")]),
                ("All files", [(0, "*")]),
            ],
            IMAGE_EXTENSIONS,
        )
    if mode == "grub-background":
        return (
            "Choose GRUB Background",
            [
                ("Images", [(0, "*.png"), (0, "*.jpg"), (0, "*.jpeg"), (0, "*.webp"), (0, "*.gif")]),
                ("All files", [(0, "*")]),
            ],
            IMAGE_EXTENSIONS,
        )
    raise ValueError(f"Unsupported picker mode: {mode}")


def open_file_with_portal(mode):
    title, filters, _allowed = filters_for_mode(mode)
    bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
    token = "qs_archtools_" + uuid.uuid4().hex
    options = {
        "handle_token": GLib.Variant("s", token),
        "modal": GLib.Variant("b", True),
        "filters": GLib.Variant("a(sa(us))", filters),
        "accept_label": GLib.Variant("s", "Select"),
    }

    response = {}
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
        return None

    uris = response.get("results", {}).get("uris", [])
    if isinstance(uris, GLib.Variant):
        uris = uris.unpack()
    return file_path_from_uri(uris[0]) if uris else None


def run_checked(command):
    subprocess.run(command, check=True)


def repo_roots():
    home = Path.home()
    return [home / ".config" / "Hyprdots", home / ".config" / "hyprdots"]


def first_existing(candidates):
    for candidate in candidates:
        if candidate.is_file():
            return candidate
    return None


def apply_sddm_background(path):
    ext = path.suffix.lower().lstrip(".")
    dest_ext = "mp4" if ext in {"mp4", "webm", "mkv"} else "jpg"
    dest = Path("/usr/share/sddm/themes/silent/backgrounds") / f"default.{dest_ext}"
    run_checked(["pkexec", "cp", str(path), str(dest)])
    notify("SDDM Background", f"Updated successfully to {path.name}", "view-refresh")


def apply_avatar(path, username):
    script = first_existing(root / "Resources" / "Scripts" / "change_sddm_avatar.sh" for root in repo_roots())
    if script is None:
        raise FileNotFoundError("change_sddm_avatar.sh was not found")
    run_checked(["pkexec", "bash", str(script), username, str(path)])
    notify("Profile Avatar", f"Updated successfully to {path.name}", "view-refresh")


def apply_grub_background(path):
    script_dir = Path(__file__).resolve().parent
    bundled = Path.home() / ".config" / "hyprdots" / "Resources" / "Configs" / "hypr" / "scripts" / "quickshell" / "archtools" / "change_hyprgrub_background.sh"
    script = first_existing([script_dir / "change_hyprgrub_background.sh", bundled])
    if script is None:
        raise FileNotFoundError("change_hyprgrub_background.sh was not found")
    run_checked(["pkexec", "bash", str(script), str(path)])
    notify("GRUB Background", f"Updated successfully to {path.name}", "image")


def validate_selection(mode, path):
    _title, _filters, allowed = filters_for_mode(mode)
    if path is None:
        return
    if not path.is_file():
        raise FileNotFoundError(f"Selected file not found: {path}")
    ext = path.suffix.lower().lstrip(".")
    if ext not in allowed:
        raise ValueError(f"Unsupported file type: {ext or '(none)'}")


def main():
    if len(sys.argv) != 3:
        print("Usage: archtools_portal_picker.py MODE USERNAME", file=sys.stderr)
        return 2

    mode = sys.argv[1]
    username = sys.argv[2]

    try:
        force_hide_archtools()
        time.sleep(0.55)
        selected = open_file_with_portal(mode)
        if selected is None:
            return 0

        validate_selection(mode, selected)
        if mode == "sddm-background":
            apply_sddm_background(selected)
        elif mode == "avatar":
            apply_avatar(selected, username)
        elif mode == "grub-background":
            apply_grub_background(selected)
        else:
            raise ValueError(f"Unsupported picker mode: {mode}")
        return 0
    except Exception as exc:
        notify("ArchTools picker failed", str(exc), "dialog-error")
        print(str(exc), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3

import argparse
import fcntl
import json
import os
import random
import signal
import subprocess
import sys
import time
from pathlib import Path


SCRIPT_DIR = Path(__file__).resolve().parent
CACHE_FILE = Path(os.environ.get("ARCHTOOLS_CACHE_FILE", "~/.cache/quickshell/archtools_cache.json")).expanduser()
LOCK_FILE = Path(os.environ.get("ARCHTOOLS_UPDATES_DAEMON_LOCK", "~/.cache/quickshell/archtools_updates_daemon.lock")).expanduser()
LOG_FILE = Path(os.environ.get("ARCHTOOLS_UPDATES_DAEMON_LOG", "~/.cache/quickshell/archtools_updates_daemon.log")).expanduser()

MIN_INTERVAL = 300

running = True


def env_int(name, default):
    try:
        return int(os.environ.get(name, str(default)))
    except ValueError:
        return default


PACKAGE_INTERVAL = env_int("ARCHTOOLS_UPDATES_DAEMON_PACKAGE_INTERVAL_SECONDS", 1800)
DOTFILES_INTERVAL = env_int("ARCHTOOLS_UPDATES_DAEMON_DOTFILES_INTERVAL_SECONDS", 3600)
INITIAL_DELAY = env_int("ARCHTOOLS_UPDATES_DAEMON_INITIAL_DELAY_SECONDS", 30)
JITTER_SECONDS = env_int("ARCHTOOLS_UPDATES_DAEMON_JITTER_SECONDS", 90)


def clamp_interval(value):
    return max(MIN_INTERVAL, int(value))


def now_ms():
    return int(time.time() * 1000)


def log(message):
    try:
        LOG_FILE.parent.mkdir(parents=True, exist_ok=True)
        with LOG_FILE.open("a", encoding="utf-8") as handle:
            handle.write(f"{time.strftime('%Y-%m-%d %H:%M:%S')} {message}\n")
    except OSError:
        pass


def load_cache():
    try:
        return json.loads(CACHE_FILE.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}


def save_cache(data):
    CACHE_FILE.parent.mkdir(parents=True, exist_ok=True)
    tmp = CACHE_FILE.with_suffix(f"{CACHE_FILE.suffix}.tmp")
    tmp.write_text(json.dumps(data, separators=(",", ":")) + "\n", encoding="utf-8")
    tmp.replace(CACHE_FILE)


def merge_cache(fields):
    cache = load_cache()
    cache.update(fields)
    save_cache(cache)


def run_command(command, timeout):
    try:
        return subprocess.run(
            command,
            cwd=str(SCRIPT_DIR),
            check=False,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
    except subprocess.TimeoutExpired as exc:
        log(f"timeout: {' '.join(command)}")
        return subprocess.CompletedProcess(command, 124, exc.stdout or "", exc.stderr or "")
    except OSError as exc:
        log(f"failed: {' '.join(command)}: {exc}")
        return subprocess.CompletedProcess(command, 127, "", str(exc))


def parse_last_json(raw):
    text = (raw or "").strip()
    if not text:
        return None
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        pass

    start = text.rfind("{")
    end = text.rfind("}")
    if start == -1 or end == -1 or end <= start:
        return None
    try:
        return json.loads(text[start:end + 1])
    except json.JSONDecodeError:
        return None


def refresh_packages():
    script = SCRIPT_DIR / "updates-check.sh"
    if not script.exists():
        log(f"missing package update script: {script}")
        return

    result = run_command(["bash", str(script)], timeout=90)
    payload = parse_last_json(result.stdout)
    if not payload:
        log(f"package refresh returned no json: exit={result.returncode}")
        return

    pacman = int(payload.get("pacman") or 0)
    aur = int(payload.get("aur") or 0)
    flatpak = int(payload.get("flatpak") or 0)
    total = pacman + aur + flatpak
    ts_ms = now_ms()

    merge_cache({
        "updPacman": pacman,
        "updAur": aur,
        "updFlatpak": flatpak,
        "updTotal": total,
        "updLastTs": time.strftime("%H:%M"),
        "updLastMs": ts_ms,
        "updatesDaemonLastOkMs": ts_ms,
        "updatesDaemonLastError": "",
    })
    log(f"packages: pacman={pacman} aur={aur} flatpak={flatpak} total={total}")


def refresh_dotfiles():
    script = SCRIPT_DIR / "dotfiles-updates.py"
    if not script.exists():
        log(f"missing dotfiles update script: {script}")
        return

    result = run_command(["python3", str(script), "--fetch"], timeout=120)
    payload = parse_last_json(result.stdout)
    if not payload:
        log(f"dotfiles refresh returned no json: exit={result.returncode}")
        return

    unread = int(payload.get("unread") or 0)
    ts_ms = now_ms()
    merge_cache({
        "unreadDotfiles": unread,
        "dotfilesDaemonLastOkMs": ts_ms,
        "dotfilesDaemonLastError": "",
    })
    log(f"dotfiles: unread={unread}")


def acquire_lock():
    LOCK_FILE.parent.mkdir(parents=True, exist_ok=True)
    handle = LOCK_FILE.open("w", encoding="utf-8")
    try:
        fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        return None

    handle.write(str(os.getpid()))
    handle.flush()
    return handle


def handle_signal(signum, frame):
    global running
    running = False


def sleep_until(deadline):
    while running:
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            return
        time.sleep(min(remaining, 5))


def next_delay(base_interval):
    jitter = random.randint(0, max(0, JITTER_SECONDS))
    return clamp_interval(base_interval) + jitter


def daemon_loop(run_once=False):
    first_delay = 0 if run_once else max(0, INITIAL_DELAY)
    next_packages = time.monotonic() + first_delay
    next_dotfiles = time.monotonic() + first_delay + (0 if run_once else 15)

    while running:
        now = time.monotonic()

        if now >= next_packages:
            refresh_packages()
            next_packages = time.monotonic() + next_delay(PACKAGE_INTERVAL)

        if now >= next_dotfiles:
            refresh_dotfiles()
            next_dotfiles = time.monotonic() + next_delay(DOTFILES_INTERVAL)

        if run_once:
            return

        sleep_until(min(next_packages, next_dotfiles))


def main():
    parser = argparse.ArgumentParser(description="Refresh ArchTools update counters outside Quickshell.")
    parser.add_argument("--once", action="store_true", help="run one package and dotfiles refresh, then exit")
    args = parser.parse_args()

    lock_handle = acquire_lock()
    if lock_handle is None:
        return 0

    signal.signal(signal.SIGTERM, handle_signal)
    signal.signal(signal.SIGINT, handle_signal)

    log("started")
    try:
        daemon_loop(run_once=args.once)
    finally:
        log("stopped")
        lock_handle.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

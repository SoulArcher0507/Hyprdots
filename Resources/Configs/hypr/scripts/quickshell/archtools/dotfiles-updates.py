#!/usr/bin/env python3

import json
import os
import subprocess
import sys
from pathlib import Path


REPO_URL = "https://github.com/SoulArcher0507/Hyprdots.git"
REPO_DIR = Path(os.path.expanduser("~/Documents/Git/Hyprdots"))
CACHE_FILE = Path(os.path.expanduser("~/.cache/quickshell/dotfiles_updates.json"))


def load_cache():
    if CACHE_FILE.exists():
        try:
            return json.loads(CACHE_FILE.read_text())
        except Exception:
            pass
    return {
        "boot_id": "",
        "unread": 0,
        "behind": 0,
        "local_head": "",
        "remote_head": "",
        "last_check_ok": False,
        "repo_dir": str(REPO_DIR),
        "repo_url": REPO_URL,
    }


def save_cache(data):
    CACHE_FILE.parent.mkdir(parents=True, exist_ok=True)
    CACHE_FILE.write_text(json.dumps(data))


def emit(**payload):
    print(json.dumps(payload))


def run_git(args, capture_output=True, check=True):
    cmd = ["git", "-C", str(REPO_DIR), *args]
    return subprocess.run(
        cmd,
        check=check,
        capture_output=capture_output,
        text=True,
    )


def repo_exists():
    return REPO_DIR.exists() and (REPO_DIR / ".git").exists()


def current_boot_id():
    try:
        return Path("/proc/sys/kernel/random/boot_id").read_text().strip()
    except Exception:
        return ""


def notify(summary, body):
    try:
        subprocess.run(
            ["notify-send", "-a", "ArchTools", "-i", "system-software-update", summary, body],
            check=False,
        )
    except FileNotFoundError:
        pass


def current_branch():
    result = run_git(["branch", "--show-current"])
    branch = result.stdout.strip()
    return branch or "main"


def upstream_ref():
    try:
        result = run_git(["rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}"])
        upstream = result.stdout.strip()
        if upstream:
            return upstream
    except subprocess.CalledProcessError:
        pass
    return f"origin/{current_branch()}"


def new_commit_subject(upstream):
    try:
        result = run_git(["log", "--format=%s", "-n", "1", f"HEAD..{upstream}"])
        return result.stdout.strip()
    except subprocess.CalledProcessError:
        return ""


def compute_status(fetch_remote):
    if not repo_exists():
        raise FileNotFoundError(f"Repository not found: {REPO_DIR}")

    if fetch_remote:
        run_git(["fetch", "--quiet", "origin"])

    upstream = upstream_ref()
    branch = current_branch()

    behind = int(run_git(["rev-list", "--count", f"HEAD..{upstream}"]).stdout.strip() or "0")
    local_head = run_git(["rev-parse", "HEAD"]).stdout.strip()
    remote_head = run_git(["rev-parse", upstream]).stdout.strip()
    subject = new_commit_subject(upstream)

    return {
        "branch": branch,
        "upstream": upstream,
        "behind": behind,
        "local_head": local_head,
        "remote_head": remote_head,
        "latest_subject": subject,
    }


def sync_cache_with_status(cache, status, boot_id, last_check_ok=True):
    cache.update({
        "boot_id": boot_id,
        "unread": status["behind"],
        "behind": status["behind"],
        "local_head": status["local_head"],
        "remote_head": status["remote_head"],
        "branch": status["branch"],
        "upstream": status["upstream"],
        "latest_subject": status["latest_subject"],
        "last_check_ok": last_check_ok,
        "repo_dir": str(REPO_DIR),
        "repo_url": REPO_URL,
    })
    return cache


def boot_check():
    cache = load_cache()
    boot_id = current_boot_id()

    if boot_id and cache.get("boot_id") == boot_id:
        emit(
            unread=int(cache.get("unread", 0)),
            behind=int(cache.get("behind", 0)),
            boot_id=boot_id,
            cached=True,
            repo_dir=str(REPO_DIR),
        )
        return 0

    try:
        status = compute_status(fetch_remote=True)
    except Exception as exc:
        cache["boot_id"] = boot_id
        cache["last_check_ok"] = False
        save_cache(cache)
        emit(
            unread=int(cache.get("unread", 0)),
            behind=int(cache.get("behind", 0)),
            boot_id=boot_id,
            error=str(exc),
            repo_dir=str(REPO_DIR),
        )
        return 1

    sync_cache_with_status(cache, status, boot_id)
    save_cache(cache)

    if status["behind"] > 0:
        body = f"{status['behind']} update disponibili in Hyprdots."
        if status["latest_subject"]:
            body += f" Ultimo commit: {status['latest_subject']}"
        notify("Hyprdots updates", body)

    emit(
        unread=status["behind"],
        behind=status["behind"],
        boot_id=boot_id,
        branch=status["branch"],
        latest_subject=status["latest_subject"],
        repo_dir=str(REPO_DIR),
    )
    return 0


def print_status():
    cache = load_cache()
    emit(
        unread=int(cache.get("unread", 0)),
        behind=int(cache.get("behind", 0)),
        boot_id=cache.get("boot_id", ""),
        repo_dir=str(REPO_DIR),
        cached=True,
    )
    return 0


def refresh_after_apply():
    cache = load_cache()
    boot_id = current_boot_id()
    try:
        status = compute_status(fetch_remote=False)
    except Exception as exc:
        cache["boot_id"] = boot_id
        cache["last_check_ok"] = False
        save_cache(cache)
        emit(error=str(exc), unread=int(cache.get("unread", 0)))
        return 1

    sync_cache_with_status(cache, status, boot_id)
    save_cache(cache)
    emit(unread=status["behind"], behind=status["behind"], branch=status["branch"])
    return 0


def apply_updates():
    if not repo_exists():
        print(f"Repository not found: {REPO_DIR}", file=sys.stderr)
        return 1

    update_script = REPO_DIR / "update.sh"
    if not update_script.exists():
        print(f"Missing update script: {update_script}", file=sys.stderr)
        return 1

    print(f"Repo: {REPO_DIR}")
    print(f"Remote: {REPO_URL}")
    print("")
    print("Pulling latest changes...")
    pull = subprocess.run(["git", "-C", str(REPO_DIR), "pull", "--ff-only"])
    if pull.returncode != 0:
        refresh_after_apply()
        return pull.returncode

    print("")
    print("Running update.sh...")
    update = subprocess.run(["bash", str(update_script)], cwd=str(REPO_DIR))
    refresh_after_apply()
    return update.returncode


def clear_status():
    cache = load_cache()
    cache["unread"] = 0
    cache["behind"] = 0
    save_cache(cache)
    emit(unread=0, behind=0)
    return 0


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "--apply":
        return apply_updates()
    if len(sys.argv) > 1 and sys.argv[1] == "--status":
        return print_status()
    if len(sys.argv) > 1 and sys.argv[1] == "--clear":
        return clear_status()
    return boot_check()


if __name__ == "__main__":
    raise SystemExit(main())

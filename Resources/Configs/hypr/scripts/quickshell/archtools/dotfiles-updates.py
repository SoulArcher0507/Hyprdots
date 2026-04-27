#!/usr/bin/env python3

import json
import os
import subprocess
import sys
from pathlib import Path


REPO_URL = "https://github.com/SoulArcher0507/Hyprdots.git"
REPO_DIR = Path(os.path.expanduser("~/.config/hyprdots"))
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


def git_output(args, default="", check=True):
    try:
        result = run_git(args, check=check)
    except subprocess.CalledProcessError:
        return default
    return result.stdout.strip() or default


def git_remote_names():
    result = git_output(["remote"], default="")
    return [line.strip() for line in result.splitlines() if line.strip()]


def ensure_repo_cloned():
    if repo_exists():
        return False

    REPO_DIR.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(["git", "clone", REPO_URL, str(REPO_DIR)], check=True)
    return True


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
    branch = git_output(["branch", "--show-current"], default="")
    return branch or "main"


def preferred_remote():
    remotes = git_remote_names()
    if "upstream" in remotes:
        return "upstream"
    if "origin" in remotes:
        return "origin"

    run_git(["remote", "add", "origin", REPO_URL], capture_output=False)
    return "origin"


def remote_head_branch(remote):
    ref = git_output(["symbolic-ref", "--quiet", "--short", f"refs/remotes/{remote}/HEAD"], default="")
    if ref.startswith(f"{remote}/"):
        return ref.split("/", 1)[1]
    return ""


def remote_branch_exists(remote, branch):
    result = run_git(["show-ref", "--verify", "--quiet", f"refs/remotes/{remote}/{branch}"], capture_output=True, check=False)
    return result.returncode == 0


def upstream_ref():
    remote = preferred_remote()
    try:
        result = run_git(["rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}"])
        upstream = result.stdout.strip()
        if upstream:
            return upstream
    except subprocess.CalledProcessError:
        pass

    branch = current_branch()
    if remote_branch_exists(remote, branch):
        return f"{remote}/{branch}"

    remote_head = remote_head_branch(remote)
    if remote_head:
        return f"{remote}/{remote_head}"

    return f"{remote}/main"


def branch_for_upstream(upstream):
    if "/" not in upstream:
        return upstream
    return upstream.split("/", 1)[1]


def new_commit_subject(upstream):
    try:
        result = run_git(["log", "--format=%s", "-n", "1", f"HEAD..{upstream}"])
        return result.stdout.strip()
    except subprocess.CalledProcessError:
        return ""


def compute_status(fetch_remote):
    if not repo_exists():
        return {
            "branch": "main",
            "upstream": "",
            "behind": 0,
            "local_head": "",
            "remote_head": "",
            "latest_subject": "",
            "repo_missing": True,
        }

    if fetch_remote:
        run_git(["fetch", "--quiet", "--prune", preferred_remote()])

    upstream = upstream_ref()
    branch = branch_for_upstream(upstream) or current_branch()

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
        "repo_missing": False,
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


def boot_check(force_fetch=False):
    cache = load_cache()
    boot_id = current_boot_id()

    if not force_fetch and boot_id and cache.get("boot_id") == boot_id:
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

    if status.get("repo_missing"):
        cache.update({
            "boot_id": boot_id,
            "unread": 0,
            "behind": 0,
            "local_head": "",
            "remote_head": "",
            "branch": "main",
            "upstream": "",
            "latest_subject": "",
            "last_check_ok": True,
            "repo_dir": str(REPO_DIR),
            "repo_url": REPO_URL,
        })
        save_cache(cache)
        emit(
            unread=0,
            behind=0,
            boot_id=boot_id,
            branch="main",
            repo_dir=str(REPO_DIR),
            repo_missing=True,
        )
        return 0

    previous_remote_head = cache.get("remote_head", "")
    previous_behind = int(cache.get("behind", 0) or 0)
    sync_cache_with_status(cache, status, boot_id)
    save_cache(cache)

    should_notify = status["behind"] > 0 and (
        not force_fetch or status["remote_head"] != previous_remote_head or previous_behind == 0
    )
    if should_notify:
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
    if not repo_exists():
        emit(
            unread=0,
            behind=0,
            boot_id="",
            repo_dir=str(REPO_DIR),
            cached=True,
            repo_missing=True,
        )
        return 0

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
    try:
        cloned = ensure_repo_cloned()
    except subprocess.CalledProcessError as exc:
        print(f"Failed to clone repository into {REPO_DIR}: {exc}", file=sys.stderr)
        return exc.returncode or 1

    update_script = REPO_DIR / "update.sh"
    if not update_script.exists():
        print(f"Missing update script: {update_script}", file=sys.stderr)
        return 1

    remote = preferred_remote()

    print(f"Repo: {REPO_DIR}")
    print(f"Remote: {REPO_URL}")
    if cloned:
        print("Repository cloned into ~/.config/hyprdots")
    print("")
    print(f"Fetching latest changes from {remote}...")
    fetch = subprocess.run(["git", "-C", str(REPO_DIR), "fetch", "--prune", remote])
    if fetch.returncode != 0:
        refresh_after_apply()
        return fetch.returncode

    upstream = upstream_ref()
    branch = branch_for_upstream(upstream) or current_branch()

    local_branch = git_output(["branch", "--show-current"], default="")
    if local_branch != branch:
        has_local_branch = run_git(["show-ref", "--verify", "--quiet", f"refs/heads/{branch}"], capture_output=True, check=False).returncode == 0
        if has_local_branch:
            checkout = subprocess.run(["git", "-C", str(REPO_DIR), "checkout", branch])
        else:
            checkout = subprocess.run(["git", "-C", str(REPO_DIR), "checkout", "-b", branch, "--track", upstream])
        if checkout.returncode != 0:
            refresh_after_apply()
            return checkout.returncode

    print(f"Pulling latest version from {upstream}...")
    pull = subprocess.run(["git", "-C", str(REPO_DIR), "pull", "--rebase", "--autostash", remote, branch])
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
    if len(sys.argv) > 1 and sys.argv[1] == "--fetch":
        return boot_check(force_fetch=True)
    return boot_check()


if __name__ == "__main__":
    raise SystemExit(main())

#!/bin/bash

update_cache_key() {
    local value="$1"

    value="${value//[^A-Za-z0-9._-]/_}"
    printf '%s\n' "$value"
}

update_script_id() {
    local script="$1"
    local base

    base="$(basename "$script")"
    base="${base%.sh}"
    printf '%s\n' "$base"
}

update_script_ran() {
    local cache_file="$1"
    local script_id="$2"

    [[ -f "$cache_file" ]] || return 1
    awk -F '\t' -v id="$script_id" '$1 == id { found = 1 } END { exit !found }' "$cache_file"
}

update_fix_cache_owner() {
    local path="$1"

    if [[ -n "${SUDO_UID-}" && -n "${SUDO_GID-}" && -e "$path" ]]; then
        chown "$SUDO_UID:$SUDO_GID" "$path" >/dev/null 2>&1 || true
    fi
}

run_cached_update_scripts() {
    local repo_root="$1"
    local target_home="$2"
    local scripts_dir="$repo_root/Resources/Scripts/update.d"
    local cache_dir cache_file post_update_head
    local script script_id tmp_cache

    [[ -d "$scripts_dir" ]] || return 0

    cache_dir="$target_home/.cache/hyprdots/update-scripts"
    cache_file="$cache_dir/hyprdots.log"
    post_update_head="${HYPRDOTS_POST_UPDATE_HEAD:-}"

    if [[ -z "$post_update_head" ]] && git -C "$repo_root" rev-parse --verify --quiet HEAD >/dev/null 2>&1; then
        post_update_head="$(git -C "$repo_root" rev-parse HEAD)"
    fi

    mkdir -p "$cache_dir"
    touch "$cache_file"
    update_fix_cache_owner "$target_home/.cache"
    update_fix_cache_owner "$target_home/.cache/hyprdots"
    update_fix_cache_owner "$cache_dir"
    update_fix_cache_owner "$cache_file"

    while IFS= read -r -d '' script; do
        script_id="$(update_script_id "$script")"

        if update_script_ran "$cache_file" "$script_id"; then
            echo "Skipping already applied update patch: $(basename "$script")"
            continue
        fi

        echo "Running update patch: $(basename "$script")"
        bash "$script"

        tmp_cache="${cache_file}.$$"
        awk -F '\t' -v id="$script_id" '$1 != id' "$cache_file" > "$tmp_cache"
        printf '%s\t%s\t%s\n' "$script_id" "$post_update_head" "$(date -Iseconds)" >> "$tmp_cache"
        mv "$tmp_cache" "$cache_file"
        update_fix_cache_owner "$cache_file"
    done < <(find "$scripts_dir" -maxdepth 1 -type f -name "*.sh" -print0 | sort -z)
}

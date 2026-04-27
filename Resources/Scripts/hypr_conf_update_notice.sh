#!/usr/bin/env bash

hypr_conf_files_differ() {
    local source_file="$1"
    local target_file="$2"

    if command -v git >/dev/null 2>&1; then
        ! git diff --no-index --quiet -- "$source_file" "$target_file" >/dev/null 2>&1
        return
    fi

    ! cmp -s "$source_file" "$target_file"
}

hypr_conf_notify() {
    local summary="$1"
    local body="$2"

    if command -v notify-send >/dev/null 2>&1; then
        notify-send -a "Hyprdots Update" -i dialog-warning -u normal "$summary" "$body" || true
    fi
}

hypr_conf_valid_commit() {
    local repo_root="$1"
    local ref="$2"

    git -C "$repo_root" rev-parse --verify --quiet "${ref}^{commit}" >/dev/null 2>&1
}

hypr_conf_collect_sources() {
    local base_dir="$1"
    local source_root="$base_dir/hypr/conf"

    [[ -d "$source_root" ]] || return 0

    while IFS= read -r -d '' source_file; do
        local rel_path="${source_file#"$base_dir/"}"
        HYPR_CONF_SOURCES["$rel_path"]="$source_file"
    done < <(find "$source_root" -type f -print0 | sort -z)
}

hypr_conf_collect_changed_rels() {
    local repo_root="$1"
    local theme_dir="$2"
    local old_ref="$3"
    local new_ref="$4"
    local theme_rel="${theme_dir#"$repo_root"/}"
    local changed_path rel_path

    while IFS= read -r -d '' changed_path; do
        case "$changed_path" in
            Resources/Configs/hypr/conf/*)
                rel_path="${changed_path#Resources/Configs/}"
                ;;
            "$theme_rel"/config/hypr/conf/*)
                rel_path="${changed_path#"$theme_rel"/config/}"
                ;;
            *)
                continue
                ;;
        esac

        [[ -n "${HYPR_CONF_SOURCES[$rel_path]-}" ]] || continue
        HYPR_CONF_CHANGED_RELS["$rel_path"]=1
    done < <(
        git -C "$repo_root" diff -z --name-only --diff-filter=ACMRT \
            "$old_ref" "$new_ref" -- \
            "Resources/Configs/hypr/conf" \
            "$theme_rel/config/hypr/conf" 2>/dev/null || true
    )
}

notify_skipped_hypr_conf_changes() {
    local repo_root="$1"
    local theme_dir="$2"
    local config_dir="$3"
    local target_file source_file rel_path source_rel status body
    local has_update_diff=0

    declare -gA HYPR_CONF_SOURCES=()
    declare -gA HYPR_CONF_CHANGED_RELS=()

    hypr_conf_collect_sources "$repo_root/Resources/Configs"
    hypr_conf_collect_sources "$theme_dir/config"

    if [[ ${#HYPR_CONF_SOURCES[@]} -eq 0 ]]; then
        return 0
    fi

    if [[ -n "${HYPRDOTS_PRE_UPDATE_HEAD-}" && -n "${HYPRDOTS_POST_UPDATE_HEAD-}" ]] \
        && hypr_conf_valid_commit "$repo_root" "$HYPRDOTS_PRE_UPDATE_HEAD" \
        && hypr_conf_valid_commit "$repo_root" "$HYPRDOTS_POST_UPDATE_HEAD"; then
        has_update_diff=1
        if [[ "$HYPRDOTS_PRE_UPDATE_HEAD" != "$HYPRDOTS_POST_UPDATE_HEAD" ]]; then
            hypr_conf_collect_changed_rels "$repo_root" "$theme_dir" "$HYPRDOTS_PRE_UPDATE_HEAD" "$HYPRDOTS_POST_UPDATE_HEAD"
        fi
    elif hypr_conf_valid_commit "$repo_root" "ORIG_HEAD" && hypr_conf_valid_commit "$repo_root" "HEAD"; then
        has_update_diff=1
        if [[ "$(git -C "$repo_root" rev-parse ORIG_HEAD)" != "$(git -C "$repo_root" rev-parse HEAD)" ]]; then
            hypr_conf_collect_changed_rels "$repo_root" "$theme_dir" "ORIG_HEAD" "HEAD"
        fi
    fi

    if [[ "$has_update_diff" == "0" ]]; then
        for rel_path in "${!HYPR_CONF_SOURCES[@]}"; do
            HYPR_CONF_CHANGED_RELS["$rel_path"]=1
        done
    fi

    for rel_path in "${!HYPR_CONF_CHANGED_RELS[@]}"; do
        source_file="${HYPR_CONF_SOURCES[$rel_path]-}"
        [[ -n "$source_file" ]] || continue

        target_file="$config_dir/$rel_path"
        status=""

        if [[ ! -e "$target_file" ]]; then
            status="is missing from your current config"
        elif hypr_conf_files_differ "$source_file" "$target_file"; then
            status="differs from the updated theme"
        else
            continue
        fi

        source_rel="${source_file#"$repo_root"/}"
        printf -v body 'File: ~/.config/%s\nStatus: %s\nSource: %s\nReview it to decide whether this skipped change is important.' \
            "$rel_path" "$status" "$source_rel"

        echo "Skipped Hypr config change: ~/.config/$rel_path ($status; source: $source_rel)"
        hypr_conf_notify "Skipped Hypr config change" "$body"
    done
}

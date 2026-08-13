#!/usr/bin/env bash

# DSL Primitive: sync
#
# Syntax:
#   sync TARGET from SOURCE
#   sync TARGET
#
# GitHub sources use the SSH host alias configured by `require github`:
#
#   github:<user>/<repo>
#
# The source is passed to git exactly as given.

sync_git() {
    local target="$1"
    local source="$2"
    local git_err
    local clone_status=0

    git_err=$(GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=echo "$gum" spin \
        --title="CLONING $target <--- $source" \
        -- \
        git clone --single-branch "$source" "$target" 2>&1) || clone_status=$?

    if [[ $clone_status -eq 0 ]] &&
        git -C "$target" rev-parse --is-inside-work-tree >/dev/null 2>&1
    then
        msg "SYNC" "$target <--- $source (cloned)"
        return 0
    fi

    error "Failed to clone $source into $target"

    if [[ -n "$git_err" ]]; then
        error "$git_err"
    fi

    return 0
}

sync_existing() {
    local target="$1"
    local source="$2"
    local current_remote
    local fetch_err
    local fetch_status=0

    if [[ ! -d "$target/.git" ]]; then
        error "Target exists and is not a git repository: $target"
        return 0
    fi

    current_remote="$(git -C "$target" config --get remote.origin.url 2>/dev/null)" || {
        error "Failed to determine Git remote for $target"
        return 0
    }

    if [[ "$current_remote" != "$source" ]]; then
        error "Git remote mismatch for $target (expected $source, found $current_remote)"
        return 0
    fi

    fetch_err=$(GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=echo "$gum" spin \
        --title="FETCHING $target <--- $source" \
        -- \
        git -C "$target" fetch 2>&1) || fetch_status=$?

    if [[ $fetch_status -ne 0 ]]; then
        error "Failed to fetch updates for $target"

        if [[ -n "$fetch_err" ]]; then
            error "$fetch_err"
        fi

        return 0
    fi

    local local_rev
    local remote_rev

    local_rev="$(git -C "$target" rev-parse '@' 2>/dev/null)" || {
        error "Failed to determine local revision for $target"
        return 0
    }

    remote_rev="$(git -C "$target" rev-parse '@{u}' 2>/dev/null)" || {
        msg "SYNC" "$target (no upstream tracking branch)"
        return 0
    }

    if [[ "$local_rev" == "$remote_rev" ]]; then
        msg "SYNC" "$target (up to date)"
        return 0
    fi

    if ! git -C "$target" diff-index --quiet HEAD -- 2>/dev/null; then
        error "Local changes detected in $target. Stash or commit before syncing."
        return 0
    fi

    if "$gum" confirm "Merge latest changes into $target?"; then
        local merge_err
        local merge_status=0

        merge_err=$("$gum" spin \
            --title="MERGING $target" \
            -- \
            git -C "$target" merge 2>&1) || merge_status=$?

        if [[ $merge_status -eq 0 ]]; then
            msg "SYNC" "$target <--- $source (updated)"
        else
            error "Merge failed for $target: $merge_err"
        fi
    else
        msg "SYNC" "$target (skipped merge by user)"
    fi

    return 0
}

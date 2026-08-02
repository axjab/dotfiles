#!/usr/bin/env bash

pull() {
    local source=$(normalize_git_url "$1")
    local to="$2"
    local target="$3"

    validate_pull_syntax "$source" "$to" "$target" || return 1

    if [[ "$to" != "to" ]]; then
        error "pull expected 'to', got '$to'"
        return 1
    fi

    if [[ ! -d "$target" ]]; then
        create_dir "$target"
    fi

    if [[ -n "$(ls -A "$target")" ]]; then
        pull_existing_directory "$source" "$target" || return 1
    else
        pull_clone "$source" "$target" || return 1
    fi

    msg "PULL"      "$source --> $target"
}

validate_pull_syntax() {
    if [[ -z "${1:-}" || -z "${2:-}" || -z "${3:-}" ]]; then
        error "pull syntax: pull URL to TARGET"
        return 1
    fi
}

pull_existing_directory() {
    local source="$1"
    local target="$2"
    local remote

    if [[ ! -d "$target/.git" ]]; then
        error "Directory exists and is not a git repository: $target"
        return 1
    fi

    remote=$(git -C "$target" config --get remote.origin.url)

    if [[ "$remote" != "$source" ]]; then
        error "Git remote mismatch:"
        error "  expected: $source"
        error "  found:    $remote"
        return 1
    fi

    gum spin \
        --title="FETCHING $source" \
        -- \
        git -C "$target" fetch

    msg "FETCHED"   "$source"

    if gum confirm "Merge latest changes into $target?"; then
        gum spin \
            --title="MERGING $source" \
            -- \
            git -C "$target" merge
    fi
}

pull_clone() {
    local source="$1"
    local target="$2"

    gum spin \
       --title="CLONING $source --> $target" \
       -- \
       git clone "$source" "$target"
}

normalize_git_url() {
    local url="$1"

    if [[ "$url" != http://* && "$url" != https://* && "$url" != git@* ]]; then
        echo "https://$url"
    else
        echo "$url"
    fi
}

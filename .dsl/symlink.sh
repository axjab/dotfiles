#!/usr/bin/env bash

# DSL Primitive: symlink
#
# Syntax:
#   symlink SOURCE to TARGET
#
# Behavior:
#   - Resolves relative paths against $ROOT (defaults to current directory if unset).
#   - Preserves absolute paths starting with '/'.
#   - Automatically creates missing parent directories for TARGET.
#   - Idempotent: Skips if TARGET is already linked to SOURCE.
#   - Non-blocking: Errors output via `error` and return status 0 to prevent breaking execution loops under `set -e`.

resolve_path() {
    local path="$1"
    local root="${ROOT:-.}"

    if [[ "$path" == /* ]]; then
        echo "$path"
    else
        echo "$root/$path"
    fi
}

symlink() {
    local raw_source="${1:-}"
    local prep="${2:-}"
    local raw_target="${3:-}"

    # Syntax Validation
    if [[ -z "$raw_source" || -z "$prep" || -z "$raw_target" ]]; then
        error "symlink syntax: symlink SOURCE to TARGET"
        return 0
    fi

    if [[ "$prep" != "to" ]]; then
        error "symlink expected preposition 'to', got '$prep'"
        return 0
    fi

    # Path Resolution (Absolute vs relative to $ROOT)
    local source target
    source=$(resolve_path "$raw_source")
    target=$(resolve_path "$raw_target")

    # Source Existence Check
    if [[ ! -e "$source" && ! -L "$source" ]]; then
        error "Symlink source does not exist: $source"
        return 0
    fi

    # Ensure Target Parent Directory Exists
    local target_dir
    target_dir=$(dirname "$target")
    if [[ ! -d "$target_dir" ]]; then
        if declare -f create_dir >/dev/null 2>&1; then
            if ! create_dir "$target_dir"; then
                error "Failed to create target directory: $target_dir"
                return 0
            fi
        else
            if ! mkdir -p "$target_dir" 2>/dev/null; then
                error "Failed to create target directory: $target_dir"
                return 0
            fi
        fi
    fi

    # Idempotence Check
    if [[ -L "$target" ]]; then
        local current_link
        current_link=$(readlink "$target" 2>/dev/null)
        
        if [[ "$current_link" == "$source" ]] || [[ "$(readlink -f "$target" 2>/dev/null)" == "$(readlink -f "$source" 2>/dev/null)" ]]; then
            msg "SYMLINK" "$target --> $source (up to date)"
            return 0
        fi
    fi

    # Execute Symlink Creation (with non-root permission fallback)
    if ! err=$(ln -snf "$source" "$target" 2>&1); then
        if ! err=$(sudo ln -snf "$source" "$target" 2>&1); then
            error "Failed to symlink $source to $target"
            [[ -n "$err" ]] && error "$err"
            return 0
        fi
    fi

    msg "SYMLINK" "$target --> $source"
    return 0
}

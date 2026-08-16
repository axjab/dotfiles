#!/usr/bin/env bash

# DSL Primitive: copy
#
# Syntax:
#   copy SOURCE to TARGET [MODE]
#
# Behavior:
#   - Resolves relative paths against $ROOT.
#   - Preserves absolute paths starting with '/'.
#   - Automatically creates missing parent directories for TARGET.
#   - Optional permission aliases are applied to the copied file.
#   - Errors output via `error` and return status 0 to prevent breaking
#     execution loops under `set -e`.

resolve_path() {
    local path="$1"
    local root="${ROOT:-.}"

    if [[ "$path" == /* ]]; then
        echo "$path"
    else
        echo "$root/$path"
    fi
}

Copy() {
    local raw_source="${1:-}"
    local prep="${2:-}"
    local raw_target="${3:-}"
    local mode="${4:-}"

    # Syntax Validation
    if [[ -z "$raw_source" || -z "$prep" || -z "$raw_target" ]]; then
        error "copy syntax: copy SOURCE to TARGET [MODE]"
        return 0
    fi

    if [[ "$prep" != "to" ]]; then
        error "copy expected preposition 'to', got '$prep'"
        return 0
    fi

    if [[ -n "$mode" ]]; then
        case "$mode" in
            READ-ONLY)
                ;;
            *)
                error "copy: unknown permission mode: $mode"
                return 0
                ;;
        esac
    fi

    # Path Resolution
    local source destination target
    source=$(resolve_path "$raw_source")
    destination=$(resolve_path "$raw_target")

    # Source Existence Check
    if [[ ! -f "$source" ]]; then
        error "Copy source does not exist or is not a file: $source"
        return 0
    fi

    # Resolve directory destinations to the source basename.
    if [[ -d "$destination" ]]; then
        target="${destination%/}/$(basename "$source")"
    else
        target="$destination"
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
                if ! sudo mkdir -p "$target_dir" 2>/dev/null; then
                    error "Failed to create target directory: $target_dir"
                    return 0
                fi
            fi
        fi
    fi

    # Copy
    local err
    if ! err=$(cp "$source" "$target" 2>&1); then
        if ! err=$(sudo cp "$source" "$target" 2>&1); then
            error "Failed to copy $source to $target"
            [[ -n "$err" ]] && error "$err"
            return 0
        fi
    fi

    # Apply Permission Alias
    case "$mode" in
        READ-ONLY)
            if ! err=$(chmod 0440 "$target" 2>&1); then
                if ! err=$(sudo chmod 0440 "$target" 2>&1); then
                    error "Failed to make $target READ-ONLY"
                    [[ -n "$err" ]] && error "$err"
                    return 0
                fi
            fi
            ;;
    esac

    msg "COPY" "$source --> $target"
    return 0
}

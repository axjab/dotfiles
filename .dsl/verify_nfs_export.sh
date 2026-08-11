#!/usr/bin/env bash

verify_nfs_export() {
    local source="$1"

    if [[ -z "${source:-}" ]]; then
        error "verify_nfs_export requires a source"
        return 1
    fi

    if [[ "$source" != *:* ]]; then
        error "Invalid NFS source: $source (expected host:/path)"
        return 1
    fi

    local host="${source%%:*}"
    local path="${source#*:}"

    if [[ -z "$host" || -z "$path" ]]; then
        error "Invalid NFS source: $source (expected host:/path)"
        return 1
    fi
}

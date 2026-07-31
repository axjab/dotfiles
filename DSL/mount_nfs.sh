#!/usr/bin/env bash

mount_nfs() {
    local source="$1"
    local onto="$2"
    local target="$3"

    mount_nfs_syntax_check "$source" "$onto" "$target" || return 1

    echo "Configuring NFS mount"
    echo "  source: $source"
    echo "  target: $target"

    ensure_package nfs-common

    ensure_directory "$target"

    check_fstab_entry \
        "$source" \
        "$target" \
        "nfs" \
        "defaults,_netdev,x-systemd.automount"

    ensure_mounted "$target"

    echo "NFS mount ready: $source onto $target"
}

mount_nfs_syntax_check() {
	if [[ -z "${1:-}" || -z "${2:-}" || -z "${3:-}" ]]; then
        error "mount_nfs syntax: mount_nfs SOURCE onto TARGET"
        return 1
    fi

    if [[ "$2" != "onto" ]]; then
        error "mount_nfs expected 'onto', got '$2'"
        return 1
    fi

    if [[ "$1" != *:* ]]; then
        error "Invalid NFS source '$1' (expected host:/path)"
        return 1
    fi
}

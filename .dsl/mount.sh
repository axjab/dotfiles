#!/usr/bin/env bash

mount() {
    local type="$1"

    case "$type" in
        dev) shift ; mount_dev "$@" ;;
        dir) shift ; mount_dir "$@" ;;
        nfs) shift ; mount_nfs "$@" ;;
        *)
            error "mount type must be one of: dev, dir, nfs"
            return 1 ;;
    esac
}

#!/usr/bin/env bash

mount_dev() {
    local source="$1"
    local onto="$2"
    local target="$3"

    validate_mount_dev_syntax \
        "$source" "$onto" "$target" || return 1

    create_dir "$target"

    check_fstab_entry \
        "$source" \
        "$target" \
        "auto" \
        "defaults"

    ensure_mounted "$target"

    msg "MOUNT"     "$source --> $target"
}

validate_mount_dev_syntax() {
    if [[ -z "${1:-}" || -z "${2:-}" || -z "${3:-}" ]]; then
        error "mount dev syntax: mount dev SOURCE onto TARGET"
        return 1
    fi

    if [[ "$2" != "onto" ]]; then
        error "mount dev expected 'onto', got '$2'"
        return 1
    fi

    case "$1" in
        /dev/*|UUID=*|LABEL=*|PARTUUID=*|PARTLABEL=*)
            ;;

        *)
            error "Invalid device source '$1'"
            return 1
            ;;
    esac
}

mount_dir() {
    local source="$1"
    local onto="$2"
    local target="$3"

    validate_mount_dir_syntax \
        "$source" "$onto" "$target" || return 1

    if [[ ! -d "$source" ]]; then
        error "Missing directory: $source"
        return 1
    fi

    create_dir "$target"

    check_fstab_entry \
        "$source" \
        "$target" \
        "none" \
        "bind"

    ensure_mounted "$target"

    msg "MOUNT"     "$source --> $target"
}

validate_mount_dir_syntax() {
    if [[ -z "${1:-}" || -z "${2:-}" || -z "${3:-}" ]]; then
        error "mount dir syntax: mount dir SOURCE onto TARGET"
        return 1
    fi

    if [[ "$2" != "onto" ]]; then
        error "mount dir expected 'onto', got '$2'"
        return 1
    fi

    if [[ "$1" != /* ]]; then
        error "Directory source must be an absolute path"
        return 1
    fi
}

mount_nfs() {
    local source="$1"
    local onto="$2"
    local target="$3"

    validate_mount_nfs_syntax \
        "$source" "$onto" "$target" || return 1

    ensure_package nfs-common

    create_dir "$target"

    check_fstab_entry \
        "$source" \
        "$target" \
        "nfs" \
        "defaults,_netdev,x-systemd.automount"

    ensure_mounted "$target"

    msg "MOUNT"     "$source --> $target"
}

validate_mount_nfs_syntax() {
    if [[ -z "${1:-}" || -z "${2:-}" || -z "${3:-}" ]]; then
        error "mount nfs syntax: mount nfs SOURCE onto TARGET"
        return 1
    fi

    if [[ "$2" != "onto" ]]; then
        error "mount nfs expected 'onto', got '$2'"
        return 1
    fi

    if [[ "$1" != *:* ]]; then
        error "Invalid NFS source '$1' (expected host:/path)"
        return 1
    fi
}

#!/usr/bin/env bash

ensure_package() {
    local package="$1"
    local os_id

    if [[ -z "${package:-}" ]]; then
        error "ensure_package requires a package name"
        return 1
    fi

    if dpkg -s "$package" >/dev/null 2>&1; then
        return 0
    fi

    if [[ ! -r /etc/os-release ]]; then
        error "ensure_package: cannot determine operating system"
        return 1
    fi

    # shellcheck disable=SC1091
    . /etc/os-release
    os_id="${ID:-}"
    os_id="${os_id,,}"

    case "$os_id" in
        debian)
            if ! sudo apt install -y "$package"; then
                error "Failed to install package: $package"
                return 1
            fi
            ;;

        pika)
            if ! pikman install "$package"; then
                error "Failed to install package: $package"
                return 1
            fi
            ;;

        *)
            error "ensure_package: unsupported operating system '$os_id'"
            return 1
            ;;
    esac

    msg "INSTALL" "$package"
    return 0
}

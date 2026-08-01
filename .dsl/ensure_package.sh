#!/usr/bin/env bash

ensure_package() {
    local package="$1"

    if [[ -z "${package:-}" ]]; then
        error "ensure_package requires a package name"
        return 1
    fi

    if dpkg -s "$package" &>/dev/null; then
        echo "Package already installed: $package"
        return 0
    fi

    echo "Installing package: $package"

    if ! command -v apt &>/dev/null; then
        error "apt not found; cannot install package: $package"
        return 1
    fi

    if ! sudo apt install -y "$package"; then
        error "Failed to install package: $package"
        return 1
    fi

    echo "Installed package: $package"
}

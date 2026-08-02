#!/usr/bin/env bash

ensure_mounted() {
    local target="$1"

    if [[ -z "${1:-}" ]]; then
        error "ensure_mounted requires a target"
        return 1
    fi

    if findmnt "$target" >/dev/null 2>&1; then
        # echo "Already mounted: $target"
        return 0
    fi

    echo "Mounting: $target"

    sudo systemctl daemon-reload

    if ! sudo mount -v "$target"; then
        error "Failed to mount: $target"
        return 1
    fi

    msg "MOUNT" "$target"
}

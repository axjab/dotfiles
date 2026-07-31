#!/usr/bin/env bash

ensure_directory() {
    local directory="$1"

    if [[ -z "${directory:-}" ]]; then
        error "ensure_directory requires a path"
        return 1
    fi

    if [[ -d "$directory" ]]; then
        echo "Directory exists: $directory"
        return 0
    fi

    if [[ -e "$directory" ]]; then
        error "Path exists but is not a directory: $directory"
        return 1
    fi

    echo "Creating directory: $directory"

    if ! sudo mkdir -p "$directory"; then
        error "Failed to create directory: $directory"
        return 1
    fi

    echo "Created directory: $directory"
}

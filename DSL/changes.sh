#!/usr/bin/env bash

declare -a CHANGES=()

changed() {
    CHANGES+=("$1")
}

summary() {
    echo
    echo "Changes:"
    printf ' - %s\n' "${CHANGES[@]:-none}"
}

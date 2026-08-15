#!/usr/bin/env bash
# =============================================================================
# create — provision local resources
#
#   create key ssh
#   create key gpg
#
# =============================================================================

create() {
    if [[ $# -lt 1 ]]; then
        error "create: expected a subcommand"
        return 1
    fi

    local subcommand="$1"
    shift

    case "$subcommand" in
        key) _create_key "$@" ;;
        *)
            error "create: unknown subcommand '${subcommand}'"
            return 1
            ;;
    esac
}

_create_key() {
    if [[ $# -ne 1 ]]; then
        error "create key: expected a key type (ssh, gpg)"
        return 1
    fi

    case "$1" in
        ssh) _create_key_ssh ;;
        gpg) _create_key_gpg ;;
        *)
            error "create key: unknown key type '$1'"
            return 1
            ;;
    esac
}

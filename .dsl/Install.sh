#!/usr/bin/env bash

# =============================================================================
# install
#
# Syntax:
#
#   install PACKAGE
#   install PACKAGE IF TAG
#   install PACKAGE IF NOT TAG
#
# Conditions are evaluated against the current host's `is` tags.
#
# Package backends:
#
#   Debian  -> sudo apt install -y PACKAGE
#   PikaOS  -> pikman install PACKAGE
#
# Package installation itself is delegated to ensure_package().
# =============================================================================

# -----------------------------------------------------------------------------
# Host state
# -----------------------------------------------------------------------------

_install_host_state_file() {
    local cache_dir="${XDG_CACHE_DIR:-$HOME/.cache}"

    printf '%s/host/state.json' "$cache_dir"
}

_install_host_name() {
    local name

    name="$(hostname)" || {
        error "install: failed to determine current hostname"
        return 1
    }

    name="${name%.}"
    printf '%s' "${name,,}"
}

_install_host_has_tag() {
    local tag="$1"
    local host_name
    local state_file

    tag="${tag,,}"

    host_name="$(_install_host_name)" || return 1
    state_file="$(_install_host_state_file)"

    if [[ ! -r "$state_file" ]]; then
        error "install: host state not found: $state_file"
        return 1
    fi

    if ! command -v jq >/dev/null 2>&1; then
        error "install: jq is required to evaluate host conditions"
        return 1
    fi

    jq \
        -e \
        --arg host "$host_name" \
        --arg tag "$tag" \
        '
        (.[$host].is // []) |
        any(.[]; ascii_downcase == $tag)
        ' \
        "$state_file" >/dev/null
}

# -----------------------------------------------------------------------------
# Conditions
# -----------------------------------------------------------------------------

_install_condition_matches() {
    local condition="${1:-}"
    local tag="${2:-}"

    condition="${condition,,}"
    tag="${tag,,}"

    case "$condition" in
        if)
            _install_host_has_tag "$tag"
            ;;

        if_not)
            if _install_host_has_tag "$tag"; then
                return 1
            fi
            return 0
            ;;

        *)
            error "install: unsupported condition '$condition'"
            return 1
            ;;
    esac
}

# -----------------------------------------------------------------------------
# install PACKAGE [IF TAG | IF NOT TAG]
# -----------------------------------------------------------------------------

Install() {
    local package="${1:-}"

    if [[ -z "$package" ]]; then
        error "install: expected a package name"
        return 1
    fi

    case "$#" in
        1)
            ensure_package "$package"
            return $?
            ;;

        3)
            local keyword="${2,,}"
            local tag="$3"

            if [[ "$keyword" != "if" ]]; then
                error "install syntax: install PACKAGE [IF [NOT] TAG]"
                return 1
            fi

            if [[ -z "$tag" ]]; then
                error "install: condition requires a tag"
                return 1
            fi

            if _install_condition_matches if "$tag"; then
                ensure_package "$package"
            else
                return 0
            fi
            ;;

        4)
            local keyword="${2,,}"
            local modifier="${3,,}"
            local tag="$4"

            if [[ "$keyword" != "if" || "$modifier" != "not" ]]; then
                error "install syntax: install PACKAGE [IF [NOT] TAG]"
                return 1
            fi

            if [[ -z "$tag" ]]; then
                error "install: condition requires a tag"
                return 1
            fi

            if _install_condition_matches if_not "$tag"; then
                ensure_package "$package"
            else
                return 0
            fi
            ;;

        *)
            error "install syntax: install PACKAGE [IF [NOT] TAG]"
            return 1
            ;;
    esac
}

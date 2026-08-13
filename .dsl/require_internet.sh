#!/usr/bin/env bash
# =============================================================================
# require — host prerequisites
#
#   require internet
#   require tailnet
#
# Prerequisites are deliberately explicit keywords rather than a generic
# dependency framework. Each keyword dispatches to its own handler.
# =============================================================================

# -----------------------------------------------------------------------------
# require internet
# -----------------------------------------------------------------------------

_require_internet() {
    local probe

    # DNS + HTTPS is a more meaningful test than pinging an arbitrary host.
    # curl must fail quickly rather than blocking the rebuild indefinitely.
    if command -v curl >/dev/null 2>&1; then
        probe=(curl -fsS --connect-timeout 5 --max-time 10
               https://connectivitycheck.gstatic.com/generate_204)
    elif command -v wget >/dev/null 2>&1; then
        probe=(wget -q --timeout=10 --tries=1 -O /dev/null
               https://connectivitycheck.gstatic.com/generate_204)
    else
        error "require internet: neither curl nor wget is available"
        return 1
    fi

    if "${probe[@]}" >/dev/null 2>&1; then
        _require_set_state offline_mode false || return 1
        printf '\033[92m✓ Internet connected\033[0m\n'
        return 0
    fi

    _require_set_state offline_mode true || return 1

    printf '\033[93m! Internet unavailable\033[0m\n' >&2

    local answer
    if [[ -n "${gum:-}" && -x "$gum" ]]; then
        if ! answer="$("$gum" choose \
            "Continue in offline mode" \
            "Exit" \
            --header "Internet is unavailable")"
        then
            return 0
        fi
    elif command -v gum >/dev/null 2>&1; then
        if ! answer="$(gum choose \
            "Continue in offline mode" \
            "Exit" \
            --header "Internet is unavailable")"
        then
            return 0
        fi
    else
        error "require internet: gum is required for the offline-mode prompt"
        return 1
    fi

    case "$answer" in
        "Continue in offline mode")
            return 0
            ;;
        "Exit")
            return 0
            ;;
        *)
            error "require internet: unexpected prompt result"
            return 1
            ;;
    esac
}

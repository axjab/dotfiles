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
# require tailnet
# -----------------------------------------------------------------------------

_require_tailnet_install() {
    if command -v tailscale >/dev/null 2>&1; then
        return 0
    fi

    printf '\033[93m! Tailscale not installed; installing\033[0m\n'

    # The installer itself must be run as root because it installs system
    # software. The requested installation mechanism remains Tailscale's
    # official installer.
    if ! sudo sh -c 'curl -fsSL https://tailscale.com/install.sh | sh'; then
        error "require tailnet: failed to install Tailscale"
        return 1
    fi

    command -v tailscale >/dev/null 2>&1 || {
        error "require tailnet: Tailscale installation completed but 'tailscale' is not on PATH"
        return 1
    }

    return 0
}

_require_tailnet_status() {
    local status_json backend_state

    if ! status_json="$(sudo tailscale status --json 2>/dev/null)"; then
        return 1
    fi

    if command -v jq >/dev/null 2>&1; then
        backend_state="$(printf '%s\n' "$status_json" |
            jq -r '.BackendState // empty' 2>/dev/null)" || return 1
    else
        # Tailscale itself documents grep as an alternative to jq for the
        # BackendState check. Keep this deliberately narrow.
        backend_state="$(printf '%s\n' "$status_json" |
            grep -o '"BackendState"[[:space:]]*:[[:space:]]*"[^"]*"' |
            sed 's/.*:[[:space:]]*"//; s/"$//')" || true
    fi

    [[ "$backend_state" == "Running" ]]
}

_require_tailnet_login() {
    printf '\033[93m! Tailscale is not authenticated\033[0m\n'

    # `tailscale login` owns the authentication interaction. Do not attempt
    # to reproduce its browser/login flow here.
    if ! sudo tailscale login; then
        error "require tailnet: Tailscale authentication failed"
        return 1
    fi

    return 0
}

_require_tailnet_prompt() {
    local answer

    printf '\033[93m! Tailnet is not connected\033[0m\n' >&2

    if [[ -n "${gum:-}" && -x "$gum" ]]; then
        if ! answer="$("$gum" choose \
            "Continue without Tailnet" \
            "Exit" \
            --header "Tailscale is not connected")"
        then
            return 0
        fi
    elif command -v gum >/dev/null 2>&1; then
        if ! answer="$(gum choose \
            "Continue without Tailnet" \
            "Exit" \
            --header "Tailscale is not connected")"
        then
            return 0
        fi
    else
        error "require tailnet: gum is required for the prompt"
        return 1
    fi

    case "$answer" in
        "Continue without Tailnet")
            return 0
            ;;
        "Exit")
            return 0
            ;;
        *)
            error "require tailnet: unexpected prompt result"
            return 1
            ;;
    esac
}

_require_tailnet() {
    _require_tailnet_install || return 1

    # my change, gives this host ssh hosting capabilities
    sudo tailscale set --ssh

    local status_json backend_state

    # First determine whether the device is authenticated. A non-running
    # backend can mean either "not authenticated" or "not connected", so
    # inspect the status JSON before deciding what action is appropriate.
    if ! status_json="$(sudo tailscale status --json 2>/dev/null)"; then
        status_json=""
    fi

    if [[ -n "$status_json" ]]; then
        if command -v jq >/dev/null 2>&1; then
            backend_state="$(printf '%s\n' "$status_json" |
                jq -r '.BackendState // empty' 2>/dev/null)" || backend_state=""
        else
            backend_state="$(printf '%s\n' "$status_json" |
                grep -o '"BackendState"[[:space:]]*:[[:space:]]*"[^"]*"' |
                sed 's/.*:[[:space:]]*"//; s/"$//')" || true
        fi
    else
        backend_state=""
    fi

    # NeedsLogin is the explicit unauthenticated state. Do not invoke login
    # merely because the daemon happens to be stopped.
    if [[ "$backend_state" == "NeedsLogin" ]]; then
        _require_tailnet_login || return 1
    fi

    # Authentication may have just completed, or the original state may have
    # been Running already. Re-read state after login rather than assuming it.
    if ! _require_tailnet_status; then
        # A device may be authenticated but currently down. `tailscale up`
        # is the normal command for connecting it, but deliberately don't
        # invoke it automatically: changing existing Tailscale configuration
        # is a policy decision, not merely a prerequisite check.
        if ! _require_tailnet_prompt; then
            return 1
        fi

        # Continuing without Tailnet is a successful prerequisite decision.
        _require_set_state tailnet false || return 1
        return 0
    fi

    _require_set_state tailnet true || return 1

    printf '\033[92m✓ Tailnet connected\033[0m\n'
    return 0
}

#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# hooks/tailnet
#
# Ensures Tailscale is installed, authenticated, and running.
# Enables Tailscale SSH on this host.
#
# stdout   key=value protocol
# stderr   progress and diagnostics
# =============================================================================

_gum() {
    if [[ -n "${gum:-}" && -x "$gum" ]]; then
        "$gum" "$@"
    elif command -v gum >/dev/null 2>&1; then
        gum "$@"
    else
        printf 'error: gum is required\n' >&2
        exit 1
    fi
}

_backend_state() {
    local json
    json="$(sudo tailscale status --json 2>/dev/null)" || { printf ''; return 0; }

    if command -v jq >/dev/null 2>&1; then
        printf '%s' "$json" | jq -r '.BackendState // empty' 2>/dev/null || true
    else
        printf '%s' "$json" |
            grep -o '"BackendState"[[:space:]]*:[[:space:]]*"[^"]*"' |
            sed 's/.*:[[:space:]]*"//; s/"$//' || true
    fi
}

# --- Install -----------------------------------------------------------------

if ! command -v tailscale >/dev/null 2>&1; then
    printf '! Tailscale not installed — installing\n' >&2
    sudo sh -c 'curl -fsSL https://tailscale.com/install.sh | sh' >&2 || {
        printf 'message=Tailscale installation failed\n'
        exit 1
    }
    command -v tailscale >/dev/null 2>&1 || {
        printf 'message=tailscale not on PATH after installation\n'
        exit 1
    }
fi

# --- SSH capability ----------------------------------------------------------

sudo tailscale set --ssh >&2 || true

# --- Authenticate ------------------------------------------------------------

backend_state="$(_backend_state)"

if [[ "$backend_state" == "NeedsLogin" ]]; then
    printf '! Tailscale not authenticated — logging in\n' >&2
    sudo tailscale login >&2 || {
        printf 'message=Tailscale authentication failed\n'
        exit 1
    }
    backend_state="$(_backend_state)"
fi

# --- Verify running ----------------------------------------------------------

if [[ "$backend_state" != "Running" ]]; then
    answer="$(_gum choose \
        "Continue without Tailnet" \
        "Exit" \
        --header "Tailscale is not connected")" || true

    case "$answer" in
        "Continue without Tailnet")
            printf 'message=continuing without Tailnet\n'
            exit 0
            ;;
        "Exit")
            exit 1
            ;;
        *)
            printf 'message=Tailnet not connected\ndetail=BackendState: %s\n' "$backend_state"
            exit 1
            ;;
    esac
fi

printf 'status=ok\ndata=example\n'
exit 0

#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
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

# --- Install -----------------------------------------------------------------

if ! command -v natsi >/dev/null 2>&1; then
    echo 'WARNING: No nats foo' >&2
    # install nats here
fi

echo 'status=ok'
# echo 'message=connected'
exit 0

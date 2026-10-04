#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# hooks/github
#
# Ensures gh is installed, SSH is configured for github.com, and gh is
# authenticated via SSH.
#
# stdout   key=value protocol
# stderr   progress and diagnostics
# =============================================================================

# --- Install -----------------------------------------------------------------

if ! command -v gh >/dev/null 2>&1; then
    printf 'message=gh is not installed\n'
    printf 'detail=Install from https://cli.github.com then re-run\n'
    exit 1
fi

# --- SSH config --------------------------------------------------------------

config="$HOME/.ssh/config"

if [[ ! -f "$config" ]]; then
    printf 'message=SSH not configured\ndetail=Run: create key ssh\n'
    exit 1
fi

if grep -Fqx "Host github" "$config"; then
    if ! grep -Fqx "    Hostname github.com" "$config" ||
       ! grep -Fqx "    User git" "$config"
    then
        printf 'message=existing Host github block is invalid\ndetail=%s\n' "$config"
        exit 1
    fi
else
    cat >> "$config" <<'EOF'

Host github
    Hostname github.com
    User git
EOF
fi

# --- Authenticate ------------------------------------------------------------

if ! gh auth status --hostname github.com >/dev/null 2>&1; then
    printf '! GitHub authentication required\n' >&2
    gh auth login --hostname github.com --git-protocol ssh >&2 || {
        printf 'message=GitHub authentication failed\n'
        exit 1
    }
    if ! gh auth status --hostname github.com >/dev/null 2>&1; then
        printf 'message=GitHub authentication could not be verified\n'
        exit 1
    fi
fi

printf 'status=ok\n'
exit 0

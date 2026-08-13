#!/usr/bin/env bash
# =============================================================================
# require github — GitHub CLI and SSH authentication
#
#   require github
#
# Ensures:
#   - gh is installed
#   - github exists as an SSH host alias
#   - gh is authenticated to github.com using SSH
# =============================================================================

_require_github_install() {
    if command -v gh >/dev/null 2>&1; then
        return 0
    fi

    ensure_package gh || {
        error "require github: failed to install gh"
        return 1
    }

    if ! command -v gh >/dev/null 2>&1; then
        error "require github: gh installation completed but 'gh' is not on PATH"
        return 1
    fi

    return 0
}

_require_github_ssh_config() {
    local ssh_dir="$HOME/.ssh"
    local config="$ssh_dir/config"

    if [[ ! -d "$ssh_dir" ]]; then
        error "require github: '$ssh_dir' does not exist; require ssh must run first"
        return 1
    fi

    if [[ ! -f "$config" ]]; then
        error "require github: '$config' does not exist; require ssh must run first"
        return 1
    fi

    if grep -Fqx "Host github" "$config"; then
        if ! grep -Fqx "    Hostname github.com" "$config" ||
            ! grep -Fqx "    User git" "$config"
        then
            error "require github: existing 'Host github' configuration is invalid"
            return 1
        fi

        return 0
    fi

    if ! cat >> "$config" <<'EOF'

Host github
    Hostname github.com
    User git
EOF
    then
        error "require github: failed to add 'Host github' to '$config'"
        return 1
    fi

    return 0
}

_require_github_auth() {
    if gh auth status --hostname github.com >/dev/null 2>&1; then
        return 0
    fi

    printf '\033[93m! GitHub authentication required\033[0m\n'

    if ! gh auth login \
        --hostname github.com \
        --git-protocol ssh
    then
        error "require github: GitHub authentication failed"
        return 1
    fi

    if ! gh auth status --hostname github.com >/dev/null 2>&1; then
        error "require github: GitHub authentication could not be verified"
        return 1
    fi

    return 0
}

_require_github() {
    _require_github_install || return 1
    _require_github_ssh_config || return 1
    _require_github_auth || return 1

    printf '\033[92m[+] GitHub authenticated\033[0m\n'
    return 0
}

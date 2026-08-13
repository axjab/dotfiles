
#!/usr/bin/env bash
# =============================================================================
# require ssh — local SSH capability
#
#   require ssh
#
# Establishes the local SSH environment and a host-specific identity key.
# The host key is the default identity for all SSH connections.
# =============================================================================

_require_ssh() {
    local ssh_dir="$HOME/.ssh"
    local hostname
    local key
    local config

    hostname="$(hostname)" || {
        error "require ssh: failed to determine hostname"
        return 1
    }

    if [[ -z "$hostname" ]]; then
        error "require ssh: hostname is empty"
        return 1
    fi

    key="$ssh_dir/$hostname.key"
    config="$ssh_dir/config"

    if ! mkdir -p "$ssh_dir"; then
        error "require ssh: failed to create '$ssh_dir'"
        return 1
    fi

    if [[ ! -f "$key" ]]; then
        if ! ssh-keygen \
            -t ed25519 \
            -f "$key" \
            -C "$hostname" \
            -N ""; then
            error "require ssh: failed to generate '$key'"
            return 1
        fi
    fi

    if [[ ! -f "$config" ]]; then
        if ! touch "$config"; then
            error "require ssh: failed to create '$config'"
            return 1
        fi
    fi

    if ! grep -Fqx "Host *" "$config"; then
        cat >> "$config" <<EOF

Host *
    IdentityFile $key
    IdentitiesOnly yes
EOF
    else
        if ! grep -Fqx "    IdentityFile $key" "$config"; then
            error "require ssh: existing 'Host *' block does not use '$key'"
            return 1
        fi

        if ! grep -Fqx "    IdentitiesOnly yes" "$config"; then
            error "require ssh: existing 'Host *' block does not set 'IdentitiesOnly yes'"
            return 1
        fi
    fi

    if ! chmod 700 "$ssh_dir"; then
        error "require ssh: failed to set permissions on '$ssh_dir'"
        return 1
    fi

    if ! chmod 600 "$config"; then
        error "require ssh: failed to set permissions on '$config'"
        return 1
    fi

    if ! chmod 600 "$key"; then
        error "require ssh: failed to set permissions on '$key'"
        return 1
    fi

    if [[ -f "$key.pub" ]] && ! chmod 644 "$key.pub"; then
        error "require ssh: failed to set permissions on '$key.pub'"
        return 1
    fi

    printf '\033[92m[+] SSH capability available\033[0m\n'
    return 0
}

#!/usr/bin/env bash
# =============================================================================
# create key ssh — local SSH identity
#
#   create key ssh
#
# Creates a host-specific Ed25519 key under ~/.ssh and configures it as the
# default identity in ~/.ssh/config. Idempotent.
# =============================================================================

_create_key_ssh() {
    local ssh_dir="$HOME/.ssh"
    local hostname key config

    hostname="$(hostname)" || {
        error "create key ssh: failed to determine hostname"
        return 1
    }

    if [[ -z "$hostname" ]]; then
        error "create key ssh: hostname is empty"
        return 1
    fi

    key="$ssh_dir/$hostname.key"
    config="$ssh_dir/config"

    mkdir -p "$ssh_dir" || {
        error "create key ssh: failed to create '$ssh_dir'"
        return 1
    }

    if [[ ! -f "$key" ]]; then
        ssh-keygen -t ed25519 -f "$key" -C "$hostname" -N "" || {
            error "create key ssh: failed to generate '$key'"
            return 1
        }
    fi

    if [[ ! -f "$config" ]]; then
        touch "$config" || {
            error "create key ssh: failed to create '$config'"
            return 1
        }
    fi

    if ! grep -Fqx "Host *" "$config"; then
        cat >> "$config" <<EOF

Host *
    IdentityFile $key
    IdentitiesOnly yes
EOF
    else
        if ! grep -Fqx "    IdentityFile $key" "$config"; then
            error "create key ssh: existing 'Host *' block does not reference '$key'"
            return 1
        fi

        if ! grep -Fqx "    IdentitiesOnly yes" "$config"; then
            error "create key ssh: existing 'Host *' block is missing 'IdentitiesOnly yes'"
            return 1
        fi
    fi

    chmod 700 "$ssh_dir" || {
        error "create key ssh: failed to set permissions on '$ssh_dir'"
        return 1
    }

    chmod 600 "$config" || {
        error "create key ssh: failed to set permissions on '$config'"
        return 1
    }

    chmod 600 "$key" || {
        error "create key ssh: failed to set permissions on '$key'"
        return 1
    }

    if [[ -f "$key.pub" ]]; then
        chmod 644 "$key.pub" || {
            error "create key ssh: failed to set permissions on '$key.pub'"
            return 1
        }
    fi

    msg "ssh" "identity ready ($key)"
    return 0
}

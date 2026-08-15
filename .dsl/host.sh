#!/usr/bin/env bash
# =============================================================================
# host — declare desired host state and SSH configuration
#
#   host NAME [at IP]
#       is TAG...
#       os VALUE
#       de VALUE
#       user VALUE
#   :
#
# Example:
#
#   host firelink at 100.121.116.55
#       is headless server
#       os Debian
#       user axjab
#   :
#
# The declaration converges:
#
#   /etc/hosts
#   ~/.ssh/config
#   $ROOT/.cache/host/state.json
#
# SSH connectivity is tested after convergence. Failure is soft: the user is
# shown the local host public key and given an opportunity to install it on
# the remote host.
# =============================================================================

HOSTS_FILE="/etc/hosts"
HOST_TAG="# ~/etc/Hostfile"

# -----------------------------------------------------------------------------
# $ROOT / state
# -----------------------------------------------------------------------------

_host_require_root() {
    if [[ -z "${ROOT:-}" ]]; then
        error "host: \$ROOT is not set (expected to be exported by the entrypoint)"
        return 1
    fi

    if [[ ! -d "$ROOT" ]]; then
        error "host: \$ROOT ('$ROOT') is not a directory"
        return 1
    fi
}

_host_state_file() {
    printf '%s/.cache/host/state.json' "$ROOT"
}

_host_require_jq() {
    if ! command -v jq >/dev/null 2>&1; then
        error "host: jq is required but not found on PATH"
        return 1
    fi
}

_host_ensure_state_file() {
    local state_file
    state_file="$(_host_state_file)"

    local dir
    dir="$(dirname "$state_file")"

    mkdir -p "$dir" || {
        error "host: failed to create state directory '$dir'"
        return 1
    }

    if [[ ! -f "$state_file" ]]; then
        printf '{}\n' > "$state_file" || {
            error "host: failed to initialize state file '$state_file'"
            return 1
        }
    fi
}

# -----------------------------------------------------------------------------
# Validation
# -----------------------------------------------------------------------------

_host_normalize_name() {
    local name="${1:-}"
    name="${name%.}"
    printf '%s' "${name,,}"
}

_host_normalize_ip() {
    local ip="${1:-}"

    if [[ "$ip" == *:* ]]; then
        if command -v python3 >/dev/null 2>&1; then
            python3 -c \
                'import ipaddress,sys; print(ipaddress.ip_address(sys.argv[1]).compressed)' \
                "$ip" 2>/dev/null ||
                printf '%s' "${ip,,}"
        else
            printf '%s' "${ip,,}"
        fi
    else
        printf '%s' "$ip"
    fi
}

_host_validate_name() {
    local name="${1:-}"

    [[ "$name" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)*$ ]]
}

_host_validate_ip() {
    local ip="${1:-}"

    if [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        local octet
        local -a octets

        IFS='.' read -r -a octets <<< "$ip"

        for octet in "${octets[@]}"; do
            (( octet >= 0 && octet <= 255 )) || return 1
        done

        return 0
    fi

    [[ "$ip" =~ ^[0-9a-fA-F:]+$ && "$ip" == *:* ]]
}

validate_host_syntax() {
    local name="${1:-}"

    if [[ -z "$name" ]]; then
        error "host: missing mandatory host name"
        return 1
    fi

    _host_validate_name "$name" || {
        error "host: invalid host name '$name'"
        return 1
    }
}

# -----------------------------------------------------------------------------
# Pending scope
# -----------------------------------------------------------------------------

_HOST_SCOPE_OPEN=0
_HOST_PENDING_NAME=""
_HOST_PENDING_AT=""
_HOST_PENDING_IS=()
_HOST_PENDING_OS=""
_HOST_PENDING_DE=""
_HOST_PENDING_USER=""

_host_reset_scope() {
    _HOST_SCOPE_OPEN=0
    _HOST_PENDING_NAME=""
    _HOST_PENDING_AT=""
    _HOST_PENDING_IS=()
    _HOST_PENDING_OS=""
    _HOST_PENDING_DE=""
    _HOST_PENDING_USER=""
}

_host_require_open_scope() {
    local caller="$1"

    if [[ "$_HOST_SCOPE_OPEN" -ne 1 ]]; then
        error "$caller: no active host declaration"
        return 2
    fi
}

# -----------------------------------------------------------------------------
# host NAME [at IP]
# -----------------------------------------------------------------------------

host() {
    if [[ "${1:-}" == "service" ]]; then
        shift
        host_service "$@"
        return $?
    fi

    if [[ "$_HOST_SCOPE_OPEN" -eq 1 ]]; then
        error "host: a host declaration for '$_HOST_PENDING_NAME' is still open (missing ':')"
        return 2
    fi

    local name="${1:-}"
    local prep="${2:-}"
    local ip="${3:-}"

    validate_host_syntax "$name" || return 1

    if [[ -n "$prep" ]]; then
        if [[ "$prep" != "at" ]]; then
            error "host: unknown preposition '$prep' (expected 'at')"
            return 1
        fi

        if [[ -z "$ip" ]]; then
            error "host: 'at' requires an IP address"
            return 1
        fi

        _host_validate_ip "$ip" || {
            error "host: invalid IP address '$ip'"
            return 1
        }
    fi

    _host_reset_scope

    _HOST_SCOPE_OPEN=1
    _HOST_PENDING_NAME="$(_host_normalize_name "$name")"

    if [[ -n "$ip" ]]; then
        _HOST_PENDING_AT="$ip"
    fi

    return 0
}

# -----------------------------------------------------------------------------
# is TAG...
# -----------------------------------------------------------------------------

is() {
    _host_require_open_scope "is" || return $?

    if [[ $# -eq 0 ]]; then
        error "is: expected one or more tags"
        return 2
    fi

    _HOST_PENDING_IS+=("$@")
}

# -----------------------------------------------------------------------------
# os VALUE
# -----------------------------------------------------------------------------

os() {
    _host_require_open_scope "os" || return $?

    if [[ $# -ne 1 ]]; then
        error "os: expected exactly one value"
        return 2
    fi

    _HOST_PENDING_OS="$1"
}

# -----------------------------------------------------------------------------
# de VALUE
# -----------------------------------------------------------------------------

de() {
    _host_require_open_scope "de" || return $?

    if [[ $# -ne 1 ]]; then
        error "de: expected exactly one value"
        return 2
    fi

    _HOST_PENDING_DE="$1"
}

# -----------------------------------------------------------------------------
# user VALUE
# -----------------------------------------------------------------------------

user() {
    _host_require_open_scope "user" || return $?

    if [[ $# -ne 1 ]]; then
        error "user: expected exactly one value"
        return 2
    fi

    _HOST_PENDING_USER="$1"
}

# -----------------------------------------------------------------------------
# SSH configuration
# -----------------------------------------------------------------------------

_host_ssh_config_file() {
    printf '%s/.ssh/config' "$HOME"
}

_host_ensure_ssh_config() {
    local ssh_dir="$HOME/.ssh"
    local config="$(_host_ssh_config_file)"

    if [[ ! -d "$ssh_dir" ]]; then
        mkdir -p "$ssh_dir" || {
            error "host: failed to create '$ssh_dir'"
            return 1
        }
    fi

    chmod 700 "$ssh_dir" || {
        error "host: failed to secure '$ssh_dir'"
        return 1
    }

    if [[ ! -f "$config" ]]; then
        touch "$config" || {
            error "host: failed to create '$config'"
            return 1
        }
    fi

    chmod 600 "$config" || {
        error "host: failed to secure '$config'"
        return 1
    }
}

_host_apply_ssh_config() {
    local name="$1"
    local hostname="$2"
    local ssh_user="$3"

    _host_ensure_ssh_config || return 1

    local config="$(_host_ssh_config_file)"
    local tmp
    tmp="$(mktemp)" || {
        error "host: failed to create temporary SSH config"
        return 1
    }

    awk \
        -v wanted="$name" \
        -v new_hostname="$hostname" \
        -v new_user="$ssh_user" '
        function emit_block() {
            print "Host " wanted
            print "    Hostname " new_hostname

            if (new_user != "")
                print "    User " new_user
        }

        BEGIN {
            in_target = 0
            found = 0
        }

        /^Host[[:space:]]+/ {
            host_name = $0
            sub(/^[[:space:]]*Host[[:space:]]+/, "", host_name)

            # Only manage an exact Host <name> block.
            if (host_name == wanted) {
                if (!found) {
                    emit_block()
                    found = 1
                }

                in_target = 1
                next
            }

            in_target = 0
        }

        {
            if (!in_target)
                print
        }

        END {
            if (!found) {
                if (NR > 0)
                    print ""

                emit_block()
            }
        }
    ' "$config" > "$tmp"

    if ! cmp -s "$config" "$tmp"; then
        mv "$tmp" "$config" || {
            rm -f "$tmp"
            error "host: failed to update '$config'"
            return 1
        }
    else
        rm -f "$tmp"
    fi

    chmod 600 "$config" || {
        error "host: failed to secure '$config'"
        return 1
    }
}

# -----------------------------------------------------------------------------
# SSH reachability / bootstrap assistance
# -----------------------------------------------------------------------------

_host_ssh_public_key() {
    local key="$HOME/.ssh/$(hostname).key.pub"

    if [[ ! -f "$key" ]]; then
        error "host: local SSH public key not found: $key"
        return 1
    fi

    cat "$key"
}

_host_test_ssh() {
    local name="$1"

    command -v ssh >/dev/null 2>&1 || {
        error "host: ssh is not installed; cannot test '$name'"
        return 1
    }

    ssh \
        -o BatchMode=yes \
        -o ConnectTimeout=5 \
        "$name" true >/dev/null 2>&1
}

_host_check_ssh() {
    local name="$1"

    if _host_test_ssh "$name"; then
        # printf '\033[1;32m[+] SSH %s reachable\033[0m\n' "$name"
        return 0
    fi

    error "host: SSH connection to '$name' failed"

    local key="$HOME/.ssh/$(hostname).key.pub"

    if [[ ! -f "$key" ]]; then
        error "host: public key not found: $key"
        return 0
    fi

    printf '\n'
    printf '\033[93mSSH public key to add to %s:~/.ssh/authorized_keys\033[0m\n' "$name"
    printf '\n'
    cat "$key"
    printf '\n\n'

    printf 'Add the key to the remote host, then press Enter to retry SSH. '
    read -r

    if _host_test_ssh "$name"; then
        printf '\033[1;32m[+] SSH %s reachable\033[0m\n' "$name"
        return 0
    fi

    error "host: SSH connection to '$name' still unavailable"
    return 0
}

# -----------------------------------------------------------------------------
# : — close scope
# -----------------------------------------------------------------------------

:() {
    if [[ "$_HOST_SCOPE_OPEN" -ne 1 ]]; then
        error "host: ':' with no active host declaration"
        return 2
    fi

    local name="$_HOST_PENDING_NAME"
    local ip="$_HOST_PENDING_AT"

    _host_require_root || {
        _host_reset_scope
        return 1
    }

    _host_require_jq || {
        _host_reset_scope
        return 1
    }

    _host_ensure_state_file || {
        _host_reset_scope
        return 1
    }

    local state_file
    state_file="$(_host_state_file)"

    # Resolve IP from current declaration or existing state.
    if [[ -z "$ip" ]]; then
        ip="$(jq -r --arg n "$name" '.[$n].ip // empty' "$state_file")"
    fi

    if [[ -n "$ip" ]]; then
        _host_validate_ip "$ip" || {
            error "host: resolved IP '$ip' for '$name' is invalid"
            _host_reset_scope
            return 1
        }
    fi

    # Resolve user from current declaration or existing state.
    local ssh_user="$_HOST_PENDING_USER"

    if [[ -z "$ssh_user" ]]; then
        ssh_user="$(jq -r --arg n "$name" '.[$n].user // empty' "$state_file")"
    fi

    # -------------------------------------------------------------------------
    # /etc/hosts
    # -------------------------------------------------------------------------

    local status=""

    if [[ -n "$ip" ]]; then
        status="$(_host_apply_etc_hosts "$name" "$ip")" || {
            _host_reset_scope
            return 1
        }
    fi

    # -------------------------------------------------------------------------
    # Merge tags
    # -------------------------------------------------------------------------

    local -a tags=()

    if [[ ${#_HOST_PENDING_IS[@]} -gt 0 ]]; then
        local t
        local seen=""

        for t in "${_HOST_PENDING_IS[@]}"; do
            [[ " $seen " == *" $t "* ]] && continue

            tags+=("$t")
            seen+=" $t"
        done
    fi

    local os_val="$_HOST_PENDING_OS"
    local de_val="$_HOST_PENDING_DE"

    local tags_json
    tags_json="$(printf '%s\n' "${tags[@]}" | jq -R . | jq -s .)"

    # -------------------------------------------------------------------------
    # Persistent state
    # -------------------------------------------------------------------------

    local tmp
    tmp="$(mktemp)" || {
        error "host: failed to create temp file"
        _host_reset_scope
        return 1
    }

    if ! jq \
        --arg n "$name" \
        --arg ip "$ip" \
        --arg user "$ssh_user" \
        --argjson tags "$tags_json" \
        --arg os "$os_val" \
        --arg de "$de_val" \
        --arg has_tags "$([[ ${#tags[@]} -gt 0 ]] && echo 1 || echo 0)" \
        --arg has_os "$([[ -n "$os_val" ]] && echo 1 || echo 0)" \
        --arg has_de "$([[ -n "$de_val" ]] && echo 1 || echo 0)" \
        --arg has_user "$([[ -n "$ssh_user" ]] && echo 1 || echo 0)" \
        '
        .[$n] = ((.[$n] // {}) as $prev |
            {
                ip: $ip,
                is: (if $has_tags == "1" then $tags else ($prev.is // []) end),
                os: (if $has_os == "1" then $os else ($prev.os // "") end),
                de: (if $has_de == "1" then $de else ($prev.de // "") end),
                user: (if $has_user == "1" then $user else ($prev.user // "") end)
            }
        )
        ' "$state_file" > "$tmp"
    then
        error "host: failed to update state for '$name'"
        rm -f "$tmp"
        _host_reset_scope
        return 1
    fi

    mv "$tmp" "$state_file" || {
        error "host: failed to install state file '$state_file'"
        rm -f "$tmp"
        _host_reset_scope
        return 1
    }

    # -------------------------------------------------------------------------
    # SSH config
    #
    # Only write a Host block when an address is known. A hostname without
    # `at` can still retain its previously generated SSH configuration.
    # -------------------------------------------------------------------------

    if [[ -n "$ip" ]]; then
        _host_apply_ssh_config "$name" "$ip" "$ssh_user" || {
            _host_reset_scope
            return 1
        }

        _host_check_ssh "$name"
    fi

    # -------------------------------------------------------------------------
    # Summary
    # -------------------------------------------------------------------------

    local summary_tags

    summary_tags="$(
        jq -r --arg n "$name" '
            .[$n] |
            ([.is[]?, .os, .de] |
                map(select(. != "" and . != null)) |
                join(", "))
        ' "$state_file"
    )"

    local location=""
    local parenthetical=""

    if [[ -n "$ip" ]]; then
        location=" at $ip"
        parenthetical=" ($status)"
    else
        parenthetical=" (no ip)"
    fi

    if [[ -n "$summary_tags" ]]; then
        msg HOST "${name}${location} [$summary_tags]${parenthetical}"
    else
        msg HOST "${name}${location}${parenthetical}"
    fi

    _host_reset_scope
}

# -----------------------------------------------------------------------------
# /etc/hosts convergence
# -----------------------------------------------------------------------------

_host_apply_etc_hosts() {
    local name="$1"
    local ip="$2"

    local ip_norm
    local existing_tagged
    local existing_untagged
    local status

    ip_norm="$(_host_normalize_ip "$ip")"

    existing_tagged="$(
        awk -v n="$name" -v tag="$HOST_TAG" '
            $0 ~ tag {
                for (i=2; i<=NF; i++) {
                    sub(/#.*/, "", $i)
                    if (tolower($i) == n) {
                        print $1
                        exit
                    }
                }
            }
        ' "$HOSTS_FILE" 2>/dev/null || true
    )"

    existing_untagged="$(
        awk -v n="$name" -v tag="$HOST_TAG" '
            $0 !~ tag && $1 !~ /^#/ {
                for (i=2; i<=NF; i++) {
                    if (tolower($i) == n) {
                        print $1
                        exit
                    }
                }
            }
        ' "$HOSTS_FILE" 2>/dev/null || true
    )"

    if [[ -n "$existing_tagged" ]]; then
        if [[ "$(_host_normalize_ip "$existing_tagged")" == "$ip_norm" ]]; then
            printf 'unchanged'
            return 0
        fi

        status="updated"

    elif [[ -n "$existing_untagged" ]]; then
        if [[ "$(_host_normalize_ip "$existing_untagged")" == "$ip_norm" ]]; then
            status="adopted"
        else
            status="updated"
        fi

    else
        status="declared"
    fi

    local tmp
    tmp="$(mktemp)" || {
        error "host: failed to create temporary hosts file"
        return 1
    }

    awk \
        -v n="$name" \
        -v new_ip="$ip" \
        -v tag="$HOST_TAG" '
        BEGIN {
            updated = 0
        }

        {
            if ($0 ~ /^[[:space:]]*#/ || NF == 0) {
                print $0
                next
            }

            has_target = 0
            new_line = $1
            comment = ""

            for (i = 2; i <= NF; i++) {
                if ($i ~ /^#/) {
                    for (j = i; j <= NF; j++)
                        comment = comment (j == i ? "" : " ") $j
                    break
                }

                if (tolower($i) == n) {
                    has_target = 1
                } else {
                    new_line = new_line "\t" $i
                }
            }

            if (has_target) {
                if (length(new_line) > length($1)) {
                    print (comment != "" ? new_line "\t" comment : new_line)
                }

                if (!updated) {
                    printf "%s\t%s\t%s\n", new_ip, n, tag
                    updated = 1
                }
            } else {
                print $0
            }
        }

        END {
            if (!updated)
                printf "%s\t%s\t%s\n", new_ip, n, tag
        }
    ' "$HOSTS_FILE" > "$tmp"

    if ! sudo cp "$tmp" "$HOSTS_FILE"; then
        rm -f "$tmp"
        error "host: failed to update '$HOSTS_FILE'"
        return 1
    fi

    sudo chmod 644 "$HOSTS_FILE"
    rm -f "$tmp"

    printf '%s' "$status"
}

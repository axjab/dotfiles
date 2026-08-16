#!/usr/bin/env bash
# =============================================================================
# host — declare desired host state and SSH configuration
#
# Syntax:
#
#   host NAME [at IP]
#       is='TAG...'
#       user=USER
#       os=OS
#       de=DE
#   :
#
# Example:
#
#   host firelink at 100.121.116.55
#       is='headless server'
#       user=ash
#       os=Debian
#   :
#
# Existing host state is loaded when the scope opens. Assignments in the
# scope replace the corresponding values. Closing the scope with ':' commits
# the resulting state.
#
# The declaration converges:
#
#   /etc/hosts
#   ~/.ssh/config
#   ${XDG_CACHE_DIR:-~/.cache}/host/state.json
#
# SSH connectivity is tested after convergence. Failure is soft: the user is
# shown the local host public key and given an opportunity to install it on
# the remote host.
# =============================================================================

HOSTS_FILE="/etc/hosts"
HOST_TAG="# ~/etc/Hostfile"

# -----------------------------------------------------------------------------
# Scope state
# -----------------------------------------------------------------------------

_HOST_SCOPE_OPEN=0
_HOST_PENDING_NAME=""
_HOST_PENDING_AT=""

# These are deliberately ordinary Bash variables. The Hostfile modifies them
# using normal assignment syntax while the scope is open.
is=""
user=""
os=""
de=""

# -----------------------------------------------------------------------------
# Cache / state
#
# Persistent host state belongs to the user's cache, not the Hostfile
# repository. XDG_CACHE_DIR may be supplied explicitly; ~/.cache is the
# fallback.
# -----------------------------------------------------------------------------

HOST_CACHE_DIR="${XDG_CACHE_DIR:-${HOME}/.cache}/host"

_host_state_file() {
    printf '%s/state.json' "$HOST_CACHE_DIR"
}

_host_require_jq() {
    if ! command -v jq >/dev/null 2>&1; then
        error "host: jq is required but not found on PATH"
        return 1
    fi
}

_host_ensure_state_file() {
    local state_file
    local state_dir

    state_file="$(_host_state_file)"
    state_dir="$(dirname "$state_file")"

    if ! mkdir -p "$state_dir"; then
        error "host: failed to create cache directory '$state_dir'"
        return 1
    fi

    if [[ ! -f "$state_file" ]]; then
        printf '{}\n' > "$state_file" || {
            error "host: failed to initialize '$state_file'"
            return 1
        }
    fi
}

# -----------------------------------------------------------------------------
# Validation / normalization
# -----------------------------------------------------------------------------

_host_normalize_name() {
    local name="${1:-}"

    name="${name%.}"
    printf '%s' "${name,,}"
}

_host_normalize_ip() {
    local ip="${1:-}"

    if [[ "$ip" == *:* ]] &&
       command -v python3 >/dev/null 2>&1
    then
        python3 -c \
            'import ipaddress,sys; print(ipaddress.ip_address(sys.argv[1]).compressed)' \
            "$ip" 2>/dev/null ||
            printf '%s' "${ip,,}"
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
        error "host: missing host name"
        return 1
    fi

    if ! _host_validate_name "$name"; then
        error "host: invalid host name '$name'"
        return 1
    fi
}

# -----------------------------------------------------------------------------
# Existing state
# -----------------------------------------------------------------------------

_host_load_state() {
    local name="$1"
    local state_file="$(_host_state_file)"

    # Start with empty values. This makes an unknown host completely explicit.
    is=""
    user=""
    os=""
    de=""

    local stored_is
    local stored_user
    local stored_os
    local stored_de

    stored_is="$(jq -r --arg n "$name" '.[$n].is // [] | join(" ")' "$state_file")"
    stored_user="$(jq -r --arg n "$name" '.[$n].user // empty' "$state_file")"
    stored_os="$(jq -r --arg n "$name" '.[$n].os // empty' "$state_file")"
    stored_de="$(jq -r --arg n "$name" '.[$n].de // empty' "$state_file")"

    is="$stored_is"
    user="$stored_user"
    os="$stored_os"
    de="$stored_de"

    # The address is handled separately because `host NAME at IP` is part of
    # the declaration syntax rather than an ordinary body assignment.
    if [[ -z "$_HOST_PENDING_AT" ]]; then
        _HOST_PENDING_AT="$(
            jq -r --arg n "$name" '.[$n].ip // empty' "$state_file"
        )"
    fi
}

# -----------------------------------------------------------------------------
# Scope management
# -----------------------------------------------------------------------------

_host_reset_scope() {
    _HOST_SCOPE_OPEN=0
    _HOST_PENDING_NAME=""
    _HOST_PENDING_AT=""

    is=""
    user=""
    os=""
    de=""
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

Host() {
    if [[ "${1:-}" == "service" ]]; then
        shift

        if declare -f host_service >/dev/null 2>&1; then
            host_service "$@"
            return $?
        fi

        error "host service: host_service is not available"
        return 1
    fi

    if [[ "$_HOST_SCOPE_OPEN" -eq 1 ]]; then
        error "host: declaration for '$_HOST_PENDING_NAME' is still open (missing ':')"
        return 2
    fi

    local name="${1:-}"
    local prep="${2:-}"
    local ip="${3:-}"

    validate_host_syntax "$name" || return 1

    if [[ -n "$prep" ]]; then
        if [[ "$prep" != "at" ]]; then
            error "host: expected 'at', got '$prep'"
            return 1
        fi

        if [[ -z "$ip" ]]; then
            error "host: 'at' requires an IP address"
            return 1
        fi

        if ! _host_validate_ip "$ip"; then
            error "host: invalid IP address '$ip'"
            return 1
        fi
    fi

    _host_require_jq || return 1
    _host_ensure_state_file || return 1

    _HOST_SCOPE_OPEN=1
    _HOST_PENDING_NAME="$(_host_normalize_name "$name")"
    _HOST_PENDING_AT="$ip"

    _host_load_state "$_HOST_PENDING_NAME"

    # An explicit `at` always wins over persisted state.
    if [[ -n "$ip" ]]; then
        _HOST_PENDING_AT="$ip"
    fi
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

    if [[ ! -d "$ssh_dir" ]] && ! mkdir -p "$ssh_dir"; then
        error "host: failed to create '$ssh_dir'"
        return 1
    fi

    if ! chmod 700 "$ssh_dir"; then
        error "host: failed to secure '$ssh_dir'"
        return 1
    fi

    if [[ ! -f "$config" ]] && ! touch "$config"; then
        error "host: failed to create '$config'"
        return 1
    fi

    if ! chmod 600 "$config"; then
        error "host: failed to secure '$config'"
        return 1
    fi
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
        if ! mv "$tmp" "$config"; then
            rm -f "$tmp"
            error "host: failed to update '$config'"
            return 1
        fi
    else
        rm -f "$tmp"
    fi

    chmod 600 "$config"
}

# -----------------------------------------------------------------------------
# SSH reachability
# -----------------------------------------------------------------------------

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
    else
        error "host: SSH connection to '$name' still unavailable"
    fi

    return 0
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
                print
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
                if (length(new_line) > length($1))
                    print (comment != "" ? new_line "\t" comment : new_line)

                if (!updated) {
                    printf "%s\t%s\t%s\n", new_ip, n, tag
                    updated = 1
                }
            } else {
                print
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

    if ! sudo chmod 644 "$HOSTS_FILE"; then
        rm -f "$tmp"
        error "host: failed to secure '$HOSTS_FILE'"
        return 1
    fi

    rm -f "$tmp"

    printf '%s' "$status"
}

# -----------------------------------------------------------------------------
# Commit scope
# -----------------------------------------------------------------------------

:() {
    if [[ "$_HOST_SCOPE_OPEN" -ne 1 ]]; then
        error "host: ':' with no active host declaration"
        return 2
    fi

    local name="$_HOST_PENDING_NAME"
    local ip="$_HOST_PENDING_AT"
    local state_file

    _host_require_jq || {
        _host_reset_scope
        return 1
    }

    _host_ensure_state_file || {
        _host_reset_scope
        return 1
    }

    state_file="$(_host_state_file)"

    if [[ -n "$ip" ]] && ! _host_validate_ip "$ip"; then
        error "host: invalid IP address '$ip' for '$name'"
        _host_reset_scope
        return 1
    fi

    # -------------------------------------------------------------------------
    # /etc/hosts
    # -------------------------------------------------------------------------

    local hosts_status=""

    if [[ -n "$ip" ]]; then
        hosts_status="$(_host_apply_etc_hosts "$name" "$ip")" || {
            _host_reset_scope
            return 1
        }
    fi

    # -------------------------------------------------------------------------
    # Persistent state
    #
    # `is` replaces existing tags.
    # user/os/de retain the values loaded when the scope opened unless the
    # Hostfile assigned new values.
    # -------------------------------------------------------------------------

    local tags_json
    local tmp

    if [[ -n "$is" ]]; then
        read -r -a _HOST_TAGS <<< "$is"
        tags_json="$(
            printf '%s\n' "${_HOST_TAGS[@]}" |
                jq -R . |
                jq -s .
        )"
    else
        tags_json='[]'
    fi

    tmp="$(mktemp)" || {
        error "host: failed to create temporary state file"
        _host_reset_scope
        return 1
    }

    if ! jq \
        --arg n "$name" \
        --arg ip "$ip" \
        --arg user "$user" \
        --arg os "$os" \
        --arg de "$de" \
        --argjson tags "$tags_json" \
        '
        .[$n] = {
            ip: $ip,
            is: $tags,
            os: $os,
            de: $de,
            user: $user
        }
        ' "$state_file" > "$tmp"
    then
        rm -f "$tmp"
        error "host: failed to update state for '$name'"
        _host_reset_scope
        return 1
    fi

    if ! mv "$tmp" "$state_file"; then
        rm -f "$tmp"
        error "host: failed to install state file '$state_file'"
        _host_reset_scope
        return 1
    fi

    # -------------------------------------------------------------------------
    # SSH configuration
    # -------------------------------------------------------------------------

    if [[ -n "$ip" ]]; then
        if ! _host_apply_ssh_config "$name" "$ip" "$user"; then
            _host_reset_scope
            return 1
        fi

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
        parenthetical=" ($hosts_status)"
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

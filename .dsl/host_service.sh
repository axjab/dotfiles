#!/usr/bin/env bash

# =============================================================================
# host service — declare desired /etc/hosts service entries
#
#   host service SERVICE at HOSTNAME_OR_IP
#
# Examples:
#
#   host service wiki at 127.0.0.1
#   host service nats at majula
#   host service file-server at 100.74.47.77
#
# The target may be either an IP address or a resolvable hostname. Hostnames
# are resolved using the system resolver via getent before the /etc/hosts
# entry is written.
#
# Service entries are owned by this primitive and marked with HOST_SERVICE_TAG.
# Existing matching unowned entries are adopted rather than duplicated.
#
# This file assumes msg() and error() are already defined by the DSL.
# =============================================================================

HOST_SERVICE_HOSTS_FILE="/etc/hosts"
HOST_SERVICE_TAG="# env:service"

# -----------------------------------------------------------------------------
# Validation
# -----------------------------------------------------------------------------

_host_service_validate_name() {
    local name="${1:-}"

    [[ -n "$name" ]] || {
        error "host service: missing service name"
        return 1
    }

    [[ "$name" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)*$ ]] || {
        error "host service: invalid service name '$name'"
        return 1
    }

    return 0
}

_host_service_validate_ipv4() {
    local ip="${1:-}"

    if [[ ! "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        return 1
    fi

    local octet
    local -a octets=()

    IFS='.' read -r -a octets <<< "$ip"

    for octet in "${octets[@]}"; do
        if (( octet < 0 || octet > 255 )); then
            return 1
        fi
    done

    return 0
}

_host_service_validate_ipv6() {
    local ip="${1:-}"

    [[ "$ip" == *:* ]] || return 1
    [[ "$ip" =~ ^[0-9a-fA-F:]+$ ]] || return 1

    return 0
}

_host_service_validate_ip() {
    local ip="${1:-}"

    _host_service_validate_ipv4 "$ip" && return 0
    _host_service_validate_ipv6 "$ip" && return 0

    return 1
}

# -----------------------------------------------------------------------------
# Normalize an IP for comparison.
#
# IPv4 needs no normalization. IPv6 is normalized when python3 is available;
# otherwise comparison falls back to case-insensitive textual comparison.
# -----------------------------------------------------------------------------

_host_service_normalize_ip() {
    local ip="${1:-}"

    if [[ "$ip" == *:* ]]; then
        if command -v python3 >/dev/null 2>&1; then
            python3 -c \
                'import ipaddress,sys; print(ipaddress.ip_address(sys.argv[1]).compressed)' \
                "$ip" 2>/dev/null || printf '%s' "${ip,,}"
        else
            printf '%s' "${ip,,}"
        fi
    else
        printf '%s' "$ip"
    fi
}

# -----------------------------------------------------------------------------
# Resolve a hostname to an address.
#
# getent is the normal Unix name-service interface and therefore respects the
# host's configured NSS sources (/etc/hosts, DNS, etc.).
#
# Prefer IPv4 when available because these entries traditionally appear in
# /etc/hosts and because it gives deterministic behavior on hosts with both
# address families configured. Fall back to any address if IPv4 is unavailable.
# -----------------------------------------------------------------------------

_host_service_resolve_target() {
    local target="$1"
    local resolved=""

    if _host_service_validate_ip "$target"; then
        _host_service_normalize_ip "$target"
        return 0
    fi

    if ! command -v getent >/dev/null 2>&1; then
        error "host service: getent is required to resolve hostname '$target'"
        return 1
    fi

    # `ahostsv4` is supported by glibc getent and gives us an address-only
    # result suitable for /etc/hosts. Ignore unsuccessful lookup explicitly
    # rather than allowing a failed conditional to become the function's
    # accidental success/failure status.
    resolved="$(
        getent ahostsv4 "$target" 2>/dev/null |
            awk '$1 != "" { print $1; exit }'
    )" || resolved=""

    if [[ -z "$resolved" ]]; then
        resolved="$(
            getent hosts "$target" 2>/dev/null |
                awk '$1 != "" { print $1; exit }'
        )" || resolved=""
    fi

    if [[ -z "$resolved" ]]; then
        error "host service: unable to resolve target '$target'"
        return 1
    fi

    _host_service_validate_ip "$resolved" || {
        error "host service: resolver returned invalid address '$resolved' for '$target'"
        return 1
    }

    _host_service_normalize_ip "$resolved"
    return 0
}

# -----------------------------------------------------------------------------
# Converge one service entry in /etc/hosts.
#
# Status:
#
#   declared  - no existing entry
#   adopted   - matching unowned entry was already present
#   updated   - an existing entry had a different address
#   unchanged - our owned entry already had the desired address
#
# The resulting entry is:
#
#   ADDRESS<TAB>SERVICE<TAB># env:service
#
# Existing aliases on the same hosts line are preserved when possible.
# Duplicate occurrences of the service name are removed.
# -----------------------------------------------------------------------------

_host_service_apply_etc_hosts() {
    local service="$1"
    local ip="$2"

    local ip_norm
    ip_norm="$(_host_service_normalize_ip "$ip")" || return 1

    local existing_owned=""
    local existing_unowned=""

    existing_owned="$(
        awk -v n="$service" -v tag="$HOST_SERVICE_TAG" '
            $0 ~ tag {
                for (i = 2; i <= NF; i++) {
                    token = $i
                    sub(/#.*/, "", token)
                    if (tolower(token) == tolower(n)) {
                        print $1
                        exit
                    }
                }
            }
        ' "$HOST_SERVICE_HOSTS_FILE" 2>/dev/null
    )" || existing_owned=""

    existing_unowned="$(
        awk -v n="$service" -v tag="$HOST_SERVICE_TAG" '
            $0 !~ tag && $1 !~ /^#/ {
                for (i = 2; i <= NF; i++) {
                    if (tolower($i) == tolower(n)) {
                        print $1
                        exit
                    }
                }
            }
        ' "$HOST_SERVICE_HOSTS_FILE" 2>/dev/null
    )" || existing_unowned=""

    local status

    if [[ -n "$existing_owned" ]]; then
        if [[ "$(_host_service_normalize_ip "$existing_owned")" == "$ip_norm" ]]; then
            printf 'unchanged'
            return 0
        fi
        status="updated"
    elif [[ -n "$existing_unowned" ]]; then
        if [[ "$(_host_service_normalize_ip "$existing_unowned")" == "$ip_norm" ]]; then
            status="adopted"
        else
            status="updated"
        fi
    else
        status="declared"
    fi

    local tmp
    tmp="$(mktemp)" || {
        error "host service: failed to create temporary /etc/hosts file"
        return 1
    }

    if ! awk \
        -v n="$service" \
        -v new_ip="$ip" \
        -v tag="$HOST_SERVICE_TAG" '
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
                    for (j = i; j <= NF; j++) {
                        comment = comment (j == i ? "" : " ") $j
                    }
                    break
                }

                if (tolower($i) == tolower(n)) {
                    has_target = 1
                } else {
                    new_line = new_line "\t" $i
                }
            }

            if (has_target) {
                # Preserve the remaining aliases/comment from the original
                # line, but remove the old occurrence of the service name.
                if (new_line != $1) {
                    if (comment != "") {
                        print new_line "\t" comment
                    } else {
                        print new_line
                    }
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
            if (!updated) {
                printf "%s\t%s\t%s\n", new_ip, n, tag
            }
        }
    ' "$HOST_SERVICE_HOSTS_FILE" > "$tmp"; then
        error "host service: failed to construct updated /etc/hosts"
        rm -f "$tmp"
        return 1
    fi

    if ! sudo cp "$tmp" "$HOST_SERVICE_HOSTS_FILE"; then
        error "host service: failed to install updated '$HOST_SERVICE_HOSTS_FILE'"
        rm -f "$tmp"
        return 1
    fi

    if ! sudo chmod 644 "$HOST_SERVICE_HOSTS_FILE"; then
        error "host service: failed to set permissions on '$HOST_SERVICE_HOSTS_FILE'"
        rm -f "$tmp"
        return 1
    fi

    rm -f "$tmp"

    printf '%s' "$status"
    return 0
}

# -----------------------------------------------------------------------------
# host service SERVICE at HOSTNAME_OR_IP
# -----------------------------------------------------------------------------

host_service() {
    if [[ $# -ne 3 ]]; then
        error "host service: expected SERVICE at HOSTNAME_OR_IP"
        return 2
    fi

    local service="$1"
    local prep="$2"
    local target="$3"

    if [[ "$prep" != "at" ]]; then
        error "host service: unknown preposition '$prep' (expected 'at')"
        return 2
    fi

    _host_service_validate_name "$service" || return 1

    if [[ -z "$target" ]]; then
        error "host service: 'at' requires a hostname or IP address"
        return 2
    fi

    if [[ ! -f "$HOST_SERVICE_HOSTS_FILE" ]]; then
        error "host service: hosts file '$HOST_SERVICE_HOSTS_FILE' does not exist"
        return 1
    fi

    local ip
    ip="$(_host_service_resolve_target "$target")" || return 1

    local status
    status="$(_host_service_apply_etc_hosts "$service" "$ip")" || return 1

    msg SERVICE "$service <--- $target ($status)"

    return 0
}

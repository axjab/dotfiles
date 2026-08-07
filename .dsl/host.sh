#!/usr/bin/env bash
# =============================================================================
# host — declare /etc/hosts name resolution
#
#   host TARGET at IP             direct IP address binding
#   host TARGET at MACHINE        alias TARGET to a declared machine's IP
#   host TARGET on MACHINE        alias TARGET to a declared machine's IP
#   host TARGET                   reconverge from ledger, or default to 127.0.0.1
#
# Every line managed by host is tagged with "# env:host".
# =============================================================================

HOSTS_FILE="/etc/hosts"
HOST_LEDGER="${HOST_LEDGER:-${XDG_STATE_HOME:-$HOME/.local/state}/env/host.ledger}"
HOST_TAG="# env:host"

# Fallback printer if 'msg' is not defined in entrypoint context
if ! declare -f msg >/dev/null; then
    msg() {
        local directive="$1"; shift
        printf '%-11s %s\n' "$directive" "$*"
    }
fi

_host_normalize_name() {
    local name="${1:-}"
    name="${name%.}"
    printf '%s' "${name,,}"
}

_host_normalize_ip() {
    local ip="${1:-}"
    if [[ "$ip" == *:* ]]; then
        if command -v python3 >/dev/null 2>&1; then
            python3 -c "import ipaddress,sys; print(ipaddress.ip_address(sys.argv[1]).compressed)" "$ip" 2>/dev/null || printf '%s' "${ip,,}"
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
        IFS='.' read -r -a octets <<< "$ip"
        for octet in "${octets[@]}"; do
            (( octet >= 0 && octet <= 255 )) || return 1
        done
        return 0
    fi
    [[ "$ip" =~ ^[0-9a-fA-F:]+$ && "$ip" == *:* ]]
}

validate_host_syntax() {
    local target="${1:-}" prep="${2:-}" src="${3:-}"

    if [[ -z "$target" ]]; then
        echo "host: missing mandatory target argument" >&2
        return 1
    fi

    _host_validate_name "$target" || {
        echo "host: invalid hostname '$target'" >&2
        return 1
    }

    case "$prep" in
        "") return 0 ;;
        at|on)
            if [[ -z "$src" ]]; then
                echo "host: '$prep' requires an IP address or machine name" >&2
                return 1
            fi
            ;;
        *)
            echo "host: unknown preposition '$prep' (expected 'at' or 'on')" >&2
            return 1
            ;;
    esac
}

_host_ledger_get() {
    local name
    name="$(_host_normalize_name "${1:-}")"
    [[ -f "$HOST_LEDGER" ]] || return 0
    awk -v n="$name" '$1 == n { print $2; exit }' "$HOST_LEDGER" 2>/dev/null || true
}

_host_ledger_via() {
    local name
    name="$(_host_normalize_name "${1:-}")"
    [[ -f "$HOST_LEDGER" ]] || return 0
    awk -v n="$name" '$1 == n { print $3; exit }' "$HOST_LEDGER" 2>/dev/null || true
}

_host_ledger_put() {
    local name ip via
    name="$(_host_normalize_name "${1:-}")"
    ip="${2:-}"
    via="${3:-}"

    local dir
    dir="$(dirname "$HOST_LEDGER")"
    mkdir -p "$dir" 2>/dev/null || true

    local tmp
    tmp="$(mktemp)"
    if [[ -f "$HOST_LEDGER" ]]; then
        grep -v "^${name}[[:space:]]" "$HOST_LEDGER" > "$tmp" 2>/dev/null || true
    fi
    printf '%s %s %s\n' "$name" "$ip" "$via" >> "$tmp"
    mv "$tmp" "$HOST_LEDGER"
}

_host_apply() {
    local name="$1" ip="$2"
    local ip_norm existing_tagged existing_untagged status

    ip_norm="$(_host_normalize_ip "$ip")"

    # Inspect existing /etc/hosts state for this exact hostname
    existing_tagged="$(awk -v n="$name" -v tag="$HOST_TAG" '
        $0 ~ tag {
            for (i=2; i<=NF; i++) {
                sub(/#.*/, "", $i)
                if (tolower($i) == n) { print $1; exit }
            }
        }
    ' "$HOSTS_FILE" 2>/dev/null || true)"

    existing_untagged="$(awk -v n="$name" -v tag="$HOST_TAG" '
        $0 !~ tag && $1 !~ /^#/ {
            for (i=2; i<=NF; i++) {
                if (tolower($i) == n) { print $1; exit }
            }
        }
    ' "$HOSTS_FILE" 2>/dev/null || true)"

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

    # Atomically transform /etc/hosts without breaking unmanaged entries
    local tmp
    tmp="$(mktemp)"

    awk -v n="$name" -v new_ip="$ip" -v tag="$HOST_TAG" '
        BEGIN { updated = 0 }
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
                    for (j = i; j <= NF; j++) comment = comment (j==i?"":" ") $j
                    break
                }
                if (tolower($i) == n) {
                    has_target = 1
                } else {
                    new_line = new_line "\t" $i
                }
            }

            if (has_target) {
                # Preserve co-located hostnames on same line if any remain (e.g. localhost)
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
            if (!updated) {
                printf "%s\t%s\t%s\n", new_ip, n, tag
            }
        }
    ' "$HOSTS_FILE" > "$tmp"

    sudo cp "$tmp" "$HOSTS_FILE"
    sudo chmod 644 "$HOSTS_FILE"
    rm -f "$tmp"

    printf '%s' "$status"
}

host() {
    local target="${1:-}" prep="${2:-}" src="${3:-}"

    validate_host_syntax "$target" "$prep" "$src" || return 1

    target="$(_host_normalize_name "$target")"
    [[ -n "$src" ]] && src="$(_host_normalize_name "$src")"

    local ip="" via=""

    case "$prep" in
        at|on)
            if _host_validate_ip "$src"; then
                ip="$src"
                via="direct"
            else
                _host_validate_name "$src" || {
                    echo "host: '$src' is neither a valid IP address nor a machine name" >&2
                    return 1
                }
                local resolved_ip
                resolved_ip="$(_host_ledger_get "$src")"
                if [[ -z "$resolved_ip" ]]; then
                    echo "host: machine '$src' must be declared before referencing it" >&2
                    return 1
                fi
                ip="$resolved_ip"
                via="$src"
            fi
            ;;
        "")
            local ledger_ip ledger_via
            ledger_ip="$(_host_ledger_get "$target")"
            ledger_via="$(_host_ledger_via "$target")"

            if [[ -n "$ledger_ip" ]]; then
                via="${ledger_via:-direct}"
                if [[ "$via" != "direct" && -n "$via" ]]; then
                    local fresh_ip
                    fresh_ip="$(_host_ledger_get "$via")"
                    ip="${fresh_ip:-$ledger_ip}"
                else
                    ip="$ledger_ip"
                fi
            else
                # Default standalone local services (e.g., host wiki) to 127.0.0.1
                ip="127.0.0.1"
                via="direct"
            fi
            ;;
    esac

    local status
    status="$(_host_apply "$target" "$ip")" || return 1
    _host_ledger_put "$target" "$ip" "$via"

    if [[ "$via" == "direct" || -z "$via" ]]; then
        msg HOST "$target <-- $ip ($status)"
    else
        msg HOST "$target <-- $via ($ip) ($status)"
    fi
}

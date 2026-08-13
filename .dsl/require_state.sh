
_require_state_file() {
    if [[ -z "${ROOT:-}" ]]; then
        error "require: \$ROOT is not set (expected to be exported by the entrypoint)"
        return 1
    fi

    if [[ ! -d "$ROOT" ]]; then
        error "require: \$ROOT ('$ROOT') is not a directory"
        return 1
    fi

    local cache="$ROOT/.cache"
    local state="$cache/state.json"

    mkdir -p "$cache" || {
        error "require: failed to create '$cache'"
        return 1
    }

    if [[ ! -f "$state" ]]; then
        printf '{}\n' > "$state" || {
            error "require: failed to initialize '$state'"
            return 1
        }
    fi

    printf '%s' "$state"
}

_require_set_state() {
    local key="$1"
    local value="$2"
    local state

    state="$(_require_state_file)" || return 1

    if command -v jq >/dev/null 2>&1; then
        local tmp
        tmp="$(mktemp)" || {
            error "require: failed to create temporary state file"
            return 1
        }

        if ! jq --arg key "$key" --argjson value "$value" \
            '.[$key] = $value' "$state" > "$tmp"
        then
            rm -f "$tmp"
            error "require: failed to update '$state'"
            return 1
        fi

        mv "$tmp" "$state" || {
            rm -f "$tmp"
            error "require: failed to install '$state'"
            return 1
        }
    else
        error "require: jq is required to update runtime state"
        return 1
    fi
}


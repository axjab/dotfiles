#!/usr/bin/env bash
# =============================================================================
# require — assert host prerequisites
#
#   require internet
#
# Prerequisites are explicit keywords rather than generic arguments. Each
# keyword is dispatched to its corresponding handler below.
#
# Persistent general DSL state lives at:
#
#   $ROOT/.cache/state.json
#
# `offline_mode` records whether the current invocation was explicitly allowed
# to continue without Internet connectivity.
# =============================================================================

_require_cache_file() {
    if [[ -z "${ROOT:-}" ]]; then
        error "require: \$ROOT is not set (expected to be exported by the entrypoint)"
        return 1
    fi

    if [[ ! -d "$ROOT" ]]; then
        error "require: \$ROOT ('$ROOT') is not a directory"
        return 1
    fi

    local cache_dir="$ROOT/.cache"
    local state_file="$cache_dir/state.json"

    mkdir -p "$cache_dir" || {
        error "require: failed to create cache directory '$cache_dir'"
        return 1
    }

    if [[ ! -f "$state_file" ]]; then
        printf '{}\n' > "$state_file" || {
            error "require: failed to initialize '$state_file'"
            return 1
        }
    fi

    printf '%s' "$state_file"
}

_require_set_offline_mode() {
    local value="$1"
    local state_file tmp

    state_file="$(_require_cache_file)" || return 1

    tmp="$(mktemp)" || {
        error "require: failed to create temporary state file"
        return 1
    }

    if ! jq --argjson value "$value" \
        '.offline_mode = $value' \
        "$state_file" > "$tmp"
    then
        error "require: failed to update '$state_file'"
        rm -f "$tmp"
        return 1
    fi

    if ! mv "$tmp" "$state_file"; then
        error "require: failed to install updated state file '$state_file'"
        rm -f "$tmp"
        return 1
    fi

    return 0
}

_require_internet() {
    local curl_bin=""

    # Prefer the repository's dependency directory when available.
    if [[ -n "${BIN:-}" && -x "$BIN/curl" ]]; then
        curl_bin="$BIN/curl"
    elif command -v curl >/dev/null 2>&1; then
        curl_bin="$(command -v curl)"
    else
        error "require internet: curl is required but was not found"
        return 1
    fi

    # Deliberately capture the status instead of putting the test directly
    # into an `if ! ...` expression whose details can become obscured by
    # strict-shell behavior.
    if "$curl_bin" \
        --fail \
        --silent \
        --show-error \
        --location \
        --max-time 5 \
        --output /dev/null \
        https://www.google.com/generate_204
    then
        _require_set_offline_mode false || return 1
        printf '\033[92m✓ Internet connected\033[0m\n'
        return 0
    fi

    # The connectivity test failed. Record the fact only after the user has
    # explicitly chosen whether this invocation may continue offline.
    #
    # gum confirm returns:
    #   0 = yes
    #   1 = no
    #
    # Capture its status explicitly so `set -e` cannot terminate the rebuild
    # before we handle the user's answer.
    local proceed=1

    if [[ -n "${gum:-}" && -x "$gum" ]]; then
        if "$gum" confirm "Internet connection unavailable. Continue in offline mode?"; then
            proceed=0
        fi
    elif [[ -n "${BIN:-}" && -x "$BIN/gum" ]]; then
        if "$BIN/gum" confirm "Internet connection unavailable. Continue in offline mode?"; then
            proceed=0
        fi
    else
        error "require internet: gum is required to choose offline mode"
        return 1
    fi

    if [[ "$proceed" -eq 0 ]]; then
        _require_set_offline_mode true || return 1
        return 0
    fi

    # Declining is a deliberate, clean termination rather than an error.
    _require_set_offline_mode false || return 1

    return 0
}

require() {
    if [[ $# -ne 1 ]]; then
        error "require: expected exactly one prerequisite"
        return 2
    fi

    local prerequisite="$1"

    case "$prerequisite" in
        internet)
            _require_internet
            ;;
        *)
            error "require: unknown prerequisite '$prerequisite'"
            return 2
            ;;
    esac

    return $?
}

#!/usr/bin/env bash
# =============================================================================
# hook — run an external provider script
#
#   hook NAME [DEFAULT_MESSAGE]
#
# Looks for ~/etc/hooks/NAME, NAME.sh, or NAME.py (in that order).
# The hook script communicates via:
#
#   stdout   key=value lines (status=, message=, detail=, plus arbitrary data)
#   stderr   human-readable diagnostics, warnings, progress (passed through)
#   exit     0 = success, non-zero = failure
#
# On success, prints the hook-provided message (if any), then the Hostfile
# default message (if supplied). On failure, prints the error detail and
# returns 1 — does NOT exit the parent shell.
# =============================================================================

Hook() {
    if [[ $# -lt 1 ]]; then
        error "hook: expected a hook name"
        return 1
    fi

    local name="$1"
    local default_message="${2:-}"
    local stderr_tmp

    local script
    script="$(_hook_resolve "$name")" || return 1

    stderr_tmp="$(mktemp)" || {
        error "hook ${name}: failed to create temporary file"
        return 1
    }

    local captured_stdout captured_exit
    captured_stdout="$("$script" 2>"$stderr_tmp")" || captured_exit=$?
    captured_exit="${captured_exit:-0}"

    # Pass stderr through regardless of outcome.
    cat "$stderr_tmp" >&2
    rm -f "$stderr_tmp"

    local key value message_val detail_val
    message_val=""
    detail_val=""

    while IFS='=' read -r key value; do
        [[ -n "$key" ]] || continue
        case "$key" in
            message) message_val="$value" ;;
            detail)  detail_val="$value"  ;;
        esac
    done <<< "$captured_stdout"

    if [[ "$captured_exit" -ne 0 ]]; then
        error "hook ${name}: ${message_val:-hook exited with status ${captured_exit}}"
        if [[ -n "$detail_val" ]]; then
            printf '  %s\n' "$detail_val" >&2
        fi
        return 1
    fi

    if [[ -n "$message_val" ]]; then
        msg "HOOK" "$name: $message_val"
    fi

    if [[ -n "$default_message" ]]; then
        msg "HOOK" "$name: $default_message"
    fi

    return 0
}

_hook_resolve() {
    local name="$1"
    local base="$HOME/etc/hooks"
    local candidate

    for candidate in "$base/$name" "$base/$name.sh" "$base/$name.py"; do
        if [[ -f "$candidate" && -x "$candidate" ]]; then
            printf '%s' "$candidate"
            return 0
        fi
    done

    error "hook: no executable hook found for '${name}' in ${base}"
    return 1
}

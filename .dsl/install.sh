#!/usr/bin/env bash

install() {
    local name="$1"
    local in="$2"
    local namespace="$3"

    validate_install_syntax "$name" "$in" "$namespace" || return 1

    case "$namespace" in
        sudoers)
            install_sudoers "$name"
            ;;
        *)
            error "Unknown install namespace: $namespace"
            return 1
            ;;
    esac
}

validate_install_syntax() {
    local name="$1"
    local in="$2"
    local namespace="$3"

    if [[ -z "${name:-}" || -z "${in:-}" || -z "${namespace:-}" ]]; then
        error "install syntax: install NAME in NAMESPACE"
        return 1
    fi

    if [[ "$in" != "in" ]]; then
        error "install expected 'in', got '$in'"
        return 1
    fi
}

install_sudoers() {
    local name="$1"
    local target="/etc/sudoers.d/$name"
    local tmp

    tmp="$(mktemp)" || {
        error "install: failed to create temporary file"
        return 1
    }

    if ! cat > "$tmp"; then
        rm -f "$tmp"
        return 1
    fi

    if ! sudo visudo -cf "$tmp" >/dev/null; then
        rm -f "$tmp"
        error "Invalid sudoers configuration for '$name'"
        return 1
    fi

    if [[ -f "$target" ]] && sudo cmp -s "$tmp" "$target"; then
        rm -f "$tmp"
        return 0
    fi

    if ! sudo install -m 0440 "$tmp" "$target"; then
        rm -f "$tmp"
        error "install: failed to install '$target'"
        return 1
    fi

    rm -f "$tmp"

    msg "INSTALL" "$name --> $target"
    return 0
}

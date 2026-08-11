#!/usr/bin/env bash

install() {
    local name="$1"
    local in="$2"
    local namespace="$3"

    validate_install_syntax "$name" "$in" "$namespace" || return 1

    case "$namespace" in
        sudoers) install_sudoers "$name" ;;
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

    tmp=$(mktemp) || return 1
    cat > "$tmp"
    sudo install -m 0440 "$tmp" "$target"
    rm -f "$tmp"

    if ! sudo visudo -c > /dev/null; then
        error "Invalid sudoers configuration"
        return 1
    fi

    msg "INSTALL"  "$name --> $target"
}

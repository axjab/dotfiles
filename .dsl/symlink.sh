#!/usr/bin/env bash

symlink() {
    local source="$1"
    local to="$2"
    local target="$3"

    validate_symlink_syntax "$source" "$to" "$target" || return 1

    source="$ETC_DIR/$source"

    if [[ ! -e "$source" ]]; then
        error "Missing source: $source"
        return 1
    fi

    echo "SYMLINK	$source ---> $target"

    if [[ -L "$target" ]] && [[ "$(readlink -f "$target")" == "$(readlink -f "$source")" ]]; then
        echo "Symlink already exists."
        return 0
    fi

    ln -snfv "$source" "$target"

    echo "Symlink ready."
}

validate_symlink_syntax() {
	if [[ -z "${1:-}" || -z "${2:-}" || -z "${3:-}" ]]; then
        error "symlink syntax: symlink SOURCE to TARGET"
        return 1
    fi

    if [[ "$2" != "to" ]]; then
        error "symlink expected 'to', got '$2'"
        return 1
    fi
}

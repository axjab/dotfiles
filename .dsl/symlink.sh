#!/usr/bin/env bash

symlink() {
    local source="$ETC_DIR/$1"
    local to="$2"
    local target="$3"

    validate_symlink_syntax "$source" "$to" "$target" || return 1

    if [[ ! -e "$source" ]]; then
        error "Missing source: $source"
        msg "SKIPPED" "$source"
        # return 1
    fi

    msg "SYMLINK"	"$1 --> $target"

    if [[ -L "$target" ]] && [[ "$(readlink -f "$target")" == "$(readlink -f "$source")" ]]; then
        return 0
    fi

    sudo ln -snf "$source" "$target"
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

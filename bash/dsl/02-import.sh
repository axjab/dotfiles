# =============================================================================
# Bash DSL — file operations
# =============================================================================

file() {
    [[ -f $1 && -r $1 ]]
}

_import_path() {
    local path=$1

    if [[ $path != /* && $path != ~/* ]]; then
        path="$HOME/.bash/$path.sh"
    elif [[ $path == ~/* ]]; then
        path="$HOME/${path#~/}"
    fi

    printf '%s\n' "$path"
}

import() {
    local optional=false
    local path

    case $1 in
        optional)
            optional=true ; shift ;;
    esac

    path=$(_import_path "$1")

    if ! file "$path"; then
        if $optional; then
            return 0
        fi

        err "file not found: $path"
        return 1
    fi

    if $optional; then
        debug "importing OPTIONAL $path"
    else
        debug "importing MANDATORY $path"
    fi

    builtin source "$path"
}

# Optional import DSL syntax:
#   import? foo
#
# `?` cannot be used in a normal Bash function declaration, so expose it
# as an alias to the optional form of `import`.
alias 'import?'='import optional'

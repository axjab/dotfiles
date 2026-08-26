# =============================================================================
# Bash DSL — file operations
# =============================================================================

file() {
    [[ -f $1 && -r $1 ]]
}

import() {
    local path=$1

    if [[ $path != /* && $path != ~/* ]]; then
        path="$HOME/.bash/$path.sh"
    elif [[ $path == ~/* ]]; then
        path="$HOME/${path#~/}"
    fi

    file "$path" || {
        err "file not found: $path"
        return 1
    }

    debug "importing $path"
    builtin source "$path"
}

load() {
    import "$@"
}

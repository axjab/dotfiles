activate() {
    local output

    has "$1" || return 0

    output=$("$@") || {
        err "failed to activate: $*"
        return 1
    }

    [[ -n $output ]] && eval "$output"
}

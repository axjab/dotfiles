without_ssh() {
    [[ -z "${SSH_CONNECTION:-}" ]] && "$@"
}

with_ssh() {
    [[ -n "${SSH_CONNECTION:-}" ]] && "$@"
}

alias no_ssh=without_ssh

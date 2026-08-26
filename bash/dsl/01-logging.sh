# =============================================================================
# Bash DSL — logging
# =============================================================================

DEBUG_BASHRC=${DEBUG_BASHRC:-}

__bashrc_color() {
    case $1 in
        warn)  printf '\033[1;33m' ;;
        err)   printf '\033[1;31m' ;;
        debug) printf '\033[2;36m' ;;
        reset) printf '\033[0m' ;;
    esac
}

__bashrc_log() {
    local level=$1
    shift

    if [[ -t 2 ]]; then
        __bashrc_color "$level" >&2
        printf '%s\033[0m\n' "$*" >&2
    else
        printf '%s\n' "$*" >&2
    fi
}

warn() {
    __bashrc_log warn "$@"
}

err() {
    __bashrc_log err "$@"
}

debug() {
    [[ -n $DEBUG_BASHRC ]] || return 0
    __bashrc_log debug "$@"
}

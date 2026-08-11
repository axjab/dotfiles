
from() {
    local -a context=()
    local directive=""
    local -a args=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            process)
                directive="$1"
                shift
                args=("$@")
                break
                ;;
            *)
                context+=("$1")
                shift
                ;;
        esac
    done

    if [[ -z "$directive" ]]; then
        error "from requires a directive"
        return 1
    fi

    case "$directive" in
        process)
            process "${context[@]}" "${args[@]}"
            ;;
        *)
            error "Unknown directive: $directive"
            return 1
            ;;
    esac
}

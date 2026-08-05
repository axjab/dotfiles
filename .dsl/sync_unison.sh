sync_unison() {
    local target="$1"
    local peer="$2"

    if ! command -v unison >/dev/null 2>&1; then
        error "Unison is not installed"
        return 0
    fi

    if [[ ! -d "$target" ]]; then
        if ! create_dir "$target"; then
            error "Failed to create target directory $target"
            return 0
        fi
    fi

    local err status=0

    err=$(unison "$target" "$peer" 2>&1) || status=$?

    if [[ $status -ne 0 ]]; then
        error "Failed to synchronize $target with $peer"
        [[ -n "$err" ]] && error "$err"
        return 0
    fi

    msg "SYNC" "$target <--> $peer"
    return 0
}

process() {
    local source=$1
    local target=$3
    local template="$ETC_DIR/$source"

    if [[ $# -ne 3 || $2 != to ]]; then
        error "process syntax: process SOURCE to TARGET"
        return 1
    fi

    if [[ ! -f "$template" ]]; then
        error "Template not found: $template"
        return 1
    fi

    local target_dir
    target_dir=$(dirname "$target")
    if [[ ! -d "$target_dir" ]]; then
        if ! mkdir -p "$target_dir"; then
            error "Failed to create directory: $target_dir"
            return 1
        fi
    fi

    local tmp_output
    tmp_output=$(mktemp) || {
        error "Failed to create temp file for $target"
        return 1
    }

    if ! gum spin --title="PROCESSING $source --> $target" -- \
        gopass process "$template" > "$tmp_output"; then
        error "gopass process failed for $template"
        rm -f "$tmp_output"
        return 1
    fi

    if [[ ! -s "$tmp_output" ]]; then
        error "gopass process produced empty output for $template"
        rm -f "$tmp_output"
        return 1
    fi

    if [[ -f "$target" ]] && cmp -s "$tmp_output" "$target"; then
        rm -f "$tmp_output"
        msg "PROCESS" "$source --> $target (unchanged)"
        return 0
    fi

    if [[ -f "$target" ]]; then
        cp "$target" "$target.$(date +%Y%m%d-%H%M%S).bak"
    fi

    chmod 600 "$tmp_output"
    mv "$tmp_output" "$target"

    msg "PROCESS" "$source --> $target"
}

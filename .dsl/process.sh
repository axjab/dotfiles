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

    if [[ -f "$target" ]]; then
        cp "$target" "$target.$(date +%Y%m%d-%H%M%S)"
    fi

    gum spin --title="PROCESSING $source --> $target" -- \
        gopass process "$template" > "$target"

    chmod 600 "$target"

    msg "PROCESS" "$source --> $target"
}


process() {
    local source="$1"
    local target="$2"

    if [[ -z "${source:-}" || -z "${target:-}" ]]; then
        error "process syntax: from SOURCE process TARGET"
        return 1
    fi

    local template="$ETC_DIR/$source"

    if [[ ! -f "$template" ]]; then
        error "Template not found: $template"
        return 1
    fi

    if [[ -f "$target" ]]; then
        cp "$target" "$target.$(date +%Y%m%d-%H%M%S)"
    fi

    gum spin \
    	-- echo "PROCESSING TEMPLATE $template ---> $target" \
    	&& gopass process "$template" > "$target"

    chmod 600 "$target"

    echo "Processed file ready."
}

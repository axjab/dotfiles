msg() {
    local name="$1"
    local body="${2:-}"

    name="${name^^}"

    local first rest
    first="${body%% *}"
    rest="${body#"$first"}"
    rest="${rest# }"

    printf "\033[1;36m%-8s\033[0m \033[33m%s\033[0m%s\n" \
        "$name" "$first" "${rest:+ $rest}"
}

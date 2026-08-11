msg() {
    local name="$1"
    local body="$2"

    name="${name^^}"
    printf "\033[1;36m%-10s\033[0m %s\n" "$name" "$body"
}

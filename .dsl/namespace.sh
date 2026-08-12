namespace() {
    local name="$1"
    local links="${2:-}"
    local dest="${4:-}"

    # validate_namespace_syntax "$name" "$owned" "$by" "$owner" || return 1

    case "$name" in
        data|exe|log)
            local target="/$name"
            create_dir "$target"
            sudo chown "$USER" "$target"
            ;&  # fallthrough
        *) ;; # msg "NAMESPACE" "[$name] has been declared as a top-level namespace" ;;
    esac

    # BRITTLE
    if [[ "$links" == "links" ]]; then
        sudo ln -snf "$dest" "/$name"
    fi
}

validate_namespace_syntax() {
    local name="$1"
    local owned="$2"
    local by="$3"
    local owner="$4"

    if [[ -z "${name:-}" ]]; then
        error "namespace syntax: namespace NAME [owned by OWNER]"
        return 1
    fi

    if [[ -n "$owned" || -n "$by" || -n "$owner" ]]; then
        if [[ "$owned" != "owned" ]]; then
            error "namespace expected 'owned', got '$owned'"
            return 1
        fi

        if [[ "$by" != "by" ]]; then
            error "namespace expected 'by', got '$by'"
            return 1
        fi

        if [[ -z "$owner" ]]; then
            error "namespace missing owner"
            return 1
        fi
    fi
}

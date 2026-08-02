namespace() {
    local name="$1"
    local owned="${2:-}"
    local by="${3:-}"
    local owner="${4:-}"

    validate_namespace_syntax "$name" "$owned" "$by" "$owner" || return 1

    case "$name" in
        data|etc|exe|repo|log|net|svc|cron)
            local target="/$name"

            create_dir "$target"

            if [[ -n "$owner" ]]; then
                sudo chown "$(resolve_owner "$owner")" "$target"
            fi
            ;;
        *)
            error "Unknown namespace: $name"
            return 1
            ;;
    esac
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

resolve_owner() {
    local owner="$1"

    case "$owner" in
        me) echo "$USER"  ;;
        *)  echo "$owner" ;;
    esac
}


sync() {
    local target="${1:-}"
    local prep="${2:-}"
    local source="${3:-}"

    if [[ -z "$target" ]]; then
        error "sync syntax: sync TARGET [from|with SOURCE]"
        return 0
    fi

    # Explicit source binding
    if [[ -n "$prep" ]]; then

        case "$prep" in

            # Git-backed import
            from)
                if [[ -z "$source" ]]; then
                    error "sync syntax: sync TARGET from SOURCE"
                    return 0
                fi

                source=$(normalize_git_url "$source")
                ;;


            # Bidirectional replica synchronization
            with)
                if [[ -z "$source" ]]; then
                    error "sync syntax: sync TARGET with PEER"
                    return 0
                fi

                if [[ "$source" == ssh://* ]]; then
                    sync_unison "$target" "$source"
                    return 0
                fi

                error "Unsupported sync peer: $source"
                return 0
                ;;


            *)
                error "sync expected preposition 'from' or 'with', got '$prep'"
                return 0
                ;;

        esac

    else
        # Intent B: Discover source from existing target metadata
        if [[ ! -d "$target/.git" ]]; then
            error "Cannot sync '$target' without a source: directory is not a git repository"
            return 0
        fi

        source=$(git -C "$target" config --get remote.origin.url 2>/dev/null)

        if [[ -z "$source" ]]; then
            error "Cannot sync '$target': no remote origin URL configured"
            return 0
        fi

        source=$(normalize_git_url "$source")
    fi


    # Target directory preparation
    if [[ ! -d "$target" ]]; then
        if ! create_dir "$target"; then
            error "Failed to create target directory $target"
            return 0
        fi
    fi


    # Dispatch git clone/update based on contents
    if [[ -z "$(ls -A "$target" 2>/dev/null)" ]]; then
        sync_clone "$target" "$source"
    else
        sync_existing "$target" "$source"
    fi
}

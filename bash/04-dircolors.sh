# =============================================================================
# Bash configuration — dircolors
# =============================================================================

if [[ -x /usr/bin/dircolors ]]; then
    debug "loading dircolors"

    if [[ -r $HOME/.dircolors ]]; then
        eval "$(dircolors -b "$HOME/.dircolors")"
    else
        eval "$(dircolors -b)"
    fi

    debug "loaded dircolors"
fi

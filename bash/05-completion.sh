# =============================================================================
# Bash configuration — completion
# =============================================================================

if ! shopt -oq posix; then
    if import /usr/share/bash-completion/bash_completion; then
        debug "loaded bash-completion"
    elif import /etc/bash_completion; then
        debug "loaded bash-completion"
    fi
fi

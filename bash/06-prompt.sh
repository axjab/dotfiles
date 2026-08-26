# =============================================================================
# Bash configuration — prompt
# =============================================================================

__bashrc_prompt_fallback() {
    [[ -z ${debian_chroot:-} && -r /etc/debian_chroot ]] &&
        debian_chroot=$(< /etc/debian_chroot)

    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '

    case $TERM in
        xterm*|rxvt*)
            PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
            ;;
    esac
}

if has starship; then
    activate starship init bash
else
    __bashrc_prompt_fallback
fi

debug "loaded prompt"

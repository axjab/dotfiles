# -----------------------------------------------
# LESSPIPE
# Makes less handle non-text files (binaries, archives, etc.)
# -----------------------------------------------
[[ -x /usr/bin/lesspipe ]] && eval "$(SHELL=/bin/sh lesspipe)"

debug "loaded lesspipe"

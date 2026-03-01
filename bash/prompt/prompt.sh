
#################################
# TO EXECUTE AFTER EACH COMMAND #
#################################

# TODO: put that shit in XML or YAML

# Capture last exit status, MUST BE AT THE TOP
LAST_EXIT=$?

# Define colors
BOLD='\[\033[1m\]'
GREEN='\[\033[0;32m\]'
RED='\[\033[0;31m\]'
BRIGHT_YELLOW='\[\033[1;33m\]'
MAGENTA='\[\033[0;35m\]'      # Magenta color for untracked files
CYAN='\[\033[0;36m\]'         # Cyan color for modified but unstaged
BLUE='\[\033[0;34m\]'         # Blue color for staged but uncommitted
RESET='\[\033[0m\]'           # Reset color to default

# Other
PROMPT_SYMBOL='$'

main() {
	ip="$(get-ip 2>&1)"
   # who's the host?
   host="\h"
   # in the future, have unique symbol for general context
   symbol="$LAST_EXIT"
   # build time in WnnThh:mm
   # time="\[\e[90m\]W\[\e[92m\]$(date +%V)\[\e[90m\]T\[\e[92m\]$(date +'%H%M')\[\e[0m\]" # ORIGINAL
   time="\[\033[92m\]$(date +'%H:%M')\[\033[0m\]"
   # build current path
   path="${CYAN}${BOLD}\w${RESET}"
   # color the '$' symbol
   exit_indicator=$(build_exit_indicator)
   # get a report of the current repo, if there is one
   git_status_report=$(git_status_report)
   # Done! PS1 is ready
   PS1="$time $host [$ip] $git_status_report ---------------------\n$path $exit_indicator "
}

get-ip() {
  ip route get 1.1.1.1 | \
  awk -F"src " 'NR == 1{ split($2, a," ");print a[1]}'
}

build_exit_indicator() {
    if [ $LAST_EXIT -eq 0 ]; then
        status="\[\[\e[1m\]$PROMPT_SYMBOL${RESET}\]"
    else
        status="\[${RED}\[\e[1m\]$LAST_EXIT$PROMPT_SYMBOL${RESET}\]"
    fi

    echo $status
}

### Function to build Git status report
git_status_report() {
    if git rev-parse --is-inside-work-tree &>/dev/null; then
        local branch
        local ahead
        local behind
        local untracked
        local modified
        local status=""

        # Get current branch name
        branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "unknown-branch")

        # Get the status output once and reuse it
        local git_status_output
        git_status_output=$(git status --porcelain)

        # Check for different types of changes
        untracked=$(echo "$git_status_output" | grep '^??' | wc -l)
        modified=$(echo "$git_status_output" | grep '^\s*[AMD]\s' | wc -l)

        # Get the number of commits ahead and behind the upstream branch
        ahead=$(git rev-list --count HEAD ^@{upstream} 2>/dev/null || echo 0)
        behind=$(git rev-list --count @{upstream} ^HEAD 2>/dev/null || echo 0)

        # Build status message based on changes
        if [ "$untracked" -gt 0 ]; then
            status+="\[$MAGENTA\]⊕${untracked}\[$RESET\] "
        fi

        if [ "$modified" -gt 0 ]; then
            status+="\[$CYAN\]✎${modified}\[$RESET\] "
        fi

        # Show red circle if there are modified files, otherwise show green checkmark
        if [ "$modified" -gt 0 ]; then
            status+="\[$RED\]●\[$RESET\] $branch"
        else
            status+="\[$GREEN\]✓\[$RESET\] $branch"
        fi

        if [ "$ahead" -gt 0 ] || [ "$behind" -gt 0 ]; then
            status+=" \[$BRIGHT_YELLOW\](${ahead}↑${behind}↓)\[$RESET\]"
        fi

        echo "$status"
    fi
}

main

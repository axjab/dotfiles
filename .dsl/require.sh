#!/usr/bin/env bash
# =============================================================================
# require — host prerequisites
#
#   require internet
#   require tailnet
#
# Each prerequisite is an explicit language keyword with its own handler.
# =============================================================================

require() {
    if [[ $# -ne 1 ]]; then
        error "require: expected exactly one prerequisite"
        return 2
    fi

    case "$1" in
        internet)   _require_internet ;;
        tailnet)    _require_tailnet  ;;
        keys)       _require_keys     ;;
        ssh)        _require_ssh      ;;
        github)     _require_github   ;;
        repository) echo "" ;;
    esac

    return $?
}

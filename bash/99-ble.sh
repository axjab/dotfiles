# ble.sh installation/activation helper.
#
# This file is intended to be imported/sourced from the END of ~/.bashrc.
#
# The ble.sh source operation intentionally happens at top level rather than
# inside a function. This follows ble.sh's recommended initialization pattern.

# ---------------------------------------------------------------------------
# Preconditions
# ---------------------------------------------------------------------------

if [[ $- != *i* ]]; then
    debug "ble.sh: non-interactive shell; skipping"
    return 0
fi

if [[ ${BLE_VERSION-} ]]; then
    debug "ble.sh: already loaded (version ${BLE_VERSION})"
    return 0
fi

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

_blesh_cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}"
_blesh_cache_file="$_blesh_cache_dir/blesh-install"
_blesh_install_root="$HOME/.local/share"
_blesh_path="$_blesh_install_root/blesh/ble.sh"

debug "ble.sh: cache file: $_blesh_cache_file"
debug "ble.sh: installation path: $_blesh_path"

# ---------------------------------------------------------------------------
# Read / obtain installation decision
# ---------------------------------------------------------------------------

if [[ -r $_blesh_cache_file ]]; then
    IFS= read -r _blesh_answer < "$_blesh_cache_file"

    case $_blesh_answer in
        yes|no)
            debug "ble.sh: using cached installation decision: $_blesh_answer"
            ;;
        *)
            debug "ble.sh: invalid cached decision; asking again"
            _blesh_answer=
            ;;
    esac
fi

if [[ -z $_blesh_answer ]]; then
    printf 'Install ble.sh? [y/N] '

    if ! IFS= read -r _blesh_input; then
        debug "ble.sh: unable to read installation decision; treating as no"
        _blesh_answer=no
    else
        case $_blesh_input in
            y|Y|yes|YES|Yes|yEs|yeS|YEs|yES|YeS)
                _blesh_answer=yes
                ;;
            *)
                _blesh_answer=no
                ;;
        esac
    fi

    debug "ble.sh: user installation decision: $_blesh_answer"

    if ! mkdir -p "$_blesh_cache_dir"; then
        warn "ble.sh cache directory could not be created"
        unset _blesh_cache_dir _blesh_cache_file _blesh_install_root \
            _blesh_path _blesh_answer _blesh_input
        return 0
    fi

    # Write the decision atomically so a partially written cache file cannot
    # accidentally become the decision for a future shell.
    _blesh_cache_tmp="${_blesh_cache_file}.$$"

    if ! printf '%s\n' "$_blesh_answer" > "$_blesh_cache_tmp" ||
       ! mv -f -- "$_blesh_cache_tmp" "$_blesh_cache_file"; then
        rm -f -- "$_blesh_cache_tmp"
        warn "ble.sh installation decision could not be cached"
        unset _blesh_cache_dir _blesh_cache_file _blesh_install_root \
            _blesh_path _blesh_answer _blesh_input _blesh_cache_tmp
        return 0
    fi

    debug "ble.sh: cached installation decision: $_blesh_answer"
fi

if [[ $_blesh_answer != yes ]]; then
    debug "ble.sh: installation declined"
    unset _blesh_cache_dir _blesh_cache_file _blesh_install_root \
        _blesh_path _blesh_answer _blesh_input
    return 0
fi

# ---------------------------------------------------------------------------
# Installation
# ---------------------------------------------------------------------------

if [[ -f $_blesh_path ]]; then
    debug "ble.sh: installed copy already exists"
else
    debug "ble.sh: installed copy is absent; checking dependencies"

    if ! command -v curl >/dev/null 2>&1; then
        warn "ble.sh requires curl"
        unset _blesh_cache_dir _blesh_cache_file _blesh_install_root \
            _blesh_path _blesh_answer _blesh_input
        return 0
    fi

    if ! command -v tar >/dev/null 2>&1; then
        warn "ble.sh requires tar"
        unset _blesh_cache_dir _blesh_cache_file _blesh_install_root \
            _blesh_path _blesh_answer _blesh_input
        return 0
    fi

    if ! command -v mktemp >/dev/null 2>&1; then
        warn "ble.sh installation requires mktemp"
        unset _blesh_cache_dir _blesh_cache_file _blesh_install_root \
            _blesh_path _blesh_answer _blesh_input
        return 0
    fi

    _blesh_tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/blesh.XXXXXXXX") || {
        warn "unable to create a temporary directory for ble.sh"
        unset _blesh_cache_dir _blesh_cache_file _blesh_install_root \
            _blesh_path _blesh_answer _blesh_input _blesh_tmpdir
        return 0
    }

    debug "ble.sh: temporary directory: $_blesh_tmpdir"
    debug "ble.sh: downloading nightly release"

    # Keep the download/extraction itself silent on success.
    #
    # pipefail is enabled in this subshell so a curl failure cannot be hidden
    # by tar subsequently exiting successfully.
    if ! (
        set -o pipefail

        curl -fsSL \
            'https://github.com/akinomyoga/ble.sh/releases/download/nightly/ble-nightly.tar.xz' |
            tar xJf - -C "$_blesh_tmpdir"
    ) >/dev/null 2>&1; then
        rm -rf -- "$_blesh_tmpdir"
        warn "ble.sh nightly release could not be downloaded"
        unset _blesh_cache_dir _blesh_cache_file _blesh_install_root \
            _blesh_path _blesh_answer _blesh_input _blesh_tmpdir
        return 0
    fi

    debug "ble.sh: nightly release downloaded"

    if [[ ! -f $_blesh_tmpdir/ble-nightly/ble.sh ]]; then
        rm -rf -- "$_blesh_tmpdir"
        warn "ble.sh nightly archive did not contain ble.sh"
        unset _blesh_cache_dir _blesh_cache_file _blesh_install_root \
            _blesh_path _blesh_answer _blesh_input _blesh_tmpdir
        return 0
    fi

    debug "ble.sh: installing into $_blesh_install_root"

    # The official installation mechanism.
    if ! bash "$_blesh_tmpdir/ble-nightly/ble.sh" \
        --install "$_blesh_install_root" >/dev/null 2>&1; then
        rm -rf -- "$_blesh_tmpdir"
        warn "ble.sh installation failed"
        unset _blesh_cache_dir _blesh_cache_file _blesh_install_root \
            _blesh_path _blesh_answer _blesh_input _blesh_tmpdir
        return 0
    fi

    rm -rf -- "$_blesh_tmpdir"
    _blesh_tmpdir=

    debug "ble.sh: installation command completed"
fi

# ---------------------------------------------------------------------------
# Verify installation
# ---------------------------------------------------------------------------

if [[ ! -f $_blesh_path ]]; then
    warn "ble.sh installation completed but ble.sh was not found"
    unset _blesh_cache_dir _blesh_cache_file _blesh_install_root \
        _blesh_path _blesh_answer _blesh_input _blesh_tmpdir
    return 0
fi

debug "ble.sh: verified installed file: $_blesh_path"

# ---------------------------------------------------------------------------
# Load ble.sh
#
# IMPORTANT:
#   This must remain at top level.
#
#   Do not put this source operation back inside a function. The ble.sh
#   documentation specifically recommends sourcing it directly from .bashrc.
#
#   Also intentionally do NOT redirect stdin/stdout/stderr here. ble.sh needs
#   the normal controlling TTY for reliable initialization.
# ---------------------------------------------------------------------------

debug "ble.sh: loading with --attach=none"

source -- "$_blesh_path" --attach=none
_blesh_source_status=$?

if (( _blesh_source_status != 0 )); then
    warn "ble.sh failed to load"
    unset _blesh_cache_dir _blesh_cache_file _blesh_install_root \
        _blesh_path _blesh_answer _blesh_input _blesh_tmpdir \
        _blesh_source_status
    return 0
fi

if [[ ! ${BLE_VERSION-} ]]; then
    warn "ble.sh loaded but did not initialize"
    unset _blesh_cache_dir _blesh_cache_file _blesh_install_root \
        _blesh_path _blesh_answer _blesh_input _blesh_tmpdir \
        _blesh_source_status
    return 0
fi

debug "ble.sh: loaded successfully (version ${BLE_VERSION})"

# ---------------------------------------------------------------------------
# Attach
#
# This file belongs at the END of ~/.bashrc, so this is the final ble.sh
# initialization step, matching the upstream recommended configuration.
#
# Again, do not redirect the standard streams.
# ---------------------------------------------------------------------------

debug "ble.sh: attaching"

ble-attach
_blesh_attach_status=$?

if (( _blesh_attach_status != 0 )); then
    warn "ble.sh failed to attach"
    unset _blesh_cache_dir _blesh_cache_file _blesh_install_root \
        _blesh_path _blesh_answer _blesh_input _blesh_tmpdir \
        _blesh_source_status _blesh_attach_status
    return 0
fi

debug "ble.sh: successfully installed, loaded, and attached"

# ---------------------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------------------

unset _blesh_cache_dir _blesh_cache_file _blesh_install_root \
    _blesh_path _blesh_answer _blesh_input _blesh_tmpdir \
    _blesh_source_status _blesh_attach_status

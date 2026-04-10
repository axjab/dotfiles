#!/bin/bash
# =============================================================================
# XDG User Dirs Override
# Symlinks custom XDG config, but only on machines with a display.
# Always confirms changes with the user before applying.
# =============================================================================

set -euo pipefail

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
YLW='\033[0;33m'
GRN='\033[0;32m'
CYN='\033[0;36m'
DIM='\033[2m'
BLD='\033[1m'
RST='\033[0m'

info() { echo -e "  ${CYN}→${RST}  $1"; }
ok()   { echo -e "  ${GRN}✓${RST}  $1"; }
warn() { echo -e "  ${YLW}⚠${RST}  $1"; }
die()  { echo -e "\n  ${RED}✗  $1${RST}\n"; exit 1; }

# ── Headless detection ────────────────────────────────────────────────────────
# is_headless() {
#     # No DISPLAY or WAYLAND_DISPLAY env vars
#     if [ -z "${DISPLAY:-}" ] && [ -z "${WAYLAND_DISPLAY:-}" ]; then
#         return 0
#     fi
#     # No logged-in graphical session via loginctl
#     if command -v loginctl &>/dev/null; then
#         if ! loginctl list-sessions 2>/dev/null | grep -qE 'x11|wayland|mir'; then
#             return 0
#         fi
#     fi
#     return 1
# }

is_headless() {
    if [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ]; then
        return 1  # has display
    fi
    return 0  # headless
}

# ── Confirm helper ────────────────────────────────────────────────────────────
confirm() {
    local prompt="$1"
    local answer
    echo -en "  ${YLW}?${RST}  ${prompt} ${DIM}[y/N]${RST} "
    read -r answer
    [[ "$answer" =~ ^[Yy]$ ]]
}

# ── Main ──────────────────────────────────────────────────────────────────────
echo ""
echo -e "  ${BLD}XDG Directory Override${RST}"
echo -e "  ${DIM}host: $(hostname)${RST}"
echo ""

# Guard: headless check
if is_headless; then
    warn "No display detected — this machine appears to be headless."
    warn "XDG overrides are only meaningful on desktop environments."
    echo ""
    die "Aborting. Run this script on a machine with a display."
fi

ok "Display detected — desktop environment present."
echo ""

# ── Show planned changes ──────────────────────────────────────────────────────
echo -e "  ${BLD}Planned changes:${RST}"
echo ""

# Directories to create
echo -e "  ${DIM}Create directories:${RST}"
info "\$HOME/dump"
info "\$HOME/dump/docs"
echo ""

# Symlinks to create
echo -e "  ${DIM}Symlinks (existing files will be backed up):${RST}"
info "$HOME/.config/user-dirs.dirs   →  $HOME/etc/xdg/dirs"
info "$HOME/.config/user-dirs.locale →  $HOME/etc/xdg/locale"
echo ""

# Verify sources exist
MISSING=0
for src in "$HOME/etc/xdg/dirs" "$HOME/etc/xdg/locale"; do
    if [ ! -e "$src" ]; then
        warn "Source does not exist: $src"
        MISSING=1
    fi
done

[ $MISSING -eq 1 ] && die "Source files missing — cannot proceed."

# ── Confirm ───────────────────────────────────────────────────────────────────
confirm "Apply these changes?" || { echo ""; info "Aborted — no changes made."; echo ""; exit 0; }
echo ""

# ── Apply ─────────────────────────────────────────────────────────────────────

# Create dirs
for dir in "$HOME/dump" "$HOME/dump/docs"; do
    if [ -d "$dir" ]; then
        info "Already exists: $dir"
    else
        mkdir -v "$dir" && ok "Created: $dir"
    fi
done

echo ""

# Symlink helper — backs up existing file before linking
make_link() {
    local src="$1"
    local dst="$2"

    if [ -L "$dst" ]; then
        info "Removing existing symlink: $dst"
        rm "$dst"
    elif [ -e "$dst" ]; then
        local backup="${dst}.bak.$(date +%Y%m%d_%H%M%S)"
        warn "Backing up existing file: $dst → $backup"
        mv "$dst" "$backup"
    fi

    ln -sv "$src" "$dst" && ok "Linked: $dst → $src"
}

make_link "$HOME/etc/xdg/dirs"   "$HOME/.config/user-dirs.dirs"
make_link "$HOME/etc/xdg/locale" "$HOME/.config/user-dirs.locale"

echo ""

# ── Update XDG ────────────────────────────────────────────────────────────────
info "Running xdg-user-dirs-update..."
if command -v xdg-user-dirs-update &>/dev/null; then
    xdg-user-dirs-update && ok "xdg-user-dirs-update complete."
else
    warn "xdg-user-dirs-update not found — skipping."
fi

# ── Mask XDG service ──────────────────────────────────────────────────────────
info "Masking XDG user-dirs service and timer..."
systemctl --user mask xdg-user-dirs-update.service && ok "Masked: xdg-user-dirs-update.service"
systemctl --user mask xdg-user-dirs-update.timer   && ok "Masked: xdg-user-dirs-update.timer"

echo ""
ok "Done."
echo ""

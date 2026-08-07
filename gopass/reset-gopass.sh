#!/usr/bin/env bash
set -euo pipefail

echo "== Killing GPG processes =="
gpgconf --kill gpg-agent 2>/dev/null || true
gpgconf --kill dirmngr 2>/dev/null || true
pkill -f pinentry 2>/dev/null || true
pkill -f gpg-agent 2>/dev/null || true

echo "== Removing gopass state =="
rm -rf ~/.local/share/gopass
rm -rf ~/.cache/gopass

echo "== Removing secrets store =="
rm -rf /data/secrets

echo "== Reloading GPG agent =="
gpgconf --launch gpg-agent

echo "== Setting GPG_TTY =="
export GPG_TTY="$(tty)"

echo
echo "Reset complete."
echo "Next steps:"
echo "  1. Verify GPG:"
echo "       gpg --list-secret-keys"
echo
echo "  2. Reinitialize/import your gopass store:"
echo "       gopass setup"
echo
echo "  3. Test:"
echo "       gopass show github/token"

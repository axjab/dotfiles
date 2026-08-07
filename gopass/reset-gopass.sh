#!/bin/bash

# Some corruption shit going on
# Run this if gopass hangs

gpgconf --kill gpg-agent
rm -rf ~/.local/share/gopass
rm -rf ~/.cache/gopass

echo "gopass show github/token"

#!/bin/bash

# SOURCE MACHINE COMMANDS


~/etc/export

# TARGET MACHINE COMMANDS

# BETTER: curl alj.cx/import-config.sh
      git clone https://github.com/axjab/dotfiles ~/env    
      run ~/env/rebuild
      gpg --import ~/gopass.key
      # test
      rm ~/gopass.key  # if successful

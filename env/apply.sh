#!/bin/bash

CFG=$HOME/etc/env

gum confirm ".env WILL BE REPLACED" \
&& gopass process $CFG/template.env > $HOME/.env \
&& chmod 600 $HOME/.env

ln -siv $CFG/aliases   $HOME/.aliases
ln -siv $CFG/bashrc    $HOME/.bashrc

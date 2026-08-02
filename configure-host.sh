#!/usr/bin/env bash
set -euo pipefail

ETC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$ROOT/.bin"		# contains dependencies
DSL="$ROOT/.dsl"		# contains language definitions

export GUM_SPIN_SPINNER=meter
export GUM_SPIN_ALIGN=left
export GUM_SPIN_TIMEOUT=300s
# export GUM_SPIN_PADDING="1 0"
# GUM_SPIN_SHOW_OUTPUT=true
export GUM_SPIN_SHOW_ERROR=true

for dsl in "$DSL"/*.sh; do
    source "$dsl"
done

##############################################################

# HOST IDENTITY FILESYSTEM
#  https://chatgpt.com/s/t_6a6dcd921f788191b90ef1b6395ab86e

namespace etc    			# Configuration
namespace data   			# Mutable state
namespace repo 			    # Shared file repository
namespace exe 	owned by me # Non-system executables
namespace log   owned by me # Non-system log aggregation
namespace net   owned by me # Network topology
namespace svc   owned by me # Services provided by this host
namespace cron  owned by me # Recurring jobs

# WIP: what are the GREAT namespaces of a universal file server?
# As for /fs or /repo:
# /act: active work (workspace)
# /archive: cold storage
# /dump: inbox or unsorted
# /srv: anything served (assets, html, data, etc.)
# /wiki: knowledge base

# ENVIRONMENT
process	 shell/env 	to $HOME/.env
pull 'github.com/axjab/executables' to /exe
install exe-path in sudoers <<-EOF
	Defaults secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/exe"
EOF

## SHELL
symlink	 shell/aliases to ~/.aliases
symlink	 shell/bashrc  to ~/.bashrc

## FILESYSTEM
mount nfs majula:/mnt/ssd 		onto /mnt/majula.ssd
mount dir /mnt/majula.ssd/files onto /repo

## APPLICATIONS
symlink helix/config.yaml	to ~/.config/helix/config.yaml
symlink helix/lang.toml		to ~/.config/helix/languages.toml
process aichat/config.yaml 	to ~/.config/aichat/config.yaml
symlink gh/config.yml		to ~/.config/gh/config.yml
symlink git/config			to /etc/gitconfig
symlink gopass/config		to ~/.config/gopass/config
symlink sqlite/config		to ~/.sqliterc
symlink starship/config		to ~/.config/starship.toml
process taskdog/cli.toml    to ~/.config/taskdog/cli.toml
symlink xdg/dirs			to ~/.config/user-dirs.dirs
# symlink xdg/locale			to ~/.config/locale.conf  # verify; may be /etc/locale.conf

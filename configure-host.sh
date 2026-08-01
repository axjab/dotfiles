#!/usr/bin/env bash
set -euo pipefail

ETC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$ROOT/.bin"		# contains dependencies
DSL="$ROOT/.dsl"		# contains language definitions

GUM_SPIN_SPINNER=meter
GUM_SPIN_ALIGN=left
GUM_SPIN_TIMEOUT=300s
GUM_SPIN_PADDING="1 0"

for dsl in "$DSL"/*.sh; do
    source "$dsl"
done

##############################################################

# HOST IDENTITY FILESYSTEM
#  https://chatgpt.com/s/t_6a6dcd921f788191b90ef1b6395ab86e

namespace data   # Mutable state
namespace etc    # Configuration
namespace exe    # Non-system executables
namespace repo   # Shared file repository
namespace log    # Non-system log aggregation
namespace net    # Network topology
namespace svc    # Services provided by this host
namespace cron   # Recurring jobs

# WIP: what are the GREAT namespaces of a universal file server?
# As for /fs or /repo:
# /act: active work (workspace)
# /archive: cold storage
# /dump: inbox or unsorted
# /srv: anything served (assets, html, data, etc.)
# /wiki: knowledge base

## SHELL
# create_env shell/env
symlink	 shell/aliases to $HOME/.aliases
symlink	 shell/bashrc  to $HOME/.bashrc
process	 shell/env 	   to $HOME/.env

## FILESYSTEM
mount_nfs majula:/mnt/ssd 		onto /mnt/majula.ssd
mount_ext /mnt/majula.ssd/files onto /repo


# TODO:

# deploy.yaml
# files:
#   # aichat
#   - source: aichat/config.yaml
#     destination: ~/.config/aichat/config.yaml
#     template: true
#     mode: "600"
# 
#   # env
#   - source: env/aliases
#     destination: ~/.aliases
#     link: true
# 
#   - source: env/bashrc
#     destination: ~/.bashrc
#     link: true
# 
#   - source: env/template.env
#     destination: ~/.env
#     template: true
#     mode: "600"
# 
#   # gh
#   - source: gh/config.yml
#     destination: ~/.config/gh/config.yml
#     link: true
#     template: false
# 
#   # git
#   - source: git/config
#     destination: ~/.config/git/config
#     link: true
#     template: false
# 
#   # gopass
#   - source: gopass/config
#     destination: ~/.config/gopass/config
#     link: true
#     template: false
# 
#   # sqlite
#   - source: sqlite/config
#     destination: ~/.sqliterc
#     link: true
#     template: false
# 
#   # ssh
#   - source: ssh/config
#     destination: ~/.ssh/config
#     template: false
#     mode: "600"
# 
#   # starship
#   - source: starship/config
#     destination: ~/.config/starship.toml
#     link: true
# 
#   # taskdog
#   - source: taskdog/cli.toml
#     destination: ~/.config/taskdog/cli.toml  # verify
#     link: true

  # xdg
  # - source: xdg/dirs
  #   destination: ~/.config/user-dirs.dirs
  #   link: true
  #   template: false

  # - source: xdg/locale
  #   destination: ~/.config/locale.conf  # verify; may be /etc/locale.conf
  #   link: true
  #   template: false

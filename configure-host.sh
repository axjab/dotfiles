#!/usr/bin/env bash
set -euo pipefail

ETC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DSL_DIR="$ETC_DIR/DSL"

for dsl in "$DSL_DIR"/*.sh; do
    source "$dsl"
done

##############################################################

mount_nfs majula:/mnt/ssd onto /mnt/majula.ssd


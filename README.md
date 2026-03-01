
# CONFIG V2

Date: 2026-03-01

My bash shell has become too slow from all the bloat and misconfiguration.
I have decided to nuke nearly everything and start fresh.
From now on, configs must be seriously documented. Nothing left to mememory.

## RULES

Structure must be simple.

### Aliases

Aliases are stored in `~/cfg/bash/alias`, linked to from ~/.alias by apply.sh, and sourced from ~/.bashrc

## TODO

- [ ] Write an `apply.sh` script, which will automatically apply the configs stored here.
Use like this:
1. Download cfg
2. ~/cfg/apply

Expected outcome, all settings appliedvia symlinks

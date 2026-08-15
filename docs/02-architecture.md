
# Hostcfg Architecture

## Repository

Repository root:

    ~/etc

$ROOT is established by the rebuild entrypoint.

## Runtime

hostcfg is responsible for:

1. establishing HOSTFILE
2. establishing ROOT
3. establishing repository environment
4. loading .dsl/*.sh
5. providing runtime helpers
6. performing bootstrap/self-update
7. sourcing the Hostfile

The Hostfile describes desired state.
Runtime/bootstrap implementation does not belong in the Hostfile.

## Repository layout

$ROOT/
    Hostfile
    .dsl/
    .bin/
    .cache/

## Persistent state

General runtime state:

    $ROOT/.cache/state.json

Host state:

    $ROOT/.cache/host/state.json

## DSL loading

DSL implementations live under:

    $ROOT/.dsl/

They are sourced by the runtime before the Hostfile is evaluated.

## Architectural boundaries

Hostfile:
    what

DSL primitives:
    how individual declarations converge state

Runtime:
    bootstrap and execution environment

Hooks:
    provider-specific external capability establishment

State:
    minimal persistence required for convergence

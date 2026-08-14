# Current State

This file is mutable. Verify important details against the code when code is
available.

## Repository

Repository: `~/etc`

`$ROOT` is established by the rebuild entrypoint.

DSL implementations live under:

    $ROOT/.dsl/

General runtime state:

    $ROOT/.cache/state.json

Host state:

    $ROOT/.cache/host/state.json

## Current Hostfile order

    require internet
    require tailnet
    require keys
    require ssh
    require github
    require repository

    namespace ...

    sync ...

    install ...

    host ...

    host service ...

    configuration ...

Namespaces and repository/executable bootstrap intentionally happen early.

## Known implementation notes

`require` currently has explicit handlers rather than generic dependency
machinery.

`require repository` is intentionally not implemented.

The exact implementation of each primitive should be verified from the
provided source before modifying it.

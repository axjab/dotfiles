# Hostfile DSL

## General form

    VERB TARGET [PREPOSITION VALUE]

Mandatory target is `$1`.

## require

    require KEY

Current requirements:

    require internet
    require tailnet
    require keys
    require ssh
    require github
    require repository

`repository` is currently out of scope.

Requirements are explicit keywords, not a generic dependency system.

## namespace

    namespace NAME
    namespace NAME owned by OWNER

Namespaces establish filesystem roles used by later declarations.

## sync

    sync TARGET from SOURCE
    sync TARGET to DESTINATION
    sync TARGET with SOURCE
    sync TARGET

Examples:

    sync ~/etc from 'github:axjab/dotfiles'
    sync /exe from 'github:axjab/executables'
    sync /data/secrets from 'github:axjab/secrets'
    sync /data/helix with 'ssh://majula//data/helix'

## install

    install NAME in NAMESPACE <<-EOF
        ...
    EOF

Example:

    install exe-path in sudoers <<-EOF
        Defaults secure_path="..."
    EOF

The sudoers implementation validates with `visudo` and only changes the
target when its contents differ.

## host

    host NAME [at IP]
        ...
    :

Example:

    host xenon at 100.109.130.76
        is gaming pc
        user ash
        os PikaOS
        de Niri
    :

Host declarations preserve unspecified existing metadata.

`is` replaces existing tags when explicitly supplied.

`user`, `os`, and `de` preserve their previous values when omitted.

An unknown IP is valid. Never fabricate `127.0.0.1`.

## host service

    host service NAME at HOST

Example:

    host service nats at majula

`service` is a subcommand of `host`.

## Other directives

The current Hostfile also uses:

    link
    process
    mount
    symlink
    set

Their exact semantics should be taken from their implementation rather
than guessed from their names.

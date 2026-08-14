# Hostfile — Permanent Rules

This is a personal Bash DSL for declaring the desired state of a Unix host.

The DSL is a language-design exercise first and Bash programming second.

Optimize for:

1. elegance
2. readability
3. simplicity
4. correctness
5. familiar Unix conventions

The Hostfile should read like configuration, not imperative shell code.

Keep the language small. Do not add abstractions unless they make the DSL
itself better.

## Syntax

Every primitive puts its mandatory target in `$1`.

General form:

    VERB <TARGET> [PREPOSITION VALUE]

Use explicit syntax. Do not infer syntax from stdin, heredocs, timing,
pipes, file descriptors, or interactive behavior.

Scoped constructs use:

    :

as the terminator.

`:` is an ordinary Bash function.

Concepts that naturally belong under an existing command should be
subcommands rather than new top-level verbs.

For example:

    host service NAME at HOST

`service` is a `host` subcommand.

## Bash

Everything must work under:

    set -euo pipefail

Expected failures must be explicitly handled.

Do not let `grep`, `cmp`, connectivity tests, SSH tests, authentication
checks, or other expected failures accidentally terminate the rebuild.

Successful functions must have an unambiguous successful return status.

Prefer ordinary Bash functions, `local` variables, small helpers, and
direct `case` statements.

Do not introduce:

- frameworks
- registries
- dispatch tables
- parser generators
- object-oriented designs
- generic DSL machinery
- unnecessary state machines
- unnecessary abstractions

## State

`$ROOT` is authoritative. Never invent another way to discover it.

Keep state minimal and owned by the thing that needs it.

Do not invent state locations casually.

Prefer idempotent operations. If the desired state already exists, do
nothing.

Do not silently overwrite unrelated user configuration.

## Output

Use the existing `msg` and `error` helpers.

Keep normal output concise.

Do not reimplement project-wide output styling inside primitives.

For interaction, prefer `gum`.

## Development

When code is available, inspect the actual code before making claims about
its implementation.

Do not pretend to have inspected files that were not provided.

When the specification and implementation disagree, point out the
disagreement rather than silently inventing behavior.

Before implementing something, settle:

- syntax
- semantics
- state
- side effects
- idempotence
- failure behavior

Then implement the smallest solution.


# Hostcfg Constitution

Hostcfg is a personal Bash DSL for declaring desired state
of Unix hosts.

The DSL is a language-design exercise first and Bash programming
second.

Optimize, in order:

1. elegance
2. readability
3. simplicity
4. correctness
5. familiar Unix conventions

The Hostfile should read like configuration, not imperative shell.

Keep the language small.

Do not introduce abstractions unless they make the DSL itself better.

## Syntax principles

Every primitive puts its mandatory local target in $1.

Prefer:

    VERB TARGET [PREPOSITION VALUE]

Use explicit syntax.

Do not infer syntax from:

- stdin
- heredocs
- timing
- pipes
- file descriptors
- interactive behavior

Concepts that naturally belong under an existing command should
be subcommands rather than new top-level verbs.

## Implementation principles

Everything must work under:

    set -euo pipefail

Expected failures must be explicitly handled.

Prefer:

- ordinary Bash functions
- local variables
- small helpers
- direct case statements
- direct filesystem operations

Avoid:

- frameworks
- registries
- dispatch tables
- parser generators
- object-oriented designs
- generic DSL machinery
- unnecessary state machines
- unnecessary abstractions

## State

$ROOT is authoritative.

Do not invent alternate ways to discover it.

Keep persistent state minimal and owned by the thing that needs it.

Prefer idempotent operations.

Do not silently overwrite unrelated user configuration.

## Output

Use existing project output helpers.

Keep normal output concise.

Prefer gum for interaction.

## Development rule

When actual source is available, inspect it before making claims.

Never treat a prompt description as evidence that an implementation exists.

When specification and implementation disagree, identify the disagreement.
Do not silently reconcile them.

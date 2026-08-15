# Hostcfg / Hostfile — Session Handoff

## Purpose

`hostcfg` is a small Unix-oriented Bash configuration system.

The **Hostfile is a DSL**, not a shell-script collection. It should describe desired state; implementation details belong in the runtime and DSL primitives.

Priorities:

1. elegance
2. readability
3. simplicity
4. correctness
5. familiar Unix conventions

Keep the language small and explicit. Avoid frameworks, registries, dispatch tables, generic dependency systems, parser generators, or unnecessary abstractions.

Everything must work under:

```bash
set -euo pipefail
```

Expected failures must be explicitly handled.

Use existing `msg` / `warn` / `error` helpers. Prefer `gum` for interaction.

---

# `hostcfg`

Current runtime:

```bash
#!/usr/bin/env bash
set -euo pipefail

export HOSTFILE="${HOSTFILE:-${HOME}/etc/Hostfile}"
export ROOT
ROOT="$(dirname "${HOSTFILE}")"

export BIN="${ROOT}/.bin"
export DSL="${ROOT}/.dsl"
export gum="${BIN}/gum"

export GUM_SPIN_SPINNER=meter
export GUM_SPIN_ALIGN=left
export GUM_SPIN_TIMEOUT=300s
export GUM_SPIN_SHOW_ERROR=true

_msg()   { printf '\033[92m✓ %s\033[0m\n' "$*";     }
_warn()  { printf '\033[93m! %s\033[0m\n' "$*" >&2; }
_error() { printf '\033[91m✗ %s\033[0m\n' "$*" >&2; }

_load_dsl() {
    if [[ ! -d "${DSL}" ]]; then
        _error "DSL directory not found: ${DSL}"
        return 1
    fi

    local f
    for f in "${DSL}"/*.sh; do
        [[ -f "${f}" ]] || continue
        source "${f}"
    done
}

_gum() {
    if [[ -x "${gum}" ]]; then
        "${gum}" "$@"
    elif command -v gum >/dev/null 2>&1; then
        gum "$@"
    else
        _error "gum is not available"
        return 1
    fi
}

_check_internet() {
    local -a probe

    if command -v curl >/dev/null 2>&1; then
        probe=(curl -fsS --connect-timeout 5 --max-time 10
               https://connectivitycheck.gstatic.com/generate_204)
    elif command -v wget >/dev/null 2>&1; then
        probe=(wget -q --timeout=10 --tries=1 -O /dev/null
               https://connectivitycheck.gstatic.com/generate_204)
    else
        _error "internet: neither curl nor wget is available"
        return 1
    fi

    if "${probe[@]}" >/dev/null 2>&1; then
        _msg "Internet connected"
        return 0
    fi

    _warn "Internet unavailable"

    local answer
    answer="$(_gum choose \
        "Continue in offline mode" \
        "Exit" \
        --header "Internet is unavailable")" || true

    case "${answer}" in
        "Continue in offline mode") return 0 ;;
        "Exit") exit 0 ;;
        *)
            _error "internet: unexpected selection"
            return 1
            ;;
    esac
}

_self_update() {
    if ! git -C "${ROOT}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        _warn "self-update: ${ROOT} is not a git repository — skipping"
        return 0
    fi

    if ! git -C "${ROOT}" diff-index --quiet HEAD -- 2>/dev/null; then
        _warn "Local changes detected in ${ROOT}:"
        git -C "${ROOT}" status --short >&2

        if _gum confirm "Commit and push local changes?"; then
            git -C "${ROOT}" add -A
            git -C "${ROOT}" commit -v
            git -C "${ROOT}" push
        fi
    fi

    GIT_TERMINAL_PROMPT=0 git -C "${ROOT}" fetch 2>/dev/null || {
        _warn "self-update: fetch failed — continuing with local version"
        return 0
    }

    local local_rev remote_rev
    local_rev="$(git -C "${ROOT}" rev-parse '@')"
    remote_rev="$(git -C "${ROOT}" rev-parse '@{u}' 2>/dev/null)" || {
        _warn "self-update: no upstream tracking branch — skipping merge"
        return 0
    }

    if [[ "${local_rev}" == "${remote_rev}" ]]; then
        _msg "self-update: up to date"
        return 0
    fi

    git -C "${ROOT}" merge --ff-only >/dev/null 2>&1 || {
        _warn "self-update: cannot fast-forward — skipping merge"
        return 0
    }

    _msg "self-update: updated"
}

_find_hostfile() {
    if [[ -f "${HOSTFILE}" ]]; then
        printf '%s' "${HOSTFILE}"
        return 0
    fi

    local f
    for f in Hostfile Hostconfig; do
        if [[ -f "${ROOT}/${f}" ]]; then
            printf '%s' "${ROOT}/${f}"
            return 0
        fi
    done

    _error "Hostfile not found (HOSTFILE=${HOSTFILE})"
    return 1
}

_main() {
    _load_dsl
    _check_internet
    _self_update

    local hostfile
    hostfile="$(_find_hostfile)"

    source "${hostfile}"
}

_main
```

### Runtime responsibilities

`hostcfg` should own runtime/bootstrap concerns:

* establish `HOSTFILE`
* establish authoritative `ROOT`
* locate/load DSL implementation
* provide bootstrap output helpers
* provide `gum`
* perform foundational runtime setup
* self-update the configuration repository before evaluating the Hostfile
* locate and source the Hostfile

The Hostfile should not contain runtime bootstrap implementation.

---

# Self-update

The intended model is that the Hostfile repository updates itself before the Hostfile is evaluated.

Therefore this:

```text
sync ~/etc from github:axjab/dotfiles
```

should eventually disappear from the Hostfile because self-sync belongs to `hostcfg`.

Current `_self_update` behavior:

* only operates if `ROOT` is a Git worktree
* detects local changes
* shows them
* optionally commits/pushes them
* fetches with `GIT_TERMINAL_PROMPT=0`
* fast-forwards only
* refuses to automatically merge divergent history
* continues with local state if fetching/updating fails

Do not unnecessarily redesign this while working on the DSL.

---

# Hostfile language

General syntax:

```text
VERB TARGET [PREPOSITION VALUE]
```

The mandatory target is `$1`.

Prefer explicit syntax.

Scoped constructs use `:` as terminator:

```text
host xenon at 100.109.130.76
    is nvidia gaming pc
    user ash
    os PikaOS
    de Niri
:
```

`:` is an ordinary Bash function/DSL construct.

Concepts naturally belonging under an existing command should be subcommands.

Example:

```text
host service nats at majula
```

not a separate `service` top-level language construct.

---

# Desired Hostfile phases

The Hostfile should read roughly as:

```text
IDENTITY

INGREDIENTS

SYNCHRONIZATION

CONFIGURATION

HOSTS

SERVICES

INSTALLATION

MOUNTS
```

The exact order may evolve, but the important bootstrap dependency is:

```text
local identity
→ external hooks
→ synchronization
→ configuration
→ host-specific state
```

The Hostfile is currently ordered and executes directives as encountered.

There is a future idea of making it orderless and parsing first, but **do not implement that casually**. It would be a major language change.

---

# Identity

The old:

```text
require ssh
require keys
```

is intentionally being replaced with explicit operations.

Desired direction:

```text
create key gpg
create key ssh
```

Exact implementation/syntax should be verified against the DSL before modification.

SSH conceptually means:

> create the host's SSH identity and configure it for use.

Current SSH behavior:

* create `~/.ssh`
* derive hostname
* create host-specific Ed25519 key if absent
* update `~/.ssh/config`
* configure the key as default identity
* set appropriate permissions

GPG conceptually means:

> create the machine's GPG encryption identity and handle enrollment into the secret infrastructure.

The GPG fingerprint is public. Private key material must remain secret.

---

# Hooks / external ingredients

The important replacement for `require` is:

```text
hook NAME
```

Optionally:

```text
hook github "GitHub authenticated"
```

A hook is an executable provider-specific script, preferably:

```text
~/etc/hooks/<name>
```

Examples:

```text
~/etc/hooks/tailnet
~/etc/hooks/github
~/etc/hooks/gitlab
~/etc/hooks/gitea
~/etc/hooks/garage
```

The Hostfile says **what capability must exist**.

The hook implements **how to establish it**.

Provider-specific logic must not leak into the core DSL.

A hook may install software, authenticate, configure credentials, connect, verify state, or prompt for human assistance as appropriate.

The core language should not distinguish provider-specific lifecycle concepts such as install/login/connect/verify.

---

# Hook protocol

This remains the main design task.

Required semantics:

* hook is an executable script
* parent invokes it directly
* `exit 0` means success
* non-zero means failure
* failure stops Hostfile evaluation
* parent must safely capture failure under `set -e`
* stderr is available for human diagnostics/progress
* stdout should provide parseable information if a protocol is needed

Do not use `return` in standalone hook scripts.

The protocol should remain small and Unix-like.

Potentially:

```text
message=...
error=...
```

or similar line-oriented records.

Do not introduce JSON unless necessary.

The Hostfile's optional message should serve as both documentation and a default success message:

```text
hook github "GitHub authenticated"
```

Need to settle:

* stdout protocol
* whether stdout is protocol-only
* multiline messages
* malformed output behavior
* optional warnings/errors
* hook arguments
* option syntax

Do not turn hooks into a second DSL.

---

# Dependency model

Do not build a generic dependency graph.

Explicit ordering in the Hostfile is sufficient.

Important dependencies:

* Internet is foundational and should not need to appear as `require internet`
* local identities precede hooks that depend on them
* Tailnet precedes private-network access where necessary
* GitHub authentication precedes private GitHub synchronization
* hooks precede synchronization

---

# Synchronization

Current examples:

```text
sync /exe from 'github:axjab/executables'
sync /data/secrets from 'github:axjab/secrets'
sync /data/helix with 'ssh://majula//data/helix'
sync ~/host
```

The self-sync:

```text
sync ~/etc from 'github:axjab/dotfiles'
```

is intended to move into `hostcfg`.

There is an unresolved question around `/data/secrets` and whether the eventual secret-management model remains Git/Gopass or changes. Do not redesign it without a concrete task.

---

# Existing Hostfile scaffold

Current intended shape:

```text
# IDENTITY

create key gpg
create key ssh

# INGREDIENTS

hook tailnet "Tailnet authenticated"
hook github "Github authenticated"

# SYNCHRONIZATION

sync /exe from 'github:axjab/executables'
sync /data/secrets from 'github:axjab/secrets'

# CONFIGURATION

install exe-path in sudoers <<-EOF
    Defaults secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/exe"
EOF

# HOSTS

host firelink at 100.121.116.55
    is headless server
    user ash
    os Debian
:

host majula at 100.109.130.76
    is headless server
    user solaire
    os Debian
:

host xenon
    is nvidia gaming pc
    user ash
    os PikaOS
    de Niri
:

host luminous at 100.95.238.38
    is nvidia gaming pc
    user axjab
    os PikaOS
    de Niri
:

host aran
    is low-powered pc
    os Debian
:
```

Services:

```text
host service wiki at localhost
host service nats at majula
host service repository at majula
host service pocketbase at majula
host service uptime-kuma at majula
```

Installation and mount directives also exist.

---

# Host semantics

Host declarations preserve unspecified existing metadata.

Explicit `is` replaces existing tags.

`user`, `os`, and `de` preserve previous values when omitted.

An unknown IP is valid.

Never fabricate `127.0.0.1`.

Current host examples:

* `firelink` — headless server, `ash`, Debian
* `majula` — headless server, `solaire`, Debian
* `xenon` — NVIDIA gaming PC, `ash`, PikaOS, Niri
* `luminous` — NVIDIA gaming PC, `axjab`, PikaOS, Niri
* `aran` — low-powered PC, Debian

Do not infer missing host information.

---

# Existing miscellaneous DSL

The Hostfile uses:

```text
namespace
sync
install
host
host service
link
process
mount
symlink
set
```

Their exact semantics should be obtained from the actual implementation.

Do not infer behavior merely from directive names.

Current examples:

```text
link /usr/bin/pinentry-curses to /usr/bin/pinentry

link gopass/config to ~/.config/gopass/config
process shell/env to ~/.env
link shell/aliases to ~/.aliases
link shell/bashrc to ~/.bashrc

link niri/config.kdl to ~/.config/niri/config.kdl
link helix/config.toml to ~/.config/helix/config.toml
link helix/lang.toml to ~/.config/helix/languages.toml

link bat/config to /etc/bat/config
link gh/config.yml to ~/.config/gh/config.yml
link git/config to /etc/gitconfig
link sqlite/config to ~/.sqliterc
link starship/config to ~/.config/starship.toml
link taskdog/cli.toml to ~/.config/taskdog/cli.toml
link xdg/dirs to ~/.config/user-dirs.dirs
```

Mount examples:

```text
mount nfs majula:/mnt/ssd onto /mnt/majula.ssd
mount dir /mnt/majula.ssd/files onto /repo
mount dir /mnt/ssd/data/garage onto /data/garage/data
```

Some are currently guarded with `set +e` because host-specific mounts may legitimately fail. This area needs eventual cleanup, but it is not the immediate hook task.

---

# Namespace question

Current conceptual namespaces:

```text
namespace data
namespace repo
namespace exe
namespace log
namespace net
namespace svc
namespace job
```

Open question:

* Should namespace declarations create directories?
* Or do namespaces merely establish semantic filesystem roles?
* Could paths instead be created when a directive actually needs them?

Prefer the smallest meaningful semantics. Do not create machinery just because namespaces currently exist.

---

# Important design principles

* `$ROOT` is authoritative.
* Do not invent alternate state locations.
* Keep state minimal.
* Prefer idempotent operations.
* Do not silently overwrite unrelated user configuration.
* Explicit syntax is preferred over inference.
* Provider-specific complexity belongs in hooks.
* The Hostfile describes **what**.
* Runtime/hooks implement **how**.
* Internet is foundational, not an ordinary dependency.
* Do not recreate `require` as a generic dispatcher under another name.
* Adding a provider should normally require adding a hook script, not modifying the core interpreter.
* Keep hooks flat under `~/etc/hooks`.
* Keep the protocol tiny.
* Don't build a dependency graph.
* Don't turn Hostfile into imperative Bash.

## Immediate focus

The next substantive task is to settle and implement the **hook mechanism**:

1. inspect the actual DSL/runtime implementation;
2. settle hook syntax;
3. settle stdout/stderr/exit-status semantics;
4. implement a minimal runner safe under `set -euo pipefail`;
5. then migrate Tailnet/GitHub into standalone hooks;
6. remove obsolete `require` machinery.

Do not assume anything not present in the actual source.


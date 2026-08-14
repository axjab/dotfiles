00-overview.md
# Hostfile project context


This is a small Unix-oriented host configuration system.


The Hostfile describes the common desired state of a collection of hosts.


The system is intentionally simple:
- Bash underneath
- flat files
- explicit directives
- Unix conventions
- little or no framework machinery
- implementation details should stay out of the Hostfile where possible


The Hostfile should describe WHAT needs to happen.


Scripts/hooks should implement HOW it happens.


Do not over-engineer the system.
Prefer boring Unix mechanisms over abstractions that exist only to make the design look sophisticated.


The system is evolving quickly, so preserve simplicity and allow the design to settle before introducing complex machinery.
01-hostfile.md
# Hostfile model


The Hostfile describes the common state of every host.


Common declarations come first.


Host-specific information and exceptions come later.


A rough Hostfile shape is:


    # bootstrap / gathering


    hook tailnet
    hook github
    hook garage


    # namespaces


    namespace data
    namespace repo
    namespace exe
    namespace log
    namespace net
    namespace svc
    namespace job


    # synchronization


    sync ~/etc from github:axjab/dotfiles
    sync /exe from github:axjab/executables
    sync /data/secrets from github:axjab/secrets


    # identity / hosts


    host firelink at 100.121.116.55
        is headless server
        user ash
        os Debian


    ...


The Hostfile should remain declarative.


Avoid turning it into a collection of shell commands whenever a higher-level directive can describe the intent more clearly.


## Bootstrap ordering


The conceptual sequence is:


1. Establish local structure and identity.
2. Gather external dependencies.
3. Synchronize shared configuration/state.
4. Apply the remaining common configuration.
5. Apply host-specific configuration/exceptions.


The exact directives are still being designed.


## Internet


Internet access is considered a universal/basic prerequisite.


It should probably not need to appear explicitly in every Hostfile.


If a hook needs Internet, the bootstrap system may simply assume that the basic environment has Internet or establish it implicitly.


Do not make the Hostfile say `require internet` merely because an implementation needs Internet.


## External dependencies


Examples:


- Tailnet
- GitHub
- GitLab
- Gitea
- Garage/S3
- external APIs
- other remote services


These are "ingredients" that should be established early.


The important property is not merely authentication.


A provider may require installation, configuration, authentication, connectivity checks, credentials, SSH configuration, or other preparation.


That is why the generic directive is `hook`, not `auth` or `require`.
02-hooks.md
# Hooks
means:


    execute the hook named NAME


The hook must succeed before the Hostfile proceeds.


Exit status is authoritative:


    exit 0       success
    non-zero     failure


The parent must invoke hooks in a way that is safe under `set -e`, for example:


    if output="$("$hook")"; then
        ...
    else
        ...
    fi


Do not invent complicated meanings for individual exit codes unless there is a demonstrated need.


## Hook output


Hooks may return structured information through stdout.


stdout is the protocol.


stderr is for human-readable diagnostics, progress, and underlying command output.


Do not mix arbitrary logging into stdout if stdout is being parsed.


A minimal response might be:


    status=ok
    message=GitHub authenticated


Failure:


    status=error
    message=GitHub authentication failed
    detail=No usable SSH identity was found


The exact protocol is NOT FINAL YET.


Decide whether this should remain a simple line-based protocol or become JSON.


Do not choose JSON merely because it is more extensible.


A simple Unix-friendly line protocol may be preferable.


## Hostfile-provided messages


The hook directive may accept a default message:


    hook github "GitHub authenticated"
    hook tailnet "Tailnet connected"


This message serves two purposes:


1. it controls default presentation;
2. it documents the purpose of the hook directly in the Hostfile.


If the hook itself provides a message, the hook-provided message may override the Hostfile default.


Exact precedence is not final yet.


## Possible future hook data


Hooks may eventually return facts to the interpreter:


    status=ok
    message=Tailnet connected
    hostname=luminous
    ip=100.95.238.38


Do not implement a large data model until a real use case requires it.


## Important distinction


The hook does not "return" a value in the shell sense.


It communicates using:


    stdout       structured response
    stderr       diagnostics / human output
    exit status  success/failure


Keep this distinction clear.
03-bootstrap.md
# Bootstrap / gathering model
- provides the host's encryption/decryption identity
- is used by gopass
- requires enrollment with the existing secret-store recipients


Creating a key and enrolling that key are conceptually separate operations.


For GPG:


1. create the key if necessary
2. expose its public fingerprint/information
3. enroll the new host with the existing secret store
4. eventually synchronize the re-encrypted store


Human assistance may currently be necessary for enrollment.


## External dependencies


After local identity exists, establish external dependencies.


Examples:


    hook tailnet
    hook github
    hook gitlab
    hook garage


Each provider gets its own hook because each provider has unique rules.


The generic bootstrap layer should not know those rules.


## Dependency ordering


Some dependencies depend on others.


For example:


    Internet
       ↓
    Tailnet
       ↓
    SSH connectivity
       ↓
    GitHub
       ↓
    private repository sync


However, this is not necessarily a universal dependency graph.


Do not hard-code provider-specific relationships into the generic hook mechanism.


The Hostfile should express important ordering explicitly when necessary.


## GitHub


GitHub is a critical dependency for synchronization.


Private repositories cannot be synchronized until GitHub access has been established.


Therefore:


    hook github


must happen before:


    sync ... from github:...


Do not move GitHub authentication after synchronization merely because it is conceptually "configuration."


## Internet


Internet is treated differently.


It is basic infrastructure rather than an ordinary provider.


It may eventually be implicit/hardcoded rather than represented as:


    require internet


Avoid cluttering every Hostfile with universal assumptions.
04-identity.md
# Host identity and keys


The system uses multiple kinds of identity.


## SSH


SSH establishes the host's SSH identity.


The existing `require ssh` implementation effectively does two things:


1. create an SSH key if it does not exist;
2. enroll/configure that key in `~/.ssh/config`.


That is a useful mental model.


The implementation currently:
- creates `~/.ssh`
- creates a host-specific Ed25519 key
- creates/updates `~/.ssh/config`
- configures the key as the default SSH identity
- sets appropriate permissions


This may eventually become a more explicit key/identity operation.


The exact directive name is not final, but it should communicate that a key is being created/configured.


## GPG


The existing `require keys` implementation effectively does:


1. create a GPG key if none exists;
2. provide enrollment information for the new key.


The second step currently requires human assistance on another trusted host.


GPG fingerprints are public identifiers.


A fingerprint such as:


    BC0663BDDD401B0C28E2B2687EF368F964202015


does not expose the private key.


The private key material must remain secret.


## GPG UID presentation


GPG commonly displays UIDs such as:


    axjab (GENERATED 4 LUMINOUS) <x@alj.cx>


or:


    Full Name <email>


The project prefers compact Unix-like identities.


For example:


    hostname


may be sufficient when the identity is purely a machine identity.


Avoid unnecessary comments and email fields when they provide no useful information.


The exact naming convention is still open.


## gopass


gopass/GPG uses public-key cryptography to protect the per-secret encryption keys.


The GPG public key is not simply used as the direct encryption key for the entire secret payload.


The secret data is encrypted using symmetric session keys, and those session keys are encrypted for the recipients' public keys.


Therefore multiple GPG recipients can decrypt the same secret without storing a separate independently encrypted plaintext copy for every recipient.


This is relevant to host enrollment:
adding a GPG recipient allows that host to decrypt the existing store after the store is re-encrypted for the new recipient.
05-tasks.md
# Current tasks


## Hook system


- [ ] Implement generic `hook NAME` Hostfile directive.
- [ ] Decide exact hook directory. Preferred: `~/etc/hooks`.
- [ ] Resolve hook path safely.
- [ ] Require hook to exist and be executable.
- [ ] Execute hook sequentially.
- [ ] Preserve normal Bash `set -e` behavior in parent.
- [ ] Capture stdout.
- [ ] Keep stderr available for diagnostics/progress.
- [ ] Define stdout protocol.
- [ ] Parse hook status.
- [ ] Parse hook message.
- [ ] Support Hostfile default message.
- [ ] Decide message precedence.
- [ ] Produce useful success output.
- [ ] Produce useful rich failure output.
- [ ] Decide whether malformed hook output is itself an error.
- [ ] Decide whether hooks may return additional data.
- [ ] Decide whether progress output needs a protocol.


## Convert existing implementation


Turn the current prerequisite functions into standalone hooks where appropriate:


- [ ] Tailnet hook
- [ ] GitHub hook
- [ ] SSH identity/key operation
- [ ] GPG identity/key operation
- [ ] Other providers as they appear


Do not recreate the old `require` dispatcher under a new name.


The point of hooks is that new providers should be added by adding scripts rather than editing a giant Bash `case` statement.


## Hostfile cleanup


- [ ] Remove old `require` directives.
- [ ] Establish a clean bootstrap/gathering section.
- [ ] Establish common namespaces.
- [ ] Establish synchronization section.
- [ ] Establish host declarations.
- [ ] Establish service declarations.
- [ ] Establish installation declarations.
- [ ] Establish filesystem/mount declarations.
- [ ] Establish configuration declarations.
- [ ] Define how host-specific exceptions work.


## Key model


- [ ] Decide final SSH key directive.
- [ ] Decide final GPG key directive.
- [ ] Separate key creation from enrollment conceptually.
- [ ] Automate GPG enrollment where safely possible.
- [ ] Decide compact machine GPG UID convention.


## Synchronization


- [ ] Ensure GitHub hook always precedes private GitHub sync.
- [ ] Revisit secret-store location.
- [ ] Revisit gopass versus Bitwarden.
- [ ] Ensure bootstrap can update/synchronize itself.


## Do not over-engineer


Before implementing:
- do not build a generic dependency graph
- do not build a plugin framework
- do not invent dozens of hook statuses
- do not introduce complex directory hierarchies
- do not make every universal prerequisite explicit
- do not turn hooks into another DSL


Prefer:


    Hostfile directive
        ↓
    executable hook
        ↓
    stdout + exit status


Keep the mechanism boring.
The handoff in one paragraph

If you need to paste only one thing into a future session, I'd use this:

We are building a small Unix-oriented Hostfile configuration system. The Hostfile describes common desired state for all hosts; implementation details should live outside the DSL. We abandoned the require abstraction because it was really a dispatcher hiding unrelated imperative functions. The replacement is hook NAME, where ~/etc/hooks/NAME is an executable standalone script. The Hostfile says what external dependency needs to be established; the hook decides how. Hooks are particularly intended for early bootstrap/gathering of external "ingredients" such as Tailnet, GitHub, GitLab, Gitea, Garage/S3, and APIs. Internet is considered universal/basic infrastructure and may eventually be implicit. Hooks run sequentially and are fail-closed: exit 0 means success, non-zero means failure. The parent must invoke them in a way compatible with set -e. Hook stdout is intended to be a parseable response protocol; stderr is for human diagnostics/progress. A minimal protocol might contain status, message, and optionally detail, but the exact protocol is not finalized. The Hostfile may provide a default success message, e.g. hook github "GitHub authenticated", which also serves as documentation. Hook-provided messages may eventually override the default. Do not recreate the old require dispatcher as hook; adding a provider should normally mean adding an executable script, not editing the interpreter. The current architecture is deliberately simple, flat, Unix-like, and not intended to become a framework. Local host identity should be established before external dependencies, external dependencies should be gathered before synchronization, and GitHub authentication must precede private GitHub repository synchronization. SSH and GPG are distinct identities: SSH establishes the host's SSH identity/configuration; GPG establishes the encryption identity used by gopass. GPG fingerprints are public identifiers. The next immediate engineering task is to implement and settle the generic hook runner and its small stdout protocol before converting the existing prerequisite functions.

Output todo as pure markdown, while the prompt should be a single file. I will divide it myself.
TODO
 Refactor the Hostfile around phases, rather than require prerequisites.
 Creation / local bootstrap
 Hooks / external identities and connections
 Synchronization
 Configuration
 Hosts
 Services
 Installation
 Mounts
 Replace the current require abstraction where appropriate.
 require ssh → explicit key/identity creation directive
 require keys → explicit GPG key creation/enrollment behavior
 require internet → make Internet an implicit universal prerequisite
 require tailnet → replace with a hook
 require github → replace with a hook
 Establish the hook concept as the general mechanism for gathering external "ingredients" before configuration proceeds.
 Define the exact hook directive syntax.
 Decide positional arguments.
 Decide supported options.
 Allow a success message/documentation string.
 Decide whether hooks can accept arguments from the Hostfile.
 Decide how hook names map to scripts under ~/etc/hooks.
 Define the hook execution protocol.
 Hook is an executable script.
 Parent invokes it directly.
 Successful completion allows Hostfile evaluation to continue.
 Failure prevents continuation.
 Define whether hooks communicate structured results through stdout, stderr, exit status, or a combination.
 Define a parseable output format for rich success/error messages.
 Decide whether stdout is reserved for protocol output.
 Decide how human-readable diagnostic output is handled.
 Decide whether exit 0 is the normal success mechanism.
 Clarify that shell return is only meaningful inside sourced functions; standalone hook scripts should use exit status.
 Ensure parent set -e behavior is explicitly controlled by the hook runner.
 Design hook error handling.
 Preserve useful context from the hook.
 Produce rich errors in the parent shell.
 Avoid losing the hook's actual failure reason behind a generic "hook failed".
 Decide whether hooks may distinguish warnings from fatal errors.
 Design hook success handling.
 Default success output should be supplied by the Hostfile when appropriate.
 Hooks may optionally return richer information.
 Avoid noisy output when the hook is already satisfied.
 Establish conventions for common hooks:
 Tailnet authentication/connection
 GitHub authentication
 GitLab authentication
 Gitea authentication
 Garage/S3 authentication
 Arbitrary API authentication
 Future providers without modifying the core Hostfile interpreter
 Determine whether authentication and connection should be semantically distinct.
 Prefer hooks that establish the complete state required by the provider.
 Avoid encoding provider-specific lifecycle semantics into the Hostfile language.
 Determine dependency ordering.
 Internet is implicit.
 Local identity/key creation happens before hooks that depend on it.
 Tailnet must be available before private-network resources are accessed.
 GitHub authentication must exist before private GitHub synchronization.
 All required hooks must complete before synchronization begins.
 Refactor synchronization around the resulting authenticated environment.
 sync ~/etc from github:...
 sync /exe from github:...
 sync /data/secrets from github:...
 Revisit whether /data/secrets should remain in Git/Gopass or move/reconcile with another secret-management system.
 Decide whether directory creation should be implicit.
 namespace data
 namespace repo
 namespace exe
 etc.
 Prefer ad-hoc creation when a directive actually needs a path, unless explicit namespaces have semantic value.
 Clean up Hostfile terminology and spelling.
 IDENTITIY → IDENTITY
 Separate machine identity from external authentication.
 Avoid comments that merely explain implementation details.
 Review whether host, service, namespace, sync, install, mount, and hook form a coherent minimal vocabulary.
 Keep the language declarative where possible; move provider-specific complexity into hooks.
 Preserve the principle that the Hostfile describes the common desired state of every host, with host-specific exceptions expressed later.
 Implement the hook runner only after the protocol is settled.
 Add tests for:
 successful hook
 failed hook
 malformed hook output
 hook with no output
 hook with custom success message
 hook with rich error
 missing hook
 non-executable hook
 hook receiving arguments
 hook behavior under parent set -e
 hook output containing arbitrary user/provider text
 Revisit the existing require implementation after the hook protocol is established; remove obsolete prerequisite abstractions rather than preserving them for compatibility unnecessarily.
Giant handoff prompt
# Hostfile / Bootstrap System — Handoff


The conceptual operation is therefore:


> create SSH identity + enroll it into local SSH configuration


The word `require` is now considered misleading because this is not merely checking a prerequisite.


A more explicit directive should probably describe creation of the identity/key.


The exact final directive name is not yet settled, but it should include the word `key` if that remains the right abstraction.


### GPG identity


The current `require keys` behavior does approximately this:


1. verify `gpg` exists
2. create a GPG key if no secret key exists
3. display the local secret-key identities
4. obtain fingerprints
5. print instructions for another host to import the public key
6. print instructions for adding the fingerprint to the Gopass recipient set


Conceptually this is:


> create GPG key if necessary + provide/enact enrollment into the shared secret infrastructure


This is also not merely a prerequisite check.


The GPG fingerprint is public information. It identifies the key but does not reveal the secret key.


The GPG key uses public-key cryptography around a session/data key; the public key is not itself the encrypted secret payload.


---


## External "ingredients"


A major design insight is that the machine should gather the external things it needs BEFORE the rest of the configuration begins.


Think of these as ingredients.


Examples:


- Tailnet
- GitHub
- GitLab
- Gitea
- Garage S3
- API 1
- API 2
- future providers


Internet itself is different.


Internet is a universal low-level prerequisite and should probably be implicit rather than something every Hostfile explicitly says.


The important point is:


> external providers have different authentication and setup rules, so the core Hostfile language should not implement those rules individually.


---


# Hook concept


The preferred term for this mechanism is:


> hook


A hook is a provider-specific executable script responsible for establishing some external capability.


For example:


```text
~/etc/hooks/
    tailnet
    github
    gitlab
    gitea
    garage
    api-foo
    ...

The Hostfile invokes a hook.

The hook owns all provider-specific behavior.

The core Hostfile interpreter only needs to know:

which hook to run
how to invoke it
what constitutes success
how to interpret its returned result
how to display that result

This makes adding a new provider mostly a matter of adding a new hook script rather than modifying the Hostfile interpreter.

Hook semantic model

The desired semantic model is:

hook <name>

means approximately:

Run the hook responsible for establishing this external capability. Continue only if it succeeds.

The hook may:

install required provider software
authenticate
configure local credentials
connect to a service
verify authentication
verify connectivity
prompt the human
repair missing local configuration
return useful information to the parent

The hook should establish the COMPLETE useful state for its provider.

Do not make the core language care whether a provider technically distinguishes:

install
login
connect
configure
verify

Those are provider-specific implementation details.

For example, a Tailnet hook may install Tailscale, authenticate it, configure SSH support, and verify the connection.

A GitHub hook may ensure gh exists, configure SSH, authenticate GitHub, and verify authentication.

The Hostfile should simply say:

hook tailnet
hook github
Why hooks instead of require

The previous design had:

require internet
require tailnet
require ssh
require keys
require github

This became misleading.

The functions behind require were not generic prerequisite checks.

They were arbitrary complex operations hidden behind a generic word.

For example:

require keys

actually meant:

create a GPG identity and help enroll it into the secret store.

Likewise:

require github

actually meant:

install GitHub CLI, configure SSH, authenticate GitHub, and verify authentication.

That is too much semantic hiding.

hook is better because it openly communicates:

this is an external operation whose implementation lives elsewhere.

Hook storage

The preferred hook directory is:

~/etc/hooks

Keep it flat.

Do not introduce a plugin hierarchy or package manager unless there is a demonstrated need.

A hook should ideally be a normal executable shell script.

Example:

~/etc/hooks/github
~/etc/hooks/tailnet
~/etc/hooks/gitlab

The Hostfile should reference the logical hook name, not necessarily its implementation filename/path.

Hook protocol

This is the major unfinished design problem.

The hook must communicate with the parent Hostfile interpreter.

The desired behavior is richer than simply:

exit 0
exit 1

because the parent should be able to display useful success/error information.

The proposed model is:

exit status determines success/failure
hook output contains parseable information
parent parses the result
parent renders a rich human-readable message

Important clarification:

A standalone shell script cannot use return as its normal process result.

return is for shell functions or sourced scripts.

For executable hook scripts:

exit 0

is normal success.

exit 1

or another non-zero status means failure.

The parent must explicitly invoke the hook in a way that safely captures its result even if the parent shell has:

set -e

Do NOT rely on set -e to implement the hook protocol.

The hook runner should deliberately capture:

output="$(hook ...)"
status=$?

or an equivalent safe pattern, and then decide what to do.

Hook output protocol

The exact protocol is NOT settled yet.

Design this carefully.

Requirements:

parseable by the parent shell
easy for shell scripts to emit
capable of rich success messages
capable of rich error messages
capable of multiline human-readable text
robust when messages contain spaces
ideally robust when messages contain arbitrary punctuation
should not require JSON unless there is a compelling reason
should not become a mini RPC protocol
should be easy to debug by running the hook manually

Possible designs may include simple tagged records such as:

message=...
error=...
warning=...

or a small line-oriented protocol.

Do not prematurely commit to a format.

Consider whether stdout should be exclusively protocol output and stderr should remain diagnostic/human output.

Consider whether the hook should be allowed to produce normal progress output directly.

The protocol must distinguish:

successful completion
failed completion
optional human-readable message
optional detailed error
potentially warnings

The protocol should remain minimal.

Hook directive options

The Hostfile hook directive may eventually support options.

One desired feature is a default success message.

For example, conceptually:

hook github "GitHub authenticated"

could both:

document what the hook establishes
provide the default success output

The exact syntax is undecided.

Potential requirements:

hook name
optional arguments
optional success message
possibly optional failure message
potentially environment/context passed to hook

Do not add options unless they solve an actual problem.

The success-message feature is especially useful because the Hostfile line itself becomes documentation.

Hook execution semantics

A hook should be idempotent where practical.

Running:

hook github

twice should generally result in:

already configured / authenticated

rather than destructive reconfiguration.

Hooks may interactively prompt when human action is genuinely required.

Hooks may install software if that is part of establishing the capability.

Hooks should verify their final state rather than assuming a command succeeded.

For example:

install -> authenticate -> verify

rather than merely:

install -> assume success
Dependency ordering

The intended conceptual bootstrap sequence is:

local structure
local keys / identity
hooks
sync
configuration

Internet is implicit.

A typical real bootstrap may therefore be:

create key ssh
create key gpg


hook tailnet
hook github


sync ~/etc from github:...
sync /exe from github:...
sync /data/secrets from github:...


...

The exact key directives are still being designed.

The important dependency is:

local identity
    ↓
external access/authentication
    ↓
GitHub authentication
    ↓
private repository synchronization
    ↓
rest of configuration

GitHub is therefore NOT optional decoration.

If private repositories are required for synchronization, GitHub authentication is a critical bootstrap dependency and must happen before those sync directives.

Tailnet may similarly be required before private network services can be reached.

Existing Hostfile

The current scaffold looks approximately like this:

##############################################################
# s3
# etc.


# IDENTITY
require ssh
require keys


# CONNECTIVITY
require internet
require tailnet
require github


namespace data
namespace repo
namespace exe
namespace log
namespace net
namespace svc
namespace job


sync ~/etc from 'github:axjab/dotfiles'
sync /exe from 'github:axjab/executables'
sync /data/secrets from 'github:axjab/secrets'


install exe-path in sudoers <<-EOF
    Defaults secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/exe"
EOF


# IDENTITY


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
    is gaming pc
    user ash
    os PikaOS
    de Niri
:
host luminous at 100.95.238.38
    is gaming pc
    user axjab
    os PikaOS
    de Niri
:
host aran
    is low-powered pc
    os Debian
:


# SERVICES


host service wiki at localhost
host service nats at majula
host service repository at majula
host service pocketbase at majula
host service uptime-kuma at majula


# INSTALLATION


# for all
# install tldr
# install nfs-common
# install unison


# for pc
# install vivaldi
# install code


# FILESYSTEM MOUNTPOINTS

This is a scaffold, not a fixed specification.

Clean up terminology and structure when implementing.

Existing namespaces

Current conceptual namespaces include:

namespace data
namespace repo
namespace exe
namespace log
namespace net
namespace svc
namespace job

They are intended to describe locations/categories of mutable or shared state.

There is an open question whether namespace creation should be explicit or implicit.

Do not solve this with unnecessary machinery.

Consider whether:

namespace data

should automatically create /data, or whether directories should simply be created when directives actually use them.

Existing synchronization

Current examples:

sync ~/etc from 'github:axjab/dotfiles'
sync /exe from 'github:axjab/executables'
sync /data/secrets from 'github:axjab/secrets'

Synchronization is intentionally downstream of authentication.

The private GitHub repositories cannot be synchronized until the GitHub hook has established access.

There is also an unresolved architectural question around:

/data/secrets

and whether Gopass/GitHub should remain the secret-store mechanism or eventually be reconciled with another system such as Bitwarden.

Do not redesign this unless needed for the current task.

Existing SSH implementation

Current require ssh roughly does:

_require_ssh() {
    local ssh_dir="$HOME/.ssh"
    local hostname
    local key
    local config


    hostname="$(hostname)" || {
        error "require ssh: failed to determine hostname"
        return 1
    }


    if [[ -z "$hostname" ]]; then
        error "require ssh: hostname is empty"
        return 1
    fi


    key="$ssh_dir/$hostname.key"
    config="$ssh_dir/config"


    mkdir -p "$ssh_dir"


    if [[ ! -f "$key" ]]; then
        ssh-keygen \
            -t ed25519 \
            -f "$key" \
            -C "$hostname" \
            -N ""
    fi


    touch "$config"


    if ! grep -Fqx "Host *" "$config"; then
        cat >> "$config" <<EOF


Host *
    IdentityFile $key
    IdentitiesOnly yes
EOF
    else
        # validate existing Host * block
    fi


    chmod 700 "$ssh_dir"
    chmod 600 "$config"
    chmod 600 "$key"
    chmod 644 "$key.pub"
}

Conceptually:

create SSH identity + enroll it into ~/.ssh/config

This pattern inspired the broader hook/identity model.

Existing GPG behavior

The current GPG bootstrap creates a key interactively if none exists.

It then prints fingerprints and enrollment instructions.

The fingerprint is public information.

The private key remains secret.

Do not expose or confuse secret key material with fingerprints.

The user prefers compact, Unix-y key identity labels.

The current ugly example:

axjab (GENERATED 4 LUMINOUS) <x@alj.cx>

was considered undesirable.

A simpler identity such as:

hostname

or:

axjab@luminous

is preferred aesthetically.

The exact naming policy is not yet finalized.

Existing helper/state implementation

There is currently a runtime state mechanism:

_require_state_file()
_require_set_state()

using:

$ROOT/.cache/state.json

and jq.

Current code:

_require_state_file() {
    if [[ -z "${ROOT:-}" ]]; then
        error "require: \$ROOT is not set (expected to be exported by the entrypoint)"
        return 1
    fi


    if [[ ! -d "$ROOT" ]]; then
        error "require: \$ROOT ('$ROOT') is not a directory"
        return 1
    fi


    local cache="$ROOT/.cache"
    local state="$cache/state.json"


    mkdir -p "$cache" || {
        error "require: failed to create '$cache'"
        return 1
    }


    if [[ ! -f "$state" ]]; then
        printf '{}\n' > "$state" || {
            error "require: failed to initialize '$state'"
            return 1
        }
    fi


    printf '%s' "$state"
}


_require_set_state() {
    local key="$1"
    local value="$2"
    local state


    state="$(_require_state_file)" || return 1


    if command -v jq >/dev/null 2>&1; then
        local tmp
        tmp="$(mktemp)" || {
            error "require: failed to create temporary state file"
            return 1
        }


        if ! jq --arg key "$key" --argjson value "$value" \
            '.[$key] = $value' "$state" > "$tmp"
        then
            rm -f "$tmp"
            error "require: failed to update '$state'"
            return 1
        fi


        mv "$tmp" "$state" || {
            rm -f "$tmp"
            error "require: failed to install '$state'"
            return 1
        }
    else
        error "require: jq is required to update runtime state"
        return 1
    fi
}

This may eventually be renamed/refactored along with the removal of require.

Do not preserve _require_* naming merely for historical reasons.

Existing Tailnet behavior

Current Tailnet logic:

install Tailscale if missing
run sudo tailscale set --ssh
inspect tailscale status --json
distinguish NeedsLogin
invoke tailscale login when required
verify final state
if authenticated but not connected, prompt whether to continue without Tailnet
store a boolean runtime state

The key architectural lesson is:

The hook should own these provider-specific decisions.

The Hostfile should not know about BackendState, NeedsLogin, tailscale set --ssh, etc.

Those belong inside:

~/etc/hooks/tailnet
Existing GitHub behavior

Current GitHub logic:

ensure gh is installed
ensure ~/.ssh/config exists
ensure Host github maps to:
Hostname github.com
User git
authenticate with:
gh auth login --hostname github.com --git-protocol ssh
verify:
gh auth status --hostname github.com

Again, this should become a provider-specific hook.

The core Hostfile should not know any of this.

Important shell behavior

The project uses Bash.

The parent script may use:

set -e

Therefore hook execution must be carefully designed.

Do not assume:

hook_output="$(...)"

is sufficient under every set -e configuration.

Capture the status explicitly in a safe context.

The hook runner should own error handling.

A failed hook must not accidentally terminate the parent before its output is parsed and rendered.

Similarly, an exit 0 from a hook is normal success and should not trigger an error.

Do not use return in executable hook scripts.

Design constraints

When implementing the hook system:

Keep it small.
Keep it Bash-native.
Keep hook scripts independently executable.
Keep the Hostfile syntax readable.
Keep provider-specific logic out of the interpreter.
Make hooks idempotent.
Make errors useful.
Make output parseable.
Do not introduce a complicated dependency graph.
Do not turn hooks into a general-purpose plugin framework.
Do not require filesystem access that the user does not currently have.
Prefer flat ~/etc/hooks.
Preserve explicit ordering in the Hostfile.
Internet should remain an implicit foundational assumption.
External providers should be explicit hooks.
Private repository synchronization must happen only after the relevant authentication hooks.
Do not over-formalize the language.
Current task

The immediate task is to design and implement the hook mechanism.

Before writing implementation code:

Examine the existing architecture.
Identify the minimum hook protocol that satisfies the requirements.
Decide exactly how hook stdout/stderr/exit status are used.
Decide the minimal hook directive syntax.
Decide how arguments/options should work, if at all.
Decide how success/error messages are represented.
Make sure the design behaves correctly under set -e.
Then implement it in the existing style.

Do not blindly preserve the old require architecture.

The goal is to replace the abstraction where appropriate.

Desired end state

Something conceptually like:

# LOCAL IDENTITY


create key ssh
create key gpg


# EXTERNAL INGREDIENTS


hook tailnet "Tailnet connected"
hook github "GitHub authenticated"


# NOW WE CAN SYNCHRONIZE


sync ~/etc from 'github:axjab/dotfiles'
sync /exe from 'github:axjab/executables'
sync /data/secrets from 'github:axjab/secrets'


# REST OF HOST CONFIGURATION


...

The exact syntax is not sacred.

The important architecture is:

local identity
        ↓
      hooks
        ↓
      sync
        ↓
 configuration

with provider-specific behavior isolated in:

~/etc/hooks/

and a deliberately tiny protocol between those scripts and the Hostfile interpreter.

Think carefully before implementing.

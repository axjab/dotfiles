# Current Task — require keys

`require keys` currently gets stuck/fails after:

    gpg --list-secret-keys --with-colons
    grep '^sec'

with:

    keys=

The important requirement:

**Do not proceed past `require keys` unless enrollment has been confirmed.**

## Desired behavior

### No key

If the required GPG key does not exist:

1. generate it interactively;
2. obtain its fingerprint;
3. show the enrollment instructions;
4. ask the user to confirm enrollment;
5. save the confirmed fingerprint;
6. continue.

### Existing but unconfirmed key

If the key exists but has not previously been confirmed:

1. show enrollment instructions;
2. ask for confirmation;
3. save the fingerprint;
4. continue only after confirmation.

### Already confirmed

If the fingerprint has already been confirmed:

- do not show enrollment instructions;
- do not ask again;
- continue silently.

### Changed key

If the relevant fingerprint changes, enrollment must be confirmed again.

## Interaction

Prefer `gum` for the confirmation.

## State

The enrollment confirmation is user-level state.

Use the XDG cache convention rather than repository host state.

Store fingerprints, not merely:

    enrolled=true

Inspect the existing project conventions before deciding the exact filename.

## Important

Do not invent additional GPG/enrollment semantics.

Do not proceed when enrollment has not been confirmed.

Must work under `set -euo pipefail`.

Keep the implementation small.

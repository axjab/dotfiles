#!/usr/bin/env bash
# =============================================================================
# require keys — local GPG identity and password-store enrollment
#
#   require keys
#
# Ensures:
#   - gpg is installed
#   - this host has a usable secret GPG key
#   - the key has been enrolled in the password store
#
# Enrollment confirmation is persisted in the user's XDG cache so that
# instructions are shown only once per key fingerprint.
# =============================================================================

_require_keys_cache() {
    local cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}"
    local cache="$cache_dir/hostfile-keys.json"

    if ! mkdir -p "$cache_dir"; then
        error "require keys: failed to create '$cache_dir'"
        return 1
    fi

    if [[ ! -f "$cache" ]]; then
        if ! printf '%s\n' '{"enrolled":[]}' > "$cache"; then
            error "require keys: failed to initialize '$cache'"
            return 1
        fi
    fi

    printf '%s' "$cache"
}

_require_keys_fingerprints() {
    local listing

    if ! listing="$(gpg --list-secret-keys --with-colons 2>/dev/null)"; then
        error "require keys: failed to list secret keys"
        return 1
    fi

    # In --with-colons output, a primary secret-key record (`sec`) is followed
    # by its primary fingerprint (`fpr`). Ignore subkey fingerprints.
    printf '%s\n' "$listing" |
        awk -F: '
            $1 == "sec" {
                want_fpr = 1
                next
            }

            want_fpr && $1 == "fpr" {
                print $10
                want_fpr = 0
                next
            }

            $1 == "sec" {
                want_fpr = 1
            }
        '
}

_require_keys_enrolled() {
    local cache="$1"
    local fingerprints="$2"
    local fpr

    if ! command -v jq >/dev/null 2>&1; then
        error "require keys: jq is required for enrollment state"
        return 1
    fi

    while IFS= read -r fpr; do
        [[ -n "$fpr" ]] || continue

        if ! jq -e \
            --arg fingerprint "$fpr" \
            '(.enrolled // []) | any(. == $fingerprint)' \
            "$cache" >/dev/null
        then
            return 1
        fi
    done <<< "$fingerprints"

    return 0
}

_require_keys_save_enrollment() {
    local cache="$1"
    local fingerprints="$2"
    local tmp

    if ! command -v jq >/dev/null 2>&1; then
        error "require keys: jq is required for enrollment state"
        return 1
    fi

    tmp="$(mktemp "${cache}.XXXXXX")" || {
        error "require keys: failed to create temporary enrollment state"
        return 1
    }

    if ! printf '%s\n' "$fingerprints" |
        jq -R -s '
            split("\n")
            | map(select(length > 0))
            | {
                enrolled: .
              }
        ' > "$tmp"
    then
        rm -f "$tmp"
        error "require keys: failed to create enrollment state"
        return 1
    fi

    if ! mv "$tmp" "$cache"; then
        rm -f "$tmp"
        error "require keys: failed to save enrollment state"
        return 1
    fi

    return 0
}

_require_keys_show_enrollment() {
    local fingerprints="$1"
    local hostname="$2"
    local fpr

    printf '\n'
    printf '  ┌─────────────────────────────────────────────────────────────────┐\n'
    printf '  │  ENROLL THIS HOST IN THE PASSWORD STORE                         │\n'
    printf '  │  Run the following on Host A (the host that can decrypt it)     │\n'
    printf '  └─────────────────────────────────────────────────────────────────┘\n'
    printf '\n'

    printf '  # Import this host'\''s public key on Host A:\n'
    printf '\n'

    while IFS= read -r fpr; do
        [[ -n "$fpr" ]] || continue

        printf '    gpg --import <(ssh %s gpg --armor --export %s)\n' \
            "$hostname" "$fpr"
    done <<< "$fingerprints"

    printf '\n'
    printf '  # Add this host as a gopass recipient on Host A:\n'
    printf '\n'

    while IFS= read -r fpr; do
        [[ -n "$fpr" ]] || continue

        printf '    gopass recipients add %s\n' "$fpr"
    done <<< "$fingerprints"

    printf '\n'
    printf '  gopass will re-encrypt the store and push it to GitHub.\n'
    printf '  Afterward, sync /data/secrets here will pull the updated store.\n'
    printf '\n'
}

_require_keys_confirm_enrollment() {
    local answer

    if [[ -n "${gum:-}" && -x "$gum" ]]; then
        if ! "$gum" confirm \
            "I have enrolled this host on Host A" \
            --affirmative "Yes" \
            --negative "Not yet"
        then
            error "require keys: enrollment has not been confirmed"
            return 1
        fi

        return 0
    fi

    if command -v gum >/dev/null 2>&1; then
        if ! gum confirm \
            "I have enrolled this host on Host A" \
            --affirmative "Yes" \
            --negative "Not yet"
        then
            error "require keys: enrollment has not been confirmed"
            return 1
        fi

        return 0
    fi

    error "require keys: gum is required for enrollment confirmation"
    return 1
}

_require_keys() {
    if ! command -v gpg >/dev/null 2>&1; then
        error "require keys: gpg is not installed"
        return 1
    fi

    local fingerprints
    fingerprints="$(_require_keys_fingerprints)" || return 1

    if [[ -z "$fingerprints" ]]; then
        msg "KEYS" "No GPG key found — generating one now"
        printf '\n'
        printf '  You will be prompted by GPG to create a key.\n'
        printf '  Recommended choices:\n'
        printf '    Key type : ECC (sign and encrypt) -> Ed25519 + Cv25519\n'
        printf '    Validity : 1y\n'
        printf '    Name     : your name or this hostname (%s)\n' "$(hostname)"
        printf '    Email    : an address you own\n'
        printf '    Passphrase: strong — this protects all your secrets\n'
        printf '\n'

        if ! gpg --full-generate-key; then
            error "require keys: key generation failed"
            return 1
        fi

        fingerprints="$(_require_keys_fingerprints)" || return 1

        if [[ -z "$fingerprints" ]]; then
            error "require keys: no usable secret key exists after generation"
            return 1
        fi
    fi

    local cache
    cache="$(_require_keys_cache)" || return 1

    # Already confirmed: do not show enrollment instructions or prompt again.
    if _require_keys_enrolled "$cache" "$fingerprints"; then
        msg "KEYS" "GPG enrollment confirmed"
        return 0
    fi

    local hostname
    hostname="$(hostname)" || {
        error "require keys: failed to determine hostname"
        return 1
    }

    if [[ -z "$hostname" ]]; then
        error "require keys: hostname is empty"
        return 1
    fi

    _require_keys_show_enrollment "$fingerprints" "$hostname"

    _require_keys_confirm_enrollment || return 1

    _require_keys_save_enrollment "$cache" "$fingerprints" || return 1

    msg "KEYS" "GPG enrollment confirmed"
    return 0
}

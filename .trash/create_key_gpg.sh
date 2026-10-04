#!/usr/bin/env bash
# =============================================================================
# create key gpg — local GPG identity and password-store enrollment
#
#   create key gpg
#
# Creates a GPG key if none exists, then walks the user through enrolling
# this host as a gopass recipient. Enrollment confirmation is cached so
# instructions are shown only once per key fingerprint.
# =============================================================================

_gpg_key_cache() {
    local cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}"
    local cache="$cache_dir/hostcfg-keys.json"

    mkdir -p "$cache_dir" || {
        error "create key gpg: failed to create '$cache_dir'"
        return 1
    }

    if [[ ! -f "$cache" ]]; then
        printf '%s\n' '{"enrolled":[]}' > "$cache" || {
            error "create key gpg: failed to initialize '$cache'"
            return 1
        }
    fi

    printf '%s' "$cache"
}

_gpg_key_fingerprints() {
    local listing

    listing="$(gpg --list-secret-keys --with-colons 2>/dev/null)" || {
        error "create key gpg: failed to list secret keys"
        return 1
    }

    printf '%s\n' "$listing" |
        awk -F: '
            $1 == "sec" { want_fpr = 1; next }
            want_fpr && $1 == "fpr" { print $10; want_fpr = 0; next }
            $1 == "sec" { want_fpr = 1 }
        '
}

_gpg_key_enrolled() {
    local cache="$1"
    local fingerprints="$2"
    local fpr

    command -v jq >/dev/null 2>&1 || {
        error "create key gpg: jq is required for enrollment state"
        return 1
    }

    while IFS= read -r fpr; do
        [[ -n "$fpr" ]] || continue
        if ! jq -e \
            --arg f "$fpr" \
            '(.enrolled // []) | any(. == $f)' \
            "$cache" >/dev/null
        then
            return 1
        fi
    done <<< "$fingerprints"

    return 0
}

_gpg_key_save_enrollment() {
    local cache="$1"
    local fingerprints="$2"
    local tmp

    command -v jq >/dev/null 2>&1 || {
        error "create key gpg: jq is required for enrollment state"
        return 1
    }

    tmp="$(mktemp "${cache}.XXXXXX")" || {
        error "create key gpg: failed to create temporary file"
        return 1
    }

    printf '%s\n' "$fingerprints" |
        jq -R -s 'split("\n") | map(select(length > 0)) | {enrolled: .}' \
        > "$tmp" || {
            rm -f "$tmp"
            error "create key gpg: failed to write enrollment state"
            return 1
        }

    mv "$tmp" "$cache" || {
        rm -f "$tmp"
        error "create key gpg: failed to install enrollment state"
        return 1
    }
}

_gpg_key_show_enrollment() {
    local fingerprints="$1"
    local hostname="$2"
    local fpr

    printf '\n'
    printf '  ┌─────────────────────────────────────────────────────────────────┐\n'
    printf '  │  ENROLL THIS HOST IN THE PASSWORD STORE                         │\n'
    printf '  │  Run the following on a host that can already decrypt the store  │\n'
    printf '  └─────────────────────────────────────────────────────────────────┘\n'
    printf '\n'
    printf '  # Import this host'\''s public key:\n\n'

    while IFS= read -r fpr; do
        [[ -n "$fpr" ]] || continue
        printf '    gpg --import <(ssh %s gpg --armor --export %s)\n' \
            "$hostname" "$fpr"
    done <<< "$fingerprints"

    printf '\n'
    printf '  # Add this host as a gopass recipient:\n\n'

    while IFS= read -r fpr; do
        [[ -n "$fpr" ]] || continue
        printf '    gopass recipients add %s\n' "$fpr"
    done <<< "$fingerprints"

    printf '\n'
    printf '  gopass will re-encrypt the store and push it to GitHub.\n'
    printf '  Afterward, sync /data/secrets will pull the updated store.\n'
    printf '\n'
}

_gpg_key_confirm_enrollment() {
    _gum confirm \
        "I have enrolled this host in the password store" \
        --affirmative "Yes" \
        --negative "Not yet" || {
            error "create key gpg: enrollment not confirmed"
            return 1
        }
}

_create_key_gpg() {
    command -v gpg >/dev/null 2>&1 || {
        error "create key gpg: gpg is not installed"
        return 1
    }

    local fingerprints
    fingerprints="$(_gpg_key_fingerprints)" || return 1

    if [[ -z "$fingerprints" ]]; then
        msg "gpg" "no key found — generating one now"
        printf '\n'
        printf '  Recommended choices:\n'
        printf '    Key type  : ECC (sign and encrypt) — Ed25519 + Cv25519\n'
        printf '    Validity  : 1y\n'
        printf '    Name      : this hostname (%s)\n' "$(hostname)"
        printf '    Passphrase: strong — this protects all your secrets\n'
        printf '\n'

        gpg --full-generate-key || {
            error "create key gpg: key generation failed"
            return 1
        }

        fingerprints="$(_gpg_key_fingerprints)" || return 1

        if [[ -z "$fingerprints" ]]; then
            error "create key gpg: no usable secret key after generation"
            return 1
        fi
    fi

    local cache
    cache="$(_gpg_key_cache)" || return 1

    if _gpg_key_enrolled "$cache" "$fingerprints"; then
        msg "gpg" "enrollment confirmed"
        return 0
    fi

    local hostname
    hostname="$(hostname)" || {
        error "create key gpg: failed to determine hostname"
        return 1
    }

    [[ -n "$hostname" ]] || {
        error "create key gpg: hostname is empty"
        return 1
    }

    _gpg_key_show_enrollment "$fingerprints" "$hostname"
    _gpg_key_confirm_enrollment || return 1
    _gpg_key_save_enrollment "$cache" "$fingerprints" || return 1

    msg "gpg" "enrollment confirmed"
    return 0
}

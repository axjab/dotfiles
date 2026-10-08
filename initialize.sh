#!/bin/bash

# URL: https://raw.githubusercontent.com/axjab/etc/server/initialize.sh

# set -e
# set -u

# Configuration Constants
SSH_TIMEOUT=3

main() {
    install_dependencies
    record_initialization
    ensure_arch
    run_tests
}

install_dependencies() {
    local deps=("jq" "git" "gpg" "gopass")
    local missing=()

    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing+=("$dep")
        fi
    done

    if (( ${#missing[@]} > 0 )); then
        printf 'Missing dependencies detected: %s. Installing automatically...\n' "${missing[*]}"
        sudo apt-get update -y

        for dep in "${missing[@]}"; do
            case "$dep" in
                tailscale)
                    curl -fsSL https://tailscale.com/install.sh | sh
                    ;;
                gopass)
                    sudo apt-get install -y gopass
                    ;;
                *)
                    sudo apt-get install -y "$dep"
                    ;;
            esac
        done

        clear
        exec "$0" "$@"
    fi
}

run_tests() {
    _test "Pretty hostname" test_pretty_hostname
    _test "Location"        test_location
    _test "Host tags"       test_tags
    _test "Default user"    test_user
    _test "GPG Fingerprint" test_gpg_fp
    _test "SSH Host Key"    test_ssh_key
    _test "Repo host"       test_git_server
    _test "Store host"      test_file_server
    _test "Tailnet status"  test_tailscale
    _test "Github status"   test_github
    _test "Executables"     test_executables
    _test "Configuration"   test_configuration
    _test "Credentials"     test_credentials
    _test "Vault decryption" test_vault_decryption
}

_test() {
    local label="$1"
    local test_fn="$2"
    local val

    # Execute test and capture stdout; errors flow directly to stderr/console
    val="$("$test_fn")"
    local status=$?

    if [[ $status -eq 0 && -n "$val" ]]; then
        printf '\033[0;32m[OK]\033[0m   %-22s -> %s\n' "$label" "$val"
    else
        printf '\033[0;31m[FAIL]\033[0m %-22s (Exit code: %d)\n' "$label" "$status"
        "$test_fn" --explain
    fi
}

_get_machine_info() {
    local key="$1"
    command -v jq >/dev/null 2>&1 || return 21

    local json
    json="$(hostnamectl status --json=short)" || return 22

    case "$key" in
        PRETTY_HOSTNAME)
            local val
            val="$(echo "$json" | jq -r '.PrettyHostname // empty')"
            [[ -n "$val" ]] && { echo "$val"; return 0; }
            ;;
        LOCATION)
            local val
            val="$(echo "$json" | jq -r '.Location // empty')"
            [[ -n "$val" ]] && { echo "$val"; return 0; }
            ;;
    esac

    echo "$json" | jq -r --arg k "$key=" '.MachineInformationData[]? | select(startswith($k)) | sub("^" + $k; "")'
}

_set_machine_info() {
    local key="$1"
    local val="$2"
    local file="/etc/machine-info"

    sudo -v || return 31

    if [[ ! -f "$file" ]]; then
        sudo touch "$file" || return 32
    fi

    if grep -q "^${key}=" "$file"; then
        sudo sed -i "s|^${key}=.*|${key}=\"${val}\"|" "$file"
    else
        echo "${key}=\"${val}\"" | sudo tee -a "$file" >/dev/null
    fi
}

_relative_time() {
    local iso="$1"
    [[ -n "$iso" ]] || return 41

    local past now diff
    past=$(date -d "$iso" +%s) || return 42
    now=$(date +%s)
    diff=$((now - past))

    if (( diff < 60 )); then
        echo "${diff}s ago"
    elif (( diff < 3600 )); then
        echo "$((diff / 60))m ago"
    elif (( diff < 86400 )); then
        echo "$((diff / 3600))h ago"
    else
        echo "$((diff / 86400))d ago"
    fi
}

record_initialization() {
    local prev_init ago
    prev_init="$(_get_machine_info "INITIALIZED_AT")" || true

    if [[ -n "$prev_init" ]]; then
        ago="$(_relative_time "$prev_init")"
        printf 'Last initialized: %s (%s)\n\n' "$prev_init" "${ago:-unknown}"
    else
        printf 'First-time host initialization.\n\n'
    fi

    local now_iso
    now_iso="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    _set_machine_info "INITIALIZED_AT" "$now_iso"
}

ensure_arch() {
    _set_machine_info "ARCH" "$(uname -m)"
}

test_pretty_hostname() {
    if [[ "$1" == "--explain" ]]; then
        printf '       -> Fix: sudo hostnamectl set-hostname --pretty "My Host Name"\n'
        return 101
    fi

    local val
    val="$(_get_machine_info "PRETTY_HOSTNAME")" || return 101
    [[ -n "$val" ]] || return 101
    echo "$val"
}

test_location() {
    if [[ "$1" == "--explain" ]]; then
        printf '       -> Fix: sudo hostnamectl location "LAT,LON"\n'
        return 102
    fi

    local val
    val="$(_get_machine_info "LOCATION")" || return 102
    [[ -n "$val" ]] || return 102
    echo "$val"
}

test_tags() {
    if [[ "$1" == "--explain" ]]; then
        printf '       -> Fix: sudo bash -c '\''echo "TAGS=server:media" >> /etc/machine-info'\''\n'
        return 103
    fi

    local val
    val="$(_get_machine_info "TAGS")" || return 103
    [[ -n "$val" ]] || return 103
    echo "$val"
}

test_user() {
    if [[ "$1" == "--explain" ]]; then
        printf '       -> Fix: sudo bash -c '\''echo "USER=%s" >> /etc/machine-info'\''\n' "${USER:-username}"
        return 104
    fi

    local val
    val="$(_get_machine_info "USER")" || return 104
    [[ -n "$val" ]] || return 104
    echo "$val"
}

test_gpg_fp() {
    if [[ "$1" == "--explain" ]]; then
        local host
        host="$(hostname -s || hostname)"
        printf '       -> Fix: Generate key via "gpg --full-generate-key" and record FP:\n'
        printf '               sudo bash -c '\''echo "GPG_FP=<FINGERPRINT>" >> /etc/machine-info'\''\n'
        return 111
    fi

    command -v gpg >/dev/null 2>&1 || return 111

    local fp
    fp="$(_get_machine_info "GPG_FP")" || return 112
    [[ -n "$fp" ]] || return 112

    if gpg --batch --quiet --list-secret-keys --with-colons | grep -Fq ":$fp:"; then
        echo "$fp"
        return 0
    fi

    return 113
}

test_ssh_key() {
    local host key_priv key_pub
    host="$(hostname -s || hostname)"
    key_priv="$HOME/.ssh/$host.key"
    key_pub="$HOME/.ssh/$host.key.pub"

    if [[ "$1" == "--explain" ]]; then
        printf '       -> Fix: ssh-keygen -t ed25519 -f "%s" -C "%s"\n' "$key_priv" "$host"
        printf '               sudo bash -c '\''echo "SSH_KEY=$(cat %s)" >> /etc/machine-info'\''\n' "$key_pub"
        return 121
    fi

    [[ -f "$key_priv" && -f "$key_pub" ]] || return 121

    local reg_key
    reg_key="$(_get_machine_info "SSH_KEY")" || return 122
    [[ -n "$reg_key" ]] || return 122

    local disk_pub
    disk_pub="$(cat "$key_pub")"
    if [[ "$disk_pub" == "$reg_key" ]]; then
        awk '{print $1, $3}' "$key_pub" || echo "valid"
        return 0
    fi

    return 123
}

test_tailscale() {
    local user
    user="$(_get_machine_info "USER")"
    user="${user:-i}"

    if [[ "$1" == "--explain" ]]; then
        printf '       -> Fix: Install and activate Tailscale SSH:\n'
        printf '               curl -fsSL https://tailscale.com/install.sh | sh\n'
        printf '               sudo tailscale up --ssh --operator %s\n' "$user"
        return 131
    fi

    command -v tailscale >/dev/null 2>&1 || return 131

    local state
    if command -v jq >/dev/null 2>&1; then
        state="$(sudo tailscale status --json | jq -r '.BackendState // empty')"
    else
        state="$(sudo tailscale status --json | grep -o '"BackendState"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*:[[:space:]]*"//; s/"$//')"
    fi

    if [[ "$state" == "Running" ]]; then
        local ip
        ip="$(tailscale ip -4)"
        echo "Running (${ip:-connected})"
        return 0
    fi

    return 132
}

test_github() {
    if [[ "$1" == "--explain" ]]; then
        printf '       -> Fix: Add SSH key to https://github.com/settings/keys and configure ~/.ssh/config:\n'
        printf '               Host github\n'
        printf '                   Hostname github.com\n'
        printf '                   User git\n'
        return 141
    fi

    # Check for Host entry or Hostname directive, ignoring leading whitespace and case
    if [[ -f "$HOME/.ssh/config" ]]; then
        grep -iqE '^[[:space:]]*(Host[[:space:]]+github|Hostname[[:space:]]+github\.com)' "$HOME/.ssh/config" || return 141
    else
        return 141
    fi

    local ssh_out
    echo "FIX: HARD-CODED Host *******************" >&2
    ssh_out="$(ssh -T -o StrictHostKeyChecking=accept-new gh 2>&1)"

    if echo "$ssh_out" | grep -q "You've successfully authenticated"; then
        local gh_user
        gh_user="$(echo "$ssh_out" | sed -n 's/.*Hi \([^!]*\)!.*/\1/p')"
        echo "Authenticated (${gh_user:-ok})"
        return 0
    fi

    return 142
}

test_git_server() {
    if [[ "$1" == "--explain" ]]; then
        printf '       -> Fix: Add Host repo (git server) block to ~/.ssh/config:\n'
        printf '               Host repo\n'
        printf '                   Hostname majula\n'
        printf '                   User git\n'
        return 151
    fi

    grep -Fqx "Host repo" "$HOME/.ssh/config" || return 151

    local ssh_out
    ssh_out="$(timeout "$SSH_TIMEOUT" ssh -o ConnectTimeout="$SSH_TIMEOUT" -o BatchMode=yes -T repo 2>&1)"
    local status=$?

    if [[ $status -eq 128 ]] || echo "$ssh_out" | grep -q "Run with no arguments or with -c cmd"; then
        echo "Authenticated (repo / majula)"
        return 0
    fi

    return 152
}

test_file_server() {
    if [[ "$1" == "--explain" ]]; then
        printf '       -> Fix: Add Host store block to ~/.ssh/config:\n'
        printf '               Host store\n'
        printf '                   HostName majula\n'
        printf '                   User store\n'
        return 161
    fi

    grep -Fqx "Host store" "$HOME/.ssh/config" || return 161

    timeout "$SSH_TIMEOUT" ssh -o ConnectTimeout="$SSH_TIMEOUT" -o BatchMode=yes -T store true  # execute any command so that it does get killed
    local status=$?

    if [[ $status -eq 0 || $status -eq 1 ]]; then
        echo "Reachable"
        return 0
    fi

    return 162
}

test_executables() {
    if [[ "$1" == "--explain" ]]; then
        printf '       -> Fix: Clone or sync executables from github:axjab/executables to /exe\n'
        return 171
    fi

    [[ -d "/exe" ]] || return 171
    find /exe -maxdepth 1 -type f | grep -q . || return 172
    echo "Installed (/exe)"
}

test_configuration() {
    if [[ "$1" == "--explain" ]]; then
        printf '       -> Fix: Ensure required dotfiles and links are present in ~/.config/etc or home directory\n'
        return 181
    fi

    [[ -f "$HOME/.env" || -d "$HOME/etc" ]] || return 181
    echo "Installed"
}

test_credentials() {
    if [[ "$1" == "--explain" ]]; then
        printf '       -> Fix: Sync /data/vault from repo or ensure credential mounts exist\n'
        return 191
    fi

    [[ -d "/data/vault" || -f "$HOME/.config/gopass/config" ]] || return 191
    echo "Installed (/data/vault)"
}

test_vault_decryption() {
    local fp hostname confirm
    fp="$(_get_machine_info "GPG_FP")" || true
    hostname="$(hostname -s || hostname)"

    if [[ "$1" == "--explain" ]]; then
        printf '\n'
        printf '  ┌─────────────────────────────────────────────────────────────────┐\n'
        printf '  │  ENROLL THIS HOST IN THE PASSWORD STORE                         │\n'
        printf '  │  Run the following on a peer host that can decrypt (e.g. majula)│\n'
        printf '  └─────────────────────────────────────────────────────────────────┘\n'
        printf '\n'
        printf '  1. Import this host'\''s public key on peer:\n'
        printf '     gpg --import <(ssh %s gpg --armor --export %s)\n\n' "$hostname" "${fp:-<GPG_FP>}"
        printf '  2. Add key and sync password store on peer:\n'
        printf '     gopass recipients add %s\n' "${fp:-<GPG_FP>}"
        printf '     gopass sync\n\n'
        printf '  3. Pull updated vault on this host:\n'
        printf '     PASSWORD_STORE_DIR=/data/vault gopass sync\n'

        if [[ -t 0 ]]; then
            read -r -p "  Has this host been enrolled in gopass and synced? [y/N]: " confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                git -C /data/vault pull
            fi
        fi
        return 201
    fi

    command -v gopass >/dev/null 2>&1 || return 201
    [[ -d "/data/vault" ]] || return 202

    if PASSWORD_STORE_DIR=/data/vault gopass gitlab/token; then
        echo "Decryption functional (/data/vault)"
        return 0
    fi

    return 203
}

main

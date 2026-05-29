
# Gopass local configuration

Summary:

Need gopass from https://github.com/ax-mad/scripts

1. Import gpg key
2. Run ~/etc/gopass/apply

## On Source Machine

### 1. List your keys
```bash
gpg --list-secret-keys --keyid-format LONG
```
Note the key ID (e.g., `DEADBEEF12345678` after `rsa4096/`).

### 2. Export private key
```bash
gpg --export-secret-keys --armor DEADBEEF12345678 > private-key.asc
```

### 3. Export public key
```bash
gpg --export --armor DEADBEEF12345678 > public-key.asc
```

### 4. Copy to new machine
```bash
scp private-key.asc public-key.asc user@newmachine:~/
```
Or use USB/network share.

## On Destination Machine

### 5. Import keys
```bash
gpg --import private-key.asc
gpg --import public-key.asc
```

### 6. Set trust level
```bash
gpg --edit-key DEADBEEF12345678
```
At the `gpg>` prompt:
```
trust
5
save
```

### 7. Verify
```bash
gpg --list-secret-keys
```

### 8. Clean up
```bash
shred -u private-key.asc public-key.asc
```

## Important Notes

- **Without the passphrase**, the key is useless — know it before migrating.
- **Securely delete** the `.asc` files after importing.
- The `--armor` flag creates text files (safe for copy/paste).
- Without `--armor`, you get binary files (smaller, not human-readable).

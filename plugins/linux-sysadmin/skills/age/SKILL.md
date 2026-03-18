---
name: age
description: >
  age file encryption tool: keypair generation, encryption to public key
  recipients, passphrase encryption, multiple recipients, ASCII armor,
  SSH key recipients, stdin/stdout pipelines, and batch file encryption patterns.
  MUST consult when installing, configuring, or troubleshooting age.
triggerPhrases:
  - "age"
  - "file encryption"
  - "encrypt file"
  - "decrypt file"
  - "age encryption"
  - "GPG alternative"
  - "modern encryption"
globs: []
last_verified: "unverified"
---

## Identity

| Property | Value |
|----------|-------|
| **Binary** | `age`, `age-keygen` |
| **Config** | No persistent config — invoked directly |
| **Logs** | No persistent logs — output to terminal |
| **Type** | CLI tool |
| **Install** | `apt install age` / `dnf install age` |

## Quick Start

```bash
sudo apt install age
age-keygen -o ~/.age/key.txt
age-keygen -y ~/.age/key.txt        # show public key
age -r age1PUBLIC_KEY... -o secret.age plaintext.txt
age -d -i ~/.age/key.txt -o plaintext.txt secret.age
```

## Key Operations

| Task | Command |
|------|---------|
| Generate a new keypair | `age-keygen -o ~/.age/key.txt` |
| Show public key from a key file | `age-keygen -y ~/.age/key.txt` |
| Encrypt a file to a recipient | `age -r age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac97 -o encrypted.age plaintext.txt` |
| Encrypt to self (using your own key file) | `age -R ~/.age/key.txt -o encrypted.age plaintext.txt` |
| Decrypt a file | `age -d -i ~/.age/key.txt -o plaintext.txt encrypted.age` |
| Encrypt with passphrase (interactive) | `age -p -o encrypted.age plaintext.txt` |
| Encrypt to multiple recipients | `age -r age1key1... -r age1key2... -o encrypted.age plaintext.txt` |
| Encrypt stdin, write to stdout | `echo "secret" \| age -r age1key... > encrypted.age` |
| Decrypt stdin, write to stdout | `age -d -i ~/.age/key.txt < encrypted.age` |
| ASCII armor output (base64 text) | `age -a -r age1key... -o encrypted.txt plaintext.txt` |
| Encrypt using an SSH public key | `age -R ~/.ssh/id_ed25519.pub -o encrypted.age plaintext.txt` |
| Decrypt using an SSH private key | `age -d -i ~/.ssh/id_ed25519 -o plaintext.txt encrypted.age` |
| Batch encrypt a directory | `tar czf - /path/to/dir \| age -r age1key... > backup.tar.gz.age` |

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| `age: error: no recipients specified` | Missing `-r` or `-R` flag | Add `-r age1...` for a public key or `-R keyfile` for a key file |
| `age: error: reading from stdin` with file input | Forgot to specify input file or pipe | Pass the file as the last positional argument, or pipe via stdin |
| Recipient public key starts with `ssh-ed25519`, not `age1` | Wrong key file — SSH public key format | Use `-R ~/.ssh/id_ed25519.pub` (capital R) for SSH pub key files |
| Decryption fails with "no identity matched" | Wrong key used for decryption | The file was encrypted to a different public key; use the matching private key |
| Passphrase decryption is very slow | scrypt KDF is intentionally slow | This is by design for brute-force resistance; wait for it |
| Binary output breaks terminal | age output is binary by default | Add `-a` for ASCII armor when the output needs to be text-safe |
| `age-keygen: command not found` | Packaged separately on some distros | Install the `age` package; `age-keygen` is usually included |

## Pain Points

- **No key management**: age has no keyring, no key ID system, and no way to list which keys can decrypt a file. Store key files yourself (e.g., in `~/.age/`) and document which keys encrypted which files.
- **`-r` takes the public key string, not a file**: The public key (starting with `age1...`) is passed directly to `-r`. To read from a file of public keys (one per line), use `-R keyfile` (capital R).
- **SSH public keys work as recipients**: Any `~/.ssh/id_ed25519.pub` or `~/.ssh/id_rsa.pub` can be used as an age recipient with `-R`. This is convenient for homelab use where you already manage SSH keys.
- **Passphrase mode uses scrypt**: The slow KDF is intentional — it makes offline brute-forcing expensive. If decryption feels slow, it's working correctly. For automated workflows, use key-based encryption instead.

## See Also
- **openssl-cli** — TLS certificate management and general-purpose encryption/hashing
- **ssh-keygen** — SSH key generation and management; age can use SSH keys as recipients

## References
See `references/` for:
- `cheatsheet.md` — task-organized command reference
- `docs.md` — official documentation links
- **age is encryption-only, not signing**: age provides confidentiality but not authentication or integrity verification beyond what encryption provides. For signed releases or verification, use `minisign` or `ssh-keygen -Y sign`.

## See Also

- **openssl-cli** — TLS certificate management and general-purpose encryption/hashing
- **ssh-keygen** — SSH key generation and management; age can use SSH keys as recipients

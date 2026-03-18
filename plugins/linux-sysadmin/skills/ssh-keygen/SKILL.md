---
name: ssh-keygen
description: >
  ssh-keygen SSH key management: key generation, passphrase management, fingerprint
  display, public key extraction, known_hosts management, format conversion,
  OpenSSH certificate signing, and signature verification.
  MUST consult when generating, managing, or converting SSH keys.
triggerPhrases:
  - "ssh-keygen"
  - "SSH key"
  - "generate SSH key"
  - "SSH keypair"
  - "authorized_keys"
  - "known_hosts"
  - "fingerprint"
  - "key signing"
  - "SSH certificate"
  - "ed25519"
globs:
  - "**/.ssh/authorized_keys"
  - "**/.ssh/known_hosts"
  - "**/.ssh/config"
  - "**/.ssh/id_*"
last_verified: "unverified"
---

## Identity

| Property | Value |
|----------|-------|
| **Binary** | `ssh-keygen` |
| **Config** | `~/.ssh/config`, `~/.ssh/authorized_keys`, `~/.ssh/known_hosts` |
| **Logs** | No persistent logs — output to terminal |
| **Type** | CLI tool |
| **Install** | `apt install openssh-client` / `dnf install openssh-clients` (pre-installed) |

## Quick Start

```bash
sudo apt install openssh-client
ssh-keygen -t ed25519 -C "user@host"          # generate Ed25519 keypair
ssh-keygen -l -f ~/.ssh/id_ed25519            # verify fingerprint
ssh-copy-id -i ~/.ssh/id_ed25519.pub user@server  # deploy to remote host
```

## Key Operations

| Task | Command |
|------|---------|
| Generate Ed25519 keypair (preferred) | `ssh-keygen -t ed25519 -C "user@host" -f ~/.ssh/id_ed25519` |
| Generate RSA keypair (4096-bit, legacy compat) | `ssh-keygen -t rsa -b 4096 -C "user@host" -f ~/.ssh/id_rsa` |
| Generate without passphrase (automation) | `ssh-keygen -t ed25519 -N "" -f /etc/myapp/ssh_key` |
| Show key fingerprint | `ssh-keygen -l -f ~/.ssh/id_ed25519` |
| Show fingerprint in SHA256 (default) | `ssh-keygen -l -E sha256 -f ~/.ssh/id_ed25519` |
| Show fingerprint in MD5 (legacy comparison) | `ssh-keygen -l -E md5 -f ~/.ssh/id_ed25519` |
| Extract public key from private key | `ssh-keygen -y -f ~/.ssh/id_ed25519 > ~/.ssh/id_ed25519.pub` |
| Change passphrase on existing key | `ssh-keygen -p -f ~/.ssh/id_ed25519` |
| Update key comment | `ssh-keygen -c -C "new-comment" -f ~/.ssh/id_ed25519` |
| Remove a host from known_hosts | `ssh-keygen -R hostname` |
| Check known_hosts for a host entry | `ssh-keygen -F hostname` |
| Hash all hostnames in known_hosts | `ssh-keygen -H -f ~/.ssh/known_hosts` |
| Convert key to PEM format | `ssh-keygen -e -m PEM -f ~/.ssh/id_rsa.pub` |
| Sign a public key with a CA | `ssh-keygen -s ca_key -I key_id -n username -V +30d ~/.ssh/id_ed25519.pub` |
| Verify a signed file | `ssh-keygen -Y verify -f allowed_signers -I identity -n namespace -s file.sig < file` |

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| `~/.ssh/authorized_keys` ignored by sshd | File or directory permissions too open | Fix: `chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys` |
| SSH still prompts for password after adding key | Wrong user's authorized_keys, or sshd `PubkeyAuthentication no` | Check sshd_config: `grep PubkeyAuthentication /etc/ssh/sshd_config`; verify the key is in the correct user's file |
| `ssh-copy-id` overwrites existing keys | It doesn't — it appends | `ssh-copy-id` is safe to run repeatedly; it skips keys already present |
| `REMOTE HOST IDENTIFICATION HAS CHANGED` | Host key changed (server rebuild, MITM risk) | Verify with the server admin, then: `ssh-keygen -R hostname` to remove the stale entry |
| `ssh-keygen -R` can't find the host | Host was stored as a hashed entry | Hashed `known_hosts` requires `ssh-keygen -F hostname` to find, then `-R hostname` to remove |
| Certificate-authenticated login fails | CA public key not in `TrustedUserCAKeys` on server | Add `TrustedUserCAKeys /etc/ssh/ca.pub` to `/etc/ssh/sshd_config` and reload sshd |

## Pain Points

- **Ed25519 over RSA for new keys**: Ed25519 keys are shorter (68 chars for the public key), faster to verify, and have no length-vs-security tradeoff. RSA is only needed for compatibility with legacy servers that predate Ed25519 support.
- **Permissions are enforced, not advisory**: sshd will silently ignore `authorized_keys` if `~/.ssh/` is group-writable or world-readable. The required modes are `700` for `~/.ssh/` and `600` for `authorized_keys`. No error message is emitted — the key simply doesn't work.
- **Use `ssh-copy-id` instead of manual editing**: Manually appending to `authorized_keys` risks formatting mistakes and accidental line overwrites. `ssh-copy-id -i ~/.ssh/id_ed25519.pub user@host` appends safely and handles newlines correctly.
- **`known_hosts` hashing prevents hostname enumeration but complicates management**: `ssh-keygen -H` hashes all entries so an attacker with read access to the file can't enumerate which hosts you connect to. The downside: you can no longer grep for a hostname directly — use `ssh-keygen -F hostname` to query.
- **OpenSSH certificates are underused in fleet management**: `ssh-keygen -s` signs a user's public key with a CA, granting time-limited, identity-bound access without distributing individual public keys to every server. Instead of managing `authorized_keys` on 100 servers, distribute only the CA public key once. Most homelabs don't set this up and pay the per-server key management tax indefinitely.

## See Also

- **sshd** — OpenSSH server that consumes the keys generated by ssh-keygen
- **age** — modern file encryption tool that can use SSH keys for encryption
- **openssl-cli** — certificate and key operations for TLS (complementary to SSH key management)
- **step-ca** — private certificate authority for issuing SSH certificates at scale

## References

See `references/` for:
- `cheatsheet.md` — key generation, fingerprint display, known_hosts management, certificate signing
- `docs.md` — official documentation links

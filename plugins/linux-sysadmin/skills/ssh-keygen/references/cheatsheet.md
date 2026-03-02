# ssh-keygen Command Reference

Each block below is copy-paste-ready. Substitute usernames, hostnames, key
paths, and identities for your actual values.

---

## 1. Generate Keys

```bash
# Ed25519 keypair (recommended for all new keys)
# -t: key type  -C: comment (usually user@host)  -f: output file
ssh-keygen -t ed25519 -C "alice@workstation" -f ~/.ssh/id_ed25519

# RSA keypair at 4096 bits (for compatibility with legacy systems)
ssh-keygen -t rsa -b 4096 -C "alice@workstation" -f ~/.ssh/id_rsa

# Generate without an interactive passphrase prompt (for automation)
ssh-keygen -t ed25519 -N "" -C "deploy-key" -f /etc/myapp/deploy_key

# Batch generation: key for each server
for host in web1 web2 db1; do
  ssh-keygen -t ed25519 -N "" -C "auto-$host" -f ~/.ssh/id_$host
done
```

---

## 2. Fingerprints and Key Inspection

```bash
# Show fingerprint of a public or private key
ssh-keygen -l -f ~/.ssh/id_ed25519

# Show fingerprint in SHA256 format (default in modern OpenSSH)
ssh-keygen -l -E sha256 -f ~/.ssh/id_ed25519

# Show fingerprint in MD5 format (for comparison with legacy systems)
ssh-keygen -l -E md5 -f ~/.ssh/id_ed25519

# Show the randomart bubble diagram
ssh-keygen -lv -f ~/.ssh/id_ed25519

# Show the public key fingerprint from a known_hosts entry
ssh-keygen -l -f ~/.ssh/known_hosts
```

---

## 3. Extract and Manage Public Keys

```bash
# Recover the public key from a private key file
ssh-keygen -y -f ~/.ssh/id_ed25519 > ~/.ssh/id_ed25519.pub

# Copy public key to a remote server's authorized_keys (safe — appends)
ssh-copy-id -i ~/.ssh/id_ed25519.pub user@host

# Copy key with a non-default SSH port
ssh-copy-id -i ~/.ssh/id_ed25519.pub -p 2222 user@host

# Manually append (use ssh-copy-id instead when possible)
cat ~/.ssh/id_ed25519.pub | ssh user@host 'mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys'
```

---

## 4. Passphrase Management

```bash
# Change (or add) passphrase on an existing key
ssh-keygen -p -f ~/.ssh/id_ed25519

# Change passphrase non-interactively (scripted)
ssh-keygen -p -f ~/.ssh/id_ed25519 -P "old_passphrase" -N "new_passphrase"

# Remove passphrase (set empty new passphrase — for service accounts)
ssh-keygen -p -f ~/.ssh/id_ed25519 -N ""

# Update the comment field without changing the key
ssh-keygen -c -C "alice@newhost" -f ~/.ssh/id_ed25519
```

---

## 5. known_hosts Management

```bash
# Check if a host is in known_hosts
ssh-keygen -F hostname

# Check with a non-default port
ssh-keygen -F '[hostname]:2222'

# Remove a host entry (after server rebuild or key rotation)
ssh-keygen -R hostname

# Remove a host with non-default port
ssh-keygen -R '[hostname]:2222'

# Hash all entries in known_hosts (prevents hostname enumeration)
ssh-keygen -H -f ~/.ssh/known_hosts

# View a hashed known_hosts entry (can't be un-hashed)
ssh-keygen -F hostname -f ~/.ssh/known_hosts
```

---

## 6. Key Format Conversion

```bash
# Convert OpenSSH public key to RFC 4716 (PEM) format
ssh-keygen -e -m RFC4716 -f ~/.ssh/id_ed25519.pub

# Convert OpenSSH public key to PKCS8 format
ssh-keygen -e -m PKCS8 -f ~/.ssh/id_rsa.pub

# Convert RFC 4716 formatted key back to OpenSSH format
ssh-keygen -i -m RFC4716 -f foreign-key.pub

# Convert PKCS8 public key to OpenSSH format
ssh-keygen -i -m PKCS8 -f pkcs8-key.pub

# Change key format of private key (OpenSSH format)
ssh-keygen -p -f ~/.ssh/id_rsa -m OpenSSH
```

---

## 7. OpenSSH Certificates (CA Signing)

```bash
# Generate a CA key (treat this key with extreme care)
ssh-keygen -t ed25519 -f ~/.ssh/ca_key -C "ssh-ca"

# Sign a user's public key with the CA
# -s: CA key  -I: key identity (who this cert is for)  -n: principals (username)  -V: validity
ssh-keygen -s ~/.ssh/ca_key -I "alice@company" -n alice -V +30d ~/.ssh/id_ed25519.pub

# Sign with multiple principals (user can log in as either)
ssh-keygen -s ~/.ssh/ca_key -I "alice@company" -n "alice,admin" -V +30d ~/.ssh/id_ed25519.pub

# Sign a host key (for host certificate — eliminates known_hosts prompts)
ssh-keygen -s ~/.ssh/ca_key -I "web1.internal" -h -n "web1.internal,192.168.1.10" -V +365d /etc/ssh/ssh_host_ed25519_key.pub

# View certificate details
ssh-keygen -L -f ~/.ssh/id_ed25519-cert.pub
```

On the server, add to `/etc/ssh/sshd_config`:
```
TrustedUserCAKeys /etc/ssh/ca.pub
```
Then copy the CA's public key to `/etc/ssh/ca.pub` and reload sshd.

---

## 8. File Signing and Verification

```bash
# Sign a file using your SSH private key
ssh-keygen -Y sign -f ~/.ssh/id_ed25519 -n file < artifact.tar.gz > artifact.tar.gz.sig

# allowed_signers file format:
# alice@example.com ssh-ed25519 AAAA...

# Verify a signed file
ssh-keygen -Y verify \
  -f allowed_signers \
  -I alice@example.com \
  -n file \
  -s artifact.tar.gz.sig \
  < artifact.tar.gz

# Check if a key is in the allowed_signers file
ssh-keygen -Y check-novalidate -n file -s artifact.tar.gz.sig -f allowed_signers
```

---

## 9. Permission Reference

SSH will silently ignore keys if permissions are wrong. Required modes:

```bash
# Set correct permissions on ~/.ssh directory and files
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_ed25519        # private key
chmod 644 ~/.ssh/id_ed25519.pub    # public key (can be world-readable)
chmod 600 ~/.ssh/authorized_keys
chmod 600 ~/.ssh/config
chmod 644 ~/.ssh/known_hosts

# Verify: sshd checks these on the server side
ls -la ~/.ssh/
```

---

## 10. Practical Key Management Patterns

```bash
# Audit which keys are authorized on a remote host
ssh user@host 'cat ~/.ssh/authorized_keys'

# Remove a specific key from authorized_keys by comment
ssh user@host "sed -i '/alice@oldhost/d' ~/.ssh/authorized_keys"

# Check all authorized_keys files on a server for a fingerprint
for f in /home/*/.ssh/authorized_keys /root/.ssh/authorized_keys; do
  [ -f "$f" ] && ssh-keygen -l -f "$f" 2>/dev/null | grep -v "^$"
done

# Generate a deploy key for a repo (no passphrase, restricted to one repo)
ssh-keygen -t ed25519 -N "" -C "deploy@repo-name" -f ~/.ssh/deploy_repo-name

# Test that key-based auth works before disabling password auth
ssh -i ~/.ssh/id_ed25519 -o PasswordAuthentication=no user@host 'echo OK'
```

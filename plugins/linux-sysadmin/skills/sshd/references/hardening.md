# sshd Hardening Guide

Practical, actionable hardening for OpenSSH servers. Each section is independent —
apply what fits your environment. The complete minimal config is at the bottom.

> **Critical rule**: Run `sudo sshd -t` before every reload. A syntax error in
> sshd_config blocks sshd from restarting — on a remote server, that means lockout.
> Keep a second session open when making config changes remotely.

---

## 1. Disable Password Authentication (Key-Only Auth)

The single highest-impact change. Eliminates password brute force entirely.

**Before disabling**: verify at least one key-based login works in a separate session.

```
# /etc/ssh/sshd_config
PasswordAuthentication no
PermitEmptyPasswords no
ChallengeResponseAuthentication no
KbdInteractiveAuthentication no
```

After changing:

```bash
sudo sshd -t                  # Validate first — always
sudo systemctl reload sshd    # reload, not restart — keeps existing sessions alive
```

To add your public key to a user account:

```bash
# On the server, as that user (or root):
mkdir -p ~/.ssh
chmod 700 ~/.ssh
echo "ssh-ed25519 AAAA... comment" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

Permissions matter: StrictModes will silently reject key auth if `~/.ssh` is
group/world-writable or if the home directory is writable by others.

---

## 2. Disable Root Login

Direct root login conflates authentication with privilege. Use a normal user + sudo instead.

```
# /etc/ssh/sshd_config
PermitRootLogin no
```

If a workflow genuinely requires root SSH access (e.g., a deployment system), use
`prohibit-password` to require key auth rather than `yes`:

```
PermitRootLogin prohibit-password
```

---

## 3. Change the Default Port

Port 22 receives constant automated scanning. Moving to a non-standard port eliminates
that noise from logs and fail2ban. It is not a security control — anyone doing a targeted
scan will find it.

```
# /etc/ssh/sshd_config
Port 2222    # or any port above 1024 that doesn't conflict
```

Update firewall rules before reloading sshd — and keep a session open:

```bash
# firewalld (RHEL/Fedora)
sudo firewall-cmd --permanent --add-port=2222/tcp
sudo firewall-cmd --remove-service=ssh --permanent   # remove port 22 after confirming new port works
sudo firewall-cmd --reload

# ufw (Debian/Ubuntu)
sudo ufw allow 2222/tcp
sudo ufw delete allow 22/tcp   # only after new port is verified

# nftables (manual)
sudo nft add rule inet filter input tcp dport 2222 accept

# Then validate and reload sshd:
sudo sshd -t && sudo systemctl reload sshd

# Test new port from another session before closing:
ssh -p 2222 user@host
```

Tell your SSH client about the new port in `~/.ssh/config`:

```
Host myserver
    HostName myserver.example.com
    Port 2222
    User alice
    IdentityFile ~/.ssh/id_ed25519
```

---

## 4. Restrict Users and Groups

Allowlist who can log in via SSH at all. This is enforced before any other auth.

```
# Allow specific users only:
AllowUsers alice bob deploy

# Or restrict by group (add users to the group, manage membership separately):
AllowGroups ssh-users

# To deny specific accounts regardless of other rules:
DenyUsers tempuser legacy
```

Evaluation order: DenyUsers, AllowUsers, DenyGroups, AllowGroups. The first match wins.
If AllowUsers is set, any user not listed is denied even if they have a valid key.

Create a dedicated SSH group:

```bash
sudo groupadd ssh-users
sudo usermod -aG ssh-users alice
sudo usermod -aG ssh-users bob
```

---

## 5. Limit Authentication Attempts

Reduce the window for per-connection brute force and cap half-open connections:

```
# /etc/ssh/sshd_config
MaxAuthTries 3          # drop connection after 3 failed attempts (default: 6)
LoginGraceTime 30       # seconds allowed to complete auth (default: 120)
MaxStartups 10:30:60    # start dropping at 10 unauthed connections, hard cap at 60
```

`MaxStartups` format: `start:rate:full`
- `start`: begin randomly dropping new connections at this many pending unauthed connections
- `rate`: percentage of connections to drop once start is reached
- `full`: reject all new connections above this count

These settings complement fail2ban, not replace it. fail2ban handles multi-source
brute force across connections; MaxAuthTries limits a single connection.

---

## 6. Client Keepalive (Prevent Dropped Sessions)

Long-idle sessions are dropped by firewalls and NAT devices. SSH-layer keepalives
prevent this and also clean up dead connections server-side.

```
# /etc/ssh/sshd_config
ClientAliveInterval 60      # send a keepalive packet every 60 seconds
ClientAliveCountMax 3       # disconnect after 3 unanswered keepalives (~3 min idle)
TCPKeepAlive yes            # TCP-layer keepalive as a backstop
```

With these settings, sessions time out after roughly 3 minutes of no response. Adjust
`ClientAliveCountMax` upward if legitimate long-running sessions are getting cut off.

---

## 7. Disable Forwarding (When Not Needed)

Forwarding features expand the attack surface. Disable anything not in active use.

```
# /etc/ssh/sshd_config
AllowAgentForwarding no    # prevent agent hijack on compromised servers
AllowTcpForwarding no      # prevent firewall bypass via port tunnels
GatewayPorts no            # prevent remote-forwarded ports from binding on all interfaces
X11Forwarding no           # prevent X display exposure
PermitTunnel no            # prevent VPN-over-SSH
```

If specific users or groups need forwarding, enable it only for them using a Match block:

```
# Allow tunneling for ops team only
Match Group ssh-admins
    AllowAgentForwarding yes
    AllowTcpForwarding yes
```

For SFTP-only accounts, restrict them completely:

```
Match User sftpuser
    ForceCommand internal-sftp
    ChrootDirectory /srv/sftp/%u
    AllowTcpForwarding no
    X11Forwarding no
```

---

## 8. fail2ban Integration

fail2ban watches `/var/log/auth.log` (or the systemd journal) for repeated auth
failures and bans offending IPs at the firewall level. It works independently of
sshd — sshd doesn't know about the bans.

The default sshd jail in fail2ban works out of the box on most distros:

```bash
# Debian/Ubuntu
sudo apt install fail2ban

# RHEL/Fedora
sudo dnf install fail2ban

# Enable and start
sudo systemctl enable --now fail2ban
```

The default sshd jail is typically enabled in `/etc/fail2ban/jail.conf`. Override
in `/etc/fail2ban/jail.local` to avoid losing customizations on upgrades:

```ini
# /etc/fail2ban/jail.local
[sshd]
enabled = true
port    = ssh          # or your custom port number
maxretry = 3
bantime  = 1h
findtime = 10m
```

Check status and active bans:

```bash
sudo fail2ban-client status sshd
sudo fail2ban-client status sshd | grep 'Banned IP'
```

When diagnosing a lockout, check BOTH sshd logs and fail2ban logs:

```bash
journalctl -u sshd --since "1 hour ago"
sudo fail2ban-client status sshd
sudo nft list ruleset | grep fail2ban    # or: sudo iptables -L -n | grep fail2ban
```

---

## 9. Key Generation Best Practices

Use ed25519 for new keys. It is faster, smaller, and considered more conservative
than ECDSA from a cryptographic standpoint. RSA at 4096 bits is an acceptable
fallback for compatibility with older clients.

```bash
# Preferred: ed25519
ssh-keygen -t ed25519 -C "user@hostname-$(date +%Y-%m)"

# RSA fallback (4096 bits minimum — the default 3072 is acceptable but 4096 is safer)
ssh-keygen -t rsa -b 4096 -C "user@hostname-$(date +%Y-%m)"
```

Always set a passphrase. An unprotected private key that leaks grants immediate access.
Use `ssh-agent` or a hardware key (YubiKey/FIDO2) to avoid retyping the passphrase.

```bash
# Add key to agent for the current session
ssh-add ~/.ssh/id_ed25519

# FIDO2/hardware key (OpenSSH 8.2+)
ssh-keygen -t ed25519-sk -C "yubikey-slot1"   # requires hardware key present
```

Key management discipline:
- One key per machine (or per purpose) — not one key for everything
- Rotate keys on role changes or device loss
- Never reuse the same key across personal and work contexts
- The `-C` comment field (`user@host-date`) aids auditing in `authorized_keys`

---

## 10. Minimal Cipher Suite (OpenSSH 8.x+)

The defaults are reasonable, but explicitly listing a restricted set removes
legacy algorithms before they can be negotiated by a downgrade attack.

```
# /etc/ssh/sshd_config

# Key exchange: curve25519 and sntrup761 (post-quantum hybrid) preferred
KexAlgorithms sntrup761x25519-sha512@openssh.com,curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512

# Ciphers: authenticated encryption (GCM/poly1305) only
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr

# MACs: encrypt-then-MAC variants first
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com,hmac-sha2-512,hmac-sha2-256

# Host key algorithms: ed25519 first, rsa-sha2-* as fallback; no legacy ssh-rsa (SHA-1)
HostKeyAlgorithms ssh-ed25519,ssh-ed25519-cert-v01@openssh.com,rsa-sha2-512,rsa-sha2-256
```

Removing algorithms may break older SSH clients (anything pre-7.x). Test with
`ssh-audit` before deploying to production:

```bash
# ssh-audit from https://github.com/jtesta/ssh-audit
ssh-audit localhost
# or against a remote host:
ssh-audit myserver.example.com
```

---

## Complete Minimal Hardened sshd_config

Drop this into `/etc/ssh/sshd_config` for a key-only, hardened baseline.
Adjust port, AllowUsers, and ClientAlive values for your environment.

```
# /etc/ssh/sshd_config — hardened baseline
# Validate before every reload: sudo sshd -t

Port 22
AddressFamily any
ListenAddress 0.0.0.0

HostKey /etc/ssh/ssh_host_ed25519_key
HostKey /etc/ssh/ssh_host_rsa_key

SyslogFacility AUTH
LogLevel VERBOSE

LoginGraceTime 30
PermitRootLogin no
StrictModes yes
MaxAuthTries 3
MaxSessions 10

PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys

PasswordAuthentication no
PermitEmptyPasswords no
ChallengeResponseAuthentication no
KbdInteractiveAuthentication no
UsePAM yes

AllowAgentForwarding no
AllowTcpForwarding no
GatewayPorts no
X11Forwarding no
PermitTunnel no

PrintMotd no
PrintLastLog yes
TCPKeepAlive yes
UseDNS no

ClientAliveInterval 60
ClientAliveCountMax 3
MaxStartups 10:30:60

# Restrict to explicit user list — update this before deploying
AllowUsers alice bob

# Modern algorithm set (OpenSSH 8.x+)
KexAlgorithms sntrup761x25519-sha512@openssh.com,curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com,hmac-sha2-512,hmac-sha2-256
HostKeyAlgorithms ssh-ed25519,ssh-ed25519-cert-v01@openssh.com,rsa-sha2-512,rsa-sha2-256

AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server
```

After deploying:

```bash
sudo sshd -t                    # must return clean
sudo sshd -T | grep -E 'password|pubkey|root|port'   # spot-check key settings
sudo systemctl reload sshd
ssh-audit localhost              # verify no weak algorithms remain
```

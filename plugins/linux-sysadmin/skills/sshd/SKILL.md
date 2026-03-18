---
name: sshd
description: >
  OpenSSH server (sshd) administration: config, key-based auth, hardening,
  troubleshooting connection issues, tunneling, and port forwarding.
  MUST consult when installing, configuring, or troubleshooting sshd.
triggerPhrases:
  - "sshd"
  - "ssh server"
  - "ssh config"
  - "openssh"
  - "ssh hardening"
  - "ssh keys"
  - "authorized_keys"
  - "sshd_config"
globs:
  - "**/sshd_config"
  - "**/sshd_config.d/**"
  - "**/.ssh/authorized_keys"
last_verified: "unverified"
---

## Identity
- **Unit**: `sshd.service` (or `ssh.service` on some Debian systems)
- **Config**: `/etc/ssh/sshd_config`, `/etc/ssh/sshd_config.d/` (drop-in dir)
- **Logs**: `journalctl -u sshd` / `journalctl -u ssh`, `/var/log/auth.log` (Debian), `/var/log/secure` (RHEL)
- **User**: runs as root (drops privs per session)
- **Install**: pre-installed on most distros; `apt install openssh-server` / `dnf install openssh-server`

## Quick Start

```bash
sudo apt install openssh-server
sudo systemctl enable --now sshd
sudo sshd -t                          # validate config syntax
ss -tlnp | grep ':22'                 # verify listening on port 22
ssh -v localhost                       # test connection
```

## Key Operations

| Task | Command |
|------|---------|
| Validate config | `sudo sshd -t` |
| Reload (without dropping connections) | `sudo systemctl reload sshd` |
| Restart (drops active sessions!) | `sudo systemctl restart sshd` |
| Test connection | `ssh -v user@host` (verbose, shows auth methods tried) |
| Check effective config | `sudo sshd -T` (shows full parsed config with defaults) |
| Test config for specific user | `sudo sshd -T -C user=myuser,host=1.2.3.4` |

## Expected Ports
- 22/tcp (default); commonly changed to reduce noise
- Verify: `ss -tlnp | grep sshd`

## Health Checks
1. `systemctl is-active sshd` → `active`
2. `sudo sshd -t` → no errors
3. `ss -tlnp | grep ':22'` → sshd listening
4. Test login: `ssh -o BatchMode=yes -o ConnectTimeout=5 localhost echo ok`

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| `Connection refused` | sshd not running or wrong port | `systemctl status sshd`, `ss -tlnp \| grep sshd` |
| `Permission denied (publickey)` | Wrong key, wrong permissions, wrong user | Check `~/.ssh/` perms (700), `authorized_keys` perms (600), correct public key present |
| `Permission denied (password)` | `PasswordAuthentication no` or wrong password | `sudo sshd -T \| grep passwordauth` |
| Config reload fails silently | Syntax error — reload succeeds but old config stays | Always run `sudo sshd -t` before reload |
| `Too many authentication failures` | SSH agent offering too many keys | Use `-o IdentitiesOnly=yes` and specify `-i keyfile` |
| `Host key verification failed` | Server key changed | `ssh-keygen -R hostname` to remove stale entry |
| Slow login | DNS reverse lookup timing out | Set `UseDNS no` in sshd_config |
| `Maximum startups` reached | Too many unauthenticated connections | Raise `MaxStartups`; investigate brute force |

## Pain Points
- **ALWAYS validate before reload**: `sshd -t` first. A syntax error in sshd_config will prevent restart — if you're remote, you're locked out.
- **Drop-in files**: `/etc/ssh/sshd_config.d/*.conf` files are included and can silently override the main config. Check `sshd -T` to see the merged result.
- **`Match` blocks**: Settings inside `Match` blocks only apply after connection, not at startup — so `sshd -t` passes but behavior differs per-user/host.
- **`AuthorizedKeysFile` path**: `.ssh/authorized_keys` is relative to the user's home. If home dir permissions are wrong, key auth silently fails.
- **Restart vs reload**: `systemctl reload sshd` re-reads config without dropping existing sessions. `restart` drops all active sessions. Always prefer reload.
- **fail2ban interaction**: fail2ban bans IPs at the firewall level; sshd itself doesn't know. Check both logs when diagnosing lockouts.

## See Also

- **ssh-keygen** — generate, manage, and convert SSH keys used for sshd authentication
- **fail2ban** — automatic brute-force protection by banning IPs after repeated login failures

## References
See `references/` for:
- `sshd_config.annotated` — every sshd_config directive explained
- `hardening.md` — key-only auth, fail2ban integration, port changes, security baseline
- `docs.md` — official documentation links

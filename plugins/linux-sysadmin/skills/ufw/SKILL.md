---
name: ufw
description: >
  ufw (Uncomplicated Firewall) administration — enabling, rules management, app
  profiles, logging, and troubleshooting. Covers iptables frontend basics.
  Triggers on: ufw, firewall, iptables, uncomplicated firewall, open port, block
  port, firewall rules, allow ssh.
globs:
  - "**/ufw/**"
  - "**/ufw/user.rules"
---

## Identity
- **Package**: `ufw`
- **Config**: `/etc/ufw/` (rules in `user.rules`, `user6.rules`)
- **App profiles**: `/etc/ufw/applications.d/`
- **Logs**: `journalctl -k | grep UFW`, `/var/log/ufw.log`
- **Install**: `apt install ufw` (Debian/Ubuntu); not default on RHEL (use firewalld instead)
- **Backend**: iptables/nftables (abstraction layer)

## Key Operations

| Goal | Command |
|------|---------|
| Check status + rules | `sudo ufw status verbose` |
| Enable firewall | `sudo ufw enable` |
| Disable firewall | `sudo ufw disable` |
| Allow a port | `sudo ufw allow 80/tcp` |
| Allow by service name | `sudo ufw allow ssh` |
| Allow app profile | `sudo ufw allow 'Nginx Full'` |
| Deny a port | `sudo ufw deny 25/tcp` |
| Delete a rule | `sudo ufw delete allow 80/tcp` |
| Allow from specific IP | `sudo ufw allow from 192.168.1.0/24` |
| Allow IP to specific port | `sudo ufw allow from 192.168.1.10 to any port 5432` |
| Numbered rules (for deletion) | `sudo ufw status numbered` |
| Delete by number | `sudo ufw delete 3` |
| Reset all rules | `sudo ufw reset` |
| Reload | `sudo ufw reload` |
| Enable logging | `sudo ufw logging on` |

## Expected State
- Status: `active`
- Default policy: `deny (incoming)`, `allow (outgoing)`, `disabled (routed)`
- SSH must be allowed before enabling: `sudo ufw allow ssh` → THEN `sudo ufw enable`

## Common Failures

| Symptom | Likely cause | Check/Fix |
|---------|-------------|-----------|
| Locked out after enabling | SSH not allowed before `ufw enable` | Access via console; `sudo ufw allow ssh` then re-enable |
| Rule shows but traffic still blocked | Rule order matters; more specific rules win | Check `sudo ufw status numbered`; rule order is insertion order |
| Docker bypasses ufw | Docker modifies iptables directly | ufw rules don't apply to Docker-published ports by default; see Pain Points |
| Port allowed but still unreachable | Application not listening, or listening on wrong interface | `ss -tlnp \| grep <port>` |
| IPv6 rule not applied | IPv6 disabled in ufw config | Check `/etc/ufw/ufw.conf` — `IPV6=yes` required |
| `ufw status` shows inactive | Not enabled | `sudo ufw enable` (allow SSH first!) |

## Pain Points
- **SSH first, enable second**: Enabling ufw without allowing SSH first locks you out of remote systems. Always: `sudo ufw allow ssh` → `sudo ufw enable`.
- **Docker bypasses ufw**: Docker uses raw iptables rules that bypass ufw's INPUT chain. Ports published with `-p 80:80` are reachable even if ufw blocks port 80. Fix: use Docker's `--iptables=false` (complex) or bind to localhost and proxy via nginx, or use specific Docker network rules.
- **`ufw reset` clears all rules**: Useful for a fresh start but removes your SSH allow rule too. Immediately re-add SSH after reset.
- **App profiles**: `/etc/ufw/applications.d/` defines named profiles (like 'Nginx Full', 'OpenSSH'). Show available profiles: `sudo ufw app list`.
- **Rule order**: First matching rule wins. More specific rules must appear before broader ones.
- **Logging**: `ufw logging on` logs at LOW level by default. Increase with `sudo ufw logging medium` or `high`.

## References
See `references/` for:
- `common-rules.md` — practical rule examples for common services
- `docs.md` — official documentation links

---
name: fail2ban
description: >
  fail2ban intrusion prevention: jail configuration, filter rules, ban/unban
  management, log monitoring, and troubleshooting.
  MUST consult when installing, configuring, or troubleshooting fail2ban.
triggerPhrases:
  - "fail2ban"
  - "intrusion prevention"
  - "ban IP"
  - "brute force protection"
  - "jail"
  - "f2b"
  - "unban"
  - "fail2ban-client"
  - "fail2ban-regex"
  - "jail.local"
globs:
  - "**/fail2ban/**"
  - "**/jail.local"
  - "**/jail.conf"
  - "**/jail.d/**"
  - "**/filter.d/**"
  - "**/action.d/**"
last_verified: "unverified"
---

## Identity
- **Unit**: `fail2ban.service`
- **Config**: `/etc/fail2ban/jail.local` (local overrides — never edit `jail.conf`)
- **Jails dir**: `/etc/fail2ban/jail.d/` (drop-in jail files)
- **Filters dir**: `/etc/fail2ban/filter.d/` (regex patterns per service)
- **Actions dir**: `/etc/fail2ban/action.d/` (ban/unban actions)
- **Logs**: `journalctl -u fail2ban`, `/var/log/fail2ban.log`
- **Install**: `apt install fail2ban` / `dnf install fail2ban`

## Quick Start

```bash
sudo apt install fail2ban
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
sudo systemctl enable --now fail2ban
sudo fail2ban-client status            # list active jails
sudo fail2ban-client status sshd       # check sshd jail details
```

## Key Operations

| Task | Command |
|------|---------|
| Check status (all jails) | `sudo fail2ban-client status` |
| Status of specific jail | `sudo fail2ban-client status sshd` |
| Unban an IP | `sudo fail2ban-client set sshd unbanip 1.2.3.4` |
| Manually ban an IP | `sudo fail2ban-client set sshd banip 1.2.3.4` |
| Test a filter | `sudo fail2ban-regex /var/log/auth.log /etc/fail2ban/filter.d/sshd.conf` |
| Reload config | `sudo fail2ban-client reload` |
| Reload specific jail | `sudo fail2ban-client reload sshd` |
| Show banned IPs for jail | `sudo fail2ban-client get sshd banned` |
| View recent bans | `sudo journalctl -u fail2ban | grep Ban` |

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| Jail not catching failures | Filter regex doesn't match log format | Test with `fail2ban-regex`; check `datepattern` |
| Ban not applied | Action misconfigured or iptables not working | Check `fail2ban.log`; verify action with `fail2ban-client get sshd actions` |
| IP unbanned immediately | `ignoreip` includes the IP | Check `ignoreip` in jail.local |
| Service won't start | Syntax error in jail.local | `fail2ban-client --test` or check log for parse errors |
| Bans not persisting across restarts | `dbpurgeage` too short or DB issue | Check `/var/lib/fail2ban/fail2ban.sqlite3` |
| Legitimate users getting banned | `findtime`/`maxretry` too aggressive | Raise `maxretry` or shorten `bantime` for affected jail |

## Pain Points
- **Never edit `jail.conf`**: It gets overwritten on upgrades. All customizations go in `jail.local` or `jail.d/*.conf`.
- **`ignoreip` is critical**: Always add your own IPs/subnets to `ignoreip`. A misconfigured jail can lock you out.
- **Log backend**: fail2ban polls log files by default. For systemd-journald logs, set `backend = systemd` in the jail.
- **Action backends**: Default uses `iptables-multiport`. On systems with nftables only, this may fail. Use `nftables` action explicitly.
- **Bantime multiplier**: `bantime.multiplier = true` enables recidivism — repeat offenders get exponentially longer bans. Very useful.
- **`fail2ban-regex` for testing**: Always test filters before deploying: `sudo fail2ban-regex /var/log/nginx/error.log /etc/fail2ban/filter.d/nginx-http-auth.conf`
- **Database**: Persistent ban state stored in `/var/lib/fail2ban/fail2ban.sqlite3`. Survives restarts if `dbpurgeage` is sufficient.

## See Also

- **crowdsec** — collaborative intrusion prevention that shares threat intelligence across installations
- **ufw** — simple firewall frontend; fail2ban injects rules into ufw/iptables to enforce bans
- **firewalld** — zone-based firewall; fail2ban can use firewalld actions for ban enforcement
- **sshd** — most common service protected by fail2ban; configure sshd hardening alongside fail2ban

## References
See `references/` for:
- `jail.local.annotated` — every jail.local directive with defaults and recommendations
- `custom-filters.md` — writing custom filters for services not built-in
- `docs.md` — official documentation links

---
name: pihole
description: >
  Pi-hole network-wide ad blocker and DNS sinkhole: installation, configuration,
  blocklist management, DNS settings, troubleshooting, and DHCP server setup.
  MUST consult when installing, configuring, or troubleshooting pihole.
triggerPhrases:
  - "pi-hole"
  - "pihole"
  - "ad blocker"
  - "DNS sinkhole"
  - "blocklist"
  - "pihole-FTL"
  - "gravity"
last_verified: "unverified"
---

## Identity
- **Service unit**: `pihole-FTL.service` (the DNS resolver + stats engine)
- **Config dir**: `/etc/pihole/` (setupVars.conf, pihole-FTL.conf, custom.list, etc.)
- **Web interface**: runs on port 80 (or configured port) — `http://<ip>/admin`
- **Logs**: `journalctl -u pihole-FTL`, `/var/log/pihole/pihole.log`, `/var/log/pihole/FTL.log`
- **Data/lists**: `/etc/pihole/gravity.db` (SQLite, blocklist database)
- **Install**: Official script: `curl -sSL https://install.pi-hole.net | bash` (review before running)

## Quick Start
```bash
curl -sSL https://install.pi-hole.net | bash   # interactive installer
pihole status                                    # FTL is listening on port 53
dig @127.0.0.1 google.com +short                # resolves = working
dig @127.0.0.1 doubleclick.net +short            # 0.0.0.0 = blocking works
```

## Key Operations

| Task | Command |
|------|---------|
| Check service status | `pihole status` |
| Update blocklists | `pihole -g` (gravity update) |
| Enable/disable blocking | `pihole enable` / `pihole disable` |
| Disable for X seconds | `pihole disable 300` |
| View query log | `pihole -t` (tail) or `pihole -q domain.com` (query) |
| Whitelist a domain | `pihole -w domain.com` |
| Blacklist a domain | `pihole -b domain.com` |
| Remove from whitelist | `pihole -w -d domain.com` |
| Update Pi-hole | `pihole -up` |
| Repair/reinstall | `pihole -r` |
| Check version | `pihole version` |
| Flush log | `pihole flush` |
| Tail FTL log | `pihole -t` |
| View statistics | `pihole -c` (chronometer in terminal) |
| Backup config | `pihole -a -t` (generates teleporter backup) |

## Expected Ports
- 53/udp+tcp (DNS — primary function)
- 80/tcp (web interface, can be changed)
- 67/udp (DHCP server, if enabled)
- 4711/tcp (FTL API, localhost only by default)

## Health Checks
1. `pihole status` → `[✓] FTL is listening on port 53`
2. `systemctl is-active pihole-FTL` → `active`
3. `dig @127.0.0.1 google.com` → resolves (Pi-hole answering)
4. `dig @127.0.0.1 doubleclick.net` → returns 0.0.0.0 (blocked)

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| DNS not resolving | FTL not running or port conflict | `pihole status`; `ss -ulnp \| grep :53` |
| Port 53 conflict | systemd-resolved using port 53 | Disable resolved stub listener; see Pain Points |
| Web interface 404 | lighttpd not running | `systemctl status lighttpd` |
| Gravity update fails | Network issue or blocklist URL down | Check internet connectivity; try `pihole -g` manually |
| Too many false positives | Aggressive blocklists | Whitelist domains; switch to less aggressive lists |
| Clients not using Pi-hole | DHCP/DNS not configured on router | Set Pi-hole as DNS server in router DHCP settings |
| `SERVFAIL` for valid domains | Upstream DNS issue or FTL crash | Check `/var/log/pihole/FTL.log`; check upstream DNS |

## Pain Points
- **systemd-resolved conflict on Ubuntu**: Ubuntu 18.04+ runs `systemd-resolved` with a stub listener on 127.0.0.53:53. This conflicts with Pi-hole on port 53. Fix: disable the stub listener in `/etc/systemd/resolved.conf` (`DNSStubListener=no`) and point `/etc/resolv.conf` at Pi-hole.
- **Runs as root**: Pi-hole's FTL service runs as root. Keep the host updated and network-isolated.
- **Teleporter backup**: Use `pihole -a -t` to export config before OS upgrades or migration. Restores blocklists, settings, and custom DNS entries.
- **Custom DNS entries**: `/etc/pihole/custom.list` for local DNS A/CNAME records. Format: `IP hostname`. Editable but `pihole restartdns` needed after changes.
- **unbound integration**: Pi-hole → unbound is a common stack. Pi-hole handles blocking; unbound handles recursive resolution. Use `127.0.0.1#5335` as Pi-hole's upstream when unbound listens on 5335.
- **Docker installs**: Official Docker image (`pihole/pihole`) requires `network_mode: host` or careful port mapping for DNS to work on all network interfaces.
- **DHCP conflicts**: Only enable Pi-hole's DHCP server if you can disable your router's DHCP server first. Running two DHCP servers causes chaos.

## See Also
- **unbound** — recursive DNS resolver commonly paired with Pi-hole for full DNS independence
- **dnsmasq** — lightweight DNS forwarder and DHCP server; Pi-hole's FTL is a fork of dnsmasq
- **bind9** — full authoritative DNS server for hosting your own zones alongside Pi-hole
- **avahi** — mDNS service discovery on the same network Pi-hole serves

## References
See `references/` for:
- `configuration.md` — setupVars.conf and pihole-FTL.conf reference
- `docs.md` — official documentation links

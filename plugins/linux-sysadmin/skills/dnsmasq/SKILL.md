---
name: dnsmasq
description: >
  dnsmasq DNS forwarder and DHCP server administration: config syntax,
  interface binding, static leases, upstream resolvers, local domain resolution,
  sinkhole/blocking, logging, and troubleshooting.
  MUST consult when installing, configuring, or troubleshooting dnsmasq.
triggerPhrases:
  - "dnsmasq"
  - "dnsmasq DHCP"
  - "dnsmasq DNS"
  - "local DNS resolver"
  - "DHCP server dnsmasq"
  - "DNS DHCP combo"
  - "dhcp-range"
  - "dhcp-host"
  - "dnsmasq.conf"
globs:
  - "**/dnsmasq.conf"
  - "**/dnsmasq.d/**"
last_verified: "unverified"
---

## Identity
- **Unit**: `dnsmasq.service`
- **Config**: `/etc/dnsmasq.conf`, `/etc/dnsmasq.d/` (drop-in directory)
- **Logs**: `journalctl -u dnsmasq`, `/var/log/dnsmasq.log` (if `log-facility` set)
- **Leases**: `/var/lib/misc/dnsmasq.leases`
- **Distro install**: `apt install dnsmasq` / `dnf install dnsmasq`

## Quick Start
```bash
sudo apt install dnsmasq
sudo systemctl enable --now dnsmasq
dnsmasq --test                     # syntax check OK
dig @127.0.0.1 google.com +short   # returns IP = forwarding works
```

## Key Operations

| Task | Command |
|------|---------|
| Status | `systemctl status dnsmasq` |
| Reload (re-reads config, leases) | `sudo systemctl reload dnsmasq` |
| Restart | `sudo systemctl restart dnsmasq` |
| Test config syntax | `dnsmasq --test` |
| Test config with explicit file | `dnsmasq --test -C /etc/dnsmasq.conf` |
| View active config (compiled) | `dnsmasq --test --conf-file=/etc/dnsmasq.conf 2>&1` |
| Check listening ports | `ss -ulnp \| grep dnsmasq; ss -tlnp \| grep dnsmasq` |
| Query DNS via dnsmasq | `dig @127.0.0.1 example.com` |
| Check DNSSEC validation | `dig @127.0.0.1 example.com +dnssec` |
| List DHCP leases | `cat /var/lib/misc/dnsmasq.leases` |
| Signal re-read of hosts/leases | `sudo kill -HUP $(pidof dnsmasq)` |
| Add static DHCP host | Add `dhcp-host=MAC,IP,hostname` to config, then reload |
| Block domain (sinkhole) | Add `address=/badsite.com/` to config, then reload |
| Watch live DNS queries | `journalctl -u dnsmasq -f` (requires `log-queries` in config) |

## Expected Ports
- **53/udp and 53/tcp** — DNS (both protocols required; TCP for large responses and DNSSEC)
- **67/udp** — DHCP server (only when DHCP is enabled)
- Verify: `ss -ulnp | grep ':53\|:67'`
- Firewall (DNS only): `sudo ufw allow 53` or `sudo firewall-cmd --add-service=dns --permanent`
- Firewall (DHCP): `sudo ufw allow 67/udp` or `sudo firewall-cmd --add-service=dhcp --permanent`

## Health Checks
1. `systemctl is-active dnsmasq` → `active`
2. `dnsmasq --test 2>&1` → contains `syntax check OK`
3. `dig @127.0.0.1 google.com +short` → returns one or more IP addresses (not `SERVFAIL`)
4. `ss -ulnp | grep ':53'` → dnsmasq listed on port 53

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| `failed to create listening socket for port 53: Address already in use` | systemd-resolved stub listener is on 53 | `ss -ulnp \| grep :53` — disable resolved stub: `DNSStubListener=no` in `/etc/systemd/resolved.conf`, then `systemctl restart systemd-resolved` |
| DHCP not handing out addresses | No `interface=` or `listen-address=` set | Add `interface=eth0` (or the LAN interface name) to config and reload |
| DNS queries return `SERVFAIL` | Upstream servers unreachable or no `server=` set | Check `/etc/resolv.conf`; add `server=8.8.8.8` explicitly; verify connectivity with `dig @8.8.8.8 google.com` |
| `/etc/hosts` entries not served via DNS | `no-hosts` option is set | Remove `no-hosts` from config, or use `addn-hosts=` to add a separate hosts file |
| NetworkManager overwrites `/etc/resolv.conf` | NM manages DNS and resets resolv.conf on reconnect | Set `dns=none` in `/etc/NetworkManager/NetworkManager.conf` under `[main]`, or configure NM to use dnsmasq as a plugin |
| Clients get IP but no DNS via DHCP | `dhcp-option=6` not set (option 6 = DNS server) | Add `dhcp-option=6,<dnsmasq-ip>` to config and reload |
| Log shows queries but responses are slow | Upstream resolver latency or no-cache scenario | Check `cache-size` (default 150); increase to 1000; verify upstream latency with `dig @<upstream>` |
| DNSSEC validation failures for legitimate domains | Clock skew or upstream doesn't support DNSSEC | Check `timedatectl`; temporarily disable with `dnssec=no` to confirm; fix NTP sync |

## Pain Points
- **systemd-resolved conflict on Ubuntu/Debian**: On modern Ubuntu, `systemd-resolved` binds 127.0.0.53:53 by default AND sets `/etc/resolv.conf` to point there. You must disable its stub listener (`DNSStubListener=no`) and point `/etc/resolv.conf` at `127.0.0.1` (dnsmasq) before dnsmasq can start. Alternatively, run dnsmasq on the physical interface address only (not `127.0.0.1`) and leave the stub in place, at the cost of some complexity.
- **`interface=` is mandatory for DHCP**: dnsmasq silently ignores DHCP requests on interfaces not explicitly listed. If DHCP appears to start but hands out nothing, a missing `interface=` line is the most likely cause.
- **`conf-dir` for modular config**: Drop-in files in `/etc/dnsmasq.d/` are only included when `conf-dir=/etc/dnsmasq.d/,*.conf` appears in `dnsmasq.conf`. Without this, the directory is ignored. Debian-packaged dnsmasq typically includes this already; manual installs may not.
- **NetworkManager integration**: NM has a built-in dnsmasq plugin (`dns=dnsmasq` in `NetworkManager.conf`) that runs its own dnsmasq instance per-connection. This conflicts with a standalone dnsmasq. Pick one approach — do not run both.
- **DNSSEC validation gotchas**: Enabling `dnssec` requires correct system time (within a few minutes) and an upstream resolver that passes DNSSEC records. Validating behind a corporate proxy that intercepts DNS will break. Use `dnssec-check-unsigned` carefully — it flags unsigned zones as `BOGUS`, which breaks many CDNs and older domains.
- **`bind-interfaces` vs default any-interface behavior**: By default dnsmasq listens on all interfaces but filters by the `interface=` list. With `bind-interfaces` it actually binds only to the listed interfaces — necessary in multi-homed hosts to avoid port conflicts with other DNS services on other interfaces.

## See Also
- **pihole** — DNS sinkhole for network-wide ad blocking, uses dnsmasq (or FTL fork) under the hood
- **unbound** — recursive DNS resolver with DNSSEC validation, often paired with dnsmasq or Pi-hole
- **bind9** — full authoritative DNS server for hosting zones, heavier than dnsmasq
- **dhcp** — ISC DHCP / Kea DHCP server for more advanced DHCP-only deployments
- **avahi** — mDNS/zeroconf for .local hostname resolution alongside DNS

## References
See `references/` for:
- `dnsmasq.conf.annotated` — complete config with every directive explained
- `docs.md` — official documentation and community links

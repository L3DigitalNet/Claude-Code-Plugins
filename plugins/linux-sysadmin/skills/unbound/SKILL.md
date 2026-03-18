---
name: unbound
description: >
  Unbound recursive DNS resolver: configuration, DNSSEC validation, root
  hints, performance tuning, Pi-hole integration, and troubleshooting.
  MUST consult when installing, configuring, or troubleshooting unbound.
triggerPhrases:
  - "unbound"
  - "recursive resolver"
  - "DNSSEC"
  - "DNS resolver"
  - "root hints"
  - "unbound.conf"
  - "unbound-control"
globs:
  - "**/unbound.conf"
  - "**/unbound/**/*.conf"
  - "**/unbound/unbound.conf.d/**"
last_verified: "unverified"
---

## Identity
- **Unit**: `unbound.service`
- **Config**: `/etc/unbound/unbound.conf`, `/etc/unbound/unbound.conf.d/`
- **Root hints**: `/usr/share/dns/root.hints` or `/var/lib/unbound/root.hints`
- **Logs**: `journalctl -u unbound`
- **User**: `unbound` (drops privileges after startup)
- **Install**: `apt install unbound` / `dnf install unbound`
- **Control**: `unbound-control` (requires key setup: `sudo unbound-control-setup`)

## Quick Start
```bash
sudo apt install unbound
sudo systemctl enable --now unbound
sudo unbound-checkconf              # no errors = valid config
dig @127.0.0.1 google.com +short    # returns IP = resolving works
```

## Key Operations

| Task | Command |
|------|---------|
| Check config | `sudo unbound-checkconf` |
| Reload config (no restart) | `sudo systemctl reload unbound` or `sudo unbound-control reload` |
| Restart service | `sudo systemctl restart unbound` |
| Flush cache | `sudo unbound-control flush_zone .` |
| Test resolution | `dig @127.0.0.1 google.com` |
| Test DNSSEC | `dig @127.0.0.1 dnssec.works` → should resolve; `dig @127.0.0.1 fail.dnssec.works` → should SERVFAIL |
| View stats | `sudo unbound-control stats_noreset` |
| Update root hints | `sudo curl -o /var/lib/unbound/root.hints https://www.internic.net/domain/named.cache` |
| View active config | `sudo unbound-control get_option verbosity` |

## Expected Ports
- 53/udp+tcp (DNS — listens on configured interfaces)
- When used with Pi-hole: configure to listen on 127.0.0.1 port 5335
- Verify: `ss -ulnp | grep unbound`

## Health Checks
1. `systemctl is-active unbound` → `active`
2. `sudo unbound-checkconf` → no errors
3. `dig @127.0.0.1 google.com` → resolves successfully
4. `dig @127.0.0.1 fail.dnssec.works` → `SERVFAIL` (DNSSEC working)

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| Port 53 conflict | systemd-resolved or another DNS service | `ss -ulnp \| grep :53`; disable conflicting service |
| `SERVFAIL` for valid domains | DNSSEC validation failure or upstream issue | Test `dig @8.8.8.8 domain.com` to confirm upstream works; check root hints freshness |
| `access denied` from Pi-hole | `access-control` not allowing Pi-hole's IP | Add `access-control: 127.0.0.1/32 allow` (or Pi-hole's IP) |
| Slow resolution | Root hints stale, cache cold | Update root hints; warm up cache over time |
| Config reload fails | Syntax error | `sudo unbound-checkconf` to find errors |
| DNSSEC failures for specific domains | Domain has broken DNSSEC | Check with `dig +dnssec domain.com @8.8.8.8`; may need to disable DNSSEC for that zone |

## Pain Points
- **Port 5335 convention for Pi-hole stack**: When used with Pi-hole, configure unbound to listen on `127.0.0.1@5335` (not 53). Pi-hole listens on 53; unbound handles recursive resolution on 5335.
- **Root hints freshness**: Root hints (list of root DNS servers) should be updated periodically (yearly or on major changes). Stale hints still work but may miss new root server IPs.
- **DNSSEC validation is strict**: When DNSSEC is enabled, domains with broken DNSSEC will `SERVFAIL` rather than resolve. This is correct behavior but can surprise users. Use `unbound-host` to diagnose.
- **`access-control` required for remote clients**: By default, unbound only allows localhost. Explicitly add subnets with `access-control: 192.168.1.0/24 allow`.
- **`interface:` directive**: By default, listens on localhost only. Set `interface: 0.0.0.0` to listen on all interfaces (needed for network-wide resolver).
- **`do-not-query-localhost`**: Set to `no` when using Pi-hole → unbound stack, so unbound can forward to Pi-hole's blocklist lookup (usually not needed in the simple recursive setup).
- **Cache size tuning**: Default cache is small. Increase `msg-cache-size` and `rrset-cache-size` (set rrset to 2x msg-cache) for better hit rates on home networks.

## See Also
- **pihole** — DNS sinkhole for network-wide ad blocking, commonly uses unbound as its upstream resolver
- **bind9** — full authoritative DNS server and recursive resolver with zone hosting and DNSSEC signing
- **coredns** — plugin-based DNS server used as Kubernetes cluster DNS
- **dnsmasq** — lightweight DNS forwarder and DHCP combo, simpler but less capable than unbound for recursion

## References
See `references/` for:
- `unbound.conf.annotated` — every directive with defaults and recommendations
- `docs.md` — official documentation links

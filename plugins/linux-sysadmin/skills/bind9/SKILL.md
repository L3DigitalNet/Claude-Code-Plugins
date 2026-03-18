---
name: bind9
description: >
  BIND9 (named) authoritative DNS server and recursive resolver administration:
  zone file syntax, named.conf configuration, rndc management, DNSSEC, split-horizon
  views, zone transfers, and troubleshooting.
  MUST consult when installing, configuring, or troubleshooting bind9.
triggerPhrases:
  - "bind9"
  - "named"
  - "BIND DNS"
  - "authoritative DNS"
  - "DNS zone"
  - "zone file"
  - "named.conf"
  - "DNS server setup"
  - "rndc"
  - "zone transfer"
  - "PTR record"
  - "SOA record"
  - "DNS resolver"
  - "forwarders"
  - "DNSSEC signing"
globs:
  - "**/named.conf*"
  - "**/*.zone"
  - "**/db.*"
  - "**/bind/**"
  - "**/named/**"
last_verified: "unverified"
---

## Identity
- **Unit**: `named.service` (Debian/Ubuntu) or `bind9.service` (newer Debian)
- **Config (Debian/Ubuntu)**: `/etc/bind/named.conf`, `/etc/bind/named.conf.options`, `/etc/bind/named.conf.local`, `/etc/bind/named.conf.default-zones`
- **Config (RHEL/Fedora)**: `/etc/named.conf`, `/etc/named/` (included zone configs)
- **Zone dir (Debian)**: `/var/lib/bind/` (dynamic/slave zones), `/etc/bind/` (static master zones)
- **Zone dir (RHEL)**: `/var/named/`
- **Logs**: `journalctl -u named` / `journalctl -u bind9`, `/var/log/named/` (if configured), `journalctl -u named -f` for live
- **Runtime control socket**: `rndc` communicates with `named` via port 953 (loopback only by default)
- **Distro install**: `apt install bind9 bind9utils` / `dnf install bind bind-utils`

## Quick Start
```bash
sudo apt install bind9 bind9utils
sudo systemctl enable --now bind9
named-checkconf /etc/bind/named.conf   # silent = valid config
dig @localhost . SOA +short             # root SOA = named is answering
```

## Key Operations

| Task | Command |
|------|---------|
| Service status | `systemctl status named` (RHEL) or `systemctl status bind9` (Debian) |
| Reload all zones (no restart) | `rndc reload` |
| Reload a specific zone | `rndc reload example.com` |
| Check entire named.conf syntax | `named-checkconf /etc/bind/named.conf` (Debian) or `named-checkconf /etc/named.conf` (RHEL) |
| Check a specific zone file | `named-checkzone example.com /etc/bind/db.example.com` |
| Flush entire cache | `rndc flush` |
| Flush cache for one domain | `rndc flushname example.com` |
| View statistics | `rndc stats` → writes to `/var/named/data/named_stats.txt` |
| Dump current cache | `rndc dumpdb -cache` → writes to `/var/named/data/named_dump.db` |
| Stop accepting queries | `rndc stop` (graceful shutdown) |
| Reload config without restart | `rndc reconfig` (picks up new/removed zones; does not reload existing zone data) |
| Query the local server | `dig @localhost example.com A` |
| Query with full trace | `dig +trace example.com A` |
| Reverse lookup test | `dig @localhost -x 192.168.1.10` |
| Check DNSSEC validation | `dig @localhost example.com A +dnssec` |
| Sign a zone (DNSSEC) | `dnssec-keygen -a ECDSAP256SHA256 -n ZONE example.com && dnssec-signzone -A -3 $(head -c 6 /dev/urandom \| base64) -N INCREMENT -o example.com -t db.example.com` |
| Show active zones | `rndc zonestatus example.com` |

## Expected Ports
- **53/udp** — Standard DNS queries (all responses up to 512 bytes; EDNS0 allows larger)
- **53/tcp** — Zone transfers, large responses, and EDNS0 overflow fallback
- **953/tcp** — `rndc` control channel (loopback only; never expose externally)

Verify: `ss -ulnp | grep :53` and `ss -tlnp | grep :53`
Firewall (ufw): `sudo ufw allow 53/udp && sudo ufw allow 53/tcp`
Firewall (firewalld): `sudo firewall-cmd --permanent --add-service=dns && sudo firewall-cmd --reload`

## Health Checks
1. `systemctl is-active named` (or `bind9`) → `active`
2. `named-checkconf /etc/bind/named.conf 2>&1` → no output (silent = success)
3. `dig @localhost . SOA +short` → returns root zone SOA (confirms named is answering)
4. `dig @localhost example.com A +short` → returns expected IP (confirms zone is loaded)

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| Zone not loading; `SERVFAIL` for zone records | Syntax error in zone file | `named-checkzone example.com /path/to/db.example.com` — shows exact line and error |
| `SERVFAIL` for delegated subdomains | Missing or wrong NS delegation in parent zone | Verify NS and glue records at parent; check with `dig NS sub.example.com @parent-ns` |
| `REFUSED` on queries from clients | `allow-query` ACL too restrictive | Add client subnet to `allow-query` in `named.conf.options`; reload |
| Open recursive resolver (security risk) | `recursion yes` with no `allow-recursion` ACL | Set `allow-recursion { trusted-clients; };` or `allow-recursion { none; };` for authoritative-only |
| Zone transfer denied to secondary | `allow-transfer` not set or wrong IP | Add secondary IP to `allow-transfer` in the primary zone definition; reload |
| Slaves not picking up changes | Serial number not incremented | Increment SOA serial (YYYYMMDDNN format); run `rndc reload` on primary; secondary will NOTIFY and re-transfer |
| AppArmor blocking zone file reads (Debian) | Zone files outside `/etc/bind/` or `/var/lib/bind/` | Move zone files to an AppArmor-allowed path, or add a rule to `/etc/apparmor.d/usr.sbin.named` |
| SELinux blocking named (RHEL) | Zone files have wrong SELinux context | `chcon -t named_zone_t /var/named/db.example.com` or `restorecon -v /var/named/db.example.com` |
| `rndc: connect failed: 127.0.0.1#953: connection refused` | named not running, or rndc key mismatch | Check `systemctl status named`; verify `/etc/bind/rndc.key` matches `controls` block in named.conf |
| `transfer of 'example.com' from x.x.x.x: Transfer completed: 0 messages` | Empty zone transfer | Check `allow-transfer` on primary; verify secondary's `masters` IP matches primary |
| named starts but ignores config changes | `rndc reconfig` vs `rndc reload` confusion | `reconfig` adds/removes zones; `reload` re-reads zone data — use `rndc reload` after zone file edits |

## Pain Points
- **Serial number format**: The YYYYMMDDNN convention (e.g., `2024031501`) is only a convention — named treats it as a plain 32-bit integer. Slaves compare serials using RFC 1982 sequence arithmetic; never decrement a serial or jump it forward by more than 2^31. If you forget to increment, `rndc reload` loads the new file locally but slaves never NOTIFY because the serial hasn't changed.
- **`allow-recursion` vs `allow-query` security**: `allow-query` controls who can send queries at all; `allow-recursion` controls who can use the server as a recursive resolver. An authoritative-only server should set `recursion no` or `allow-recursion { none; };` — leaving recursion open to the internet creates an open resolver usable for DNS amplification attacks.
- **Debian vs RHEL config layout**: Debian splits named.conf into `named.conf.options` (global options), `named.conf.local` (your zones), and `named.conf.default-zones` (root hints, localhost). RHEL uses a single `/etc/named.conf`. Include-based edits must target the correct file.
- **`rndc reload` vs `rndc reconfig` vs full restart**: `rndc reload` re-reads zone files for all currently configured zones. `rndc reconfig` only picks up zone additions and removals from named.conf — it does not re-read zone file data. A full `systemctl restart named` is rarely needed and causes a brief outage; prefer `rndc reload`.
- **DNSSEC complexity**: Key management (ZSK/KSK rotation), signing, NSEC vs NSEC3 choice, DS record submission to parent zone, and key rollover timing are all manual steps unless using automated DNSSEC (`dnssec-policy` in BIND 9.16+). A zone with stale DNSSEC signatures causes SERVFAIL for all DNSSEC-validating resolvers.
- **Forwarders vs recursive resolution**: `forwarders` in the options block makes named forward all recursive queries to the listed servers instead of resolving from root. This is appropriate for internal resolvers that should use corporate DNS. For a public authoritative server, `forwarders` is usually wrong and `recursion no` is the right choice.

## See Also
- **unbound** — recursive-only DNS resolver with built-in DNSSEC validation, simpler than BIND for pure caching/resolving
- **coredns** — plugin-based DNS server, commonly used as Kubernetes cluster DNS
- **dnsmasq** — lightweight DNS forwarder and DHCP combo for small networks
- **bind-utils** — DNS query tools (dig, nslookup, host) for testing and debugging BIND zones
- **pihole** — DNS sinkhole for network-wide ad blocking, can forward to BIND

## References
See `references/` for:
- `named.conf.annotated` — complete named.conf with every directive explained, plus an annotated zone file
- `common-patterns.md` — authoritative server, recursive resolver, split-horizon views, zone transfers, DNSSEC, and more
- `docs.md` — official ISC BIND documentation links

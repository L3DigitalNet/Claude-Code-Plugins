---
name: dhcp
description: >
  ISC DHCP server (isc-dhcp-server / dhcpd) and Kea DHCP administration:
  configuration, lease management, static reservations, subnet declarations,
  relay configuration, and troubleshooting. ISC DHCP reached end-of-life in
  December 2022; Kea DHCP is the supported successor.
  MUST consult when installing, configuring, or troubleshooting dhcp.
triggerPhrases:
  - "DHCP server"
  - "isc-dhcp"
  - "dhcpd"
  - "dhcp lease"
  - "DHCP Linux"
  - "IP address assignment"
  - "dhcpd.conf"
  - "Kea DHCP"
  - "dhcp pool"
  - "dhcp reservation"
  - "dhcp relay"
  - "dhcpd.leases"
globs:
  - "**/dhcpd.conf"
  - "**/dhcp/dhcpd.conf"
  - "**/kea-dhcp4.conf"
  - "**/kea/kea-dhcp4.conf"
last_verified: "unverified"
---

> **EOL Notice**: ISC DHCP (isc-dhcp-server) reached end-of-life on 31 December
> 2022. ISC no longer releases security patches. For new deployments, use
> **Kea DHCP** instead. This skill covers both: isc-dhcp-server because it
> remains widely deployed, and Kea for migrations and greenfield setups.

## Identity

**ISC DHCP (isc-dhcp-server)**
- **Unit**: `isc-dhcp-server.service` (Debian/Ubuntu) or `dhcpd.service` (RHEL/Fedora)
- **Config**: `/etc/dhcp/dhcpd.conf` (Debian) or `/etc/dhcp/dhcpd.conf` (RHEL)
- **Interface config**: `/etc/default/isc-dhcp-server` (Debian) or `/etc/sysconfig/dhcpd` (RHEL)
- **Leases**: `/var/lib/dhcpd/dhcpd.leases`
- **Logs**: `journalctl -u isc-dhcp-server` or `journalctl -u dhcpd`
- **Config validator**: `dhcpd -t -cf /etc/dhcp/dhcpd.conf`
- **Distro install**: `apt install isc-dhcp-server` / `dnf install dhcp-server`

**Kea DHCP (successor)**
- **Unit**: `kea-dhcp4-server.service`
- **Config**: `/etc/kea/kea-dhcp4.conf`
- **Leases**: `/var/lib/kea/kea-leases4.csv` (CSV backend, default)
- **Logs**: `journalctl -u kea-dhcp4-server`
- **Config validator**: `kea-dhcp4 -t /etc/kea/kea-dhcp4.conf`
- **Distro install**: `apt install kea-dhcp4-server` / `dnf install kea-dhcp4`

**Protocol**
- **Port**: 67/UDP (server), 68/UDP (client)

## Quick Start

```bash
sudo apt install isc-dhcp-server                    # install ISC DHCP (or kea-dhcp4-server for Kea)
sudo systemctl enable isc-dhcp-server               # enable on boot
sudo systemctl start isc-dhcp-server                # start the service
dhcpd -t -cf /etc/dhcp/dhcpd.conf                   # validate config syntax
ss -ulnp | grep :67                                  # verify listening on DHCP port
```

## Key Operations

| Task | ISC DHCP | Kea DHCP |
|------|----------|----------|
| Service status | `systemctl status isc-dhcp-server` | `systemctl status kea-dhcp4-server` |
| Show active leases | `cat /var/lib/dhcpd/dhcpd.leases` | `cat /var/lib/kea/kea-leases4.csv` |
| Leases with expiry | `dhcp-lease-list` (isc-dhcp-utils) | `kea-admin lease-dump v4 -o -` |
| Validate config | `dhcpd -t -cf /etc/dhcp/dhcpd.conf` | `kea-dhcp4 -t /etc/kea/kea-dhcp4.conf` |
| Restart after config change | `systemctl restart isc-dhcp-server` | `systemctl reload kea-dhcp4-server` (hot reload) |
| Show logs | `journalctl -u isc-dhcp-server -f` | `journalctl -u kea-dhcp4-server -f` |
| Check listening interface | `ss -ulnp \| grep :67` | `ss -ulnp \| grep :67` |
| Ping gateway to verify coverage | `ping -c3 <gateway-ip>` | `ping -c3 <gateway-ip>` |
| Add static reservation | Edit `dhcpd.conf`, add `host` block, restart | Edit `kea-dhcp4.conf`, add reservation, reload |
| Show pool utilization | `dhcpd-pools -c /etc/dhcp/dhcpd.conf -l /var/lib/dhcpd/dhcpd.leases` | `kea-admin lease-dump v4 \| wc -l` |
| Runtime management | `omshell` (online management shell) | REST API on `http://localhost:8000/` |
| Clear all leases | Stop service, truncate leases file, restart | Stop service, remove CSV, restart |

## Expected Ports

- **67/UDP**: Server receives DHCP requests from clients (and relay agents)
- **68/UDP**: Clients receive DHCP responses
- Verify: `ss -ulnp | grep ':67\|:68'`
- Firewall (ufw): `sudo ufw allow 67/udp && sudo ufw allow 68/udp`
- Firewall (firewalld): `sudo firewall-cmd --add-service=dhcp --permanent && sudo firewall-cmd --reload`

## Health Checks

1. `systemctl is-active isc-dhcp-server` → `active`
2. `dhcpd -t -cf /etc/dhcp/dhcpd.conf 2>&1` → `Internet Systems Consortium DHCP Server ... syntax OK`
3. `ss -ulnp | grep ':67'` → dhcpd listed on the expected interface

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| `No subnet declaration for <IP>` | Interface not declared in config or not listed in INTERFACES var | Debian: check `/etc/default/isc-dhcp-server` `INTERFACESv4=`; RHEL: `/etc/sysconfig/dhcpd`. Add a `subnet` block covering that interface's network |
| Service starts but no leases issued | Subnet declared but no `range` statement | Add `range <start-ip> <end-ip>;` inside the subnet block |
| `no free leases` | Pool exhausted | Check `dhcpd-pools` output; expand range or reduce lease times |
| Static reservation not honoured | Wrong MAC format | ISC DHCP requires colon-separated lowercase hex: `aa:bb:cc:dd:ee:ff` — not hyphens or uppercase |
| Clients on remote subnet get no address | DHCP relay not configured | Ensure relay agent (`dhcrelay` or router `ip helper-address`) forwards to this server; add remote subnet's `subnet` block to config |
| Firewall blocking DHCP | UDP 67/68 not open | `iptables -L -n | grep 67` or `ufw status`; open both ports |
| Lease file corrupt, service won't start | Unclean shutdown or disk full | Stop service, move leases file aside, create empty replacement: `echo "" > /var/lib/dhcpd/dhcpd.leases`, restart |
| `ddns-update-style` warning at startup | Default changed in newer versions | Explicit `ddns-update-style none;` suppresses warning if dynamic DNS is not used |

## Pain Points

- **isc-dhcp-server is EOL**: No security patches since January 2023. Kea DHCP is the direct successor from ISC. Migration is non-trivial but straightforward for simple setups — see the migration guide in `references/docs.md`.
- **Interface variable is not optional (Debian)**: The service will fail silently or refuse to bind if `/etc/default/isc-dhcp-server` does not have `INTERFACESv4="eth0"` (or equivalent). This is separate from the subnet declaration and catches newcomers repeatedly.
- **Leases file grows indefinitely**: `dhcpd.leases` is append-only; old entries are never removed automatically. Use `dhcpd-pools` to monitor utilization and periodically restart the service (which rewrites the file with only active leases). A 100K+ line leases file is not unusual on busy networks.
- **Dynamic DNS updates require Kerberos or shared secret**: `ddns-update-style interim` with a TSIG key to BIND works but the key management is fiddly. Most deployments set `ddns-update-style none;` and handle DNS separately.
- **omshell for runtime changes**: ISC DHCP supports online management via `omshell` — adding leases or reservations without a restart. The syntax is arcane; see the man page. Kea's REST API is significantly more approachable.
- **Kea hot reload**: Unlike isc-dhcp-server, Kea supports `systemctl reload` for config changes without dropping active leases. This is a meaningful operational advantage when managing busy networks.

## See Also

- **dnsmasq** — Lightweight combined DNS/DHCP server, simpler alternative for small networks
- **pihole** — DNS sinkhole that can also serve as a DHCP server on the local network

## References

See `references/` for:
- `dhcpd.conf.annotated` — fully annotated ISC DHCP config with Kea equivalents
- `docs.md` — official documentation, EOL announcement, and migration guides

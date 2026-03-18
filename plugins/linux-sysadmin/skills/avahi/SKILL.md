---
name: avahi
description: >
  Avahi mDNS/zeroconf daemon administration: .local hostname resolution, service
  discovery, service registration, nsswitch.conf configuration, and
  troubleshooting.
  MUST consult when installing, configuring, or troubleshooting avahi.
triggerPhrases:
  - "avahi"
  - "mDNS"
  - "zeroconf"
  - ".local hostname"
  - "avahi-daemon"
  - "service discovery"
  - "mdns4_minimal"
  - "avahi-browse"
globs:
  - "**/avahi-daemon.conf"
  - "**/avahi/services/*.service"
last_verified: "unverified"
---

## Identity
- **Daemon**: `avahi-daemon`
- **Unit**: `avahi-daemon.service`
- **Config**: `/etc/avahi/avahi-daemon.conf`
- **Service definitions**: `/etc/avahi/services/` (XML `.service` files)
- **Port**: 5353/UDP (mDNS multicast — `224.0.0.251`)
- **Distro install**: `apt install avahi-daemon avahi-utils` / `dnf install avahi avahi-tools`
- **NSS plugin**: `libnss-mdns` (Debian/Ubuntu) / `nss-mdns` (Fedora) — required for `.local` resolution

## Quick Start
```bash
sudo apt install avahi-daemon avahi-utils libnss-mdns
sudo systemctl enable --now avahi-daemon
avahi-resolve --name $(hostname).local   # should return an IP
avahi-browse --all --terminate            # list visible services
```

## Key Operations

| Task | Command |
|------|---------|
| Check daemon status | `systemctl status avahi-daemon` |
| Browse all advertised services | `avahi-browse --all --resolve --terminate` |
| Browse a specific service type | `avahi-browse --resolve --terminate _http._tcp` |
| Resolve a `.local` hostname | `avahi-resolve --name hostname.local` |
| Resolve an IP to `.local` name | `avahi-resolve --address 192.168.1.x` |
| Show what this host publishes | `avahi-browse --all --resolve --terminate \| grep "$(hostname)"` |
| Check all published service types | `avahi-browse --dump-db` |
| Register a one-shot service (ad-hoc) | `avahi-publish-service "My Service" _http._tcp 8080` |
| Deregister ad-hoc service | Kill the `avahi-publish-service` process |
| Run daemon in debug/foreground mode | `avahi-daemon --no-drop-root --debug` |
| Disable on a specific interface | Set `deny-interfaces=eth0` in `avahi-daemon.conf` |
| Check NSS mDNS config | `grep mdns /etc/nsswitch.conf` |
| Validate a `.service` XML file | `xmllint --noout /etc/avahi/services/myservice.service` |

## Expected State
- `avahi-daemon.service` active (running)
- `avahi-daemon.socket` active (listening)
- `avahi-resolve --name $(hostname).local` returns a valid IP
- `/etc/nsswitch.conf` hosts line contains `mdns4_minimal [NOTFOUND=return]` before `dns`

## Health Checks
1. `systemctl is-active avahi-daemon` → `active`
2. `avahi-resolve --name $(hostname).local` → returns an IP address (not an error)
3. `avahi-browse --all --terminate 2>/dev/null | wc -l` → non-zero (services visible on network)

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| `.local` names not resolving | `mdns4_minimal` not in `nsswitch.conf` | Check `/etc/nsswitch.conf` hosts line; add `mdns4_minimal [NOTFOUND=return]` before `dns` |
| `.local` resolves on some hosts, not others | `libnss-mdns` not installed on that host | `apt install libnss-mdns` or `dnf install nss-mdns` |
| Hostname not visible to other devices | `avahi-daemon` not running or firewall blocking 5353 | `systemctl start avahi-daemon`; open 5353/UDP and multicast in firewall |
| Conflicts with `systemd-resolved` | Both trying to own 5353/UDP | Either disable avahi (`systemctl disable avahi-daemon`) or set `MulticastDNS=no` in `/etc/systemd/resolved.conf` and restart resolved |
| Slow `.local` resolution (2–5 s delay) | `mdns` (not `mdns4_minimal`) causing IPv6 AAAA lookups to time out | Use `mdns4_minimal` in nsswitch.conf instead of `mdns`; or ensure IPv6 is functional |
| Service not appearing in `avahi-browse` | XML syntax error in `.service` file | `xmllint --noout /etc/avahi/services/file.service`; check `journalctl -u avahi-daemon` for parse errors |
| Firewall blocking mDNS | 5353/UDP or multicast address blocked | `firewall-cmd --add-protocol=mdns` (firewalld) or `ufw allow 5353/udp` |
| `avahi-daemon: WARNING: No valid network interface found` | All interfaces are loopback or disabled | Check `allow-interfaces` / `deny-interfaces` in `avahi-daemon.conf`; verify at least one non-loopback interface is up |

## Pain Points
- **`nsswitch.conf` ordering is mandatory**: The hosts line must include `mdns4_minimal [NOTFOUND=return]` placed *before* `dns`. Without `[NOTFOUND=return]`, the resolver falls through to DNS for `.local` queries — DNS usually times out, causing the 2–5 second delay. Without the entry entirely, `.local` resolution never works.
- **`systemd-resolved` conflict**: On systems where `systemd-resolved` has `MulticastDNS=yes` (default on some distros), both daemons compete for 5353/UDP. One will fail to bind. Disable mDNS in one of them — disabling it in `systemd-resolved.conf` is usually easier than replacing the stub resolver.
- **Firewall multicast rules**: Allowing 5353/UDP alone is not always enough — mDNS uses the `224.0.0.251` multicast group. Some firewall configurations block multicast by default. With firewalld, the `mdns` service rule handles both; with raw iptables, you may need explicit `--destination 224.0.0.251` rules.
- **`.service` XML files are strict**: avahi-daemon rejects files with any XML error (missing closing tag, invalid characters, wrong encoding) silently — the service simply does not appear. Always validate with `xmllint` after editing; check `journalctl -u avahi-daemon` for the parse error line.
- **`publish-hinfo` and hostname leakage**: By default avahi publishes the OS name and CPU type as HINFO records. Set `publish-hinfo=no` and `publish-workstation=no` in `avahi-daemon.conf` if this is a concern on shared networks.

## See Also
- **dnsmasq** — lightweight DNS forwarder and DHCP server for local networks
- **unbound** — recursive DNS resolver with DNSSEC validation
- **pihole** — network-wide DNS sinkhole for ad blocking, often paired with local DNS

## References
See `references/` for:
- `avahi-config.md` — annotated `avahi-daemon.conf`, `.service` XML format, nsswitch.conf, and `avahi-browse` output explained
- `docs.md` — official documentation and man page links

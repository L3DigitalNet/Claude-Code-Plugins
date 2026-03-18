---
name: firewalld
description: >
  firewalld zone-based firewall management and nftables: zone configuration,
  rich rules, port forwarding, services, runtime vs permanent rules, and
  troubleshooting.
  MUST consult when installing, configuring, or troubleshooting firewalld.
triggerPhrases:
  - "firewalld"
  - "firewall-cmd"
  - "nftables"
  - "nft"
  - "zone"
  - "rich rule"
  - "RHEL firewall"
  - "Fedora firewall"
globs: []
last_verified: "unverified"
---

## Identity
- **Unit**: `firewalld.service`
- **Config**: `/etc/firewalld/` (zones, services, rich rules — user overrides)
- **Default zones/services**: `/usr/lib/firewalld/` (system-provided; don't edit)
- **Custom zones**: `/etc/firewalld/zones/`
- **Custom services**: `/etc/firewalld/services/`
- **Backend**: nftables (default since firewalld 0.6); legacy iptables still supported
- **Logs**: `journalctl -u firewalld`
- **Install**: `dnf install firewalld` (default on RHEL/Fedora); `apt install firewalld`

## Quick Start

```bash
sudo apt install firewalld
sudo systemctl enable --now firewalld
sudo firewall-cmd --add-service=ssh --permanent
sudo firewall-cmd --reload
sudo firewall-cmd --list-all          # verify active zone rules
```

## Key Operations

| Task | Command |
|------|---------|
| Check if running | `sudo firewall-cmd --state` |
| Get default zone | `sudo firewall-cmd --get-default-zone` |
| List all zones | `sudo firewall-cmd --get-zones` |
| List active zones + interfaces | `sudo firewall-cmd --get-active-zones` |
| List services in zone | `sudo firewall-cmd --zone=public --list-services` |
| List all rules in zone | `sudo firewall-cmd --zone=public --list-all` |
| Add service (runtime) | `sudo firewall-cmd --zone=public --add-service=http` |
| Add service (permanent) | `sudo firewall-cmd --zone=public --add-service=http --permanent` |
| Remove service | `sudo firewall-cmd --zone=public --remove-service=http --permanent` |
| Add port (runtime) | `sudo firewall-cmd --zone=public --add-port=8080/tcp` |
| Add port (permanent) | `sudo firewall-cmd --zone=public --add-port=8080/tcp --permanent` |
| Remove port | `sudo firewall-cmd --zone=public --remove-port=8080/tcp --permanent` |
| Add rich rule | `sudo firewall-cmd --zone=public --add-rich-rule='rule family="ipv4" source address="10.0.0.1" accept' --permanent` |
| List rich rules | `sudo firewall-cmd --zone=public --list-rich-rules` |
| Set default zone | `sudo firewall-cmd --set-default-zone=home` |
| Reload firewall | `sudo firewall-cmd --reload` |
| Make runtime permanent | `sudo firewall-cmd --runtime-to-permanent` |
| List available services | `sudo firewall-cmd --get-services` |
| View actual nftables rules | `sudo nft list ruleset` |

## Zone Concept

Zones define trust levels; each network interface is assigned to exactly one zone. Packets arriving on an interface are evaluated against that zone's rules. Common zones, from most restrictive to least:

- **drop**: All incoming packets dropped silently; only outgoing allowed.
- **block**: Incoming rejected with ICMP unreachable; outgoing allowed.
- **public**: Default for internet-facing interfaces. Explicitly allowed services only.
- **external**: Like public, with masquerading enabled (NAT for routing).
- **dmz**: Publicly accessible services, limited internal access.
- **work / home / internal**: Progressively more trust; some services allowed by default.
- **trusted**: All connections accepted.

`public` is the typical default for internet-facing servers. An interface not explicitly assigned to a zone falls back to the default zone.

## Expected State

Default policy after install: `public` zone active, `ssh` (and `dhcpv6-client`) allowed, all other incoming blocked. Outgoing is unrestricted.

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| Rule added but traffic still blocked | Used `--permanent` but forgot `--reload` | `sudo firewall-cmd --reload` |
| Rule lost after reload/restart | Forgot `--permanent` flag | Re-add with `--permanent`; rules without it are runtime-only |
| Service not found | Service name not recognized | `sudo firewall-cmd --get-services` to list valid names |
| Docker ports bypass firewall | Docker writes nftables rules directly | Use DOCKER-USER zone or bind containers to localhost |
| Zone not applied to interface | Interface not assigned to zone | `sudo firewall-cmd --get-active-zones`; assign with `--change-interface` |
| Rich rule syntax error | Quoting or family mismatch | Test runtime first (no `--permanent`); check `journalctl -u firewalld` |
| `nft` rules conflict with firewalld | Mixed management | Don't mix `nft` manual rules with firewalld; use only `firewall-cmd` |

## Pain Points

- **`--permanent` vs runtime**: Without `--permanent`, rules reset on reload or restart. Without `--reload`, permanent rules don't take effect in the running firewall. Standard pattern for persistent changes: add with `--permanent` then `sudo firewall-cmd --reload`. For testing first: add without `--permanent` (takes effect immediately), verify, then add again with `--permanent`.

- **Docker bypass**: Docker writes nftables rules that are evaluated before firewalld's zone rules. Ports published with `-p 80:80` are reachable even if port 80 is not allowed in the public zone. Workaround: bind containers to localhost (`-p 127.0.0.1:8080:80`) and proxy through nginx, or add rich rules to the `DOCKER-USER` chain via firewalld's direct interface.

- **nftables direct access**: `sudo nft list ruleset` shows the full active ruleset that firewalld generates. This is useful for debugging but `firewall-cmd` is the correct management interface. Manually adding `nft` rules alongside firewalld is unsupported and will be overwritten on reload.

- **Zone assignment**: `sudo firewall-cmd --get-active-zones` reveals which interfaces are in which zone. If an interface isn't listed, it's using the default zone silently. Assign explicitly with `--change-interface=eth0 --zone=public --permanent`.

- **Rich rules for complex logic**: Regular `--add-port` and `--add-service` can't express source IP restrictions, port forwarding, or logging. Rich rules handle all of these. The rich rule language is verbose — see `references/common-rules.md` for copy-paste examples.

- **`--runtime-to-permanent`**: If you've made several runtime changes and want to persist them all at once without re-entering each command, `sudo firewall-cmd --runtime-to-permanent` promotes the entire current runtime configuration to permanent.

## See Also

- **ufw** — simpler iptables frontend for Debian/Ubuntu environments
- **fail2ban** — automatic IP banning based on log pattern matching
- **crowdsec** — collaborative intrusion prevention with community-shared blocklists

## References
See `references/` for:
- `common-rules.md` — practical rule examples for common services
- `docs.md` — official documentation links

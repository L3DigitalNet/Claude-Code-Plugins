---
name: crowdsec
description: >
  CrowdSec collaborative intrusion prevention system — installation, bouncers,
  collections, scenarios, hub management, decisions, alerts, and troubleshooting.
  Triggers on: crowdsec, crowdsecurity, bouncer, LAPI, cscli, intrusion
  prevention, collaborative security, community blocklist, hub upgrade,
  crowdsec-firewall-bouncer, crowdsec-nginx-bouncer.
globs:
  - "**/crowdsec/**"
  - "**/acquis.yaml"
  - "**/acquis.d/**"
  - "**/profiles.yaml"
  - "**/allowlists.yaml"
---

## Identity
- **Unit**: `crowdsec.service`
- **Config**: `/etc/crowdsec/config.yaml` (main), `/etc/crowdsec/acquis.yaml` (log sources), `/etc/crowdsec/profiles.yaml` (decision profiles)
- **Decisions DB**: `/var/lib/crowdsec/data/crowdsec.db`
- **Log**: `journalctl -u crowdsec`, `/var/log/crowdsec/crowdsec.log`
- **Install**: Official script (`curl -s https://packagecloud.io/install/repositories/crowdsec/crowdsec/script.deb.sh | sudo bash`) or distro package repo

## Architecture

CrowdSec has three distinct layers that must all be present for traffic to actually be blocked:

```
Log files / journald
       ↓
  Agent (crowdsec.service)
  - Reads logs via acquis.yaml
  - Applies parser chains to normalize events
  - Runs scenarios to detect attack patterns
  - Writes decisions to LAPI
       ↓
  LAPI (Local API, port 8080)
  - Stores decisions in crowdsec.db
  - Serves decisions to registered bouncers
  - Optionally syncs with CrowdSec community blocklist
       ↓
  Bouncer (crowdsec-firewall-bouncer, crowdsec-nginx-bouncer, etc.)
  - Polls LAPI for active decisions
  - Enforces bans at the network or application layer
```

**Critical**: CrowdSec detects and decides; bouncers enforce. Without an installed and registered bouncer, bans exist in the database but no traffic is actually blocked.

## Key Operations

| Goal | Command |
|------|---------|
| Check service status | `systemctl status crowdsec` |
| Check agent version | `sudo cscli version` |
| List active alerts | `sudo cscli alerts list` |
| List active decisions (bans) | `sudo cscli decisions list` |
| Delete a decision (unban IP) | `sudo cscli decisions delete --ip 1.2.3.4` |
| Ban an IP manually | `sudo cscli decisions add --ip 1.2.3.4 --duration 24h --reason "manual ban"` |
| List registered bouncers | `sudo cscli bouncers list` |
| List installed collections | `sudo cscli collections list` |
| Install a collection | `sudo cscli collections install crowdsecurity/nginx` |
| Remove a collection | `sudo cscli collections remove crowdsecurity/nginx` |
| Update hub index | `sudo cscli hub update` |
| Upgrade all hub items | `sudo cscli hub upgrade` |
| Inspect a scenario | `sudo cscli scenarios inspect crowdsecurity/ssh-bf` |
| Tail live alerts | `sudo cscli alerts list -o human --since 1m` (repeat; no live stream by default) |
| Test parser against log | `sudo cscli explain --log "Failed password for root" --type sshd` |
| View metrics | `sudo cscli metrics` |
| Reload agent config | `sudo systemctl reload crowdsec` |

## Expected Ports

- **8080/tcp** — LAPI (Local API). Listens on `127.0.0.1:8080` by default. Bouncers and remote agents connect here.
- No external ports required for a single-node deployment.

## Health Checks

1. `systemctl is-active crowdsec` — agent running
2. `sudo cscli version` — CLI and LAPI reachable
3. `sudo cscli alerts list` — shows recent detections (empty = no attacks detected yet, or parsers not matching)
4. `sudo cscli bouncers list` — at least one bouncer registered with a recent `Last API pull` timestamp

## Common Failures

| Symptom | Likely cause | Check / Fix |
|---------|-------------|-------------|
| Bouncer shows "LAPI not reachable" | LAPI not running or wrong API URL in bouncer config | `systemctl status crowdsec`; check `api_url` in bouncer config (`/etc/crowdsec/bouncers/*.yaml`) |
| No alerts despite known attacks | Log source not in `acquis.yaml`, or parser not installed | `sudo cscli parsers list`; add log path to `acquis.yaml`; install matching collection |
| Decisions exist but traffic not blocked | Bouncer not installed or not registered | `sudo cscli bouncers list`; install a bouncer (`apt install crowdsec-firewall-bouncer-iptables`) |
| Scenario never triggers | Parser not normalizing events correctly | `sudo cscli explain --log "..." --type sshd`; check parser stage output |
| Legitimate IPs being banned (false positives) | Aggressive scenario thresholds or missing allowlist | `sudo cscli decisions delete --ip <ip>`; add IP to `/etc/crowdsec/allowlists.yaml` |
| Allowlist not taking effect | Allowlist file not referenced in `config.yaml`, or old format | Check `crowdsec_service.allowlists` in `config.yaml`; restart after editing |
| Community blocklist not loading | Instance not enrolled in CrowdSec console | `sudo cscli console enroll <token>` from app.crowdsec.net |
| Hub items stale / scenarios outdated | Hub index not updated | `sudo cscli hub update && sudo cscli hub upgrade` |

## Pain Points

- **Agent ≠ bouncer**: CrowdSec detects and records decisions; bouncers enforce them. Without a bouncer, bans in `cscli decisions list` have zero network effect. Install at minimum `crowdsec-firewall-bouncer-iptables` (or nftables variant).

- **Collections vs scenarios vs parsers**: Collections bundle parsers + enrichers + scenarios for a service. Always install a collection (`cscli collections install crowdsecurity/nginx`) rather than individual parsers — collections keep all dependencies in sync.

- **Log acquisition (`acquis.yaml`)**: CrowdSec does not auto-detect log files. Add an entry for every service you want monitored. Missing an entry means the agent never sees those logs. See `references/configuration.md` for examples.

- **Hub updates**: Hub items (parsers, scenarios, collections) are versioned independently of the CrowdSec binary. Run `cscli hub update && cscli hub upgrade` after upgrading the package and periodically in production.

- **Allowlists**: Use `sudo cscli decisions delete --ip <ip>` for one-off unbans. For permanent exceptions, add IPs/CIDRs to `/etc/crowdsec/allowlists.yaml` and reference the file from `config.yaml`. The `cscli allowlists` subcommand is available in v1.6+.

- **Community blocklist**: Instances enrolled in the CrowdSec console receive shared ban decisions from the community. Requires a free account at `app.crowdsec.net` and running `sudo cscli console enroll <token>`. Without enrollment, the instance is local-only.

- **nftables vs iptables**: The firewall bouncer comes in `iptables` and `nftables` variants. On modern Fedora/RHEL/Debian 12+, nftables is the default backend. Installing the wrong variant causes silent failures — bans are registered but no firewall rules are created.

## References
See `references/` for:
- `configuration.md` — annotated config files: `config.yaml`, `acquis.yaml`, `profiles.yaml`, bouncers, allowlists
- `docs.md` — official documentation and hub links

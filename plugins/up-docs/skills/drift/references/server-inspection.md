# Server Inspection Patterns

Reference for Phase 1 of drift analysis. Match inspection commands to what the wiki page documents. Do not run commands unrelated to the page content.

## General System State

For any documented host, start with baseline inspection:

```bash
ssh <host> "hostname && uname -r"
ssh <host> "uptime && free -h"
ssh <host> "df -h"
```

## Service-Specific Patterns

### Systemd Services

When a page documents a systemd-managed service:

```bash
ssh <host> "systemctl status <service> --no-pager"
ssh <host> "systemctl is-enabled <service>"
ssh <host> "journalctl -u <service> --no-pager -n 30"
```

### Docker / Compose

When a page documents Docker containers or Compose stacks:

```bash
ssh <host> "docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'"
ssh <host> "docker inspect <container> --format '{{json .Config.Env}}'"
ssh <host> "docker compose -f <compose-file> config"  # verify compose file parses
```

For container-specific config:

```bash
ssh <host> "docker exec <container> cat /path/to/config"
```

### Web Servers (nginx, Caddy, Apache)

```bash
ssh <host> "nginx -T 2>/dev/null || caddy adapt --config /etc/caddy/Caddyfile 2>/dev/null"
ssh <host> "curl -sI http://localhost:<port>"  # verify listening
```

### Databases (PostgreSQL, MariaDB, Redis, etc.)

```bash
ssh <host> "sudo -u postgres psql -c 'SELECT version()'" 2>/dev/null
ssh <host> "mysql --version" 2>/dev/null
ssh <host> "redis-cli info server 2>/dev/null | head -20"
```

### DNS (Pi-hole, Unbound, dnsmasq)

```bash
ssh <host> "pihole version 2>/dev/null"
ssh <host> "unbound-control status 2>/dev/null"
ssh <host> "dig @localhost example.com +short"
```

### Reverse Proxies and Auth

```bash
ssh <host> "curl -sI https://localhost --insecure"  # check TLS
ssh <host> "cat /etc/authentik/config.yml 2>/dev/null || echo 'not found'"
```

### VPN and Networking

```bash
ssh <host> "tailscale status"
ssh <host> "wg show" 2>/dev/null
ssh <host> "ip route show"
ssh <host> "ss -tlnp"  # listening ports
```

### Monitoring and Observability

```bash
ssh <host> "curl -s http://localhost:9090/-/healthy" 2>/dev/null  # Prometheus
ssh <host> "curl -s http://localhost:3000/api/health" 2>/dev/null  # Grafana
ssh <host> "systemctl status node_exporter --no-pager" 2>/dev/null
```

### Backup Services

```bash
ssh <host> "borg list <repo> --last 3" 2>/dev/null
ssh <host> "restic snapshots --latest 3" 2>/dev/null
```

### Configuration Files

When a page references specific configuration files:

```bash
ssh <host> "cat <config-path>"
ssh <host> "stat <config-path>"  # check last modified time
```

Compare the actual file content against what the wiki documents. Look for:
- Changed values (ports, paths, credentials references, feature flags)
- New directives not in the wiki
- Removed directives still documented in the wiki
- File location changes

## Inspection Strategy

1. **Read the wiki page first.** Extract every concrete claim: hostnames, ports, paths, versions, service names, config values.

2. **Group by host.** Batch all SSH commands to the same host into a single session where practical.

3. **Start broad, then narrow.** Begin with service status and listening ports. Only inspect config files when the wiki makes specific claims about their contents.

4. **Record actual values.** For each inspected fact, note: wiki says X, actual is Y. This becomes the discrepancy list.

5. **Handle unreachable hosts.** If SSH fails, log the host as unreachable and continue. Do not block the entire analysis on one down server. Report unreachable hosts in the summary.

6. **Respect sensitive data.** Do not write passwords, tokens, or secrets into wiki pages. Reference their storage location (e.g., "stored in /etc/service/env") without exposing values.

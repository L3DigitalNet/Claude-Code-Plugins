---
name: grafana
description: >
  Grafana observability platform administration: installation, configuration,
  data sources, dashboards, panels, alerting, provisioning, plugins, and
  troubleshooting.
  MUST consult when installing, configuring, or troubleshooting grafana.
triggerPhrases:
  - "grafana"
  - "Grafana"
  - "grafana dashboard"
  - "grafana datasource"
  - "grafana alert"
  - "grafana panel"
  - "visualization"
  - "grafana-cli"
  - "grafana.ini"
  - "grafana provisioning"
  - "grafana plugin"
globs:
  - "**/grafana.ini"
  - "**/grafana/provisioning/**"
  - "**/grafana/**/*.yaml"
  - "**/grafana/**/*.yml"
  - "**/grafana/**/*.json"
last_verified: "unverified"
---

## Identity

- **Unit**: `grafana-server.service`
- **Config**: `/etc/grafana/grafana.ini`
- **Data dir**: `/var/lib/grafana/` (SQLite DB, sessions, images)
- **Plugin dir**: `/var/lib/grafana/plugins/`
- **Logs**: `journalctl -u grafana-server`, `/var/log/grafana/grafana.log`
- **Port**: 3000/tcp (HTTP)
- **CLI tool**: `grafana-cli` (plugin management, admin resets)
- **Distro install**: `apt install grafana` / `dnf install grafana` (after adding Grafana APT/RPM repo)

## Quick Start

```bash
# Add Grafana APT repo (see grafana.com/docs for current key URL)
sudo apt update && sudo apt install grafana
sudo systemctl enable --now grafana-server
curl -s http://localhost:3000/api/health
# Default login: admin / admin (change on first login)
```

## Key Operations

| Task | Command |
|------|---------|
| Service status | `systemctl status grafana-server` |
| Start / stop / restart | `sudo systemctl start\|stop\|restart grafana-server` |
| Reload (provisioning only) | `curl -s -u admin:password http://localhost:3000/api/admin/provisioning/dashboards/reload` |
| Check logs (live) | `journalctl -u grafana-server -f` |
| Check logs (last 100 lines) | `journalctl -u grafana-server -n 100 --no-pager` |
| API health check | `curl -s http://localhost:3000/api/health` |
| API ping (no auth needed) | `curl -s http://localhost:3000/api/health \| python3 -m json.tool` |
| CLI — list installed plugins | `grafana-cli plugins ls` |
| CLI — install plugin | `sudo grafana-cli plugins install <plugin-id>` |
| CLI — update all plugins | `sudo grafana-cli plugins update-all` |
| CLI — reset admin password | `sudo grafana-cli admin reset-admin-password <newpassword>` |
| Import dashboard from JSON | UI: Dashboards → Import → Upload JSON file |
| Import dashboard by ID | UI: Dashboards → Import → Enter grafana.com ID |
| Export dashboard JSON | UI: Dashboard → Share → Export → Save to file |
| Provisioning reload (datasources) | `curl -s -u admin:pass -X POST http://localhost:3000/api/admin/provisioning/datasources/reload` |
| Backup grafana.db | `sudo cp /var/lib/grafana/grafana.db /backup/grafana-$(date +%Y%m%d).db` |

## Expected Ports

- **3000/tcp** — Grafana web UI and API (HTTP by default)
- Verify: `ss -tlnp | grep :3000`
- Firewall: `sudo ufw allow 3000/tcp` (or restrict to reverse proxy only)
- If behind a reverse proxy, bind Grafana to loopback only: set `http_addr = 127.0.0.1` in `grafana.ini`

## Health Checks

1. `systemctl is-active grafana-server` → `active`
2. `curl -s http://localhost:3000/api/health` → `{"commit":"...","database":"ok","version":"..."}`
3. `curl -s -u admin:<password> http://localhost:3000/api/org` → JSON org object (confirms auth works)

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| "invalid username or password" on first login | Default creds are `admin` / `admin`; change forced on first login | Log in with `admin`/`admin`, set new password when prompted |
| "invalid username or password" after migration | Admin password hash mismatch (e.g., DB restored without ini) | `sudo grafana-cli admin reset-admin-password <newpassword>` |
| Datasource "Data source connected but no labels found" | Prometheus not scraped yet, wrong URL, or wrong time range | Verify URL in datasource settings; check `http://prometheus:9090/targets` |
| Panel shows "No data" | Wrong query, time range too narrow, or wrong datasource selected | Check query in Explore; widen time range; confirm datasource |
| Plugin install fails with connection errors | Grafana server lacks internet access | Download plugin zip manually: `grafana-cli --pluginUrl <url> plugins install <id>` |
| "database is locked" error in logs | SQLite single-writer contention under load | Upgrade to PostgreSQL or MySQL via `[database]` section in `grafana.ini` |
| Alert emails not sent | SMTP not configured or disabled | Set `[smtp] enabled = true` and configure host/credentials in `grafana.ini` |
| 502 Bad Gateway from nginx upstream | Wrong port or Grafana not running | Confirm `proxy_pass http://127.0.0.1:3000`; check `systemctl status grafana-server` |
| Provisioning changes not picked up | Service not restarted or wrong file path | `sudo systemctl restart grafana-server`; verify files are under `/etc/grafana/provisioning/` |

## Pain Points

- **SQLite is single-writer**: The default `grafana.db` (SQLite) serializes all writes. Under concurrent dashboard saves or alert state updates, you will see "database is locked" errors. Switch to PostgreSQL or MySQL for any multi-user or production deployment.
- **Admin password in logs on first start**: Grafana logs the generated admin password to stdout on the very first start. Check `journalctl -u grafana-server` immediately after install if you missed it, or reset with `grafana-cli admin reset-admin-password`.
- **Provisioning requires restart awareness**: Datasource and dashboard provisioning files are read at startup. Dashboard JSON changes in provisioned files are picked up on restart or via the API reload endpoint — but adding a new provisioning YAML file always requires a restart, not just a reload.
- **Dashboard UIDs must be unique**: When importing dashboards by ID from grafana.com or from JSON, the embedded `uid` field must be unique across your Grafana instance. Duplicate UIDs on import silently overwrite the existing dashboard. Explicitly set or clear the `uid` field before importing if you want independent copies.
- **Plugin management is out-of-band from the package manager**: Grafana plugins are managed via `grafana-cli` or the UI, not `apt`/`dnf`. They are stored under `/var/lib/grafana/plugins/` and persist across Grafana upgrades, but they are not tracked by the system package manager. Audit installed plugins after OS-level Grafana upgrades to check compatibility.

## See Also

- **prometheus** — Time-series database and metrics collector; the primary data source for most Grafana deployments
- **loki** — Log aggregation from the Grafana stack; query logs in Grafana alongside metrics using LogQL
- **netdata** — Real-time monitoring with its own dashboard; can also export metrics to Grafana via Prometheus remote_write
- **influxdb** — time series data source for Grafana alongside Prometheus

## References

See `references/` for:
- `grafana.ini.annotated` — full configuration file with every directive explained
- `common-patterns.md` — datasource setup, provisioning, nginx reverse proxy, backup, and more
- `docs.md` — official documentation links

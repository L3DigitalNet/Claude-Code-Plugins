---
name: osquery
description: >
  osquery endpoint monitoring: osqueryi interactive shell, osqueryd daemon,
  SQL-based queries against OS state, scheduled queries, packs, configuration,
  logging, and file integrity monitoring (FIM).
  MUST consult when installing, configuring, or troubleshooting osquery.
triggerPhrases:
  - "osquery"
  - "osqueryi"
  - "osqueryd"
  - "osquery table"
  - "osquery schedule"
  - "osquery pack"
  - "osquery FIM"
  - "file integrity monitoring"
  - "endpoint monitoring"
  - "os instrumentation"
  - "osquery SQL"
globs:
  - "**/osquery.conf"
  - "**/osquery.conf.d/**"
  - "**/osquery/**"
  - "**/packs/*.conf"
last_verified: "2026-03"
---

## Identity
- **Unit**: `osqueryd.service`
- **Daemon**: `osqueryd`
- **Interactive shell**: `osqueryi`
- **Config**: `/etc/osquery/osquery.conf`, `/etc/osquery/osquery.conf.d/`
- **Flags file**: `/etc/osquery/osquery.flags`
- **Database**: `/var/osquery/osquery.db` (RocksDB; stores scheduled query state)
- **Logs**: `/var/log/osquery/osqueryd.results.log` (query results), `/var/log/osquery/osqueryd.INFO` (daemon log)
- **Packs dir**: `/usr/share/osquery/packs/` or `/etc/osquery/packs/`
- **User**: `root` (osquery needs root to read most OS tables)
- **Distro install**: see install section; not in default distro repos

## Quick Start

```bash
# Install (Ubuntu/Debian)
curl -L https://pkg.osquery.io/deb/pubkey.gpg | sudo apt-key add -
sudo add-apt-repository 'deb [arch=amd64] https://pkg.osquery.io/deb deb main'
sudo apt update && sudo apt install osquery

# Interactive shell (ad-hoc queries)
osqueryi
osqueryi --line 'SELECT * FROM os_version;'

# Start daemon (scheduled queries + FIM)
sudo systemctl enable --now osqueryd
```

## Key Operations

| Task | Command |
|------|---------|
| Interactive shell | `osqueryi` |
| Run single query | `osqueryi --line 'SELECT pid, name FROM processes LIMIT 10;'` |
| Run query as JSON | `osqueryi --json 'SELECT * FROM users;'` |
| List all tables | `osqueryi '.tables'` |
| Show table schema | `osqueryi '.schema processes'` |
| Start daemon | `sudo systemctl start osqueryd` |
| Check daemon status | `sudo systemctl status osqueryd` |
| View result logs | `tail -f /var/log/osquery/osqueryd.results.log` |
| View daemon logs | `tail -f /var/log/osquery/osqueryd.INFO` |
| Check config syntax | `osqueryctl config-check` |
| Verify extensions | `osqueryi 'SELECT * FROM osquery_extensions;'` |
| Check osquery version | `osqueryi --version` |
| List scheduled queries | `osqueryi 'SELECT name, interval, query FROM osquery_schedule;'` |
| Check FIM events | `osqueryi 'SELECT * FROM file_events;'` |
| Check running processes | `osqueryi 'SELECT pid, name, uid, cmdline FROM processes;'` |
| Find listening ports | `osqueryi 'SELECT p.name, l.port, l.protocol, l.address FROM listening_ports l JOIN processes p ON l.pid = p.pid;'` |
| Check logged-in users | `osqueryi 'SELECT * FROM logged_in_users;'` |
| Check installed packages | `osqueryi 'SELECT name, version FROM deb_packages;'` (Debian/Ubuntu) |
| Check crontab entries | `osqueryi 'SELECT * FROM crontab;'` |
| Check kernel modules | `osqueryi 'SELECT name, status FROM kernel_modules;'` |

## Health Checks

1. `systemctl is-active osqueryd` — expect `active`
2. `osqueryi --line 'SELECT version FROM osquery_info;'` — returns current version
3. `ls -la /var/osquery/osquery.db` — RocksDB directory exists and is being written to
4. `tail -1 /var/log/osquery/osqueryd.results.log | jq .` — recent results flowing

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| `osqueryi: command not found` | Not installed or not in PATH | Install from https://osquery.io/downloads; binary is at `/usr/bin/osqueryi` |
| `osqueryd` exits immediately | Config parse error | Run `osqueryctl config-check` to find the error; check JSON syntax |
| No results in `file_events` | FIM not configured or `disable_events=true` | Add `file_paths` to config; ensure `disable_events` is not set to true in flags |
| `Error: table not found` | Table only available on specific OS or requires events | Check `osqueryi '.schema <table>'`; some tables are Linux-only, macOS-only, or event-based |
| Scheduled queries not running | `osqueryd` not running, or interval set too high | Check `systemctl status osqueryd`; verify `interval` in schedule config |
| RocksDB corruption | Unclean shutdown or disk full | Stop osqueryd, delete `/var/osquery/osquery.db`, restart (loses cached state) |
| High CPU usage | Expensive query running too frequently | Increase interval; check `/var/log/osquery/osqueryd.INFO` for denylisted queries; reduce `schedule_splay_percent` |
| Permission denied on tables | Running osqueryi as non-root | Many tables require root; run `sudo osqueryi` |
| Stale pack data | Pack file path wrong or discovery query failing | Verify pack paths in config; test discovery queries manually in osqueryi |

## Pain Points

- **osquery needs root for most useful tables**: Tables like `processes`, `listening_ports`, `file_events`, and `kernel_modules` require root access. Running `osqueryi` as a regular user shows empty results for many tables without any error.

- **Event tables require the daemon**: Tables ending in `_events` (like `file_events`, `process_events`, `socket_events`) only collect data when `osqueryd` is running. The interactive shell `osqueryi` does not run event subscribers; it only reads what the daemon already buffered in RocksDB.

- **JSON config is strict**: The config file is JSON, not JSONC. No comments allowed, no trailing commas. A single syntax error prevents `osqueryd` from starting. Use `osqueryctl config-check` or `python3 -m json.tool /etc/osquery/osquery.conf` to validate.

- **Scheduled query results are differential by default**: osquery logs only the delta (rows added or removed since the last run). Set `"snapshot": true` on a query to get a full point-in-time dump each interval instead.

- **Query performance matters**: osquery runs SQL against live OS state, not a pre-indexed database. A `SELECT *` on large tables (e.g., `file` with a broad path) can be expensive. Always add `WHERE` clauses and use `LIMIT`. Queries that exceed resource limits get automatically denylisted for 24 hours.

- **Pack discovery queries**: Packs can include `discovery` queries that control whether the pack's scheduled queries run. If the discovery query returns zero rows, the pack is silently disabled. This is useful for host targeting but confusing when debugging "why isn't my pack running."

- **FIM watches directories, not individual files directly**: The `file_paths` config uses glob patterns. Watching `/etc/**` monitors everything under `/etc/`. Watching `/etc/passwd` specifically requires `/etc/passwd` as a literal path in the glob list. The `%%` wildcard in osquery globs means "recursive."

## See Also
- **auditd** — Linux audit framework for syscall-level monitoring and compliance logging
- **falco** — runtime security tool that detects threats using eBPF/kernel module and Falco rules
- **prometheus** — metrics collection and alerting; complementary to osquery's point-in-time OS queries

## References
See `references/` for:
- `docs.md` — official documentation links (installation, configuration, schema, tables)
- `common-patterns.md` — configuration examples, useful queries, FIM setup, pack definitions, and log shipping

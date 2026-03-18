---
name: influxdb
description: >
  InfluxDB time series database administration: InfluxDB 3.x/OSS server management,
  SQL and InfluxQL queries, database and table operations, write/query API,
  retention policies, Telegraf integration, backup/restore, and plugin system.
  MUST consult when installing, configuring, or troubleshooting influxdb.
triggerPhrases:
  - "influxdb"
  - "InfluxDB"
  - "influxdb3"
  - "influx"
  - "time series database"
  - "influxdb write"
  - "influxdb query"
  - "influxdb3 serve"
  - "influx line protocol"
  - "telegraf influxdb"
  - "influxdb bucket"
  - "influxdb retention"
  - "influxdb token"
  - "influxql"
  - "tsdb"
globs:
  - "**/telegraf.conf"
  - "**/telegraf.d/*.conf"
last_verified: "2026-03"
---

## Identity

- **Binary**: `influxdb3` (CLI and server combined)
- **Unit**: `influxdb3-core.service` (DEB/RPM installs)
- **Config**: command-line flags or environment variables (no config file; flags take precedence over env vars)
- **Data dir**: `--data-dir` flag (default varies by install method)
- **Logs**: `journalctl -u influxdb3-core` or stdout (controlled by `--log-destination`)
- **Web/API**: port 8181 (default; configurable via `--http-bind`)
- **Install**: `curl -O https://www.influxdata.com/d/install_influxdb3.sh && sh install_influxdb3.sh` / `apt install influxdb3-core` / `docker pull influxdb:3-core`
- **Version check**: `influxdb3 --version`; current stable is 3.8.x

## Quick Start

```bash
# Install (Debian/Ubuntu)
curl --silent --location -O https://repos.influxdata.com/influxdata-archive.key
# ... GPG verification steps per docs ...
sudo apt-get install influxdb3-core

# Start the server
sudo systemctl enable --now influxdb3-core

# Or run directly (dev mode, in-memory store)
influxdb3 serve --object-store memory --node-id dev01

# Create a database and write data
influxdb3 create database mydb --host http://localhost:8181
influxdb3 write --database mydb --host http://localhost:8181 \
  'cpu,host=server01 usage=42.5'

# Query with SQL
influxdb3 query --database mydb --host http://localhost:8181 \
  "SELECT * FROM cpu"
```

## Key Operations

| Task | Command |
|------|---------|
| Start server | `influxdb3 serve --object-store file --data-dir /var/lib/influxdb3 --node-id prod01` |
| Start server (Docker) | `docker run -p 8181:8181 -v influxdb3:/var/lib/influxdb3 influxdb:3-core` |
| Create database | `influxdb3 create database <name> --host http://localhost:8181` |
| List databases | `influxdb3 show databases --host http://localhost:8181` |
| Delete database | `influxdb3 delete database <name> --host http://localhost:8181` |
| Write line protocol | `influxdb3 write --database <db> --host http://localhost:8181 '<measurement>,<tags> <fields>'` |
| Write from file | `influxdb3 write --database <db> --host http://localhost:8181 --file data.lp` |
| Query (SQL) | `influxdb3 query --database <db> --host http://localhost:8181 "SELECT * FROM <table>"` |
| Query (InfluxQL) | `influxdb3 query --database <db> --host http://localhost:8181 --language influxql "SELECT * FROM <measurement>"` |
| Create admin token | `influxdb3 create token --admin --host http://localhost:8181` |
| List tokens | `influxdb3 show tokens --host http://localhost:8181` |
| Show system info | `influxdb3 show system --host http://localhost:8181` |
| HTTP API write | `curl -X POST 'http://localhost:8181/api/v3/write_lp?db=mydb' -d 'cpu,host=s1 usage=55.2'` |
| HTTP API query (SQL) | `curl -G 'http://localhost:8181/api/v3/query_sql' --data-urlencode 'db=mydb' --data-urlencode 'q=SELECT * FROM cpu'` |
| v2 compat write | `curl -X POST 'http://localhost:8181/api/v2/write?bucket=mydb' -d 'cpu,host=s1 usage=55.2'` |

## Expected Ports

- **8181/tcp** -- InfluxDB 3 HTTP API and web interface (default)
- **8182/tcp** -- Admin token recovery endpoint (localhost only, `--admin-token-recovery-http-bind`)
- Verify: `ss -tlnp | grep -E '8181|8182'`
- Firewall: `sudo ufw allow from 10.0.0.0/8 to any port 8181`

## Health Checks

1. `systemctl is-active influxdb3-core` -> `active`
2. `influxdb3 --version` -> prints version
3. `curl -sf http://localhost:8181/health` -> 200 OK
4. `influxdb3 show databases --host http://localhost:8181` -> lists databases without error

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| `connection refused` on port 8181 | Server not running or bound to different address | `systemctl status influxdb3-core`; check `--http-bind` flag |
| Write rejected: `database not found` | Database doesn't exist yet | `influxdb3 create database <name>` first, or use auto-create on write |
| Token authentication failure | Missing or invalid token | `influxdb3 show tokens`; create new token with `influxdb3 create token` |
| `object store` error on startup | Invalid `--object-store` or missing `--data-dir` | For file store, ensure data dir exists and has write permissions |
| High memory usage | Large parquet cache or many concurrent queries | Tune `--parquet-mem-cache-size` and `--exec-mem-pool-bytes` |
| WAL flush errors in logs | Disk full or I/O errors | Check `df -h` on data dir; review `--wal-flush-interval` |
| Old InfluxDB 1.x/2.x commands fail | CLI changed completely in v3 | Use `influxdb3` binary, not `influx`; v1/v2 write API endpoints still work for compatibility |
| Telegraf can't write | Wrong output plugin or port | Use `outputs.influxdb_v2` plugin with `urls = ["http://localhost:8181"]` |

## Pain Points

- **InfluxDB 3 is a ground-up rewrite.** It uses Apache DataFusion and Arrow, stores data in Parquet files on object storage, and drops Flux entirely. If you're migrating from v1 or v2, the data model (databases + tables instead of buckets + measurements) and CLI (`influxdb3` instead of `influx`) are different. The v1 and v2 write API endpoints remain for backward compatibility.
- **No config file.** All configuration is via CLI flags or environment variables (prefixed `INFLUXDB3_`). Flags take precedence. For systemd deployments, put flags in the unit file or an override.
- **SQL is the primary query language.** InfluxQL is supported for backward compatibility, but SQL is the recommended path. Flux is not supported in v3.
- **Retention is per-database, not global.** Set retention at database creation time or alter it later. The `--hard-delete-default-duration` flag sets the server-wide default (90 days). The `--retention-check-interval` controls how often expired data is removed (default 30m).
- **Object storage is the canonical store.** Even "file" mode writes Parquet to a local directory that mimics object storage semantics. For production, use S3, GCS, or Azure Blob. The WAL provides durability between Parquet flushes.
- **Telegraf uses the v2 output plugin.** Despite being v3, InfluxDB 3 Core accepts writes through the v2-compatible `/api/v2/write` endpoint. Configure Telegraf's `outputs.influxdb_v2` with `urls = ["http://localhost:8181"]`, `organization = ""`, and `bucket = "<database_name>"`.

## See Also

- **prometheus** -- Pull-based metrics collection; often feeds data to InfluxDB via remote_write or Telegraf
- **grafana** -- Visualization platform with native InfluxDB datasource support (SQL and InfluxQL)
- **elk-stack** -- Log aggregation stack; complementary to InfluxDB for logs vs metrics

## References

See `references/` for:
- `common-patterns.md` -- Telegraf setup, database management, retention, write patterns, query examples, object storage backends
- `docs.md` -- official documentation links
- `config.toml.annotated` -- annotated config covering both v2 (TOML) and v3 (CLI flags/env vars) with storage, WAL, cache, retention, logging, TLS, and query options

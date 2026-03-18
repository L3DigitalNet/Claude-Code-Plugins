---
name: loki
description: >
  Grafana Loki log aggregation system: installation, configuration, LogQL queries,
  Promtail agent setup, storage backends, retention, alerting, and troubleshooting.
  MUST consult when installing, configuring, or troubleshooting loki.
triggerPhrases:
  - "loki"
  - "Grafana Loki"
  - "Loki log aggregation"
  - "Promtail"
  - "LogQL"
  - "log aggregation"
  - "centralized logs"
globs:
  - "**/loki-config.yaml"
  - "**/promtail-config.yaml"
  - "**/loki.yaml"
  - "**/promtail.yaml"
last_verified: "unverified"
---

## Identity
- **Loki unit**: `loki.service` (binary install) or `grafana-loki.service` (package)
- **Promtail unit**: `promtail.service`
- **Loki config**: `/etc/loki/loki-config.yaml` (binary), `/etc/loki/config.yaml` (package)
- **Promtail config**: `/etc/promtail/promtail-config.yaml`
- **Loki data**: `/var/lib/loki/` (chunks, index, WAL, compactor working dir)
- **Promtail positions**: `/tmp/positions.yaml` (tracks file read offsets; persist across restarts)
- **Logs**: `journalctl -u loki`, `journalctl -u promtail`
- **Install options**: pre-built binary from GitHub releases, `docker run grafana/loki`, Grafana APT/RPM package (`apt install loki`), Helm chart

## Quick Start

```bash
sudo apt install loki promtail
sudo systemctl enable --now loki
sudo systemctl enable --now promtail
curl -s http://localhost:3100/ready
```

## Key Operations

| Task | Command |
|------|---------|
| Loki status | `systemctl status loki` |
| Promtail status | `systemctl status promtail` |
| Loki readiness | `curl -s http://localhost:3100/ready` → `ready` |
| Loki metrics endpoint | `curl -s http://localhost:3100/metrics` |
| Promtail metrics/targets | `curl -s http://localhost:9080/metrics` |
| Promtail active targets | `curl -s http://localhost:9080/targets` |
| LogQL query via API | `curl -G 'http://localhost:3100/loki/api/v1/query_range' --data-urlencode 'query={job="myapp"}' --data-urlencode 'start=1h ago'` |
| List labels | `curl -s http://localhost:3100/loki/api/v1/labels` |
| List label values | `curl -s 'http://localhost:3100/loki/api/v1/label/job/values'` |
| Tail logs via logcli | `logcli query --tail '{job="myapp"}'` |
| Push logs via API | `curl -X POST http://localhost:3100/loki/api/v1/push -H 'Content-Type: application/json' -d '{"streams":[{"stream":{"job":"test"},"values":[["'$(date +%s%N)'","hello"]]}]}'` |
| Check retention config | `grep -i retention /etc/loki/loki-config.yaml` |
| Check ingester ring | `curl -s http://localhost:3100/ring` |
| Promtail pipeline dry-run | `promtail --config.file=/etc/promtail/promtail-config.yaml --dry-run --stdin` |
| Check compactor status | `curl -s http://localhost:3100/loki/api/v1/delete` |

## Expected Ports
- **3100/tcp**: Loki HTTP API and UI
- **9095/tcp**: Loki gRPC (inter-component; single-binary mode rarely needs this open)
- **9080/tcp**: Promtail HTTP metrics and targets UI
- Verify: `ss -tlnp | grep -E '3100|9080|9095'`
- Firewall: Loki port 3100 is typically internal only (Grafana on same host or LAN). Promtail 9080 is local only unless scraping Promtail metrics remotely.

## Health Checks
1. `curl -s http://localhost:3100/ready` → must return `ready`
2. `systemctl is-active loki promtail` → both `active`
3. `curl -s http://localhost:9080/targets | python3 -m json.tool | grep -c '"health":"up"'` → count equals number of configured scrape targets
4. `logcli labels` → returns label names (empty set is normal on a fresh install with no logs ingested yet)

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| `entry out of order` in Loki logs | Log lines arriving with timestamps older than the current chunk window; out-of-order ingestion is disabled by default | Enable `allow_structured_metadata: true` and `unordered_writes: true` in `limits_config`, or fix the timestamp source in the Promtail pipeline |
| Promtail not scraping a file | Wrong path glob, file owned by root and Promtail running as unprivileged user | Check `curl localhost:9080/targets` for `"health":"down"` entries; verify file path and `chmod`/`chown` or run Promtail as root |
| Label cardinality too high | Using high-cardinality values (IP addresses, UUIDs, user IDs) as stream labels | Replace with a static label (e.g., `env`, `app`) and move dynamic values into the log line for LogQL filtering via `|=` or `| json` |
| `no matching log streams found` | Wrong label selector in LogQL query; labels not yet ingested | `logcli labels` to see what exists; double-check `{job="..."}` matches a label Promtail actually sends |
| Storage full / chunk flush errors | `/var/lib/loki/` partition full or permissions wrong | `df -h /var/lib/loki`; check `ls -la /var/lib/loki/chunks`; verify `loki` user owns the directory |
| Index cache errors on startup | Stale BoltDB index files from an incompatible schema version or interrupted shutdown | Check logs for specific file name; remove corrupt index file from `active_index_directory` and restart |
| Grafana datasource "Bad Gateway" or no data | Datasource URL misconfigured — must reach Loki HTTP port from Grafana's perspective | Set URL to `http://localhost:3100` (same host) or `http://loki:3100` (Docker Compose service name); test with "Save & Test" |

## Pain Points
- **Two storage layers, both required**: BoltDB shipper manages the index (which labels map to which chunks); `filesystem` or an object store manages chunks. Misconfiguring either path causes data loss or startup failures. For local single-node setups, point both to subdirectories of `/var/lib/loki/`.
- **Label cardinality is a first-class constraint**: Unlike Elasticsearch, Loki's index only contains label key-value pairs. High-cardinality labels (per-user, per-request) explode the index and degrade performance. The rule: keep label count below ~10 per stream; put everything else in the log line and filter at query time.
- **LogQL is not PromQL**: Log queries start with a stream selector `{label="value"}` then optionally pipe through filter expressions (`|=`, `!=`, `|~`) and parsers (`| json`, `| logfmt`, `| regex`). Metric queries wrap a log pipeline in an aggregation function (`rate`, `count_over_time`). The two syntaxes look similar but have different semantics.
- **Out-of-order logs require explicit opt-in**: Loki rejects log lines with timestamps earlier than the most recent entry in a chunk. Systemd journal replay, batch log shippers, and multi-threaded apps all hit this. Enable `unordered_writes: true` under `limits_config` (Loki 2.8+) or ensure Promtail uses `__timestamp__` from the log line rather than the tail time.
- **Promtail scrape_configs mirror Prometheus syntax**: `static_configs`, `relabel_configs`, `pipeline_stages` — if you know Prometheus, the structure is familiar but `pipeline_stages` is Loki-specific (parse, extract, label, timestamp, output transforms).
- **Retention requires the compactor component**: Setting `retention_period` in `limits_config` has no effect without `compactor.retention_enabled: true` and a running compactor. In single-binary mode the compactor runs automatically; in microservices mode it must be deployed separately.

## See Also

- **grafana** — Visualization platform for querying and displaying Loki logs alongside metrics dashboards
- **prometheus** — Metrics collection counterpart to Loki; correlate logs and metrics in Grafana using shared labels
- **journald** — Systemd journal that Promtail can scrape as a log source; use when you need to forward journal entries to Loki

## References
See `references/` for:
- `loki-config.yaml.annotated` — complete annotated single-binary Loki config plus annotated Promtail config
- `common-patterns.md` — minimal setup, Grafana integration, systemd/Docker log collection, LogQL queries, alerting, logcli, multi-tenancy
- `docs.md` — official documentation links

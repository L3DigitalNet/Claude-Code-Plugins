---
name: prometheus
description: >
  Prometheus monitoring system administration: scrape configuration, PromQL
  queries, alerting rules, recording rules, Alertmanager routing, target health,
  TSDB management, and exporter integration. Triggers on: prometheus, Prometheus,
  PromQL, alertmanager, prometheus scrape, prometheus metrics, prometheus exporter,
  prometheus.yml, alerting_rules, recording_rules, promtool, remote_write,
  node_exporter.
globs:
  - "**/prometheus.yml"
  - "**/prometheus.yaml"
  - "**/alerting_rules.yml"
  - "**/alerting_rules.yaml"
  - "**/recording_rules.yml"
  - "**/recording_rules.yaml"
  - "**/rules/**/*.yml"
  - "**/rules/**/*.yaml"
---

## Identity
- **Binary**: `prometheus`
- **Unit**: `prometheus.service`
- **Config**: `/etc/prometheus/prometheus.yml`
- **Rules dir**: `/etc/prometheus/rules/` (glob-referenced from prometheus.yml)
- **Data dir**: `/var/lib/prometheus/`
- **Logs**: `journalctl -u prometheus`
- **Web UI + API**: port 9090
- **Alertmanager**: port 9093
- **Distro install**: `apt install prometheus` / `dnf install prometheus` (or binary from prometheus.io)

## Key Operations

| Operation | Command |
|-----------|---------|
| Status | `systemctl status prometheus` |
| Check config syntax | `promtool check config /etc/prometheus/prometheus.yml` |
| Check alerting/recording rules | `promtool check rules /etc/prometheus/rules/*.yml` |
| Reload config (no restart) | `curl -X POST http://localhost:9090/-/reload` or `sudo systemctl reload prometheus` |
| SIGHUP reload | `sudo kill -HUP $(pidof prometheus)` |
| Instant query via API | `curl 'http://localhost:9090/api/v1/query?query=up'` |
| Range query via API | `curl 'http://localhost:9090/api/v1/query_range?query=up&start=...&end=...&step=60'` |
| List active targets | `curl -s http://localhost:9090/api/v1/targets \| jq '.data.activeTargets[].health'` |
| List active alerts | `curl -s http://localhost:9090/api/v1/alerts \| jq '.data.alerts'` |
| Count total series | `curl -s 'http://localhost:9090/api/v1/query?query=prometheus_tsdb_head_series' \| jq '.data.result[0].value[1]'` |
| TSDB stats (cardinality) | `curl -s http://localhost:9090/api/v1/status/tsdb \| jq '.data.seriesCountByMetricName[:10]'` |
| Create TSDB snapshot | `curl -X POST http://localhost:9090/api/v1/admin/tsdb/snapshot` (requires `--web.enable-admin-api`) |
| Delete series by label | `curl -X POST 'http://localhost:9090/api/v1/admin/tsdb/delete_series?match[]=job="old_job"'` (requires admin API) |
| Clean tombstones after delete | `curl -X POST http://localhost:9090/api/v1/admin/tsdb/clean_tombstones` |
| Verify scrape target reachable | `curl -v http://<target-host>:<port>/metrics` |
| Build info / version | `curl -s http://localhost:9090/api/v1/status/buildinfo \| jq .` |

## Expected Ports

- **9090/tcp** — Prometheus web UI and HTTP API
- **9093/tcp** — Alertmanager (if running)
- **9100/tcp** — node_exporter (convention, not enforced)
- Verify: `ss -tlnp | grep -E '9090|9093|9100'`
- Firewall (internal only, do not expose 9090 publicly without auth):
  `sudo ufw allow from 10.0.0.0/8 to any port 9090`

## Health Checks

1. `systemctl is-active prometheus` → `active`
2. `promtool check config /etc/prometheus/prometheus.yml` → `SUCCESS`
3. `curl -sf http://localhost:9090/-/healthy` → `Prometheus Server is Healthy.`
4. `curl -s 'http://localhost:9090/api/v1/query?query=up' | jq '.data.result | length'` → non-zero (targets are being scraped)

## Common Failures

| Symptom | Likely cause | Check/Fix |
|---------|-------------|-----------|
| Target shows `DOWN` in web UI | Exporter not running or wrong port | `curl http://<target>:<port>/metrics`; `systemctl status <exporter>` |
| Target shows `DOWN`: connection refused | Firewall blocking scrape or wrong IP | `ss -tlnp` on target host; check `static_configs` target address |
| Scrape timeout | Exporter too slow or metrics endpoint overloaded | Increase `scrape_timeout` for that job; profile exporter |
| Config reload fails | YAML syntax error in prometheus.yml or rule files | `promtool check config /etc/prometheus/prometheus.yml` — shows exact line |
| Rule evaluation error in logs | Bad PromQL expression in alerting/recording rule | `promtool check rules /etc/prometheus/rules/*.yml` |
| "too many samples" error | High cardinality query or series explosion | Check TSDB stats endpoint; identify high-cardinality labels |
| Disk filling up | Default 15-day retention accumulating | Set `--storage.tsdb.retention.time=30d` or `--storage.tsdb.retention.size=50GB` in systemd unit |
| Alertmanager not receiving alerts | Wrong alertmanager address in `alerting:` block | Check `alertmanagers` config; `curl http://localhost:9093/-/healthy` |
| Alerts firing but not routing | Alertmanager route/receiver misconfigured | `amtool config routes test` or check `amtool alert` output |
| OOM kill / high memory | Too many active series in TSDB head | Reduce retention, add recording rules, drop high-cardinality labels via `metric_relabel_configs` |

## Pain Points

- **High cardinality kills performance.** Each unique label value combination creates a new time series. Labels like `user_id`, `request_id`, or `url` in metric names can create millions of series. Drop them with `metric_relabel_configs` using `action: labeldrop` before they enter the TSDB.
- **Default retention is 15 days, not forever.** Data older than `--storage.tsdb.retention.time` is deleted automatically. For long-term storage, configure `remote_write` to Thanos, Mimir, or VictoriaMetrics — Prometheus alone is not an archival system.
- **No built-in authentication.** Prometheus's HTTP API and web UI have no access control. Put it behind nginx or Caddy with basic auth or mTLS before exposing it on any network interface other than localhost.
- **PromQL range vectors vs instant vectors.** `http_requests_total` is an instant vector (current value). `http_requests_total[5m]` is a range vector (a set of samples over 5 minutes). Functions like `rate()` and `increase()` require a range vector; arithmetic and comparisons require an instant vector. Mixing them is the most common PromQL beginner error.
- **Recording rules for expensive queries.** Dashboard queries that aggregate across thousands of series run on every panel refresh. Pre-compute them with recording rules so dashboards query a single pre-aggregated series instead of triggering a full scan at render time.
- **Alertmanager config is separate from Prometheus config.** Alerting rules live in Prometheus (which decides when to fire); routing, receivers, and silences live in Alertmanager (`/etc/alertmanager/alertmanager.yml`). `promtool check rules` validates the rule expressions but does not validate Alertmanager routing. Use `amtool config check` for Alertmanager's config.

## References

See `references/` for:
- `prometheus.yml.annotated` — full config with every directive explained, plus an alerting rule file example
- `common-patterns.md` — node monitoring, file SD, alerting rules, PromQL, recording rules, Alertmanager, nginx auth proxy, remote_write, and retention sizing
- `docs.md` — official documentation links

---
name: node-exporter
description: >
  Prometheus Node Exporter administration: installation, collector management,
  textfile collector, TLS/auth configuration, and troubleshooting. Triggers on:
  node exporter, node_exporter, prometheus node, system metrics, hardware metrics
  prometheus, host metrics, node_cpu_seconds_total, node_memory, hwmon collector,
  textfile collector, 9100.
globs: []
---

## Identity
- **Unit**: `prometheus-node-exporter.service` (Debian/Ubuntu), `node_exporter.service` (RHEL/Fedora, manual install)
- **Binary**: `/usr/bin/prometheus-node-exporter` (package) or `/usr/local/bin/node_exporter` (manual)
- **Config**: No config file — all configuration is via command-line flags in the systemd unit
- **Flags location**: `/etc/default/prometheus-node-exporter` (Debian/Ubuntu) or `ExecStart=` in the unit override
- **Metrics endpoint**: `http://localhost:9100/metrics`
- **Distro install**: `apt install prometheus-node-exporter` / `dnf install golang-github-prometheus-node-exporter`

## Key Operations

| Operation | Command |
|-----------|---------|
| Service status | `systemctl status prometheus-node-exporter` |
| Check metrics endpoint | `curl -s localhost:9100/metrics \| head -50` |
| Count exposed metrics | `curl -s localhost:9100/metrics \| grep -c '^node_'` |
| List enabled collectors | `prometheus-node-exporter --help 2>&1 \| grep 'collector\.'` |
| Filter CPU metrics | `curl -s localhost:9100/metrics \| grep '^node_cpu'` |
| Check filesystem metrics | `curl -s localhost:9100/metrics \| grep '^node_filesystem'` |
| Check disk I/O metrics | `curl -s localhost:9100/metrics \| grep '^node_disk'` |
| Check memory metrics | `curl -s localhost:9100/metrics \| grep '^node_memory'` |
| Check network metrics | `curl -s localhost:9100/metrics \| grep '^node_network'` |
| Check load/CPU pressure | `curl -s localhost:9100/metrics \| grep '^node_load\|node_pressure'` |
| Textfile collector output | `curl -s localhost:9100/metrics \| grep '^node_textfile\|^# HELP node_textfile'` |
| Hardware temperature (hwmon) | `curl -s localhost:9100/metrics \| grep '^node_hwmon'` |
| Systemd unit states | `curl -s localhost:9100/metrics \| grep '^node_systemd'` |
| View active flags | `systemctl cat prometheus-node-exporter \| grep ExecStart` |

## Expected Ports
- **9100/tcp** — metrics endpoint (HTTP or HTTPS if TLS configured)
- Verify: `ss -tlnp | grep 9100`
- Node exporter binds to all interfaces by default — restrict with `--web.listen-address=127.0.0.1:9100` if Prometheus scrapes locally

## Health Checks
1. `systemctl is-active prometheus-node-exporter` → `active`
2. `curl -sf http://localhost:9100/metrics > /dev/null && echo OK` → `OK`
3. `curl -s localhost:9100/metrics | grep -c '^node_' | awk '$1 > 100 {print "metrics present"}'` → `metrics present`

## Common Failures

| Symptom | Likely cause | Check/Fix |
|---------|-------------|-----------|
| `connection refused` on port 9100 | Service not running | `systemctl start prometheus-node-exporter` |
| No `node_filesystem_*` metrics | Mount point excluded or wrong filesystem type | Check `--collector.filesystem.mount-points-exclude` flag; tmpfs excluded by default |
| No `node_hwmon_*` metrics | hwmon collector disabled or no sensors detected | Verify `lm_sensors` installed: `sensors`; collector may need `--collector.hwmon` explicitly |
| Textfile metrics not appearing | Wrong directory or file permissions | Confirm dir matches `--collector.textfile.directory`; file must be world-readable and end in `.prom` |
| Port 9100 reachable from internet | No firewall rule restricting access | Add firewall rule or use `--web.listen-address=127.0.0.1:9100`; node exporter has no auth by default |
| Old metric names (`node_cpu` not `node_cpu_seconds_total`) | Pre-v1.0 package installed | v1.0 renamed many metrics; check `prometheus-node-exporter --version` and update scrape queries |
| `too many open files` in logs | System ulimit too low for large number of mounts/disks | Add `LimitNOFILE=65536` to systemd unit override |

## Pain Points
- **No built-in authentication**: Node exporter exposes all system metrics without credentials by default. Bind to localhost (`--web.listen-address=127.0.0.1:9100`) unless Prometheus is on a different host, and use firewall rules or a reverse proxy for remote access. TLS + basic auth via `--web.config.file` requires v1.5+.
- **Textfile collector is the extension point**: The only supported way to add custom metrics is to write `.prom` files into the textfile directory. Scripts that generate these files must be run separately (e.g., via cron). The collector reads them at scrape time, not on a schedule.
- **Collector flags are cumulative**: `--collector.disable-defaults` disables everything; then `--collector.cpu`, `--collector.meminfo`, etc. opt in. Without `--collector.disable-defaults`, you get all collectors and can only exclude with `--no-collector.<name>`.
- **Metric naming changed in v1.0**: `node_cpu` became `node_cpu_seconds_total`, `node_filesystem_free` became `node_filesystem_free_bytes`, etc. Any dashboards or alerts from before v1.0 will silently show no data after an upgrade.
- **Loop devices inflate filesystem metrics**: By default, loop devices (`/dev/loop*`) appear in `node_filesystem_*` metrics. Exclude with `--collector.filesystem.mount-points-exclude='^/(dev|proc|run/credentials/.+|sys|var/lib/docker/.+)($|/)' --collector.diskstats.device-exclude='^(loop|ram)\d+$'`.
- **High cardinality on busy systems**: On servers with many CPUs, disks, or network interfaces, the default collectors produce thousands of time series. Disable unused collectors (e.g., `--no-collector.arp`, `--no-collector.bcache`) to reduce overhead on resource-constrained systems.

## References
See `references/` for:
- `common-patterns.md` — install, restrict access, collector configuration, textfile collector, PromQL, Grafana dashboards, TLS auth
- `docs.md` — official documentation and reference links

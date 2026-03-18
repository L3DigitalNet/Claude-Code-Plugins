---
name: observability-stack
description: >
  Complete observability stack deployment — Prometheus metrics, Grafana dashboards,
  Loki log aggregation, Node Exporter host metrics, and Alertmanager notifications.
  How the components connect and a working end-to-end setup.
  MUST consult when installing, configuring, or troubleshooting the observability stack (Prometheus, Grafana, Loki).
triggerPhrases:
  - "monitoring stack"
  - "observability stack"
  - "prometheus grafana"
  - "set up monitoring"
  - "metrics and logs"
  - "grafana loki prometheus"
  - "full monitoring"
  - "alerting stack"
last_verified: "2026-03"
---

## Overview

This is a **composite stack skill**. Each component has its own per-tool skill with full configuration reference and troubleshooting. This skill covers the glue: how the pieces connect, data flows, and a working end-to-end deployment.

### Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Grafana (:3000)                          │
│         Dashboards & Alerting UI                                │
│     ┌──────────────┐    ┌──────────────┐                        │
│     │  Prometheus   │    │    Loki      │                        │
│     │  datasource   │    │  datasource  │                        │
│     └──────┬───────┘    └──────┬───────┘                        │
└────────────┼───────────────────┼────────────────────────────────┘
             │ PromQL            │ LogQL
             ▼                   ▼
┌────────────────────┐  ┌────────────────────┐
│  Prometheus (:9090)│  │   Loki (:3100)     │
│  Scrape & Store    │  │   Log Aggregation  │
│  Time Series       │  │   Label-Indexed    │
├────────────────────┤  ├────────────────────┤
│  alerting_rules    │  │                    │
│        │           │  │                    │
│        ▼           │  │                    │
│  Alertmanager      │  │                    │
│     (:9093)        │  │                    │
│  Route → Notify    │  │                    │
└────────┬───────────┘  └────────┬───────────┘
         │ scrapes                │ receives logs
         ▼                        ▼
┌────────────────────┐  ┌────────────────────┐
│ Node Exporter      │  │  Promtail          │
│   (:9100)          │  │  (log shipper)     │
│ Host CPU, RAM,     │  │  Tails files,      │
│ disk, network      │  │  journals          │
└────────────────────┘  └────────────────────┘
         ▲                        ▲
         └────── Host OS ─────────┘
```

### Data Flow Summary

1. **Node Exporter** exposes host metrics at `/metrics` on port 9100.
2. **Prometheus** scrapes Node Exporter (and any other targets) every 15s, stores time series in its TSDB, and evaluates alerting rules.
3. **Alertmanager** receives firing alerts from Prometheus, deduplicates and groups them, then routes notifications to email, Slack, PagerDuty, etc.
4. **Promtail** tails log files and systemd journals, attaches labels, and pushes log streams to Loki.
5. **Loki** stores log streams indexed by label, queryable via LogQL.
6. **Grafana** queries both Prometheus (PromQL) and Loki (LogQL) datasources, renders dashboards, and provides a unified alerting UI.

## Components

| Component | Role | Default Port | Data Direction |
|-----------|------|-------------|----------------|
| Node Exporter | Exposes host hardware and OS metrics | 9100 | Scraped by Prometheus |
| Prometheus | Scrapes metrics, stores time series, evaluates alert rules | 9090 | Pulls from exporters; pushes alerts to Alertmanager |
| Alertmanager | Deduplicates, groups, and routes alert notifications | 9093 | Receives from Prometheus; sends to notification channels |
| Loki | Stores and indexes log streams | 3100 | Receives from Promtail/agents |
| Promtail | Ships logs from files and journals to Loki | 9080 (metrics) | Pushes to Loki |
| Grafana | Visualization, dashboards, unified alerting UI | 3000 | Queries Prometheus and Loki |

## Quick Start (Docker Compose)

The reference `docker-compose.yml` in `references/` deploys all five services pre-wired. To get started:

```bash
mkdir -p monitoring && cd monitoring

# Copy the docker-compose.yml from references/ into this directory,
# or use this inline version:

# Create required config directories
mkdir -p prometheus alertmanager grafana/provisioning/datasources grafana/provisioning/dashboards

# Prometheus config — scrapes itself and Node Exporter
cat > prometheus/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

alerting:
  alertmanagers:
    - static_configs:
        - targets: ['alertmanager:9093']

rule_files:
  - '/etc/prometheus/rules/*.yml'

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']
EOF

# Basic alert rules
mkdir -p prometheus/rules
cat > prometheus/rules/node-alerts.yml << 'EOF'
groups:
  - name: node-alerts
    rules:
      - alert: HighCPU
        expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage on {{ $labels.instance }}"
          description: "CPU usage above 80% for 5 minutes (current: {{ $value | printf \"%.1f\" }}%)"

      - alert: HighMemory
        expr: (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100 > 85
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage on {{ $labels.instance }}"

      - alert: DiskSpaceLow
        expr: (1 - node_filesystem_avail_bytes{fstype!~"tmpfs|overlay"} / node_filesystem_size_bytes) * 100 > 85
        for: 10m
        labels:
          severity: critical
        annotations:
          summary: "Disk space low on {{ $labels.instance }} ({{ $labels.mountpoint }})"

      - alert: InstanceDown
        expr: up == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Instance {{ $labels.instance }} is down"
EOF

# Alertmanager config
cat > alertmanager/alertmanager.yml << 'EOF'
global:
  resolve_timeout: 5m

route:
  group_by: ['alertname', 'severity']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h
  receiver: 'default'

receivers:
  - name: 'default'
    # Replace with your notification channel:
    # webhook_configs:
    #   - url: 'http://gotify:8080/...'
    # slack_configs:
    #   - api_url: 'https://hooks.slack.com/...'
    #     channel: '#alerts'
EOF

# Grafana datasource provisioning — auto-configures Prometheus + Loki
cat > grafana/provisioning/datasources/datasources.yml << 'EOF'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: false

  - name: Loki
    type: loki
    access: proxy
    url: http://loki:3100
    editable: false
EOF

# Start the stack
docker compose up -d

# Verify all services are healthy
docker compose ps
curl -s http://localhost:9090/-/healthy          # Prometheus
curl -s http://localhost:3100/ready              # Loki
curl -s http://localhost:3000/api/health          # Grafana
curl -s http://localhost:9093/-/healthy           # Alertmanager
curl -s http://localhost:9100/metrics | head -5   # Node Exporter
```

Grafana is accessible at `http://localhost:3000` with default credentials `admin` / `admin`. Both Prometheus and Loki datasources are pre-configured via provisioning.

## Quick Start (Bare Metal / VM)

For non-containerized deployments, install each component via the system package manager, then wire them together through configuration.

```bash
# 1. Node Exporter
sudo apt install prometheus-node-exporter
sudo systemctl enable --now prometheus-node-exporter
curl -s localhost:9100/metrics | head -5

# 2. Prometheus
sudo apt install prometheus
# Edit /etc/prometheus/prometheus.yml to add node-exporter target:
#   - job_name: 'node'
#     static_configs:
#       - targets: ['localhost:9100']
sudo systemctl enable --now prometheus
promtool check config /etc/prometheus/prometheus.yml

# 3. Alertmanager
sudo apt install prometheus-alertmanager
# Edit /etc/prometheus/alertmanager.yml with receivers
# Edit /etc/prometheus/prometheus.yml alerting section:
#   alerting:
#     alertmanagers:
#       - static_configs:
#           - targets: ['localhost:9093']
sudo systemctl enable --now prometheus-alertmanager

# 4. Loki + Promtail
sudo apt install loki promtail
sudo systemctl enable --now loki promtail
curl -s http://localhost:3100/ready

# 5. Grafana
# Add Grafana APT repo (see grafana.com/docs/grafana/latest/setup-grafana/installation/debian/)
sudo apt install grafana
sudo systemctl enable --now grafana-server
# Open http://localhost:3000, add Prometheus + Loki datasources via UI or provisioning
```

## Integration Points

### Prometheus → Node Exporter (scrape)

Prometheus pulls metrics from Node Exporter's `/metrics` endpoint. The connection is defined in `prometheus.yml`:

```yaml
scrape_configs:
  - job_name: 'node'
    static_configs:
      - targets: ['localhost:9100']       # bare metal
      # - targets: ['node-exporter:9100'] # Docker Compose service name
    scrape_interval: 15s                  # override global if needed
```

Verify the scrape target is healthy:
- Prometheus UI → Status → Targets → `node` job should show `UP`
- API check: `curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | select(.job=="node") | .health'`

### Prometheus → Alertmanager (alert forwarding)

Prometheus evaluates `rule_files` every `evaluation_interval` and pushes firing alerts to Alertmanager:

```yaml
# In prometheus.yml
alerting:
  alertmanagers:
    - static_configs:
        - targets: ['localhost:9093']      # bare metal
        # - targets: ['alertmanager:9093'] # Docker Compose

rule_files:
  - '/etc/prometheus/rules/*.yml'
```

Alertmanager then deduplicates, groups by label, and routes to receivers defined in `alertmanager.yml`. Test the pipeline:

```bash
# Check rules are loaded
curl -s http://localhost:9090/api/v1/rules | jq '.data.groups[].rules[].name'

# Check active alerts
curl -s http://localhost:9090/api/v1/alerts | jq '.data.alerts'

# Check Alertmanager received them
curl -s http://localhost:9093/api/v2/alerts | jq '.[].labels.alertname'
```

### Grafana → Prometheus (PromQL queries)

Grafana queries Prometheus as a datasource. The datasource can be added via UI or provisioned:

```yaml
# /etc/grafana/provisioning/datasources/prometheus.yml
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    url: http://localhost:9090           # bare metal
    # url: http://prometheus:9090       # Docker Compose
    access: proxy
    isDefault: true
```

Useful starter dashboards from grafana.com:
- **Node Exporter Full** (ID: 1860) — the standard host metrics dashboard
- **Prometheus Stats** (ID: 2) — Prometheus internal metrics

Import via Grafana UI: Dashboards → Import → Enter ID.

### Grafana → Loki (LogQL queries)

Grafana queries Loki for log data. Provisioned datasource:

```yaml
# /etc/grafana/provisioning/datasources/loki.yml
apiVersion: 1
datasources:
  - name: Loki
    type: loki
    url: http://localhost:3100           # bare metal
    # url: http://loki:3100             # Docker Compose
    access: proxy
```

In Grafana's Explore view, select the Loki datasource and query with LogQL:

```logql
{job="varlogs"} |= "error"                              # filter by substring
{job="systemd-journal", unit="nginx.service"} | json     # parse JSON logs
rate({job="varlogs"} |= "error" [5m])                    # error rate metric
```

### Promtail → Loki (log shipping)

Promtail pushes log streams to Loki's HTTP API. Minimal Promtail config:

```yaml
server:
  http_listen_port: 9080

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://localhost:3100/loki/api/v1/push    # bare metal
    # url: http://loki:3100/loki/api/v1/push       # Docker Compose

scrape_configs:
  - job_name: varlogs
    static_configs:
      - targets: [localhost]
        labels:
          job: varlogs
          __path__: /var/log/*.log

  - job_name: systemd-journal
    journal:
      max_age: 12h
      labels:
        job: systemd-journal
    relabel_configs:
      - source_labels: ['__journal__systemd_unit']
        target_label: 'unit'
```

### Correlating Metrics and Logs in Grafana

The real power of this stack is correlating metrics and logs in a single view. Use consistent labels across Prometheus and Loki:

1. In Prometheus scrape config, label the target with `instance` and `job`.
2. In Promtail, attach the same `instance` label to log streams from that host.
3. In Grafana, use the "Explore" split view: PromQL on the left, LogQL on the right, with a shared time range.

Grafana also supports data links between panels, so clicking a spike in a metrics graph can jump to the corresponding log query for that time window.

## Health Check (Full Stack)

```bash
# Quick verification that all components are running and connected
echo "--- Node Exporter ---"
curl -sf localhost:9100/metrics > /dev/null && echo "OK" || echo "FAIL"

echo "--- Prometheus ---"
curl -sf http://localhost:9090/-/healthy && echo ""

echo "--- Prometheus targets ---"
curl -s http://localhost:9090/api/v1/targets | \
  jq -r '.data.activeTargets[] | "\(.job): \(.health)"'

echo "--- Alertmanager ---"
curl -sf http://localhost:9093/-/healthy && echo ""

echo "--- Loki ---"
curl -sf http://localhost:3100/ready

echo "--- Grafana ---"
curl -sf http://localhost:3000/api/health | jq -r '.database'
```

Expected output: all `OK`/`ready`/`Healthy`, all Prometheus targets `up`, Grafana database `ok`.

## Common Stack-Level Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| Grafana shows "No data" for Prometheus | Datasource URL wrong or Prometheus not reachable from Grafana | Grafana → Configuration → Data Sources → Prometheus → "Save & Test"; use Docker service name in Compose, not `localhost` |
| Grafana shows "No data" for Loki | Same URL issue, or no logs ingested yet | Check `curl http://loki:3100/ready`; verify Promtail is running and labels match the query |
| Prometheus target shows `DOWN` | Node Exporter not running, firewall, or wrong address | `curl http://<target>:9100/metrics` from Prometheus host |
| Alerts fire but no notification arrives | Alertmanager receiver not configured or misconfigured | Check `alertmanager.yml` receivers; test with `amtool alert add test severity=critical` |
| Loki "entry out of order" | Promtail sending logs with old timestamps | Enable `unordered_writes: true` in Loki's `limits_config` |
| High Prometheus memory | Too many time series from scrape targets | Check cardinality: `curl http://localhost:9090/api/v1/status/tsdb`; drop high-cardinality labels with `metric_relabel_configs` |
| Grafana provisioned datasources not visible | Provisioning YAML in wrong path or syntax error | Check `journalctl -u grafana-server`; files must be under `/etc/grafana/provisioning/datasources/` |

## See Also

- **elk-stack** — alternative log aggregation stack (Elasticsearch, Kibana, Logstash); heavier but more powerful for full-text search
- **netdata** — lightweight real-time monitoring with auto-detection; good for single-host setups without the full stack
- **influxdb** — alternative time-series database; pairs with Grafana but uses Flux/InfluxQL instead of PromQL

## References

See `references/` for:
- `docker-compose.yml` — working Docker Compose file with all five services pre-wired and Grafana datasources provisioned
- `docs.md` — official documentation links for each component

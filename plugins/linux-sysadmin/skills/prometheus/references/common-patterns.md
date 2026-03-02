# Prometheus Common Patterns

Each section is a complete, copy-paste-ready reference. Validate config changes with
`promtool check config /etc/prometheus/prometheus.yml` before reloading.

---

## 1. Basic Node Monitoring (Prometheus + node_exporter)

Install both on the same host, scrape locally. This is the minimum viable monitoring setup.

```bash
# Install (Debian/Ubuntu)
sudo apt install prometheus prometheus-node-exporter

# Verify both are running
systemctl status prometheus prometheus-node-exporter

# Confirm node_exporter is exposing metrics
curl -s http://localhost:9100/metrics | head -20

# Add the node_exporter job to /etc/prometheus/prometheus.yml
# (see annotated config for full job block)
# Then reload:
sudo systemctl reload prometheus
# or
curl -X POST http://localhost:9090/-/reload
```

Minimal `/etc/prometheus/prometheus.yml` for a single host:

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: "prometheus"
    static_configs:
      - targets: ["localhost:9090"]

  - job_name: "node_exporter"
    static_configs:
      - targets: ["localhost:9100"]
```

---

## 2. Add a New Scrape Target

Append a job block to `scrape_configs`, then reload. No restart required.

```yaml
# /etc/prometheus/prometheus.yml
scrape_configs:
  # ... existing jobs ...

  - job_name: "my_service"
    scrape_interval: 30s          # Override global interval for this job
    metrics_path: /metrics        # Default — omit if standard
    static_configs:
      - targets:
          - "10.0.0.5:9100"       # host:port
          - "10.0.0.6:9100"
        labels:
          env: "prod"             # Additional labels on all metrics from these targets
          service: "web"
```

After editing:

```bash
promtool check config /etc/prometheus/prometheus.yml
curl -X POST http://localhost:9090/-/reload
# Verify target appears and is UP:
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job, instance, health}'
```

---

## 3. File-Based Service Discovery

Use file SD when targets are managed by an external system (Ansible, Terraform, etc.).
Prometheus watches the files and reloads automatically — no SIGHUP needed for target changes.

`prometheus.yml` job:

```yaml
- job_name: "dynamic_hosts"
  file_sd_configs:
    - files:
        - "/etc/prometheus/file_sd/*.json"
      refresh_interval: 1m
```

Target file format (`/etc/prometheus/file_sd/web-servers.json`):

```json
[
  {
    "targets": ["10.0.1.10:9100", "10.0.1.11:9100"],
    "labels": {
      "env": "prod",
      "role": "web"
    }
  },
  {
    "targets": ["10.0.2.10:9100"],
    "labels": {
      "env": "staging",
      "role": "web"
    }
  }
]
```

YAML format is also accepted:

```yaml
- targets:
    - "10.0.1.10:9100"
  labels:
    role: "database"
```

Generate/update the file from a script and Prometheus picks up changes within `refresh_interval`.

---

## 4. Write an Alerting Rule

Save rule files in `/etc/prometheus/rules/` and reference them in `prometheus.yml`'s
`rule_files:` section. Validate before reloading.

```yaml
# /etc/prometheus/rules/host_alerts.yml
groups:
  - name: host_alerts
    rules:

      # Alert when any scrape target is unreachable for more than 2 minutes.
      - alert: TargetDown
        expr: up == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "{{ $labels.job }}/{{ $labels.instance }} is unreachable"
          description: "Scrape target has been down for > 2 minutes."

      # Alert when CPU usage stays above 90% for 5 minutes.
      - alert: HighCPU
        expr: |
          100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 90
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High CPU on {{ $labels.instance }}"
          description: "CPU usage is {{ $value | printf \"%.1f\" }}% (threshold: 90%)."

      # Alert when available memory drops below 10%.
      - alert: LowMemory
        expr: |
          (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100 < 10
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Low memory on {{ $labels.instance }}"
          description: "Only {{ $value | printf \"%.1f\" }}% memory available."
```

```bash
# Validate
promtool check rules /etc/prometheus/rules/host_alerts.yml

# Reload
curl -X POST http://localhost:9090/-/reload

# Check alert status (Pending = condition met but `for` not elapsed; Firing = active)
curl -s http://localhost:9090/api/v1/alerts | jq '.data.alerts[] | {name: .labels.alertname, state: .state}'
```

---

## 5. Essential PromQL Queries

These cover the most common infrastructure monitoring needs. Run them in the Prometheus
web UI (http://localhost:9090) or via the API.

```promql
# --- Availability ---

# Is each scrape target up? (1 = up, 0 = down)
up

# Count of down targets per job
count by (job) (up == 0)


# --- CPU ---

# Per-instance CPU usage % (5-minute rate, averaged across all cores)
100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Top 10 instances by CPU usage
topk(10, 100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100))


# --- Memory ---

# Available memory % per instance
(node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100

# Used memory in GiB
(node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / 1024^3


# --- Disk ---

# Disk usage % per mount (excludes tmpfs)
100 - (
  node_filesystem_avail_bytes{fstype!~"tmpfs|squashfs"}
  / node_filesystem_size_bytes{fstype!~"tmpfs|squashfs"}
  * 100
)

# Disk write throughput (bytes/sec, 5m rate)
rate(node_disk_written_bytes_total[5m])


# --- Network ---

# Network receive throughput per interface (bytes/sec)
rate(node_network_receive_bytes_total{device!~"lo|veth.*"}[5m])

# Network transmit throughput per interface
rate(node_network_transmit_bytes_total{device!~"lo|veth.*"}[5m])


# --- Prometheus self ---

# Number of active time series in the TSDB head
prometheus_tsdb_head_series

# Scrape duration per target (helpful for diagnosing slow exporters)
scrape_duration_seconds

# Rate of samples ingested per second
rate(prometheus_tsdb_head_samples_appended_total[5m])
```

---

## 6. Recording Rules for Dashboard Performance

Recording rules pre-compute expensive aggregations as new metrics. Dashboards then
query the small pre-aggregated metric instead of running a full scan on every panel
refresh. Name recording rules using the convention `namespace:metric:aggregation`.

```yaml
# /etc/prometheus/rules/recording_rules.yml
groups:
  - name: node_recording_rules
    # Evaluation interval for this group. Match your scrape interval.
    interval: 15s
    rules:

      # Pre-compute per-instance CPU usage. Dashboards query this single series
      # instead of aggregating across all CPU mode series at render time.
      - record: node:cpu_usage_percent:avg5m
        expr: |
          100 - (
            avg by (instance) (
              rate(node_cpu_seconds_total{mode="idle"}[5m])
            ) * 100
          )

      # Pre-compute memory available % per instance.
      - record: node:memory_available_percent:current
        expr: |
          (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100

      # Pre-compute disk usage % per instance and mountpoint.
      - record: node:disk_usage_percent:current
        expr: |
          100 - (
            node_filesystem_avail_bytes{fstype!~"tmpfs|squashfs"}
            / node_filesystem_size_bytes{fstype!~"tmpfs|squashfs"}
            * 100
          )

      # Cluster-wide average CPU (useful for overview dashboards).
      - record: cluster:cpu_usage_percent:avg5m
        expr: avg(node:cpu_usage_percent:avg5m)
```

After adding recording rules, verify they produce data:

```bash
promtool check rules /etc/prometheus/rules/recording_rules.yml
curl -X POST http://localhost:9090/-/reload
# Query the new metric after one evaluation interval
curl -s 'http://localhost:9090/api/v1/query?query=node:cpu_usage_percent:avg5m' | jq '.data.result'
```

---

## 7. Alertmanager Setup (Email and Slack Routing)

Alertmanager is a separate binary. Install and configure it, then point Prometheus's
`alerting:` block at it.

```bash
# Install (Debian/Ubuntu)
sudo apt install prometheus-alertmanager

# Validate config
amtool check-config /etc/alertmanager/alertmanager.yml

# Reload Alertmanager config (no restart)
curl -X POST http://localhost:9093/-/reload

# List current active alerts in Alertmanager
amtool alert
```

`/etc/alertmanager/alertmanager.yml`:

```yaml
global:
  # Default SMTP settings for email notifications.
  smtp_smarthost: "smtp.example.com:587"
  smtp_from: "alertmanager@example.com"
  smtp_auth_username: "alertmanager@example.com"
  smtp_auth_password_file: "/etc/alertmanager/smtp-password"
  smtp_require_tls: true

  # Slack API URL (from Incoming Webhook integration).
  slack_api_url: "https://hooks.slack.com/services/T.../B.../..."

# The root route — every alert passes through this first.
route:
  # Default receiver for alerts that don't match a child route.
  receiver: "email-ops"

  # How long to wait before re-sending an unresolved alert.
  repeat_interval: 4h

  # Group alerts by these labels to avoid alert storms (one notification per group).
  group_by: ["alertname", "job", "instance"]

  # How long to wait for more alerts to arrive before sending the first notification.
  group_wait: 30s

  # How long to wait before sending a notification for a new group that appeared
  # after the first grouped batch.
  group_interval: 5m

  # Child routes override the root route for specific label matchers.
  routes:
    # Route critical alerts to Slack immediately.
    - matchers:
        - severity="critical"
      receiver: "slack-critical"
      group_wait: 10s
      repeat_interval: 1h

    # Route warning alerts to email only.
    - matchers:
        - severity="warning"
      receiver: "email-ops"
      repeat_interval: 6h

receivers:
  - name: "email-ops"
    email_configs:
      - to: "ops-team@example.com"
        send_resolved: true

  - name: "slack-critical"
    slack_configs:
      - channel: "#alerts-critical"
        send_resolved: true
        # Custom message template showing alert name, instance, and description.
        text: >-
          {{ range .Alerts }}
          *Alert:* {{ .Labels.alertname }}
          *Instance:* {{ .Labels.instance }}
          *Description:* {{ .Annotations.description }}
          {{ end }}

# Silences suppress matching alerts. Create them via the Alertmanager web UI
# (http://localhost:9093) or with amtool:
#   amtool silence add alertname="InstanceDown" instance="10.0.0.5:9100" --duration=2h
```

---

## 8. Secure with nginx Reverse Proxy and Basic Auth

Prometheus has no built-in auth. Put it behind nginx with basic auth before exposing
it to any network that isn't strictly localhost.

```bash
# Create htpasswd file (prompts for password)
sudo apt install apache2-utils
sudo htpasswd -c /etc/nginx/prometheus.htpasswd prometheus
sudo chmod 640 /etc/nginx/prometheus.htpasswd
sudo chown root:www-data /etc/nginx/prometheus.htpasswd
```

`/etc/nginx/sites-available/prometheus`:

```nginx
server {
    listen 80;
    server_name prometheus.example.com;
    # Redirect to HTTPS — omit if running internally without TLS.
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    http2 on;
    server_name prometheus.example.com;

    ssl_certificate     /etc/letsencrypt/live/prometheus.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/prometheus.example.com/privkey.pem;

    location / {
        auth_basic "Prometheus";
        auth_basic_user_file /etc/nginx/prometheus.htpasswd;

        proxy_pass http://127.0.0.1:9090;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
    }
}
```

```bash
nginx -t && sudo systemctl reload nginx
```

Ensure Prometheus is listening on localhost only:

```ini
# /etc/default/prometheus (Debian) or systemd override
# Add --web.listen-address=127.0.0.1:9090 to prevent direct access
```

---

## 9. Long-Term Storage with remote_write

Prometheus's local TSDB is not designed for multi-year retention. Use `remote_write`
to stream metrics to a dedicated long-term store. Thanos and Mimir are the most common.

**Thanos**: sidecar reads TSDB blocks and uploads to object storage (S3/GCS).
**Mimir**: horizontally scalable, drop-in Prometheus-compatible remote_write endpoint.
**VictoriaMetrics**: single-binary, high compression, compatible API.

```yaml
# In prometheus.yml — add at the top level alongside scrape_configs
remote_write:
  - url: "http://mimir:9009/api/v1/push"
    # Optional queue tuning — defaults work for most workloads.
    queue_config:
      # Max samples buffered before sending a batch.
      max_samples_per_send: 2000
      # Max time a sample can wait in the queue before being sent.
      batch_send_deadline: 5s
      # How long to retry on failure before dropping.
      min_backoff: 30ms
      max_backoff: 5s
    # Metadata about the remote write endpoint (optional, for observability).
    name: "mimir-prod"

  # Alternatively, remote_write to a Thanos receive component:
  # - url: "http://thanos-receive:19291/api/v1/receive"

# remote_read: queries can fall through to remote storage for historical data.
# remote_read:
#   - url: "http://mimir:9009/prometheus/api/v1/read"
#     read_recent: false   # Only use remote for data older than local retention
```

---

## 10. Retention and Storage Sizing

Prometheus stores data in 2-hour blocks that are compacted over time. Default retention
is 15 days. Control via command-line flags in the systemd unit or startup script.

```ini
# /etc/default/prometheus (Debian/Ubuntu) — or create a systemd override
# sudo systemctl edit prometheus

ARGS="--storage.tsdb.retention.time=30d \
      --storage.tsdb.retention.size=50GB \
      --web.enable-admin-api"
```

Or via systemd override (`sudo systemctl edit prometheus`):

```ini
[Service]
ExecStart=
ExecStart=/usr/bin/prometheus \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/var/lib/prometheus \
  --storage.tsdb.retention.time=30d \
  --storage.tsdb.retention.size=50GB \
  --web.listen-address=127.0.0.1:9090 \
  --web.enable-admin-api
```

```bash
sudo systemctl daemon-reload && sudo systemctl restart prometheus
```

Storage sizing formula (rough estimate):

```
bytes_per_sample ≈ 1.5 bytes  (after compaction)
samples_per_second = series_count × (1 / scrape_interval_seconds)
bytes_per_day = samples_per_second × 86400 × bytes_per_sample
total_bytes = bytes_per_day × retention_days
```

Example: 100,000 series × 15s interval × 30 days ≈ **~26 GB**

Check current disk usage:

```bash
du -sh /var/lib/prometheus/
# Check TSDB head series count (current in-memory active series)
curl -s 'http://localhost:9090/api/v1/query?query=prometheus_tsdb_head_series' \
  | jq '.data.result[0].value[1]'
# Cardinality breakdown by metric name (top 10)
curl -s http://localhost:9090/api/v1/status/tsdb \
  | jq '.data.seriesCountByMetricName | sort_by(.seriesCount) | reverse | .[:10]'
```

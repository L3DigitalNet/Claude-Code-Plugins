# Loki Common Patterns

Each block below is a complete, copy-paste-ready configuration or command set.
Adjust hostnames, paths, and label names to match your environment.

---

## 1. Minimal Loki + Promtail Setup (Single Node)

Install and configure Loki and Promtail from pre-built binaries on a single Linux host.

```bash
# 1. Download binaries (check https://github.com/grafana/loki/releases for latest version)
LOKI_VERSION="3.1.0"
curl -LO "https://github.com/grafana/loki/releases/download/v${LOKI_VERSION}/loki-linux-amd64.zip"
curl -LO "https://github.com/grafana/loki/releases/download/v${LOKI_VERSION}/promtail-linux-amd64.zip"
unzip loki-linux-amd64.zip && unzip promtail-linux-amd64.zip
sudo mv loki-linux-amd64 /usr/local/bin/loki
sudo mv promtail-linux-amd64 /usr/local/bin/promtail
sudo chmod +x /usr/local/bin/loki /usr/local/bin/promtail

# 2. Create data directories and dedicated user
sudo useradd --system --no-create-home --shell /bin/false loki
sudo mkdir -p /etc/loki /etc/promtail /var/lib/loki /var/lib/promtail
sudo chown -R loki:loki /var/lib/loki /var/lib/promtail /etc/loki /etc/promtail

# 3. Place loki-config.yaml at /etc/loki/loki-config.yaml (see annotated reference)
# Place promtail-config.yaml at /etc/promtail/promtail-config.yaml

# 4. Create systemd units
sudo tee /etc/systemd/system/loki.service <<'EOF'
[Unit]
Description=Loki log aggregation system
After=network.target

[Service]
User=loki
Group=loki
ExecStart=/usr/local/bin/loki --config.file=/etc/loki/loki-config.yaml
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

sudo tee /etc/systemd/system/promtail.service <<'EOF'
[Unit]
Description=Promtail log collection agent
After=network.target

[Service]
User=root  # Root required to read /var/log/* and systemd journal
ExecStart=/usr/local/bin/promtail --config.file=/etc/promtail/promtail-config.yaml
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

# 5. Enable and start
sudo systemctl daemon-reload
sudo systemctl enable --now loki promtail

# 6. Verify
curl -s http://localhost:3100/ready   # → ready
curl -s http://localhost:9080/targets | python3 -m json.tool
```

---

## 2. Add Loki as a Grafana Data Source

Via Grafana UI or provisioning file. The provisioning approach is idempotent and
survives Grafana restarts without manual reconfiguration.

```yaml
# /etc/grafana/provisioning/datasources/loki.yaml
# Grafana reads this on startup and creates/updates the data source automatically.
apiVersion: 1

datasources:
  - name: Loki
    type: loki
    access: proxy  # Grafana server proxies requests to Loki; browser never contacts Loki directly.
    url: http://localhost:3100  # Change to Loki's host if Grafana runs on a different machine.
    isDefault: false  # Set to true if Loki should be the default data source.
    jsonData:
      maxLines: 1000  # Maximum log lines returned per query in Explore view.
      # timeout: 60   # Query timeout in seconds; increase for slow long-range queries.
    version: 1
    editable: true
```

After placing the file, restart Grafana: `sudo systemctl restart grafana-server`

To verify: Grafana sidebar > Connections > Data Sources > Loki > "Save & Test" → green checkmark.

---

## 3. Collect systemd Journal Logs with Promtail

Add this scrape_config to `/etc/promtail/promtail-config.yaml`. Promtail must run
as root (or a user in the `systemd-journal` group) to access `/var/log/journal`.

```yaml
scrape_configs:
  - job_name: systemd-journal

    journal:
      path: /var/log/journal
      max_age: 12h       # On first run, only tail the last 12h; avoids replaying the full journal.
      labels:
        job: systemd
        host: __hostname__  # Resolved to the machine's hostname at runtime.

    pipeline_stages:
      # The systemd journal message body is in the MESSAGE field.
      # Without this output stage, Promtail sends the raw JSON journal entry as the log line.
      - output:
          source: message

      # Optionally promote the PRIORITY field (0–7) as a label for filtering by severity.
      # Values: 0=emerg, 1=alert, 2=crit, 3=err, 4=warning, 5=notice, 6=info, 7=debug
      # This is low-cardinality (8 values) — safe as a label.
      - labels:
          PRIORITY:
          _SYSTEMD_UNIT:  # The unit name (e.g., "nginx.service") — also low-cardinality for typical servers.
```

Query in LogQL: `{job="systemd", _SYSTEMD_UNIT="nginx.service"} |= "error"`

---

## 4. Collect Docker Container Logs with Promtail

Docker writes JSON log files to `/var/lib/docker/containers/<id>/<id>-json.log`.
Promtail can tail these files and attach container metadata via `relabel_configs`.

```yaml
scrape_configs:
  - job_name: docker-containers

    static_configs:
      - targets:
          - localhost
        labels:
          job: docker
          __path__: /var/lib/docker/containers/*/*-json.log

    # relabel_configs run before pipeline_stages — they operate on the file path metadata.
    # This extracts the container ID from the log file path and attaches it as a label.
    relabel_configs:
      - source_labels: [__path__]
        # Capture the 64-char container ID from the path.
        regex: '/var/lib/docker/containers/([a-f0-9]+)/.*'
        target_label: container_id
        replacement: '$1'

    pipeline_stages:
      # Each line in a Docker JSON log file is a JSON object.
      - json:
          expressions:
            output: log    # The actual log message.
            stream: stream # "stdout" or "stderr".
            timestamp: time

      - timestamp:
          source: timestamp
          format: RFC3339Nano

      # Trim the trailing newline Docker appends to each log message.
      - replace:
          expression: '(.*)\n$'
          replace: '$1'
          source: output

      - labels:
          stream:

      - output:
          source: output
```

For richer container metadata (image name, compose project), use the Docker service
discovery (`docker_sd_configs`) instead of static_configs. See Promtail docs.

---

## 5. Parse Structured JSON Logs (Pipeline Stage)

When applications emit JSON log lines, use the `json` pipeline stage to extract
fields and promote low-cardinality ones as stream labels.

```yaml
# Assume log lines look like:
# {"timestamp":"2024-01-15T10:23:45Z","level":"error","service":"payments","message":"charge failed","user_id":"u_123","amount":9900}

pipeline_stages:
  # Extract all top-level JSON fields into the pipeline context.
  - json:
      expressions:
        level: level
        service: service
        message: message
        ts: timestamp
        # Do NOT extract user_id or amount as labels — high cardinality.

  # Use the JSON timestamp as the authoritative log timestamp.
  # Prevents "entry out of order" when logs are buffered before reaching Promtail.
  - timestamp:
      source: ts
      format: RFC3339  # Go reference: "2006-01-02T15:04:05Z07:00"

  # Promote only low-cardinality fields as stream labels.
  # "level" has ~5 values; "service" has as many values as your services — check cardinality.
  - labels:
      level:
      service:

  # Replace the raw JSON line with just the message field for cleaner display in Grafana.
  # Comment this out if you want the full JSON available for filtering in LogQL.
  - output:
      source: message
```

---

## 6. Essential LogQL Queries

LogQL has two query types: log queries (return log lines) and metric queries (return time series).
All queries start with a stream selector `{label="value"}`.

```logql
# --- Log Queries ---

# All logs from a job
{job="myapp"}

# Filter to lines containing "error" (case-sensitive substring match)
{job="myapp"} |= "error"

# Exclude health check noise
{job="myapp"} != "/health"

# Regex filter — lines matching the pattern
{job="myapp"} |~ "ERROR|FATAL"

# Parse JSON and filter on an extracted field value
{job="myapp"} | json | level="error"

# Parse logfmt (key=value format) and filter
{job="myapp"} | logfmt | status="500"

# Parse with regex named capture groups
{job="myapp"} | pattern `<timestamp> <level> <message>`

# Extract a field and filter by value range (numeric comparison requires label_format or json)
{job="myapp"} | json | response_time > 1.0

# --- Metric Queries ---

# Log line rate over time (lines per second, 5-minute window)
rate({job="myapp"}[5m])

# Count of error lines per minute
sum(rate({job="myapp"} |= "error" [1m]))

# Count by level label (requires level to be a stream label or extracted via json)
sum by (level) (rate({job="myapp"} | json [5m]))

# Total log volume in bytes per second
sum(bytes_rate({job="myapp"}[5m]))

# Detect when error rate exceeds 10/min (for alerting)
sum(rate({job="myapp"} |= "error" [5m])) > 10/60
```

---

## 7. LogQL Metric Queries (Unwrapped Values)

Unwrapped range aggregations operate on extracted numeric values rather than line counts.
Use these when log lines contain durations, sizes, or other numeric metrics.

```logql
# Average HTTP response time from JSON logs over 5 minutes
# Assumes JSON field "duration_ms" is numeric.
avg_over_time(
  {job="myapp"} | json | unwrap duration_ms [5m]
)

# 95th percentile response time (requires Loki 2.1+)
quantile_over_time(0.95,
  {job="myapp"} | json | unwrap duration_ms [5m]
)

# Sum of bytes transferred in the last hour
sum_over_time(
  {job="nginx"} | logfmt | unwrap bytes_sent [1h]
)
```

---

## 8. Alert Rules in LogQL

Loki ruler evaluates LogQL metric queries and sends alerts to Alertmanager.
Place rule files in the directory configured under `ruler.storage.local.directory`.

```yaml
# /var/lib/loki/rules/fake/rules.yaml
# "fake" is the tenant directory when auth_enabled: false.
# For multi-tenant setups, replace "fake" with the tenant ID.

groups:
  - name: myapp-alerts
    interval: 1m  # How often these rules are evaluated.
    rules:

      # Alert when error rate exceeds threshold.
      - alert: HighErrorRate
        # expr must be a metric query (rate, count_over_time, etc.) — not a log query.
        expr: |
          sum(rate({job="myapp"} |= "error" [5m])) > 0.1
        # for: how long the condition must be true before firing.
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High error rate in myapp"
          description: "Error rate is {{ $value | humanize }} errors/sec (threshold: 0.1)"

      # Alert when no logs are received (potential Promtail or app failure).
      - alert: NoLogsReceived
        expr: |
          sum(rate({job="myapp"}[10m])) == 0
        for: 10m
        labels:
          severity: critical
        annotations:
          summary: "No logs received from myapp for 10 minutes"
```

After creating or modifying rule files, Loki picks up changes within `ruler.poll_interval` (default 1m).
Verify rules are loaded: `curl -s http://localhost:3100/ruler/api/v1/rules | python3 -m json.tool`

---

## 9. logcli CLI Tool Usage

`logcli` is the official Loki command-line query tool. Install the binary from the
same GitHub release page as Loki.

```bash
# Set the default Loki address (avoids repeating --addr on every command).
export LOKI_ADDR=http://localhost:3100

# List all available label names
logcli labels

# List all values for a specific label
logcli labels job

# Run a log query (last 1 hour by default)
logcli query '{job="myapp"}'

# Tail logs in real time (streams until Ctrl+C)
logcli query --tail '{job="myapp"}'

# Specify a time range
logcli query '{job="myapp"}' \
  --from="2024-01-15T10:00:00Z" \
  --to="2024-01-15T11:00:00Z"

# Increase result limit (default is 30 lines)
logcli query '{job="myapp"} |= "error"' --limit=500

# Run a metric query and output as a time series table
logcli query 'rate({job="myapp"}[5m])' --step=1m

# Output in JSON format (useful for scripting)
logcli query '{job="myapp"}' --output=jsonl

# For multi-tenant Loki, specify the org ID
logcli --org-id=myteam labels
logcli --org-id=myteam query '{job="myapp"}'

# Use basic auth (if Loki is behind a proxy with auth)
logcli --username=admin --password=secret query '{job="myapp"}'
```

---

## 10. Multi-Tenant Setup (X-Scope-OrgID Header)

When `auth_enabled: true` in `loki-config.yaml`, every request must carry an
`X-Scope-OrgID` header identifying the tenant. Data is fully isolated per tenant.

```yaml
# promtail-config.yaml — send logs to a specific tenant
clients:
  - url: http://loki:3100/loki/api/v1/push
    tenant_id: team-alpha  # Promtail sends X-Scope-OrgID: team-alpha on every push.
```

```bash
# logcli — query a specific tenant
logcli --org-id=team-alpha query '{job="myapp"}'

# Direct API query for tenant "team-alpha"
curl -H "X-Scope-OrgID: team-alpha" \
  -G 'http://localhost:3100/loki/api/v1/query_range' \
  --data-urlencode 'query={job="myapp"}' \
  --data-urlencode 'start=1h'

# Grafana: set the tenant via the data source "HTTP Headers" field:
# Header name: X-Scope-OrgID
# Header value: team-alpha
# This scopes all Grafana queries to that tenant without exposing the header to dashboard users.
```

Per-tenant limits (ingestion rate, retention period) are set in `limits_config` and
can be overridden per-tenant via the Loki `/loki/api/v1/rules` API or the ruler's
per-tenant overrides file. See `overrides:` under `limits_config` in the Loki docs.

# node_exporter Common Patterns

---

## 1. Basic Setup and Verify Metrics Endpoint

Install and confirm the exporter is running and serving metrics.

```bash
# Debian/Ubuntu
sudo apt install prometheus-node-exporter
sudo systemctl enable --now prometheus-node-exporter

# RHEL/Fedora
sudo dnf install golang-github-prometheus-node-exporter
sudo systemctl enable --now node_exporter

# Manual install (any distro)
VERSION="1.8.2"
wget "https://github.com/prometheus/node_exporter/releases/download/v${VERSION}/node_exporter-${VERSION}.linux-amd64.tar.gz"
tar xf node_exporter-*.tar.gz
sudo mv node_exporter-*/node_exporter /usr/local/bin/
sudo useradd -r -s /bin/false node_exporter

# Verify endpoint
curl -s http://localhost:9100/metrics | head -30
curl -s http://localhost:9100/metrics | grep -c '^node_'   # should be > 100
```

---

## 2. Restrict to Localhost and Add to Prometheus Scrape Config

Node exporter has no authentication by default. Bind to localhost if Prometheus is on the same host.

```bash
# Debian/Ubuntu: /etc/default/prometheus-node-exporter
ARGS="--web.listen-address=127.0.0.1:9100"

# Then reload the service
sudo systemctl restart prometheus-node-exporter
```

```yaml
# /etc/prometheus/prometheus.yml — add to scrape_configs
scrape_configs:
  - job_name: "node"
    static_configs:
      - targets: ["localhost:9100"]
        labels:
          instance: "myhost"
          env: "production"
```

For remote hosts, use a targets file so you can add hosts without restarting Prometheus:

```yaml
scrape_configs:
  - job_name: "node"
    file_sd_configs:
      - files:
          - /etc/prometheus/targets/node_*.yml
        refresh_interval: 30s
```

```yaml
# /etc/prometheus/targets/node_prod.yml
- targets:
    - "10.0.0.1:9100"
    - "10.0.0.2:9100"
  labels:
    env: "production"
    role: "webserver"
```

---

## 3. Enable/Disable Specific Collectors via Flags

The default set of enabled collectors is large. Disable what you don't need or opt-in to extra collectors.

```bash
# See all collectors and their default state
prometheus-node-exporter --help 2>&1 | grep 'collector\.'

# Disable specific collectors while keeping defaults (prefix with --no-collector)
ARGS="--no-collector.arp \
      --no-collector.bcache \
      --no-collector.ipvs \
      --no-collector.rapl"

# Opt-in to non-default collectors (e.g., systemd, processes)
ARGS="--collector.systemd \
      --collector.processes"

# Disable ALL defaults and opt-in to only what you need
# (useful for very constrained systems)
ARGS="--collector.disable-defaults \
      --collector.cpu \
      --collector.meminfo \
      --collector.filesystem \
      --collector.diskstats \
      --collector.netdev \
      --collector.loadavg \
      --collector.uname"
```

Exclude loop and ramdisk devices from disk metrics:

```bash
ARGS="--collector.diskstats.device-exclude='^(loop|ram)\d+$' \
      --collector.filesystem.mount-points-exclude='^/(dev|proc|run/credentials/.+|sys|var/lib/docker/.+|snap/.+)($|/)'"
```

---

## 4. Textfile Collector: Push Custom Metrics from Scripts

The textfile collector reads `.prom` files from a directory at scrape time. Use it for metrics that node_exporter doesn't expose natively.

```bash
# 1. Create the textfile directory
sudo mkdir -p /var/lib/prometheus/node-exporter
sudo chown prometheus:prometheus /var/lib/prometheus/node-exporter  # or the user running node_exporter

# 2. Enable in node_exporter flags
ARGS="--collector.textfile.directory=/var/lib/prometheus/node-exporter"

# 3. Write a script that generates .prom content
cat > /usr/local/bin/node-exporter-backup-status.sh << 'EOF'
#!/bin/bash
# Writes backup job status as a Prometheus metric.
# Run via cron; node_exporter reads the file at scrape time.

TEXTFILE_DIR="/var/lib/prometheus/node-exporter"
TMPFILE=$(mktemp)

# Check last backup timestamp from a sentinel file
LAST_BACKUP=$(stat -c %Y /var/backups/last-success 2>/dev/null || echo 0)
NOW=$(date +%s)
AGE=$((NOW - LAST_BACKUP))

cat > "$TMPFILE" << PROM
# HELP backup_last_success_timestamp_seconds Unix timestamp of last successful backup.
# TYPE backup_last_success_timestamp_seconds gauge
backup_last_success_timestamp_seconds ${LAST_BACKUP}
# HELP backup_age_seconds Seconds since last successful backup.
# TYPE backup_age_seconds gauge
backup_age_seconds ${AGE}
PROM

# Atomic write — prevents node_exporter from reading a partial file
mv "$TMPFILE" "${TEXTFILE_DIR}/backup_status.prom"
EOF
chmod +x /usr/local/bin/node-exporter-backup-status.sh

# 4. Schedule with cron (runs every 5 minutes)
echo "*/5 * * * * root /usr/local/bin/node-exporter-backup-status.sh" \
  | sudo tee /etc/cron.d/node-exporter-backup-status

# 5. Verify the metrics appear
curl -s localhost:9100/metrics | grep '^backup_'
```

Key rules for textfile `.prom` files:
- Must end in `.prom`
- Must be valid Prometheus text exposition format (HELP/TYPE lines optional but recommended)
- Write atomically: write to a temp file, then `mv` into place — node_exporter reads at scrape time
- File must be readable by the node_exporter process user

---

## 5. Essential Metrics and What They Mean

```bash
# CPU usage per mode per core (rate over 5m gives usage fraction 0–1)
curl -s localhost:9100/metrics | grep '^node_cpu_seconds_total'
# Labels: cpu="0", mode="idle|user|system|iowait|irq|softirq|steal|nice"

# Memory (all values in bytes)
curl -s localhost:9100/metrics | grep '^node_memory_MemTotal\|MemAvailable\|MemFree\|Cached\|Buffers'
# MemAvailable is the most useful — includes reclaimable cache

# Disk space per mount (bytes)
curl -s localhost:9100/metrics | grep '^node_filesystem_size_bytes\|avail_bytes\|free_bytes'
# Labels: device, fstype, mountpoint

# Disk I/O (counters, use rate() in PromQL)
curl -s localhost:9100/metrics | grep '^node_disk_read_bytes_total\|written_bytes_total\|io_time_seconds_total'

# Network traffic (counters)
curl -s localhost:9100/metrics | grep '^node_network_receive_bytes_total\|transmit_bytes_total'

# System load
curl -s localhost:9100/metrics | grep '^node_load1\|node_load5\|node_load15'

# System uptime
curl -s localhost:9100/metrics | grep '^node_boot_time_seconds'
# Uptime = time() - node_boot_time_seconds
```

---

## 6. Key PromQL Queries for Node Monitoring

```promql
# CPU usage % across all cores (5m average)
100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memory usage %
100 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes * 100)

# Disk space usage % per mount
100 - (node_filesystem_avail_bytes{fstype!~"tmpfs|devtmpfs"} / node_filesystem_size_bytes * 100)

# Disk I/O utilization % (time disk was busy)
rate(node_disk_io_time_seconds_total[5m]) * 100

# Network receive bandwidth (bytes/s)
rate(node_network_receive_bytes_total{device!~"lo|veth.*|docker.*"}[5m])

# Network transmit bandwidth (bytes/s)
rate(node_network_transmit_bytes_total{device!~"lo|veth.*|docker.*"}[5m])

# System uptime in hours
(time() - node_boot_time_seconds) / 3600

# Top 5 hosts by CPU usage
topk(5, 100 - avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Alert: disk > 85% full
node_filesystem_avail_bytes{fstype!~"tmpfs|devtmpfs"} / node_filesystem_size_bytes < 0.15

# Alert: memory available < 10%
node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes < 0.10
```

---

## 7. Useful Grafana Dashboard IDs for Node Exporter

Import these from grafana.com (Dashboards → Import → paste ID).

| Dashboard | ID | Notes |
|-----------|-----|-------|
| Node Exporter Full | 1860 | Most comprehensive — CPU, memory, disk, network, system |
| Node Exporter for Prometheus | 405 | Simpler single-host view |
| Node Exporter Quickstart | 13978 | Good for multi-host fleet view |

To import: Grafana → Dashboards → New → Import → enter ID → select Prometheus data source.

---

## 8. Monitor Multiple Nodes (Prometheus Scrape Config)

```yaml
# /etc/prometheus/prometheus.yml
scrape_configs:
  # Static list — simple, requires Prometheus restart to add hosts
  - job_name: "node-static"
    scrape_interval: 15s
    scrape_timeout: 10s
    static_configs:
      - targets:
          - "web01.internal:9100"
          - "web02.internal:9100"
          - "db01.internal:9100"
        labels:
          env: "production"

  # File-based service discovery — add hosts by editing YAML files
  - job_name: "node-file-sd"
    file_sd_configs:
      - files:
          - /etc/prometheus/targets/node_*.yml
        refresh_interval: 60s
    # Relabeling: use the hostname label from the target file as the instance label
    relabel_configs:
      - source_labels: [__address__]
        target_label: instance
        regex: '([^:]+):\d+'
        replacement: '$1'
```

Firewall: open port 9100 from the Prometheus server IP only.

```bash
# UFW
sudo ufw allow from 10.0.0.5 to any port 9100

# firewalld
sudo firewall-cmd --permanent --add-rich-rule='rule family=ipv4 source address=10.0.0.5 port port=9100 protocol=tcp accept'
sudo firewall-cmd --reload
```

---

## 9. TLS and Basic Auth with web.config (node_exporter v1.5+)

Node exporter supports TLS and HTTP basic auth via a web configuration file. Requires v1.5 or later.

```yaml
# /etc/node_exporter/web.config.yml
tls_server_config:
  cert_file: /etc/node_exporter/tls.crt
  key_file:  /etc/node_exporter/tls.key

# Basic auth — password must be bcrypt hashed
# Generate hash: htpasswd -nB prometheus | cut -d: -f2
basic_auth_users:
  prometheus: "$2y$12$abc...hashedpassword...xyz"
```

```bash
# Generate a self-signed cert (replace with a real cert for production)
sudo mkdir -p /etc/node_exporter
sudo openssl req -x509 -newkey rsa:4096 -keyout /etc/node_exporter/tls.key \
  -out /etc/node_exporter/tls.crt -days 3650 -nodes \
  -subj "/CN=node-exporter"
sudo chown -R prometheus:prometheus /etc/node_exporter

# Enable in flags
ARGS="--web.config.file=/etc/node_exporter/web.config.yml"
```

```yaml
# Prometheus scrape config for TLS + basic auth target
scrape_configs:
  - job_name: "node-tls"
    scheme: https
    tls_config:
      # If self-signed, either provide the CA cert or skip verification (not recommended for production)
      ca_file: /etc/prometheus/node-exporter-ca.crt
      # insecure_skip_verify: true
    basic_auth:
      username: prometheus
      password: "the-plaintext-password"  # Prometheus encrypts at rest with --web.config.file
    static_configs:
      - targets: ["myhost:9100"]
```

---

## 10. Temperature and Hardware Sensors (hwmon Collector)

The `hwmon` collector exposes hardware sensor data from `/sys/class/hwmon/`. It requires kernel modules and may need `lm_sensors` for sensor detection.

```bash
# Install lm_sensors and detect chips
sudo apt install lm-sensors
sudo sensors-detect --auto
sensors   # verify sensors are readable

# Enable the hwmon collector if not enabled by default
ARGS="--collector.hwmon"

# Query temperature metrics
curl -s localhost:9100/metrics | grep '^node_hwmon_temp'
# node_hwmon_temp_celsius{chip="...",sensor="temp1"} 42.0
# node_hwmon_temp_max_celsius{chip="...",sensor="temp1"} 100.0
# node_hwmon_temp_crit_celsius{chip="...",sensor="temp1"} 105.0

# Other hwmon metrics (fan speed, voltage, power)
curl -s localhost:9100/metrics | grep '^node_hwmon'
```

PromQL alert for high CPU temperature:

```promql
# Alert if any temperature sensor exceeds 80°C
node_hwmon_temp_celsius > 80
```

Label meanings:
- `chip`: hardware device path (e.g., `platform_coretemp_0`)
- `sensor`: sensor identifier within the chip (e.g., `temp1`, `Core 0`)

If `node_hwmon_*` metrics are missing after enabling the collector, check that the kernel module for your hardware is loaded: `lsmod | grep hwmon`.

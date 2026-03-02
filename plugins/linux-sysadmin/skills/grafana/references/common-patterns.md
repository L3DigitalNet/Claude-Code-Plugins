# Grafana Common Patterns

Each section below is a complete, copy-paste-ready procedure or config block.
Provisioning files go under `/etc/grafana/provisioning/`. After editing provisioning
files, restart Grafana or use the API reload endpoints to apply changes.

---

## 1. Add Prometheus as a Data Source

Via the UI: Configuration → Data Sources → Add data source → Prometheus.

To add programmatically via the API (useful for scripting or testing):

```bash
curl -s -X POST http://localhost:3000/api/datasources \
  -H "Content-Type: application/json" \
  -u admin:<password> \
  -d '{
    "name": "Prometheus",
    "type": "prometheus",
    "url": "http://localhost:9090",
    "access": "proxy",
    "isDefault": true
  }'
```

`"access": "proxy"` means Grafana's backend makes the request to Prometheus —
not the user's browser. Always prefer `proxy` over `direct` for server-side
datasources; `direct` exposes your internal network topology to the browser.

---

## 2. Import a Community Dashboard by ID

Community dashboards are published at https://grafana.com/grafana/dashboards/.
Each has a numeric ID (e.g., Node Exporter Full = 1860).

Via the UI:
1. Dashboards → Import
2. Enter the dashboard ID in "Import via grafana.com"
3. Click Load
4. Select the Prometheus datasource from the dropdown
5. Click Import

Via the API:

```bash
# Fetch the dashboard JSON from grafana.com
curl -s "https://grafana.com/api/dashboards/1860/revisions/latest/download" \
  -o /tmp/dashboard.json

# Import it into your Grafana instance
curl -s -X POST http://localhost:3000/api/dashboards/import \
  -H "Content-Type: application/json" \
  -u admin:<password> \
  -d "{
    \"dashboard\": $(cat /tmp/dashboard.json),
    \"overwrite\": true,
    \"inputs\": [{
      \"name\": \"DS_PROMETHEUS\",
      \"type\": \"datasource\",
      \"pluginId\": \"prometheus\",
      \"value\": \"Prometheus\"
    }],
    \"folderId\": 0
  }"
```

The `inputs` array maps the dashboard's datasource placeholder (from the JSON's
`__inputs` field) to a datasource that exists in your Grafana instance. Check
the JSON's `__inputs` array to find the correct placeholder name.

---

## 3. Create a Basic Node Monitoring Dashboard

A minimal dashboard querying node_exporter metrics (assumes Node Exporter data
source configured as "Prometheus").

Panels to add manually via UI (New Dashboard → Add panel):

| Panel | Query | Visualization |
|-------|-------|---------------|
| CPU Usage | `100 - (avg by(instance)(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)` | Time series |
| Memory Usage % | `(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100` | Gauge |
| Disk Usage % | `100 - ((node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100)` | Gauge |
| Network In | `rate(node_network_receive_bytes_total{device!="lo"}[5m])` | Time series |
| Network Out | `rate(node_network_transmit_bytes_total{device!="lo"}[5m])` | Time series |
| System Load | `node_load1`, `node_load5`, `node_load15` | Time series |

Set a dashboard variable for `$instance` to make it multi-host:
- Dashboard Settings → Variables → Add variable
- Type: Query, Datasource: Prometheus
- Query: `label_values(node_uname_info, instance)`

---

## 4. Provisioning Data Sources as Code (YAML)

Place in `/etc/grafana/provisioning/datasources/prometheus.yaml`.
Grafana reads all `.yaml`/`.yml` files in this directory at startup.

```yaml
# Declarative datasource provisioning.
# Grafana applies this on startup. Changes require a restart or API reload.
# deleteDatasources removes datasources that are no longer in this file.
apiVersion: 1

deleteDatasources:
  - name: Old-Prometheus
    orgId: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    orgId: 1
    url: http://localhost:9090
    isDefault: true
    version: 1
    editable: false      # Prevents UI edits — enforces config-as-code
    jsonData:
      timeInterval: "15s"   # Matches Prometheus scrape interval

  - name: Loki
    type: loki
    access: proxy
    orgId: 1
    url: http://localhost:3100
    isDefault: false
    version: 1
    editable: false
```

Reload without restart:
```bash
curl -s -u admin:<password> -X POST \
  http://localhost:3000/api/admin/provisioning/datasources/reload
```

---

## 5. Provisioning Dashboards as Code (JSON + YAML config)

Two parts: a YAML provider config and the dashboard JSON files.

**Provider config** — `/etc/grafana/provisioning/dashboards/default.yaml`:

```yaml
apiVersion: 1

providers:
  - name: default
    orgId: 1
    folder: ""           # Empty string = General folder
    folderUid: ""
    type: file
    disableDeletion: false   # Set true to prevent UI deletion of provisioned dashboards
    updateIntervalSeconds: 30
    allowUiUpdates: false    # Prevents UI saves — edits are discarded on next reload
    options:
      path: /etc/grafana/provisioning/dashboards
      foldersFromFilesStructure: true  # Subdirectory name becomes folder name in UI
```

**Dashboard JSON files** — place `.json` files alongside the YAML config.
Export from the UI: Dashboard → Share → Export → Save to file.
Then copy to `/etc/grafana/provisioning/dashboards/`.

The `uid` field in the JSON is the stable identifier — Grafana uses it to match
existing dashboards on update. Keep it consistent across environments.

Reload without restart:
```bash
curl -s -u admin:<password> -X POST \
  http://localhost:3000/api/admin/provisioning/dashboards/reload
```

---

## 6. Configure SMTP for Alert Notifications

Edit `/etc/grafana/grafana.ini`:

```ini
[smtp]
enabled = true
host = smtp.example.com:587
user = grafana@example.com
# Store password in systemd environment rather than in the ini file:
# Create /etc/systemd/system/grafana-server.service.d/smtp.conf:
#   [Service]
#   Environment="GF_SMTP_PASSWORD=yourpassword"
password =
from_address = grafana@example.com
from_name = Grafana Alerts
```

Storing the password via systemd override (preferred over putting it in the ini):

```bash
sudo mkdir -p /etc/systemd/system/grafana-server.service.d/
sudo tee /etc/systemd/system/grafana-server.service.d/smtp.conf <<'EOF'
[Service]
Environment="GF_SMTP_PASSWORD=yourpassword"
EOF
sudo systemctl daemon-reload
sudo systemctl restart grafana-server
```

After configuring: Alerting → Contact points → Add contact point → Email.
Use "Test" button to verify SMTP connectivity before creating alert rules.

---

## 7. Grafana Behind nginx with Subpath

Goal: Grafana accessible at `https://example.com/grafana/`.

**grafana.ini** changes:

```ini
[server]
domain = example.com
root_url = https://example.com/grafana/
serve_from_sub_path = true
http_addr = 127.0.0.1   # Bind to loopback — nginx handles public traffic
```

**nginx** site config:

```nginx
server {
    listen 443 ssl;
    http2 on;
    server_name example.com;

    ssl_certificate     /etc/letsencrypt/live/example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;

    location /grafana/ {
        proxy_pass http://127.0.0.1:3000/grafana/;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Required for Grafana's WebSocket live streaming (alert state, etc.)
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

Both the trailing slash in `location /grafana/` and in `proxy_pass` are required.
`serve_from_sub_path = true` in Grafana ensures asset URLs include the subpath prefix.

---

## 8. Backup and Restore Grafana

### Backup

```bash
# Stop Grafana to get a consistent SQLite snapshot (for sqlite3 type only).
sudo systemctl stop grafana-server

# Back up the database.
sudo cp /var/lib/grafana/grafana.db /backup/grafana-$(date +%Y%m%d-%H%M%S).db

# Back up provisioning and config.
sudo tar czf /backup/grafana-provisioning-$(date +%Y%m%d).tar.gz \
  /etc/grafana/provisioning/

sudo cp /etc/grafana/grafana.ini /backup/grafana.ini.$(date +%Y%m%d)

# Restart Grafana.
sudo systemctl start grafana-server
```

For PostgreSQL/MySQL backends, use `pg_dump` / `mysqldump` instead — the database
can be backed up while Grafana is running.

### Restore

```bash
sudo systemctl stop grafana-server
sudo cp /backup/grafana-20240101-120000.db /var/lib/grafana/grafana.db
sudo chown grafana:grafana /var/lib/grafana/grafana.db
sudo systemctl start grafana-server
```

Verify: `curl -s http://localhost:3000/api/health` should return `"database":"ok"`.

---

## 9. Plugin Installation

### From the plugin catalog (requires internet access)

```bash
# Install a plugin by ID (find IDs at https://grafana.com/grafana/plugins/).
sudo grafana-cli plugins install grafana-worldmap-panel

# Restart Grafana to load the new plugin.
sudo systemctl restart grafana-server

# List all installed plugins.
grafana-cli plugins ls
```

### Without internet access (air-gapped)

```bash
# On a machine with internet: download the plugin zip.
curl -L -o /tmp/grafana-worldmap-panel.zip \
  "https://grafana.com/api/plugins/grafana-worldmap-panel/versions/latest/download"

# Copy the zip to the target host, then:
sudo grafana-cli --pluginUrl file:///tmp/grafana-worldmap-panel.zip \
  plugins install grafana-worldmap-panel

sudo systemctl restart grafana-server
```

### Remove a plugin

```bash
sudo grafana-cli plugins remove grafana-worldmap-panel
sudo systemctl restart grafana-server
```

---

## 10. Organization and Team Setup for Multi-User Access

Grafana has two levels of access isolation: Organizations (hard isolation, separate
data sources) and Teams (soft isolation, folder/dashboard permissions within an org).

### Create an additional organization via API

```bash
curl -s -X POST http://localhost:3000/api/orgs \
  -H "Content-Type: application/json" \
  -u admin:<password> \
  -d '{"name": "Operations Team"}'
```

### Add a user to an organization with a specific role

```bash
# First get the user's ID.
curl -s -u admin:<password> http://localhost:3000/api/users/lookup?loginOrEmail=user@example.com

# Add them to org ID 2 as Editor.
curl -s -X POST http://localhost:3000/api/orgs/2/users \
  -H "Content-Type: application/json" \
  -u admin:<password> \
  -d '{"loginOrEmail": "user@example.com", "role": "Editor"}'
```

### Create a team and assign dashboard folder permissions

```bash
# Create a team in org 1.
curl -s -X POST http://localhost:3000/api/teams \
  -H "Content-Type: application/json" \
  -u admin:<password> \
  -d '{"name": "SRE Team", "orgId": 1}'

# Add a user to the team (use team ID from above response).
curl -s -X POST http://localhost:3000/api/teams/1/members \
  -H "Content-Type: application/json" \
  -u admin:<password> \
  -d '{"userId": 2}'
```

Folder permissions are set via UI: Dashboards → (folder) → Manage permissions.
Teams can be granted Viewer, Editor, or Admin on specific folders, scoping their
access without affecting other folders in the same org.

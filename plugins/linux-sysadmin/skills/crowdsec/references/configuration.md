# CrowdSec Configuration Reference

## `/etc/crowdsec/config.yaml` — Main Configuration

Key sections (most others can remain at defaults for a single-node setup):

```yaml
common:
  daemonize: true
  log_media: file                  # "file" or "stdout" (stdout useful for journald)
  log_level: info                  # debug | info | warning | error
  log_dir: /var/log/crowdsec/
  working_dir: .

config_paths:
  config_dir: /etc/crowdsec/
  data_dir: /var/lib/crowdsec/data/
  simulation_path: /etc/crowdsec/simulation.yaml
  hub_dir: /etc/crowdsec/hub/
  index_path: /etc/crowdsec/.index.json

crowdsec_service:
  acquisition_path: /etc/crowdsec/acquis.yaml
  acquisition_dir: /etc/crowdsec/acquis.d/   # drop-in acquisition files
  parser_routines: 1
  # Reference allowlist files (v1.6+):
  allowlists:
    - /etc/crowdsec/allowlists.yaml

api:
  client:
    # Used by the agent to register with LAPI
    insecure_skip_verify: false
    credentials_path: /etc/crowdsec/local_api_credentials.yaml
  server:
    # LAPI settings — change listen_uri to expose to remote agents
    log_level: info
    listen_uri: 127.0.0.1:8080
    profiles_path: /etc/crowdsec/profiles.yaml
    console_path: /etc/crowdsec/console.yaml
    # TLS for remote bouncers (optional)
    # tls:
    #   cert_file: /etc/crowdsec/ssl/server.crt
    #   key_file:  /etc/crowdsec/ssl/server.key

db_config:
  log_level: silent
  type: sqlite                     # sqlite (default) or postgresql/mysql for multi-node
  db_path: /var/lib/crowdsec/data/crowdsec.db
  flush:
    max_items: 5000
    max_age: 7d

prometheus:
  enabled: false
  level: full                      # "full" or "aggregated"
  listen_addr: 127.0.0.1
  listen_port: 6060
```

After editing `config.yaml`: `sudo systemctl restart crowdsec`

---

## `/etc/crowdsec/acquis.yaml` — Log Acquisition

Tells CrowdSec which log sources to monitor. Each source is a YAML document separated by `---`.

### File-based sources

```yaml
# SSH authentication logs (Debian/Ubuntu path)
filenames:
  - /var/log/auth.log
labels:
  type: syslog

---
# SSH authentication logs (RHEL/Fedora path)
filenames:
  - /var/log/secure
labels:
  type: syslog

---
# Nginx access and error logs
filenames:
  - /var/log/nginx/access.log
  - /var/log/nginx/error.log
labels:
  type: nginx
```

### Journald source (preferred on systemd systems)

```yaml
# Read from journald instead of log files — lower latency, no log rotation issues
source: journald
journalctl_filter:
  - "_SYSTEMD_UNIT=ssh.service"
labels:
  type: syslog

---
source: journald
journalctl_filter:
  - "_SYSTEMD_UNIT=nginx.service"
labels:
  type: nginx
```

### Docker container logs

```yaml
source: docker
container_name:
  - my-nginx-container
labels:
  type: nginx

---
# Wildcard by name prefix
source: docker
container_name_regexp: "^nginx-.*"
labels:
  type: nginx
```

### Drop-in files (`/etc/crowdsec/acquis.d/`)

Place additional `.yaml` files here to avoid editing the main `acquis.yaml`. Useful for packaging — each service adds its own acquisition file:

```yaml
# /etc/crowdsec/acquis.d/postfix.yaml
filenames:
  - /var/log/mail.log
labels:
  type: syslog
```

After adding a source: `sudo systemctl reload crowdsec` (or restart if reload doesn't pick up new files).

---

## `/etc/crowdsec/profiles.yaml` — Decision Profiles

Profiles map alert scenarios to decisions (ban type, duration) and optional notifications.

```yaml
# Default profile — applies to all alerts not matched by a more specific profile
name: default_ip_remediation
filters:
  - Alert.Remediation == true && Alert.GetScope() == "Ip"
decisions:
  - type: ban
    duration: 4h
# Optionally send notifications:
# notifications:
#   - slack_default
on_success: break   # stop evaluating further profiles once this one matches

---
# Longer ban for particularly severe scenarios
name: aggressive_ban
filters:
  - Alert.Remediation == true && Alert.GetScope() == "Ip" && Alert.GetScenario() contains "scan"
decisions:
  - type: ban
    duration: 24h
on_success: break
```

After editing `profiles.yaml`: `sudo systemctl reload crowdsec`

---

## Bouncer Installation

### Firewall bouncer (iptables)

Blocks IPs at the kernel firewall level. Works on any Linux system with iptables/nftables.

```bash
# Debian/Ubuntu
sudo apt install crowdsec-firewall-bouncer-iptables

# RHEL/Fedora
sudo dnf install crowdsec-firewall-bouncer-iptables
```

Config: `/etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml`

```yaml
mode: iptables                      # or "nftables" on modern systems
pid_dir: /var/run/
update_frequency: 10s
daemonize: true
log_mode: file
log_dir: /var/log/crowdsec/
log_level: info
api_url: http://127.0.0.1:8080/
api_key: <generated on install>     # set automatically by package post-install script
```

After install, the bouncer auto-registers with the local LAPI. Verify: `sudo cscli bouncers list`

### Nginx bouncer

Blocks at the application layer using the nginx `lua-resty-crowdsec` module. Decisions are evaluated per-request by nginx itself — more granular than firewall-level bans.

```bash
# Requires nginx with LuaJIT support (openresty or lua module)
sudo apt install crowdsec-nginx-bouncer
```

Config: `/etc/crowdsec/bouncers/crowdsec-nginx-bouncer.conf`

```ini
API_URL=http://127.0.0.1:8080
API_KEY=<generated on install>
# Return 403 to banned IPs, or redirect to a custom page:
BAN_TEMPLATE_PATH=/etc/crowdsec/bouncers/ban.html
REDIRECT_LOCATION=
```

The package injects a snippet into nginx's config. Restart nginx after install: `sudo systemctl restart nginx`

---

## `/etc/crowdsec/allowlists.yaml` — Permanent Allowlists

IPs and CIDRs added here are never banned, even if they trigger scenarios.

```yaml
name: my_allowlist
description: "Internal networks and trusted IPs — never ban these"
reason: "Local infrastructure"

allowlists:
  - reason: "Home network"
    ip: "203.0.113.10"
  - reason: "Office subnet"
    cidr: "192.168.1.0/24"
  - reason: "Loopback and RFC1918"
    cidr: "127.0.0.0/8"
  - reason: "Monitoring server"
    ip: "10.0.0.5"
```

Reference this file from `config.yaml` under `crowdsec_service.allowlists`. After editing: `sudo systemctl restart crowdsec`

To check if an IP is currently allowlisted: `sudo cscli allowlists inspect <ip>` (v1.6+)

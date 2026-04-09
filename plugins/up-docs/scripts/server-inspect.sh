#!/usr/bin/env bash
# server-inspect.sh — Batch SSH inspection for a single host.
#
# Usage: server-inspect.sh <host> <service-type> [--config-paths <paths>] [--max-config-lines 200]
# Output: JSON with system info, service status, config files, ports.
# Exit:   0 always (captures errors in output JSON).

set -euo pipefail
PYTHON=$(command -v python3 2>/dev/null || command -v python 2>/dev/null) \
  || { echo '{"error":"python3 not found"}' >&2; exit 1; }

HOST="${1:?Usage: server-inspect.sh <host> <service-type>}"
SERVICE_TYPE="${2:?Usage: server-inspect.sh <host> <service-type>}"
shift 2

CONFIG_PATHS=""
MAX_CONFIG_LINES=200

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config-paths) CONFIG_PATHS="$2"; shift 2 ;;
    --max-config-lines) MAX_CONFIG_LINES="$2"; shift 2 ;;
    *) shift ;;
  esac
done

SSH_OPTS="-o ConnectTimeout=10 -o BatchMode=yes -o StrictHostKeyChecking=accept-new"

# Test connectivity
if ! ssh $SSH_OPTS "$HOST" "echo ok" >/dev/null 2>&1; then
  echo "{\"host\":\"$HOST\",\"reachable\":false,\"error\":\"SSH connection failed\"}"
  exit 0
fi

# Build service-specific commands
SERVICE_CMDS=""
case "$SERVICE_TYPE" in
  systemd|generic)
    SERVICE_CMDS='
echo "###DELIM:service_status###"
timeout 30 systemctl status '"$SERVICE_TYPE"' 2>&1 || echo "N/A"
echo "###DELIM:service_journal###"
timeout 30 journalctl -u '"$SERVICE_TYPE"' -n 20 --no-pager 2>&1 || echo "N/A"' ;;
  docker)
    SERVICE_CMDS='
echo "###DELIM:docker_ps###"
timeout 30 docker ps --format "{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" 2>&1 || echo "N/A"' ;;
  docker-compose)
    SERVICE_CMDS='
echo "###DELIM:docker_ps###"
timeout 30 docker ps --format "{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" 2>&1 || echo "N/A"
echo "###DELIM:compose_valid###"
timeout 30 docker compose config --quiet 2>&1 && echo "valid" || echo "invalid"' ;;
  nginx)
    SERVICE_CMDS='
echo "###DELIM:nginx_test###"
timeout 30 nginx -T 2>&1 | head -100 || echo "N/A"' ;;
  caddy)
    SERVICE_CMDS='
echo "###DELIM:caddy_config###"
timeout 30 caddy adapt --config /etc/caddy/Caddyfile 2>&1 | head -50 || echo "N/A"' ;;
  postgresql)
    SERVICE_CMDS='
echo "###DELIM:pg_version###"
timeout 30 sudo -u postgres psql -c "SELECT version()" 2>&1 || echo "N/A"' ;;
  redis)
    SERVICE_CMDS='
echo "###DELIM:redis_info###"
timeout 30 redis-cli info server 2>&1 | head -20 || echo "N/A"' ;;
  tailscale)
    SERVICE_CMDS='
echo "###DELIM:tailscale_status###"
timeout 30 tailscale status 2>&1 || echo "N/A"' ;;
  wireguard)
    SERVICE_CMDS='
echo "###DELIM:wg_show###"
timeout 30 wg show 2>&1 || echo "N/A"' ;;
  prometheus)
    SERVICE_CMDS='
echo "###DELIM:prom_health###"
timeout 10 curl -sf localhost:9090/-/healthy 2>&1 || echo "N/A"' ;;
  grafana)
    SERVICE_CMDS='
echo "###DELIM:grafana_health###"
timeout 10 curl -sf localhost:3000/api/health 2>&1 || echo "N/A"' ;;
  borg)
    SERVICE_CMDS='
echo "###DELIM:borg_list###"
timeout 30 borg list --last 3 2>&1 || echo "N/A"' ;;
  restic)
    SERVICE_CMDS='
echo "###DELIM:restic_snapshots###"
timeout 30 restic snapshots --latest 3 2>&1 || echo "N/A"' ;;
esac

# Build config reading commands
CONFIG_CMDS=""
if [[ -n "$CONFIG_PATHS" ]]; then
  IFS=',' read -ra PATHS <<< "$CONFIG_PATHS"
  for path in "${PATHS[@]}"; do
    path=$(echo "$path" | xargs)  # trim whitespace
    CONFIG_CMDS+="
echo \"###DELIM:config:${path}###\"
if [ -f '${path}' ]; then
  echo \"EXISTS:true\"
  stat -c '%Y' '${path}' 2>/dev/null || echo 'MTIME:unknown'
  head -n ${MAX_CONFIG_LINES} '${path}' 2>/dev/null
  if [ \$(wc -l < '${path}' 2>/dev/null || echo 0) -gt ${MAX_CONFIG_LINES} ]; then
    echo 'TRUNCATED:true'
  fi
else
  echo 'EXISTS:false'
fi"
  done
fi

# Execute all commands in a single SSH session
RAW_OUTPUT=$(ssh $SSH_OPTS "$HOST" bash << REMOTE_EOF
echo "###DELIM:hostname###"
hostname 2>/dev/null || echo "unknown"
echo "###DELIM:kernel###"
uname -r 2>/dev/null || echo "unknown"
echo "###DELIM:uptime###"
timeout 30 uptime 2>/dev/null || echo "unknown"
echo "###DELIM:memory###"
timeout 30 free -h 2>/dev/null || echo "N/A"
echo "###DELIM:disk###"
timeout 30 df -h 2>/dev/null || echo "N/A"
echo "###DELIM:ports###"
timeout 30 ss -tlnp 2>/dev/null || echo "N/A"
${SERVICE_CMDS}
${CONFIG_CMDS}
REMOTE_EOF
) 2>/dev/null || true

# Parse the output with Python
export RAW_OUTPUT HOST SERVICE_TYPE MAX_CONFIG_LINES

$PYTHON << 'PYEOF'
import json, os, re, sys

raw = os.environ.get("RAW_OUTPUT", "")
host = os.environ.get("HOST", "unknown")
service_type = os.environ.get("SERVICE_TYPE", "generic")
max_lines = int(os.environ.get("MAX_CONFIG_LINES", "200"))

# Parse delimited sections
sections = {}
current_key = None
current_lines = []

for line in raw.splitlines():
    m = re.match(r'^###DELIM:(.+)###$', line)
    if m:
        if current_key is not None:
            sections[current_key] = "\n".join(current_lines)
        current_key = m.group(1)
        current_lines = []
    else:
        current_lines.append(line)

if current_key is not None:
    sections[current_key] = "\n".join(current_lines)

# Build system info
system = {
    "hostname": sections.get("hostname", "unknown").strip(),
    "kernel": sections.get("kernel", "unknown").strip(),
    "uptime": sections.get("uptime", "unknown").strip(),
}

# Parse listening ports
ports = []
for line in sections.get("ports", "").splitlines()[1:]:
    parts = line.split()
    if len(parts) >= 4:
        local = parts[3]
        if ':' in local:
            port = local.rsplit(':', 1)[-1]
            ports.append(f"{port}/tcp")

# Parse service-specific data
service = {}
errors = []

if service_type in ("docker", "docker-compose"):
    containers = []
    for line in sections.get("docker_ps", "").splitlines():
        parts = line.split("\t")
        if len(parts) >= 4:
            containers.append({
                "name": parts[0], "image": parts[1],
                "status": parts[2], "ports": parts[3],
            })
    service["containers"] = containers
    if "compose_valid" in sections:
        service["compose_valid"] = "valid" in sections["compose_valid"]

for key in sections:
    if key.startswith("config:"):
        pass  # Handled separately below

# Collect remaining service-type sections
for key, val in sections.items():
    if key not in ("hostname", "kernel", "uptime", "memory", "disk", "ports", "docker_ps", "compose_valid") and not key.startswith("config:"):
        service[key] = val.strip()[:500]

# Parse config files
config_files = []
for key, val in sections.items():
    if key.startswith("config:"):
        path = key[7:]  # Remove "config:" prefix
        lines = val.splitlines()
        exists = False
        content_lines = []
        truncated = False
        last_modified = None

        for line in lines:
            if line.startswith("EXISTS:"):
                exists = line == "EXISTS:true"
            elif line.startswith("MTIME:"):
                last_modified = line[6:]
            elif line == "TRUNCATED:true":
                truncated = True
            else:
                content_lines.append(line)

        # Redact sensitive values
        content = "\n".join(content_lines)
        content = re.sub(r'(password|token|secret|api_key|POSTGRES_PASSWORD|_SECRET|Bearer)\s*[:=]\s*\S+',
                        r'\1=<REDACTED>', content, flags=re.IGNORECASE)

        config_files.append({
            "path": path,
            "exists": exists,
            "content": content if exists else None,
            "last_modified": last_modified,
            "truncated": truncated,
        })

result = {
    "host": host,
    "reachable": True,
    "service_type": service_type,
    "inspection": {
        "system": system,
        "service": service,
        "config_files": config_files,
        "listening_ports": sorted(set(ports)),
    },
    "errors": errors,
}

print(json.dumps(result, indent=2))
PYEOF

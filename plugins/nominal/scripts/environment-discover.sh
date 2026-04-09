#!/usr/bin/env bash
# environment-discover.sh — Discover environment profile for the nominal plugin.
#
# Usage: environment-discover.sh [<ssh-host>]
#   If no host is given, discovers the local system.
#   If a host is given, discovers via SSH.
#
# Output: JSON to stdout matching the environment-profile.md schema.
# Exit:   0 on success, 1 on script-level failures.

source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

HOST="${1:-}"

# Helper: run a command locally or remotely depending on HOST
rcmd() {
  if [[ -n "$HOST" ]]; then
    run_check "$1" --host "$HOST"
  else
    eval "$1" 2>/dev/null
  fi
}

# Helper: run a command and return output or empty string on failure
try_cmd() {
  rcmd "$1" 2>/dev/null || echo ""
}

# --- Gather raw data ---

# Host info
HOSTNAME_VAL=$(try_cmd "hostname -f 2>/dev/null || hostname")
OS_RELEASE=$(try_cmd "cat /etc/os-release 2>/dev/null")
UNAME_A=$(try_cmd "uname -a")
ARCH=$(try_cmd "uname -m")
VIRT_TYPE=$(try_cmd "systemd-detect-virt 2>/dev/null")

# Network
IP_ADDR=$(try_cmd "ip -j addr show 2>/dev/null || ip addr show 2>/dev/null")
IP_ROUTE=$(try_cmd "ip -j route show 2>/dev/null || ip route show 2>/dev/null")
FW_TOOL=$(
  if [[ -n "$HOST" ]]; then
    rcmd "command -v ufw >/dev/null 2>&1 && echo ufw || (command -v firewall-cmd >/dev/null 2>&1 && echo firewall-cmd || (command -v nft >/dev/null 2>&1 && echo nft || (command -v iptables >/dev/null 2>&1 && echo iptables || echo none)))" 2>/dev/null || echo "none"
  else
    detect_firewall
  fi
)

# VPN detection
VPN_TOOL=""
if rcmd "command -v tailscale >/dev/null 2>&1" 2>/dev/null; then
  VPN_TOOL="Tailscale"
elif rcmd "command -v wg >/dev/null 2>&1" 2>/dev/null; then
  VPN_TOOL="WireGuard"
fi

# Services (systemd units + listening ports)
SYSTEMD_UNITS=$(try_cmd "systemctl list-units --type=service --state=running --no-pager --no-legend 2>/dev/null")
LISTENING_PORTS=$(try_cmd "ss -tlnp 2>/dev/null")

# Docker containers
DOCKER_PS=""
if rcmd "command -v docker >/dev/null 2>&1" 2>/dev/null; then
  DOCKER_PS=$(try_cmd "docker ps --format '{{.Names}}\t{{.Image}}\t{{.Ports}}' 2>/dev/null")
fi

# Ingress: reverse proxy detection
PROXY_TOOL=""
PROXY_CONFIG=""
for proxy in nginx caddy traefik haproxy; do
  if rcmd "command -v $proxy >/dev/null 2>&1" 2>/dev/null; then
    PROXY_TOOL="$proxy"
    case "$proxy" in
      nginx)  PROXY_CONFIG=$(try_cmd "nginx -t 2>&1 | grep -oP 'configuration file \\K[^ ]+'") ;;
      caddy)  PROXY_CONFIG=$(try_cmd "find /etc/caddy -name Caddyfile -type f 2>/dev/null | head -1") ;;
      traefik) PROXY_CONFIG=$(try_cmd "find /etc/traefik -name '*.yml' -o -name '*.toml' 2>/dev/null | head -1") ;;
      haproxy) PROXY_CONFIG="/etc/haproxy/haproxy.cfg" ;;
    esac
    break
  fi
done

# SSL/certs
CERT_TOOL=""
CERT_CONFIG=""
CERT_RENEWAL=""
for ct in certbot acme.sh; do
  if rcmd "command -v $ct >/dev/null 2>&1" 2>/dev/null; then
    CERT_TOOL="$ct"
    case "$ct" in
      certbot)
        CERT_CONFIG="/etc/letsencrypt"
        # Check renewal mechanism
        if rcmd "systemctl is-active certbot.timer >/dev/null 2>&1" 2>/dev/null; then
          CERT_RENEWAL="systemd_timer"
        elif rcmd "crontab -l 2>/dev/null | grep -q certbot" 2>/dev/null; then
          CERT_RENEWAL="cron"
        fi
        ;;
      acme.sh)
        CERT_CONFIG="$HOME/.acme.sh"
        CERT_RENEWAL="cron"
        ;;
    esac
    break
  fi
done
# Caddy handles its own certs
if [[ -z "$CERT_TOOL" && "$PROXY_TOOL" == "caddy" ]]; then
  CERT_TOOL="Caddy"
  CERT_RENEWAL="daemon"
fi

# Monitoring
METRICS_TOOL=""
METRICS_CHECK=""
for mt in netdata prometheus-node-exporter prometheus grafana; do
  if rcmd "systemctl is-active $mt >/dev/null 2>&1" 2>/dev/null; then
    METRICS_TOOL="$mt"
    METRICS_CHECK="systemctl is-active $mt"
    break
  fi
done

UPTIME_TOOL=""
UPTIME_CHECK=""
if rcmd "systemctl is-active uptime-kuma >/dev/null 2>&1" 2>/dev/null; then
  UPTIME_TOOL="Uptime Kuma"
  UPTIME_CHECK="systemctl is-active uptime-kuma"
fi

LOG_TOOL=""
LOG_CHECK=""
for lt in loki elasticsearch promtail; do
  if rcmd "systemctl is-active $lt >/dev/null 2>&1" 2>/dev/null; then
    LOG_TOOL="$lt"
    LOG_CHECK="systemctl is-active $lt"
    break
  fi
done

# Backup
BACKUP_TOOL=""
BACKUP_TARGETS=""
BACKUP_CHECK=""
for bt in restic borg; do
  if rcmd "command -v $bt >/dev/null 2>&1" 2>/dev/null; then
    BACKUP_TOOL="$bt"
    break
  fi
done

# Secrets
SECRETS_APPROACH=""
SECRETS_LOCATION=""
if rcmd "command -v bao >/dev/null 2>&1" 2>/dev/null; then
  SECRETS_APPROACH="openbao"
  SECRETS_LOCATION="vault://secret/"
elif rcmd "command -v vault >/dev/null 2>&1" 2>/dev/null; then
  SECRETS_APPROACH="hashicorp_vault"
  SECRETS_LOCATION="vault://secret/"
else
  # Look for common env file locations
  for ef in /opt/stacks/.env /etc/environment .env; do
    if rcmd "test -f $ef" 2>/dev/null; then
      SECRETS_APPROACH="env_file"
      SECRETS_LOCATION="$ef"
      break
    fi
  done
fi

# Security tooling
FIM_TOOL=""
FIM_UPDATE=""
for fim in aide rkhunter tripwire; do
  if rcmd "command -v $fim >/dev/null 2>&1" 2>/dev/null; then
    FIM_TOOL="$fim"
    case "$fim" in
      aide) FIM_UPDATE="aide --update" ;;
      rkhunter) FIM_UPDATE="rkhunter --propupd" ;;
      tripwire) FIM_UPDATE="tripwire --update-policy" ;;
    esac
    break
  fi
done

IPS_TOOL=""
IPS_CHECK=""
for ips in fail2ban crowdsec; do
  if rcmd "command -v ${ips}-client >/dev/null 2>&1 || command -v $ips >/dev/null 2>&1" 2>/dev/null; then
    IPS_TOOL="$ips"
    case "$ips" in
      fail2ban) IPS_CHECK="fail2ban-client status" ;;
      crowdsec) IPS_CHECK="cscli metrics" ;;
    esac
    break
  fi
done

# VCS
GIT_REMOTE=$(try_cmd "git remote get-url origin 2>/dev/null")

# Config tracked paths: look for common infrastructure directories
CONFIG_PATHS=$(try_cmd "find /etc/caddy /etc/nginx /etc/haproxy /opt/stacks -maxdepth 0 -type d 2>/dev/null")

# --- Export all gathered data for Python ---

export HOSTNAME_VAL OS_RELEASE UNAME_A ARCH VIRT_TYPE
export FW_TOOL VPN_TOOL
export SYSTEMD_UNITS LISTENING_PORTS DOCKER_PS
export PROXY_TOOL PROXY_CONFIG
export CERT_TOOL CERT_CONFIG CERT_RENEWAL
export METRICS_TOOL METRICS_CHECK UPTIME_TOOL UPTIME_CHECK LOG_TOOL LOG_CHECK
export BACKUP_TOOL
export SECRETS_APPROACH SECRETS_LOCATION
export FIM_TOOL FIM_UPDATE IPS_TOOL IPS_CHECK
export GIT_REMOTE CONFIG_PATHS

# --- Assemble JSON ---

$PYTHON << 'PYEOF'
import json, sys, os
from datetime import datetime, timezone

def env_or_none(name):
    v = os.environ.get(name, "").strip()
    return v if v else None

def parse_os_release(text):
    """Extract NAME and VERSION_ID from /etc/os-release content."""
    vals = {}
    for line in (text or "").splitlines():
        if "=" in line:
            k, _, v = line.partition("=")
            vals[k.strip()] = v.strip().strip('"')
    return vals.get("NAME"), vals.get("VERSION_ID")

def parse_virt(text):
    """Map systemd-detect-virt output to our schema values."""
    v = (text or "").strip().lower()
    mapping = {
        "none": "bare_metal",
        "lxc": "proxmox_lxc",
        "qemu": "proxmox_vm",
        "kvm": "proxmox_vm",
        "docker": "docker_host",
        "": None,
    }
    return mapping.get(v, v)

def parse_listening_ports(ss_output):
    """Parse ss -tlnp output into a list of (address, port) tuples."""
    ports = []
    for line in (ss_output or "").splitlines()[1:]:  # skip header
        parts = line.split()
        if len(parts) >= 4:
            local = parts[3]
            # Format: addr:port or [addr]:port
            if ']:' in local:
                port = local.rsplit(':', 1)[-1]
            elif ':' in local:
                port = local.rsplit(':', 1)[-1]
            else:
                continue
            try:
                ports.append(int(port))
            except ValueError:
                pass
    return sorted(set(ports))

def build_services(systemd_units, listening_ports, docker_ps):
    """Build a basic services inventory from discovered data."""
    services = []
    seen_names = set()

    # From systemd units
    for line in (systemd_units or "").splitlines():
        parts = line.split()
        if not parts:
            continue
        unit = parts[0]
        # Only include .service units, skip system internals
        if not unit.endswith(".service"):
            continue
        name = unit.replace(".service", "")
        # Skip common system services that aren't application services
        skip_prefixes = (
            "sys-", "systemd-", "dbus", "getty", "user@", "ssh", "sshd",
            "cron", "rsyslog", "networkd", "resolved", "timesyncd",
            "udev", "polkit", "snap", "accounts-daemon", "ModemManager",
            "udisks", "plymouth", "thermald", "upower", "wpa_supplicant",
            "avahi", "bluetooth", "colord", "fwupd", "power-profiles",
            "rtkit", "switcheroo", "cups", "kerneloops", "unattended-upgrades",
        )
        if any(name.startswith(p) or name == p for p in skip_prefixes):
            continue
        if name not in seen_names:
            seen_names.add(name)
            services.append({
                "name": name,
                "role": None,
                "host_address": None,
                "ports": None,
                "access_tier": None,
                "dependencies": None,
                "health_endpoint": None,
                "monitoring_collector": None,
            })

    # From docker containers
    for line in (docker_ps or "").splitlines():
        parts = line.split("\t")
        if len(parts) < 1:
            continue
        name = parts[0].strip()
        if name and name not in seen_names:
            seen_names.add(name)
            svc = {
                "name": name,
                "role": None,
                "host_address": None,
                "ports": None,
                "access_tier": None,
                "dependencies": None,
                "health_endpoint": None,
                "monitoring_collector": None,
            }
            # Try to extract ports from docker ps output
            if len(parts) >= 3:
                port_str = parts[2].strip()
                if port_str:
                    import re
                    port_nums = re.findall(r':(\d+)->', port_str)
                    if port_nums:
                        svc["ports"] = [int(p) for p in port_nums]
            services.append(svc)

    return services

# Read gathered data from environment
os_name, os_version = parse_os_release(os.environ.get("OS_RELEASE", ""))
virt_type = parse_virt(os.environ.get("VIRT_TYPE", ""))
ports = parse_listening_ports(os.environ.get("LISTENING_PORTS", ""))
services = build_services(
    os.environ.get("SYSTEMD_UNITS", ""),
    os.environ.get("LISTENING_PORTS", ""),
    os.environ.get("DOCKER_PS", ""),
)

# Determine environment name from hostname
hostname = env_or_none("HOSTNAME_VAL") or "unknown"
env_name = hostname.split(".")[0].lower().replace(" ", "-")

# Network topology guess
topology = "flat"
if env_or_none("VPN_TOOL"):
    topology = "hybrid"

# Config tracked paths
config_paths = [p for p in (os.environ.get("CONFIG_PATHS", "") or "").splitlines() if p.strip()]

now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

profile = {
    "_schema_version": "1.0.0",
    env_name: {
        "description": None,
        "first_discovered": now,
        "last_validated": now,
        "host": {
            "hostname": hostname,
            "os_name": os_name,
            "os_version": os_version,
            "architecture": env_or_none("ARCH"),
            "kernel_version": (os.environ.get("UNAME_A", "") or "").split()[2] if os.environ.get("UNAME_A", "").strip() else None,
            "virtualization_type": virt_type,
            "_discovery_note": None,
        },
        "network": {
            "topology": topology,
            "private_bridge_or_overlay": None,
            "private_subnet": None,
            "vpn_tool": env_or_none("VPN_TOOL"),
            "firewall_tool": env_or_none("FW_TOOL") if env_or_none("FW_TOOL") != "none" else None,
            "_discovery_note": None,
        },
        "ingress": {
            "reverse_proxy_tool": env_or_none("PROXY_TOOL"),
            "config_path": env_or_none("PROXY_CONFIG"),
            "access_model": None,
            "_discovery_note": None,
        },
        "ssl": {
            "cert_tool": env_or_none("CERT_TOOL"),
            "config_path": env_or_none("CERT_CONFIG"),
            "renewal_mechanism": env_or_none("CERT_RENEWAL"),
            "_discovery_note": None,
        },
        "monitoring": {
            "metrics_tool": env_or_none("METRICS_TOOL"),
            "metrics_status_check": env_or_none("METRICS_CHECK"),
            "uptime_tool": env_or_none("UPTIME_TOOL"),
            "uptime_status_check": env_or_none("UPTIME_CHECK"),
            "log_aggregation_tool": env_or_none("LOG_TOOL"),
            "log_status_check": env_or_none("LOG_CHECK"),
            "_discovery_note": None,
        },
        "backup": {
            "backup_tool": env_or_none("BACKUP_TOOL"),
            "targets": None,
            "pre_dump_scripts": None,
            "last_run_check": None,
            "_discovery_note": None,
        },
        "secrets": {
            "approach": env_or_none("SECRETS_APPROACH"),
            "canonical_location": env_or_none("SECRETS_LOCATION"),
            "_discovery_note": None,
        },
        "security_tooling": {
            "fim_tool": env_or_none("FIM_TOOL"),
            "fim_baseline_update_method": env_or_none("FIM_UPDATE"),
            "ips_tool": env_or_none("IPS_TOOL"),
            "ips_status_check": env_or_none("IPS_CHECK"),
            "_discovery_note": None,
        },
        "vcs": {
            "tool": "git" if env_or_none("GIT_REMOTE") else None,
            "remote": env_or_none("GIT_REMOTE"),
            "config_tracked_paths": config_paths if config_paths else None,
            "_discovery_note": None,
        },
        "services": services,
    },
}

print(json.dumps(profile, indent=2))
PYEOF

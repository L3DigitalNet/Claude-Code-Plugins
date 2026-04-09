#!/usr/bin/env bash
# go-nogo-poll.sh — Preflight go/no-go poll and post-abort verification.
#
# Reads the environment profile and runs quick validation checks:
# hosts reachable, services running, reverse proxy responding,
# monitoring active, backup recent, firewall active.
#
# Usage: go-nogo-poll.sh <path-to-environment.json>
# Output: JSON with checks array and all_passed boolean.
# Exit:   0 always (Claude interprets all_passed). Exit 1 only if profile unreadable.

source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

PROFILE_PATH="${1:?Usage: go-nogo-poll.sh <path-to-environment.json>}"

# Load and parse the profile
PROFILE_JSON=$(load_profile "$PROFILE_PATH")

# Pass profile to Python, which orchestrates all checks via subprocess
export PROFILE_JSON

$PYTHON << 'PYEOF'
import json, os, subprocess, sys

def run(cmd, timeout=10):
    """Run a shell command, return (success, output)."""
    try:
        r = subprocess.run(
            cmd, shell=True, capture_output=True, text=True, timeout=timeout
        )
        return r.returncode == 0, (r.stdout.strip() or r.stderr.strip())
    except subprocess.TimeoutExpired:
        return False, "timeout"
    except Exception as e:
        return False, str(e)

def check(name, target, ok, evidence):
    return {
        "check": name,
        "target": target,
        "status": "pass" if ok else "fail",
        "evidence": evidence,
    }

profile = json.loads(os.environ["PROFILE_JSON"])
# Find the environment object (skip _schema_version)
env_key = next(k for k in profile if k != "_schema_version")
env = profile[env_key]

checks = []

# 1. Host reachability — ping the host if it has a hostname
host_info = env.get("host") or {}
hostname = host_info.get("hostname")
if hostname:
    ok, out = run(f"ping -c1 -W3 {hostname} 2>/dev/null")
    if ok:
        # Extract RTT from ping output
        import re
        rtt = re.search(r'time[=<]([\d.]+)', out)
        evidence = f"ping RTT {rtt.group(1)}ms" if rtt else "reachable"
    else:
        evidence = out or "unreachable"
    checks.append(check("host_reachable", hostname, ok, evidence))

# 2. Services spot-check — verify a sample of services respond
services = env.get("services") or []
for svc in services:
    name = svc.get("name", "unknown")
    health = svc.get("health_endpoint")
    host_addr = svc.get("host_address")
    ports = svc.get("ports") or []

    if health:
        # Try health endpoint
        for tool in ["curl", "wget"]:
            if subprocess.run(f"command -v {tool}", shell=True, capture_output=True).returncode == 0:
                if tool == "curl":
                    ok, out = run(f"curl -sf --max-time 5 '{health}'", timeout=8)
                else:
                    ok, out = run(f"wget -qO- --timeout=5 '{health}'", timeout=8)
                evidence = f"{tool}: {'ok' if ok else 'failed'}"
                if not ok:
                    evidence += f" ({out[:100]})" if out else ""
                checks.append(check("service_health", name, ok, evidence))
                break
        else:
            # Python urllib fallback
            try:
                from urllib.request import urlopen
                from urllib.error import URLError
                resp = urlopen(health, timeout=5)
                checks.append(check("service_health", name, True, f"HTTP {resp.status}"))
            except Exception as e:
                checks.append(check("service_health", name, False, str(e)[:100]))
    elif host_addr and ports:
        # TCP port check for first port
        port = ports[0]
        ok, out = run(f"bash -c 'echo >/dev/tcp/{host_addr}/{port}' 2>/dev/null", timeout=5)
        evidence = f"port {port} {'open' if ok else 'closed'}"
        checks.append(check("service_port", name, ok, evidence))

# 3. Reverse proxy
ingress = env.get("ingress") or {}
proxy_tool = ingress.get("reverse_proxy_tool")
if proxy_tool:
    ok, out = run(f"systemctl is-active {proxy_tool} 2>/dev/null")
    if not ok:
        # Try alternative service names
        ok, out = run(f"pgrep -x {proxy_tool} >/dev/null 2>&1")
    evidence = f"{proxy_tool}: {'active' if ok else 'inactive'}"
    checks.append(check("reverse_proxy", proxy_tool, ok, evidence))

# 4. Monitoring platform
monitoring = env.get("monitoring") or {}
metrics_check = monitoring.get("metrics_status_check")
metrics_tool = monitoring.get("metrics_tool")
if metrics_check:
    ok, out = run(metrics_check)
    evidence = f"{metrics_tool or 'metrics'}: {'active' if ok else 'inactive'}"
    checks.append(check("monitoring_metrics", metrics_tool or "metrics", ok, evidence))

uptime_check = monitoring.get("uptime_status_check")
uptime_tool = monitoring.get("uptime_tool")
if uptime_check:
    ok, out = run(uptime_check)
    evidence = f"{uptime_tool or 'uptime'}: {'active' if ok else 'inactive'}"
    checks.append(check("monitoring_uptime", uptime_tool or "uptime", ok, evidence))

# 5. Backup — check tool present and last run
backup = env.get("backup") or {}
backup_tool = backup.get("backup_tool")
last_run_check = backup.get("last_run_check")
if backup_tool:
    ok, out = run(f"command -v {backup_tool} >/dev/null 2>&1")
    evidence = f"{backup_tool}: {'installed' if ok else 'not found'}"
    checks.append(check("backup_tool", backup_tool, ok, evidence))

    if last_run_check and ok:
        ok2, out2 = run(last_run_check, timeout=15)
        evidence2 = out2[:200] if out2 else ("completed" if ok2 else "check failed")
        checks.append(check("backup_recent", backup_tool, ok2, evidence2))

# 6. Firewall
network = env.get("network") or {}
fw_tool = network.get("firewall_tool")
if fw_tool:
    fw_cmds = {
        "ufw": "ufw status | head -1",
        "firewall-cmd": "firewall-cmd --state",
        "nft": "nft list ruleset | head -1",
        "iptables": "iptables -L -n 2>/dev/null | head -5",
    }
    cmd = fw_cmds.get(fw_tool, f"systemctl is-active {fw_tool}")
    ok, out = run(cmd)
    # For ufw, check if the output indicates active status
    if fw_tool == "ufw":
        ok = "active" in (out or "").lower()
    # Fallback: check systemd service status if tool command fails (e.g. no root)
    if not ok:
        ok2, out2 = run(f"systemctl is-active {fw_tool} 2>/dev/null")
        if ok2:
            ok, out = True, f"service active (systemd)"
    evidence = out[:100] if out else ("active" if ok else "inactive")
    checks.append(check("firewall_active", fw_tool, ok, evidence))

# Determine overall pass/fail
all_passed = all(c["status"] == "pass" for c in checks) if checks else True

result = {
    "checks": checks,
    "all_passed": all_passed,
}

print(json.dumps(result, indent=2))
PYEOF

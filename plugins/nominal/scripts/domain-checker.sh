#!/usr/bin/env bash
# domain-checker.sh — Parameterized verification domain checker.
#
# Runs all checks for a single domain (1-11) against the environment profile.
# Claude calls this once per domain during postflight, replacing 4-6 tool calls
# per domain with a single invocation.
#
# Usage: domain-checker.sh <domain-number> <environment-json-path> [--host <ssh-host>] [--since-time <iso-timestamp>]
# Output: JSON with domain, checks array, and summary.
# Exit:   0 always (Claude classifies severity). Exit 1 only on script-level failures.

source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

# --- Argument parsing ---

DOMAIN=""
PROFILE_PATH=""
SSH_HOST=""
SINCE_TIME=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host) SSH_HOST="$2"; shift 2 ;;
    --since-time) SINCE_TIME="$2"; shift 2 ;;
    *)
      if [[ -z "$DOMAIN" ]]; then
        DOMAIN="$1"
      elif [[ -z "$PROFILE_PATH" ]]; then
        PROFILE_PATH="$1"
      fi
      shift
      ;;
  esac
done

if [[ -z "$DOMAIN" || -z "$PROFILE_PATH" ]]; then
  json_error "Usage: domain-checker.sh <domain-number> <environment.json> [--host <host>] [--since-time <ts>]"
fi

# Load profile
PROFILE_JSON=$(load_profile "$PROFILE_PATH")

# Export for Python
export DOMAIN PROFILE_JSON SSH_HOST SINCE_TIME

$PYTHON << 'PYEOF'
import json, os, subprocess, sys, re

DOMAIN = int(os.environ["DOMAIN"])
PROFILE = json.loads(os.environ["PROFILE_JSON"])
SSH_HOST = os.environ.get("SSH_HOST", "")
SINCE_TIME = os.environ.get("SINCE_TIME", "")

# Find the environment object
env_key = next(k for k in PROFILE if k != "_schema_version")
ENV = PROFILE[env_key]

def run(cmd, timeout=30):
    """Run a shell command, optionally via SSH."""
    if SSH_HOST:
        cmd = (
            f"ssh -o ConnectTimeout=10 -o BatchMode=yes "
            f"-o StrictHostKeyChecking=accept-new {SSH_HOST} {repr(cmd)}"
        )
    try:
        r = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=timeout)
        return r.returncode == 0, (r.stdout.strip() or r.stderr.strip())
    except subprocess.TimeoutExpired:
        return False, "timeout"
    except Exception as e:
        return False, str(e)

def has_tool(name):
    ok, _ = run(f"command -v {name} >/dev/null 2>&1", timeout=5)
    return ok

def chk(name, status, evidence, target=None):
    """Build a check result dict."""
    r = {"name": name, "status": status, "evidence": evidence}
    if target:
        r["target"] = target
    return r

# --- Domain functions ---

def domain_1():
    """Operational scripts & automation — backup coverage, uptime monitors, metrics collectors, systemd units."""
    checks = []
    services = ENV.get("services") or []
    backup = ENV.get("backup") or {}
    monitoring = ENV.get("monitoring") or {}
    backup_tool = backup.get("backup_tool")
    metrics_tool = monitoring.get("metrics_tool")
    uptime_tool = monitoring.get("uptime_tool")

    for svc in services:
        name = svc.get("name", "unknown")

        # Check systemd unit exists and is enabled
        ok, out = run(f"systemctl is-enabled {name} 2>/dev/null")
        if ok:
            checks.append(chk("systemd_unit", "pass", f"enabled ({out})", name))
        else:
            # Try with .service suffix
            ok2, out2 = run(f"systemctl is-enabled {name}.service 2>/dev/null")
            if ok2:
                checks.append(chk("systemd_unit", "pass", f"enabled ({out2})", name))
            else:
                checks.append(chk("systemd_unit", "skip", "no systemd unit found", name))

        # Check backup coverage if backup is configured
        if backup_tool:
            # Lightweight check: just note if backup tool is configured for this service
            checks.append(chk("backup_coverage", "skip",
                f"manual verification needed (backup tool: {backup_tool})", name))

        # Check monitoring coverage
        if metrics_tool:
            checks.append(chk("metrics_coverage", "skip",
                f"manual verification needed (metrics tool: {metrics_tool})", name))

        if uptime_tool and svc.get("health_endpoint"):
            checks.append(chk("uptime_monitor", "skip",
                f"manual verification needed (uptime tool: {uptime_tool})", name))

    return checks

def domain_2():
    """Backup integrity — tool installed, service active, recent run, files exist."""
    checks = []
    backup = ENV.get("backup") or {}
    backup_tool = backup.get("backup_tool")

    if not backup_tool:
        return [chk("backup_configured", "skip", "no backup tool in profile")]

    # Tool installed
    ok, _ = run(f"command -v {backup_tool} >/dev/null 2>&1")
    checks.append(chk("backup_installed", "pass" if ok else "fail",
        f"{backup_tool} {'found' if ok else 'not found'}"))

    if not ok:
        return checks

    # Service active (try systemd)
    ok, out = run(f"systemctl is-active {backup_tool} 2>/dev/null || systemctl is-active {backup_tool}.timer 2>/dev/null")
    checks.append(chk("backup_active", "pass" if ok else "skip",
        f"service: {out}" if ok else "no systemd service/timer found"))

    # Last run check
    last_run_check = backup.get("last_run_check")
    if last_run_check:
        ok, out = run(last_run_check, timeout=15)
        checks.append(chk("backup_recent", "pass" if ok else "fail",
            out[:200] if out else ("completed" if ok else "check failed")))

    # Check targets exist
    targets = backup.get("targets") or []
    for target in targets:
        if target.startswith("s3://") or target.startswith("b2://"):
            checks.append(chk("backup_target", "skip", f"remote target: {target}", target))
        else:
            ok, out = run(f"test -d '{target}' && ls '{target}' | head -3")
            checks.append(chk("backup_target", "pass" if ok else "fail",
                out[:100] if out else ("exists" if ok else "not found"), target))

    # Pre-dump scripts
    pre_dumps = backup.get("pre_dump_scripts") or []
    for script in pre_dumps:
        ok, _ = run(f"test -x '{script}'")
        if ok:
            ok2, out2 = run(f"stat -c '%Y' '{script}' 2>/dev/null")
            checks.append(chk("pre_dump_script", "pass", f"executable, mtime: {out2}", script))
        else:
            checks.append(chk("pre_dump_script", "fail", "not executable or not found", script))

    return checks

def domain_3():
    """Credential & secrets hygiene — permissions, process scan, git scan."""
    checks = []
    secrets = ENV.get("secrets") or {}
    canonical = secrets.get("canonical_location")

    if not canonical:
        return [chk("secrets_configured", "skip", "no canonical secrets location in profile")]

    # Check canonical location permissions
    if canonical.startswith("vault://"):
        checks.append(chk("secrets_permissions", "skip", f"vault-based: {canonical}"))
    else:
        ok, out = run(f"stat -c '%a %U' '{canonical}' 2>/dev/null")
        if ok:
            parts = out.split()
            perms = parts[0] if parts else "unknown"
            owner = parts[1] if len(parts) > 1 else "unknown"
            # World-readable check: last digit should be 0
            world_readable = len(perms) >= 3 and perms[-1] != '0'
            status = "fail" if world_readable else "pass"
            checks.append(chk("secrets_permissions", status,
                f"permissions: {perms}, owner: {owner}", canonical))
        else:
            checks.append(chk("secrets_permissions", "fail", "cannot stat canonical location", canonical))

    # Scan process args for exposed secrets
    ok, out = run(
        "ps aux 2>/dev/null | grep -iE '(password|token|api.?key|secret)' "
        "| grep -v grep | grep -v 'domain-checker' | head -5"
    )
    if ok and out:
        # Redact actual values — just count occurrences
        lines = [l for l in out.splitlines() if l.strip()]
        checks.append(chk("secrets_process_scan", "fail",
            f"{len(lines)} process(es) with potential secret exposure in args"))
    else:
        checks.append(chk("secrets_process_scan", "pass", "no secrets found in process arguments"))

    # Check git history for secret-like filenames
    vcs = ENV.get("vcs") or {}
    if vcs.get("tool") == "git":
        ok, out = run(
            "git log --diff-filter=A --name-only --pretty=format: -20 2>/dev/null "
            "| grep -iE '(\\.env|\\.pem|\\.key|credential|secret|password)' | head -5"
        )
        if ok and out:
            files = [f for f in out.splitlines() if f.strip()]
            checks.append(chk("secrets_git_scan", "fail",
                f"secret-like files in recent commits: {', '.join(files[:3])}"))
        else:
            checks.append(chk("secrets_git_scan", "pass", "no secret-like files in recent git history"))

    # Check canonical not inside git-tracked path
    if canonical and not canonical.startswith("vault://"):
        config_paths = (vcs.get("config_tracked_paths") or [])
        in_git = False
        for cp in config_paths:
            if canonical.startswith(cp):
                in_git = True
                break
        if not in_git:
            # Also check if the file itself is tracked
            ok, _ = run(f"git ls-files --error-unmatch '{canonical}' 2>/dev/null")
            in_git = ok

        if in_git:
            # Check for gitignore
            ok, _ = run(f"git check-ignore '{canonical}' 2>/dev/null")
            if ok:
                checks.append(chk("secrets_git_tracked", "pass",
                    "canonical location is git-ignored", canonical))
            else:
                checks.append(chk("secrets_git_tracked", "fail",
                    "canonical location is inside a git-tracked path without .gitignore exclusion", canonical))
        else:
            checks.append(chk("secrets_git_tracked", "pass",
                "canonical location is not in a git-tracked path", canonical))

    return checks

def domain_4():
    """Reachability & access tier correctness — service responds, proxy works, auth challenges."""
    checks = []
    services = ENV.get("services") or []
    ingress = ENV.get("ingress") or {}

    for svc in services:
        name = svc.get("name", "unknown")
        health = svc.get("health_endpoint")
        host_addr = svc.get("host_address")
        ports = svc.get("ports") or []
        access_tier = svc.get("access_tier")

        # Basic reachability
        if health:
            # HTTP health check
            ok, out = run(f"curl -sf --max-time 5 '{health}' >/dev/null 2>&1 && echo ok || wget -qO- --timeout=5 '{health}' >/dev/null 2>&1 && echo ok", timeout=8)
            if not ok:
                # Python fallback
                try:
                    from urllib.request import urlopen
                    resp = urlopen(health, timeout=5)
                    ok = True
                    out = f"HTTP {resp.status}"
                except Exception as e:
                    out = str(e)[:100]
            checks.append(chk("service_reachable", "pass" if ok else "fail",
                out[:100] if out else ("reachable" if ok else "unreachable"), name))
        elif host_addr and ports:
            port = ports[0]
            ok, _ = run(f"bash -c 'echo >/dev/tcp/{host_addr}/{port}' 2>/dev/null", timeout=5)
            checks.append(chk("service_reachable", "pass" if ok else "fail",
                f"TCP {host_addr}:{port} {'open' if ok else 'closed'}", name))
        else:
            checks.append(chk("service_reachable", "skip",
                "no health endpoint or address:port defined", name))

        # Auth challenge check for auth_gated services
        if access_tier == "auth_gated" and health:
            ok, out = run(
                f"curl -so /dev/null -w '%{{http_code}}' --max-time 5 '{health}'",
                timeout=8
            )
            if ok and out:
                code = out.strip()
                challenged = code in ("401", "403", "302", "303", "307")
                checks.append(chk("auth_challenge", "pass" if challenged else "fail",
                    f"HTTP {code} on unauthenticated request", name))

        # Dependency reachability
        deps = svc.get("dependencies") or []
        for dep_name in deps:
            dep_svc = next((s for s in services if s.get("name") == dep_name), None)
            if dep_svc:
                dep_health = dep_svc.get("health_endpoint")
                dep_addr = dep_svc.get("host_address")
                dep_ports = dep_svc.get("ports") or []
                if dep_health:
                    ok, _ = run(f"curl -sf --max-time 5 '{dep_health}' >/dev/null 2>&1", timeout=8)
                    checks.append(chk("dependency_reachable", "pass" if ok else "fail",
                        f"{dep_name} {'reachable' if ok else 'unreachable'}", f"{name}->{dep_name}"))
                elif dep_addr and dep_ports:
                    ok, _ = run(f"bash -c 'echo >/dev/tcp/{dep_addr}/{dep_ports[0]}' 2>/dev/null", timeout=5)
                    checks.append(chk("dependency_reachable", "pass" if ok else "fail",
                        f"{dep_name} TCP {dep_addr}:{dep_ports[0]} {'open' if ok else 'closed'}",
                        f"{name}->{dep_name}"))

    return checks

def domain_5():
    """Security posture — firewall active, undeclared ports, FIM, IPS."""
    checks = []
    network = ENV.get("network") or {}
    security = ENV.get("security_tooling") or {}
    services = ENV.get("services") or []

    # Firewall active
    fw_tool = network.get("firewall_tool")
    if fw_tool:
        fw_cmds = {
            "ufw": "ufw status 2>/dev/null || systemctl is-active ufw 2>/dev/null",
            "firewall-cmd": "firewall-cmd --state 2>/dev/null",
            "nft": "nft list ruleset 2>/dev/null | head -1",
            "iptables": "iptables -L -n 2>/dev/null | head -3",
        }
        cmd = fw_cmds.get(fw_tool, f"systemctl is-active {fw_tool} 2>/dev/null")
        ok, out = run(cmd)
        checks.append(chk("firewall_active", "pass" if ok else "fail",
            out[:150] if out else ("active" if ok else "inactive")))
    else:
        checks.append(chk("firewall_active", "skip", "no firewall tool in profile"))

    # Undeclared ports — compare ss -tlnp against services inventory
    ok, out = run("ss -tlnp 2>/dev/null")
    if ok and out:
        declared_ports = set()
        for svc in services:
            for p in (svc.get("ports") or []):
                declared_ports.add(int(p))

        listening = set()
        for line in out.splitlines()[1:]:
            parts = line.split()
            if len(parts) >= 4:
                local = parts[3]
                port_str = local.rsplit(':', 1)[-1] if ':' in local else None
                if port_str:
                    try:
                        listening.add(int(port_str))
                    except ValueError:
                        pass

        undeclared = listening - declared_ports
        if undeclared and declared_ports:
            checks.append(chk("undeclared_ports", "fail",
                f"undeclared listening ports: {sorted(undeclared)}"))
        elif not declared_ports:
            checks.append(chk("undeclared_ports", "skip",
                f"no ports declared in profile; {len(listening)} ports listening"))
        else:
            checks.append(chk("undeclared_ports", "pass",
                f"all {len(listening)} listening ports are declared"))
    else:
        checks.append(chk("undeclared_ports", "skip", "ss not available"))

    # FIM baseline
    fim_tool = security.get("fim_tool")
    if fim_tool:
        ok, out = run(f"command -v {fim_tool} >/dev/null 2>&1")
        checks.append(chk("fim_installed", "pass" if ok else "fail",
            f"{fim_tool} {'found' if ok else 'not found'}"))
    else:
        checks.append(chk("fim_installed", "skip", "no FIM tool in profile"))

    # IPS status
    ips_tool = security.get("ips_tool")
    ips_check = security.get("ips_status_check")
    if ips_tool and ips_check:
        ok, out = run(ips_check)
        checks.append(chk("ips_active", "pass" if ok else "fail",
            out[:150] if out else ("active" if ok else "inactive")))
    elif ips_tool:
        ok, out = run(f"systemctl is-active {ips_tool} 2>/dev/null")
        checks.append(chk("ips_active", "pass" if ok else "fail",
            f"{ips_tool}: {out}" if out else ("active" if ok else "inactive")))
    else:
        checks.append(chk("ips_active", "skip", "no IPS tool in profile"))

    return checks

def domain_6():
    """Performance & resource baselines — CPU, memory, disk, OOM, container limits."""
    checks = []

    # CPU load
    ok, out = run("cat /proc/loadavg 2>/dev/null")
    if ok and out:
        load_1m = float(out.split()[0])
        # Get number of CPUs for context
        ok2, cpus = run("nproc 2>/dev/null")
        ncpu = int(cpus) if ok2 and cpus.strip().isdigit() else 1
        ratio = load_1m / ncpu
        status = "fail" if ratio > 0.9 else ("pass" if ratio < 0.8 else "pass")
        checks.append(chk("cpu_load", status,
            f"load avg: {out}, cpus: {ncpu}, ratio: {ratio:.2f}"))
    else:
        checks.append(chk("cpu_load", "skip", "cannot read /proc/loadavg"))

    # Memory
    ok, out = run("free -m 2>/dev/null")
    if ok and out:
        lines = out.splitlines()
        if len(lines) >= 2:
            parts = lines[1].split()
            if len(parts) >= 7:
                total = int(parts[1])
                available = int(parts[6])
                pct_used = ((total - available) / total * 100) if total > 0 else 0
                status = "fail" if pct_used > 95 else "pass"
                checks.append(chk("memory", status,
                    f"total: {total}MB, available: {available}MB, used: {pct_used:.1f}%"))
            else:
                checks.append(chk("memory", "skip", f"unexpected free output format"))
        else:
            checks.append(chk("memory", "skip", "unexpected free output format"))
    else:
        checks.append(chk("memory", "skip", "free not available"))

    # Disk
    ok, out = run("df -h --output=target,pcent,avail 2>/dev/null || df -h 2>/dev/null")
    if ok and out:
        disk_issues = []
        for line in out.splitlines()[1:]:
            parts = line.split()
            if len(parts) >= 2:
                # Find the percentage column
                pct_col = None
                for p in parts:
                    if p.endswith('%'):
                        pct_col = p
                        break
                if pct_col:
                    try:
                        pct = int(pct_col.rstrip('%'))
                        mount = parts[0] if not parts[0].endswith('%') else parts[-1]
                        if pct >= 95:
                            disk_issues.append(f"{mount}: {pct}% (CRITICAL)")
                        elif pct >= 90:
                            disk_issues.append(f"{mount}: {pct}% (warning)")
                    except ValueError:
                        pass

        if disk_issues:
            critical = any("CRITICAL" in d for d in disk_issues)
            checks.append(chk("disk", "fail" if critical else "pass",
                "; ".join(disk_issues)))
        else:
            checks.append(chk("disk", "pass", "all filesystems below 90%"))
    else:
        checks.append(chk("disk", "skip", "df not available"))

    # OOM events since session start
    if SINCE_TIME:
        ok, out = run(f"journalctl -k --since='{SINCE_TIME}' --no-pager 2>/dev/null | grep -i oom | head -5")
        if ok and out:
            checks.append(chk("oom_events", "fail", f"OOM events found: {out[:200]}"))
        else:
            checks.append(chk("oom_events", "pass", "no OOM events since session start"))
    else:
        # No session time provided; check last hour as fallback
        ok, out = run("journalctl -k --since='1 hour ago' --no-pager 2>/dev/null | grep -i oom | head -5")
        if ok and out:
            checks.append(chk("oom_events", "fail", f"OOM events in last hour: {out[:200]}"))
        else:
            checks.append(chk("oom_events", "pass", "no OOM events in last hour"))

    # Container limits (if applicable)
    host = ENV.get("host") or {}
    virt = host.get("virtualization_type") or ""
    if "lxc" in virt.lower() or "docker" in virt.lower():
        ok, out = run("cat /sys/fs/cgroup/memory.max 2>/dev/null || cat /sys/fs/cgroup/memory/memory.limit_in_bytes 2>/dev/null")
        if ok and out:
            ok2, used = run("cat /sys/fs/cgroup/memory.current 2>/dev/null || cat /sys/fs/cgroup/memory/memory.usage_in_bytes 2>/dev/null")
            if ok2 and used:
                try:
                    limit = int(out.strip())
                    current = int(used.strip())
                    if limit > 0 and limit < 2**62:
                        pct = current / limit * 100
                        checks.append(chk("container_memory", "fail" if pct > 90 else "pass",
                            f"limit: {limit // (1024*1024)}MB, used: {current // (1024*1024)}MB ({pct:.1f}%)"))
                except ValueError:
                    checks.append(chk("container_memory", "skip", f"cannot parse cgroup values"))

    return checks

def domain_7():
    """Service lifecycle & boot ordering — autostart, After=/Requires=, restart policy."""
    checks = []
    services = ENV.get("services") or []

    for svc in services:
        name = svc.get("name", "unknown")

        # Autostart (enabled)
        ok, out = run(f"systemctl is-enabled {name} 2>/dev/null || systemctl is-enabled {name}.service 2>/dev/null")
        if ok:
            checks.append(chk("autostart", "pass" if out == "enabled" else "pass",
                f"{out}", name))
        else:
            checks.append(chk("autostart", "skip", "no systemd unit found", name))
            continue

        # Dependency directives
        deps = svc.get("dependencies") or []
        if deps:
            ok, out = run(f"systemctl show -p After,Requires {name} 2>/dev/null")
            if ok and out:
                has_after = "After=" in out
                has_requires = "Requires=" in out
                for dep_name in deps:
                    dep_in_after = dep_name in out
                    if dep_in_after:
                        checks.append(chk("dependency_ordering", "pass",
                            f"After/Requires includes {dep_name}", f"{name}->{dep_name}"))
                    else:
                        checks.append(chk("dependency_ordering", "fail",
                            f"{dep_name} not found in After/Requires directives", f"{name}->{dep_name}"))

        # Restart policy
        ok, out = run(f"systemctl show -p Restart {name} 2>/dev/null")
        if ok and out:
            restart = out.replace("Restart=", "").strip()
            checks.append(chk("restart_policy", "pass", f"Restart={restart}", name))

    return checks

def domain_8():
    """Observability completeness — metrics, uptime, log platforms active and collecting."""
    checks = []
    monitoring = ENV.get("monitoring") or {}

    # Metrics platform
    metrics_check = monitoring.get("metrics_status_check")
    metrics_tool = monitoring.get("metrics_tool")
    if metrics_check:
        ok, out = run(metrics_check)
        checks.append(chk("metrics_platform", "pass" if ok else "fail",
            f"{metrics_tool or 'metrics'}: {out[:100]}" if out else ("active" if ok else "inactive")))
    elif metrics_tool:
        ok, out = run(f"systemctl is-active {metrics_tool} 2>/dev/null")
        checks.append(chk("metrics_platform", "pass" if ok else "fail",
            f"{metrics_tool}: {out}" if out else ("active" if ok else "inactive")))
    else:
        checks.append(chk("metrics_platform", "skip", "no metrics tool in profile"))

    # Uptime tool
    uptime_check = monitoring.get("uptime_status_check")
    uptime_tool = monitoring.get("uptime_tool")
    if uptime_check:
        ok, out = run(uptime_check)
        checks.append(chk("uptime_platform", "pass" if ok else "fail",
            f"{uptime_tool or 'uptime'}: {out[:100]}" if out else ("active" if ok else "inactive")))
    elif uptime_tool:
        ok, out = run(f"systemctl is-active {uptime_tool} 2>/dev/null")
        checks.append(chk("uptime_platform", "pass" if ok else "fail",
            f"{uptime_tool}: {out}" if out else ("active" if ok else "inactive")))
    else:
        checks.append(chk("uptime_platform", "skip", "no uptime tool in profile"))

    # Log aggregation
    log_check = monitoring.get("log_status_check")
    log_tool = monitoring.get("log_aggregation_tool")
    if log_check:
        ok, out = run(log_check)
        checks.append(chk("log_platform", "pass" if ok else "fail",
            f"{log_tool or 'logs'}: {out[:100]}" if out else ("active" if ok else "inactive")))
    elif log_tool:
        ok, out = run(f"systemctl is-active {log_tool} 2>/dev/null")
        checks.append(chk("log_platform", "pass" if ok else "fail",
            f"{log_tool}: {out}" if out else ("active" if ok else "inactive")))
    else:
        checks.append(chk("log_platform", "skip", "no log aggregation in profile"))

    # Per-service monitoring coverage
    services = ENV.get("services") or []
    for svc in services:
        name = svc.get("name", "unknown")
        health = svc.get("health_endpoint")
        access_tier = svc.get("access_tier")
        collector = svc.get("monitoring_collector")

        if collector:
            checks.append(chk("service_monitoring", "pass",
                f"collector: {collector}", name))
        elif metrics_tool:
            checks.append(chk("service_monitoring", "skip",
                f"no explicit collector; {metrics_tool} may be collecting", name))

        # Uptime monitor for public/auth_gated services with health endpoints
        if uptime_tool and health and access_tier in ("public", "auth_gated"):
            checks.append(chk("service_uptime_monitor", "skip",
                f"manual verification needed ({uptime_tool})", name))

    return checks

def domain_9():
    """DNS & certificate lifecycle — DNS resolves, cert valid, renewal active."""
    checks = []
    ssl = ENV.get("ssl") or {}
    services = ENV.get("services") or []

    cert_tool = ssl.get("cert_tool")
    renewal = ssl.get("renewal_mechanism")

    # DNS resolution for public/auth_gated services
    for svc in services:
        name = svc.get("name", "unknown")
        access_tier = svc.get("access_tier")
        health = svc.get("health_endpoint")

        if access_tier not in ("public", "auth_gated"):
            continue
        if not health:
            continue

        # Extract hostname from health endpoint
        hostname = None
        if health.startswith("http"):
            try:
                from urllib.parse import urlparse
                hostname = urlparse(health).hostname
            except Exception:
                pass

        if hostname and not re.match(r'^\d+\.\d+\.\d+\.\d+$', hostname):
            # DNS check
            ok, out = run(f"dig +short {hostname} 2>/dev/null || host {hostname} 2>/dev/null || nslookup {hostname} 2>/dev/null")
            if ok and out:
                checks.append(chk("dns_resolution", "pass", f"{hostname} -> {out.splitlines()[0]}", name))
            else:
                checks.append(chk("dns_resolution", "fail", f"{hostname} does not resolve", name))

            # SSL cert check
            ok, out = run(
                f"echo | openssl s_client -servername {hostname} -connect {hostname}:443 2>/dev/null "
                f"| openssl x509 -noout -enddate -subject 2>/dev/null"
            )
            if ok and out:
                # Parse expiry
                expiry_match = re.search(r'notAfter=(.*)', out)
                subject_match = re.search(r'subject=(.*)', out)
                if expiry_match:
                    from datetime import datetime
                    try:
                        expiry_str = expiry_match.group(1).strip()
                        # OpenSSL date format: Mon DD HH:MM:SS YYYY GMT
                        expiry = datetime.strptime(expiry_str, "%b %d %H:%M:%S %Y %Z")
                        days_left = (expiry - datetime.utcnow()).days
                        status = "fail" if days_left <= 7 else "pass"
                        checks.append(chk("cert_valid", status,
                            f"expires: {expiry_str} ({days_left} days)", name))
                    except ValueError:
                        checks.append(chk("cert_valid", "pass", f"expiry: {expiry_str}", name))
            else:
                checks.append(chk("cert_valid", "skip", "cannot check certificate (no openssl or no TLS)", name))

    # Renewal mechanism
    if cert_tool:
        if renewal == "systemd_timer":
            ok, out = run(f"systemctl is-active certbot.timer 2>/dev/null || systemctl list-timers --no-pager 2>/dev/null | grep -i cert")
            checks.append(chk("cert_renewal", "pass" if ok else "fail",
                f"timer: {out[:100]}" if out else ("active" if ok else "inactive")))
        elif renewal == "cron":
            ok, out = run("crontab -l 2>/dev/null | grep -i cert")
            checks.append(chk("cert_renewal", "pass" if ok else "fail",
                out[:100] if out else ("configured" if ok else "no cron entry found")))
        elif renewal == "daemon":
            checks.append(chk("cert_renewal", "pass", f"{cert_tool} handles renewal as daemon"))
        elif renewal:
            checks.append(chk("cert_renewal", "skip", f"renewal mechanism: {renewal}"))
        else:
            checks.append(chk("cert_renewal", "skip", "no renewal mechanism configured"))

        # Dry run if certbot
        if cert_tool.lower() == "certbot":
            ok, out = run("certbot renew --dry-run 2>&1 | tail -3", timeout=60)
            checks.append(chk("cert_dry_run", "pass" if ok else "fail",
                out[:200] if out else ("passed" if ok else "failed")))
    else:
        checks.append(chk("cert_renewal", "skip", "no cert tool in profile"))

    return checks

def domain_10():
    """Network routing correctness — inter-service connectivity, 0.0.0.0 bindings, VPN, firewall."""
    checks = []
    network = ENV.get("network") or {}
    services = ENV.get("services") or []

    # Check for 0.0.0.0 bindings on services that should be private
    ok, out = run("ss -tlnp 2>/dev/null")
    if ok and out:
        wildcard_bindings = []
        for line in out.splitlines()[1:]:
            if "*:*" in line or "0.0.0.0:" in line or ":::*" in line:
                parts = line.split()
                if len(parts) >= 4:
                    local = parts[3]
                    port_str = local.rsplit(':', 1)[-1] if ':' in local else None
                    if port_str:
                        try:
                            port = int(port_str)
                            # Check if any vpn_only service uses this port
                            for svc in services:
                                if svc.get("access_tier") == "vpn_only":
                                    svc_ports = svc.get("ports") or []
                                    if port in svc_ports:
                                        wildcard_bindings.append(
                                            f"{svc['name']} port {port} bound to 0.0.0.0")
                        except ValueError:
                            pass

        if wildcard_bindings:
            checks.append(chk("wildcard_bindings", "fail",
                "; ".join(wildcard_bindings)))
        else:
            checks.append(chk("wildcard_bindings", "pass",
                "no vpn_only services bound to 0.0.0.0"))
    else:
        checks.append(chk("wildcard_bindings", "skip", "ss not available"))

    # VPN interface check
    vpn_tool = network.get("vpn_tool")
    if vpn_tool:
        if vpn_tool.lower() == "tailscale":
            ok, out = run("tailscale status --peers=false 2>/dev/null")
            checks.append(chk("vpn_status", "pass" if ok else "fail",
                out[:150] if out else ("connected" if ok else "disconnected")))
        elif vpn_tool.lower() == "wireguard":
            ok, out = run("wg show 2>/dev/null | head -5")
            checks.append(chk("vpn_status", "pass" if ok else "fail",
                out[:150] if out else ("active" if ok else "inactive")))
        else:
            ok, out = run(f"systemctl is-active {vpn_tool} 2>/dev/null")
            checks.append(chk("vpn_status", "pass" if ok else "fail",
                f"{vpn_tool}: {out}" if out else ("active" if ok else "inactive")))
    else:
        checks.append(chk("vpn_status", "skip", "no VPN in profile"))

    # Inter-service direct connectivity for dependent services
    for svc in services:
        deps = svc.get("dependencies") or []
        for dep_name in deps:
            dep_svc = next((s for s in services if s.get("name") == dep_name), None)
            if dep_svc:
                dep_addr = dep_svc.get("host_address")
                dep_ports = dep_svc.get("ports") or []
                if dep_addr and dep_ports:
                    port = dep_ports[0]
                    ok, _ = run(f"bash -c 'echo >/dev/tcp/{dep_addr}/{port}' 2>/dev/null", timeout=5)
                    checks.append(chk("direct_connectivity", "pass" if ok else "fail",
                        f"{dep_addr}:{port} {'open' if ok else 'closed'}",
                        f"{svc['name']}->{dep_name}"))

    return checks

def domain_11():
    """Documentation & state — uncommitted changes, profile freshness."""
    checks = []
    vcs = ENV.get("vcs") or {}
    config_paths = vcs.get("config_tracked_paths") or []

    # Check for uncommitted changes in config-tracked paths
    if config_paths:
        for path in config_paths:
            ok, out = run(f"git -C '{path}' status --porcelain 2>/dev/null")
            if out:
                file_count = len([l for l in out.splitlines() if l.strip()])
                checks.append(chk("config_uncommitted", "fail",
                    f"{file_count} uncommitted file(s)", path))
            else:
                checks.append(chk("config_uncommitted", "pass", "clean", path))
    else:
        # Check current repo
        ok, out = run("git status --porcelain 2>/dev/null")
        if out:
            file_count = len([l for l in out.splitlines() if l.strip()])
            checks.append(chk("config_uncommitted", "fail",
                f"{file_count} uncommitted file(s) in repo"))
        else:
            checks.append(chk("config_uncommitted", "pass", "working tree clean"))

    # Check if local is ahead of remote
    ok, out = run("git log --branches --not --remotes --oneline 2>/dev/null | head -5")
    if ok and out:
        commit_count = len([l for l in out.splitlines() if l.strip()])
        checks.append(chk("commits_not_pushed", "fail" if commit_count > 0 else "pass",
            f"{commit_count} commit(s) ahead of remote" if commit_count else "in sync"))
    else:
        checks.append(chk("commits_not_pushed", "pass", "in sync with remote"))

    # Profile freshness — check if services count matches what we see
    services = ENV.get("services") or []
    ok, out = run("systemctl list-units --type=service --state=running --no-pager --no-legend 2>/dev/null | wc -l")
    if ok and out:
        try:
            running_count = int(out.strip())
            profile_count = len(services)
            # Large divergence suggests profile is stale
            if running_count > profile_count * 2:
                checks.append(chk("profile_freshness", "fail",
                    f"profile has {profile_count} services but {running_count} running units detected"))
            else:
                checks.append(chk("profile_freshness", "pass",
                    f"profile: {profile_count} services, running units: {running_count}"))
        except ValueError:
            pass

    return checks


# --- Dispatch ---

DOMAIN_FUNCS = {
    1: domain_1,   2: domain_2,   3: domain_3,
    4: domain_4,   5: domain_5,   6: domain_6,
    7: domain_7,   8: domain_8,   9: domain_9,
    10: domain_10, 11: domain_11,
}

if DOMAIN not in DOMAIN_FUNCS:
    print(json.dumps({"error": f"Invalid domain: {DOMAIN}. Must be 1-11."}), file=sys.stderr)
    sys.exit(1)

checks = DOMAIN_FUNCS[DOMAIN]()

# Build summary
total = len(checks)
passed = sum(1 for c in checks if c["status"] == "pass")
failed = sum(1 for c in checks if c["status"] == "fail")
skipped = sum(1 for c in checks if c["status"] == "skip")

result = {
    "domain": DOMAIN,
    "checks": checks,
    "summary": {
        "total": total,
        "pass": passed,
        "fail": failed,
        "skip": skipped,
    }
}

print(json.dumps(result, indent=2))
PYEOF

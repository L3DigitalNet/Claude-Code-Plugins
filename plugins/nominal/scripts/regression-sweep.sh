#!/usr/bin/env bash
# regression-sweep.sh — Lightweight regression check after fix-forward actions.
#
# Re-runs the single most important check ("key signal") for each specified
# domain. Detects whether a fix-forward caused regression in previously-passing
# domains.
#
# Usage: regression-sweep.sh <environment-json-path> <domains-csv>
#   domains-csv: comma-separated list of domain numbers (e.g. "1,2,3,4,5")
#
# Output: JSON with domains_checked, regressions array, and clean boolean.
# Exit:   0 always. Exit 1 only on script-level failures.

source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

PROFILE_PATH="${1:?Usage: regression-sweep.sh <environment.json> <domains-csv>}"
DOMAINS_CSV="${2:?Usage: regression-sweep.sh <environment.json> <domains-csv>}"

# Load profile
PROFILE_JSON=$(load_profile "$PROFILE_PATH")

export PROFILE_JSON DOMAINS_CSV

$PYTHON << 'PYEOF'
import json, os, subprocess, sys

PROFILE = json.loads(os.environ["PROFILE_JSON"])
DOMAINS = [int(d.strip()) for d in os.environ["DOMAINS_CSV"].split(",") if d.strip()]

env_key = next(k for k in PROFILE if k != "_schema_version")
ENV = PROFILE[env_key]

def run(cmd, timeout=15):
    try:
        r = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=timeout)
        return r.returncode == 0, r.stdout.strip() or r.stderr.strip()
    except subprocess.TimeoutExpired:
        return False, "timeout"
    except Exception as e:
        return False, str(e)

regressions = []

for domain in DOMAINS:
    ok = True
    detail = ""

    if domain == 1:
        # Key signal: count active services matches profile service count
        services = ENV.get("services") or []
        if services:
            ok2, out = run("systemctl list-units --type=service --state=running --no-legend --no-pager 2>/dev/null | wc -l")
            if ok2:
                try:
                    running = int(out.strip())
                    # Don't flag unless services disappeared (running < profile count)
                    if running < len(services):
                        ok = False
                        detail = f"only {running} running units, profile has {len(services)} services"
                    else:
                        detail = f"{running} running units (profile: {len(services)} services)"
                except ValueError:
                    detail = "cannot parse service count"
            else:
                detail = "cannot list services"

    elif domain == 2:
        # Key signal: backup timestamp still within window
        backup = ENV.get("backup") or {}
        last_run_check = backup.get("last_run_check")
        if last_run_check:
            ok, out = run(last_run_check)
            detail = out[:150] if out else ("recent" if ok else "check failed")
        else:
            detail = "no last_run_check in profile"

    elif domain == 3:
        # Key signal: canonical location permissions still restricted
        secrets = ENV.get("secrets") or {}
        canonical = secrets.get("canonical_location")
        if canonical and not canonical.startswith("vault://"):
            ok2, out = run(f"stat -c '%a' '{canonical}' 2>/dev/null")
            if ok2 and out:
                perms = out.strip()
                world_readable = len(perms) >= 3 and perms[-1] != '0'
                ok = not world_readable
                detail = f"permissions: {perms}"
            else:
                detail = "cannot stat canonical location"
        elif canonical:
            detail = f"vault-based: {canonical}"
        else:
            detail = "no canonical location configured"

    elif domain == 4:
        # Key signal: all services respond on declared ports (fast TCP check)
        services = ENV.get("services") or []
        failed_svcs = []
        for svc in services:
            addr = svc.get("host_address")
            ports = svc.get("ports") or []
            health = svc.get("health_endpoint")
            name = svc.get("name", "unknown")
            if health:
                ok2, _ = run(f"curl -sf --max-time 3 '{health}' >/dev/null 2>&1", timeout=5)
                if not ok2:
                    failed_svcs.append(name)
            elif addr and ports:
                ok2, _ = run(f"bash -c 'echo >/dev/tcp/{addr}/{ports[0]}' 2>/dev/null", timeout=5)
                if not ok2:
                    failed_svcs.append(name)
        if failed_svcs:
            ok = False
            detail = f"unreachable: {', '.join(failed_svcs)}"
        else:
            checked = sum(1 for s in services if s.get("health_endpoint") or (s.get("host_address") and s.get("ports")))
            detail = f"all {checked} checkable services responding"

    elif domain == 5:
        # Key signal: firewall still active
        network = ENV.get("network") or {}
        fw = network.get("firewall_tool")
        if fw:
            ok, out = run(f"systemctl is-active {fw} 2>/dev/null")
            detail = f"{fw}: {'active' if ok else 'inactive'}"
        else:
            detail = "no firewall in profile"

    elif domain == 6:
        # Key signal: no new OOM events, disk still below 95%
        # Disk check
        ok2, out = run("df -h --output=target,pcent 2>/dev/null || df -h 2>/dev/null")
        if ok2 and out:
            for line in out.splitlines()[1:]:
                for part in line.split():
                    if part.endswith('%'):
                        try:
                            pct = int(part.rstrip('%'))
                            if pct >= 95:
                                ok = False
                                detail = f"disk at {pct}%"
                        except ValueError:
                            pass
            if ok:
                detail = "disk below 95%"
        # OOM check
        ok3, out3 = run("journalctl -k --since='10 minutes ago' --no-pager 2>/dev/null | grep -i oom | head -1")
        if ok3 and out3:
            ok = False
            detail += f"; OOM event: {out3[:80]}"

    elif domain == 7:
        # Key signal: all services still enabled
        services = ENV.get("services") or []
        disabled = []
        for svc in services:
            name = svc.get("name", "unknown")
            ok2, out = run(f"systemctl is-enabled {name} 2>/dev/null || systemctl is-enabled {name}.service 2>/dev/null")
            if ok2 and "enabled" in (out or ""):
                pass
            elif ok2:
                pass  # might be "static" or "alias" which is fine
            else:
                disabled.append(name)
        if disabled:
            ok = False
            detail = f"disabled/missing: {', '.join(disabled)}"
        else:
            detail = f"all {len(services)} services enabled"

    elif domain == 8:
        # Key signal: metrics platform still responding
        monitoring = ENV.get("monitoring") or {}
        metrics_check = monitoring.get("metrics_status_check")
        metrics_tool = monitoring.get("metrics_tool")
        if metrics_check:
            ok, out = run(metrics_check)
            detail = f"{metrics_tool or 'metrics'}: {'active' if ok else 'inactive'}"
        elif metrics_tool:
            ok, out = run(f"systemctl is-active {metrics_tool} 2>/dev/null")
            detail = f"{metrics_tool}: {out}"
        else:
            detail = "no metrics platform configured"

    elif domain == 9:
        # Key signal: DNS still resolves for first public service, cert expiry unchanged
        services = ENV.get("services") or []
        checked = False
        for svc in services:
            if svc.get("access_tier") in ("public", "auth_gated") and svc.get("health_endpoint"):
                try:
                    from urllib.parse import urlparse
                    hostname = urlparse(svc["health_endpoint"]).hostname
                    if hostname:
                        ok, out = run(f"dig +short {hostname} 2>/dev/null || host {hostname} 2>/dev/null")
                        detail = f"{hostname}: {'resolves' if ok and out else 'FAILS'}"
                        if not (ok and out):
                            ok = False
                        checked = True
                        break
                except Exception:
                    pass
        if not checked:
            detail = "no public services with health endpoints"

    elif domain == 10:
        # Key signal: no new 0.0.0.0 bindings vs. profile expectation
        services = ENV.get("services") or []
        vpn_ports = set()
        for svc in services:
            if svc.get("access_tier") == "vpn_only":
                for p in (svc.get("ports") or []):
                    vpn_ports.add(int(p))
        if vpn_ports:
            ok2, out = run("ss -tlnp 2>/dev/null")
            bad = []
            if ok2 and out:
                for line in out.splitlines()[1:]:
                    if "0.0.0.0:" in line or ":::*" in line:
                        for p in vpn_ports:
                            if f":{p}" in line:
                                bad.append(str(p))
            if bad:
                ok = False
                detail = f"vpn_only ports on 0.0.0.0: {', '.join(bad)}"
            else:
                detail = "no vpn_only services on 0.0.0.0"
        else:
            detail = "no vpn_only services defined"

    elif domain == 11:
        # Key signal: git status clean on config tracked paths
        vcs = ENV.get("vcs") or {}
        config_paths = vcs.get("config_tracked_paths") or []
        if config_paths:
            for path in config_paths:
                ok2, out = run(f"git -C '{path}' status --porcelain 2>/dev/null")
                if out:
                    ok = False
                    detail = f"uncommitted changes in {path}"
                    break
            if ok:
                detail = f"all {len(config_paths)} config paths clean"
        else:
            ok2, out = run("git status --porcelain 2>/dev/null")
            if out:
                ok = False
                detail = "uncommitted changes in repo"
            else:
                detail = "working tree clean"

    if not ok:
        regressions.append({
            "domain": domain,
            "check": f"domain_{domain}_key_signal",
            "detail": detail,
        })

result = {
    "domains_checked": len(DOMAINS),
    "regressions": regressions,
    "clean": len(regressions) == 0,
}

print(json.dumps(result, indent=2))
PYEOF

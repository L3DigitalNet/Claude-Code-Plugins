---
name: netdata
description: >
  Netdata real-time monitoring agent: installation, configuration, plugin
  management, health alarms, Netdata Cloud integration, and troubleshooting.
  Triggers on: netdata, Netdata, netdata monitoring, real-time metrics,
  netdata dashboard, netdata agent, netdata cloud, netdata plugins,
  netdata alarms, netdata health, 19999.
globs:
  - "**/netdata.conf"
  - "**/netdata/**/*.conf"
---

## Identity
- **Unit**: `netdata.service`
- **Config**: `/etc/netdata/netdata.conf`, override dir `/etc/netdata/`
- **Plugin dirs**: `/usr/libexec/netdata/plugins.d/` (internal), `/etc/netdata/python.d/` (Python collectors), `/etc/netdata/go.d/` (Go collectors)
- **Logs**: `journalctl -u netdata`, `/var/log/netdata/error.log`, `/var/log/netdata/access.log`, `/var/log/netdata/debug.log`
- **User**: `netdata` (runs as its own system user)
- **Web dashboard**: `http://localhost:19999`
- **Install (one-liner)**: `wget -O /tmp/netdata-kickstart.sh https://get.netdata.cloud/kickstart.sh && sh /tmp/netdata-kickstart.sh`
- **Distro install**: `apt install netdata` / `dnf install netdata` (older package versions — prefer kickstart for current release)

## Key Operations

| Operation | Command |
|-----------|---------|
| Status | `sudo systemctl status netdata` |
| Check dashboard | `curl -s http://localhost:19999/api/v1/info \| python3 -m json.tool` |
| Simple dashboard ping | `curl -sI http://localhost:19999` |
| Check claimed status (Cloud) | `sudo netdata-claim.sh -status` or `cat /var/lib/netdata/cloud.d/claimed_id` |
| Reload config (no restart) | `sudo kill -USR1 $(pidof netdata)` — reloads health alarms; full config requires restart |
| Restart | `sudo systemctl restart netdata` |
| netdata-cli | `sudo netdatacli help` — send commands to running agent (reload health, pause, resume) |
| Reload health alarms only | `sudo netdatacli reload-health` |
| Check installed plugins | `ls /usr/libexec/netdata/plugins.d/` |
| List detected charts | `curl -s http://localhost:19999/api/v1/charts \| python3 -c "import sys,json; d=json.load(sys.stdin); [print(k) for k in d['charts']]"` |
| View error log | `sudo tail -f /var/log/netdata/error.log` |
| Debug mode (foreground) | `sudo netdata -D` — runs in foreground, verbose output to terminal |
| Health alarm status | `curl -s http://localhost:19999/api/v1/alarms \| python3 -m json.tool` |
| Silence an alarm | `sudo netdatacli silence-all-alarms` or per-chart: `sudo netdatacli silence-alarm <alarm_id>` |

## Expected Ports
- 19999/tcp (HTTP dashboard and API)
- Verify: `ss -tlnp | grep netdata`
- Firewall (local dashboard only — do not expose publicly without auth): `sudo ufw allow from <your-ip> to any port 19999`
- Firewall (block public access): `sudo ufw deny 19999`

## Health Checks
1. `systemctl is-active netdata` → `active`
2. `curl -sf http://localhost:19999/api/v1/info > /dev/null && echo OK` → `OK`
3. `curl -s http://localhost:19999/api/v1/alarms | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('status', 'unknown'))"` → alarm summary with counts

## Common Failures

| Symptom | Likely cause | Check/Fix |
|---------|-------------|-----------|
| Port 19999 unreachable from outside | Firewall blocking or Netdata bound to `localhost` only | Check `bind to = 0.0.0.0` in `[web]` section; check `ufw status` |
| Plugin not auto-detecting a service | Plugin runs as `netdata` user without permissions to read stats | Check plugin logs in `/var/log/netdata/error.log`; add `netdata` user to the relevant group (e.g., `sudo usermod -aG docker netdata`) |
| Netdata Cloud agent connection failing | Wrong claim token, proxy blocking outbound, or clock skew | Verify token via `netdata-claim.sh -status`; check `/var/log/netdata/error.log` for TLS errors; confirm `chronyc tracking` shows <1s offset |
| Memory usage high | Too many enabled collectors or long retention history | Disable unused plugins in `[plugins]` section; reduce `history` in `[global]`; switch `memory mode = dbengine` and tune `page cache size` |
| Alarm triggering incorrectly | Default thresholds tuned for generic workloads | Override alarm in `/etc/netdata/health.d/<alarm>.conf`; use `to: silent` to suppress; tune `warn` and `crit` expressions |
| Python plugin fails silently | Missing Python dependency for that collector | Run manually: `sudo -u netdata /usr/libexec/netdata/plugins.d/python.d.plugin <module> debug trace`; install missing dep |
| `netdata-claim.sh` not found | Older package install missing Cloud tools | Re-run kickstart: `sh /tmp/netdata-kickstart.sh --claim-token <token> --claim-rooms <room>` |

## Pain Points
- **Zero-config is genuine but can over-collect**: Netdata auto-detects hundreds of metrics on start. On small servers, disable plugin categories you don't need (`[plugins]` section) — the CPU and memory savings are significant.
- **1-second granularity costs more RAM and disk than other tools**: The default `dbengine` mode writes to disk, but RAM pressure from the page cache still grows with metric count. Monitor with `ps aux | grep netdata` and tune `page cache size` in `[global]`.
- **Cloud sync is optional**: The agent works entirely standalone — local dashboard, alarms, and data retention all function without a Netdata Cloud account. Claiming to Cloud adds centralized visibility and alert routing but is not required.
- **Plugin detection depends on the target process running at Netdata startup**: If you start a service after Netdata, the auto-detected chart may not appear until Netdata restarts. Force detection without restart by running `sudo netdatacli reload-health` or restarting the specific plugin module.
- **Health check thresholds may need tuning for your workload**: Default alarms (CPU >75%, RAM >80%) will fire on workloads that are perfectly normal for your server. Review `/etc/netdata/health.d/` after install and adjust expressions before relying on alerting.

## References
See `references/` for:
- `netdata.conf.annotated` — full config with every directive explained
- `docs.md` — official documentation links

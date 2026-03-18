---
name: supervisor
description: >
  Supervisor process manager: supervisord daemon, supervisorctl commands,
  program configuration, process groups, event listeners, log management,
  and web UI administration.
  MUST consult when installing, configuring, or troubleshooting supervisor.
triggerPhrases:
  - "supervisor"
  - "supervisord"
  - "supervisorctl"
  - "supervisor process"
  - "supervisor program"
  - "supervisor conf"
  - "supervisor web ui"
  - "supervisor event listener"
  - "supervisor process manager"
globs:
  - "**/supervisord.conf"
  - "**/supervisor.conf"
  - "**/supervisor/conf.d/*.conf"
  - "**/supervisord.conf.d/*.conf"
last_verified: "2026-03"
---

## Identity
- **Unit**: `supervisor.service` (Debian/Ubuntu), `supervisord.service` (RHEL/pip install)
- **Daemon**: `supervisord`
- **CLI**: `supervisorctl`
- **Config**: `/etc/supervisor/supervisord.conf` (Debian/Ubuntu), `/etc/supervisord.conf` (RHEL/pip)
- **Program configs**: `/etc/supervisor/conf.d/*.conf` (Debian/Ubuntu)
- **Logs**: `/var/log/supervisor/supervisord.log` (daemon), program logs in configured paths
- **PID file**: `/var/run/supervisord.pid`
- **User**: `root` (daemon runs as root; individual programs can run as different users)
- **Distro install**: `apt install supervisor` / `dnf install supervisor` / `pip install supervisor`

## Quick Start

```bash
# Install
sudo apt install supervisor

# Enable and start
sudo systemctl enable --now supervisor

# Create a program config
cat <<'EOF' | sudo tee /etc/supervisor/conf.d/myapp.conf
[program:myapp]
command=/usr/bin/python3 /opt/myapp/app.py
directory=/opt/myapp
user=www-data
autostart=true
autorestart=true
stdout_logfile=/var/log/supervisor/myapp.log
stderr_logfile=/var/log/supervisor/myapp-error.log
EOF

# Reload and start the program
sudo supervisorctl reread
sudo supervisorctl update
sudo supervisorctl status
```

## Key Operations

| Task | Command |
|------|---------|
| Check all process status | `sudo supervisorctl status` |
| Start a program | `sudo supervisorctl start myapp` |
| Stop a program | `sudo supervisorctl stop myapp` |
| Restart a program | `sudo supervisorctl restart myapp` |
| Start all programs | `sudo supervisorctl start all` |
| Stop all programs | `sudo supervisorctl stop all` |
| Restart all programs | `sudo supervisorctl restart all` |
| Reload config (read new/changed) | `sudo supervisorctl reread` |
| Apply config changes | `sudo supervisorctl update` |
| Reload + apply in one step | `sudo supervisorctl reread && sudo supervisorctl update` |
| Tail stdout log | `sudo supervisorctl tail myapp` |
| Tail stderr log | `sudo supervisorctl tail myapp stderr` |
| Follow log (like tail -f) | `sudo supervisorctl tail -f myapp` |
| Show program config | `sudo supervisorctl avail` |
| Clear program logs | `sudo supervisorctl clear myapp` |
| Clear all logs | `sudo supervisorctl clear all` |
| Enter interactive shell | `sudo supervisorctl` |
| Restart supervisord itself | `sudo systemctl restart supervisor` |
| Check config syntax | `sudo supervisord -c /etc/supervisor/supervisord.conf -n` (runs in foreground for testing) |

## Expected Ports
- `9001/tcp` — Web UI / XML-RPC interface (disabled by default)
- Enable in `[inet_http_server]` section of supervisord.conf
- Verify: `ss -tlnp | grep 9001`
- Firewall: bind to `127.0.0.1:9001` only; do NOT expose publicly without authentication

## Health Checks

1. `systemctl is-active supervisor` — expect `active`
2. `sudo supervisorctl status` — all expected programs show `RUNNING`
3. `sudo supervisorctl pid` — returns supervisord PID
4. `curl -sf http://localhost:9001` — web UI responds (if enabled)

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| Program stuck in `STARTING` | Takes longer than `startsecs` to start | Increase `startsecs`; check program actually binds/initializes within the window |
| Program in `FATAL` | Exceeded `startretries` without staying up for `startsecs` | Check program logs (`supervisorctl tail myapp stderr`); fix the underlying crash |
| Program in `BACKOFF` | Crashing and being retried | Supervisor retries `startretries` times before going to FATAL; check stderr log for the error |
| `ERROR (no such process)` | Config not loaded after adding new `.conf` file | Run `supervisorctl reread && supervisorctl update` |
| `ERROR (already started)` | Trying to start an already-running program | Use `restart` instead of `start`; check `status` first |
| `unix:///var/run/supervisor.sock no such file` | supervisord not running | Start it: `sudo systemctl start supervisor` |
| `REFUSED` on XML-RPC | `[inet_http_server]` not configured or wrong credentials | Add section to config; check `username`/`password` if set |
| Programs not starting after reboot | supervisor service not enabled | `sudo systemctl enable supervisor` |
| Wrong user running program | `user=` directive not set or user doesn't exist | Add `user=www-data` (or appropriate user) to program section |
| Log file permission denied | Log directory doesn't exist or wrong ownership | Create dir and set permissions: `mkdir -p /var/log/supervisor && chown root:root /var/log/supervisor` |
| `spawn error` | Command path wrong, binary missing, or no execute permission | Verify command path exists and is executable; use absolute paths |

## Pain Points

- **`reread` vs `update`**: `reread` checks for new or changed config files but does not start/stop anything. `update` applies the changes from the last `reread` (starts new programs, restarts changed ones, removes deleted ones). You need both commands when changing config.

- **Distro packages lag behind PyPI**: Ubuntu and Debian ship older versions of Supervisor. The current release is 4.3.0 on PyPI, but distro repos may have 4.2.x. If you need the latest features, install via `pip install supervisor` into a virtualenv.

- **Not a replacement for systemd**: Supervisor predates systemd and fills a niche for managing application processes that are not packaged as system services. For system services, use systemd. Supervisor excels at managing multiple instances of an application, dev environments, and legacy daemons.

- **`autorestart=unexpected` vs `true`**: The default `autorestart=unexpected` only restarts a program if it exits with an exit code not listed in `exitcodes` (default: 0). Set `autorestart=true` to restart unconditionally, including on clean exit.

- **`startsecs` and `startretries` interaction**: Supervisor considers a program "started" only if it runs for `startsecs` seconds (default: 1) without exiting. If it exits sooner, that counts as a failed start. After `startretries` (default: 3) failed starts, the program enters `FATAL` state. For programs with slow initialization, increase `startsecs`.

- **Environment variables are tricky**: The `environment` directive uses `KEY="val",KEY2="val2"` syntax (not shell syntax). Values with commas or quotes need careful escaping. For complex environments, consider a wrapper script.

- **Log rotation is built in but limited**: Supervisor rotates logs via `stdout_logfile_maxbytes` and `stdout_logfile_backups`. For more control, set `stdout_logfile` to `/dev/stdout` and use an external log shipper, or use syslog via `stdout_events_enabled=true` with an event listener.

- **No dependency ordering between programs**: Supervisor starts programs in `priority` order (lower starts first) but does not wait for one to be "ready" before starting the next. If program B depends on program A, use a wrapper script that waits for A's readiness.

## See Also
- **systemd** — system and service manager; handles boot services, dependency ordering, and cgroups natively
- **docker** — containerized process isolation; each container is its own process tree
- **pm2** (node-runtime) — process manager optimized for Node.js with cluster mode and zero-downtime reload

## References
See `references/` for:
- `docs.md` — official documentation links (configuration, XML-RPC API, events)
- `common-patterns.md` — program configs, process groups, event listeners, web UI, Docker entrypoint patterns

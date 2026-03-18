---
name: logrotate
description: >
  logrotate log file rotation administration: config syntax, rotation frequency,
  compression, postrotate scripts, application signal handling, troubleshooting
  rotation failures, and state file inspection.
  MUST consult when installing, configuring, or troubleshooting logrotate.
triggerPhrases:
  - "logrotate"
  - "log rotation"
  - "log file rotation"
  - "logs growing"
  - "rotate logs"
  - "logrotate.conf"
  - "/etc/logrotate.d"
  - "copytruncate"
  - "postrotate"
  - "log cleanup"
  - "log archiving"
globs:
  - "**/logrotate.conf"
  - "**/logrotate.d/**"
last_verified: "unverified"
---

## Identity
- **Binary**: `/usr/sbin/logrotate`
- **Config**: `/etc/logrotate.conf`
- **Drop-in dir**: `/etc/logrotate.d/` (each file rotates one or more applications)
- **State file**: `/var/lib/logrotate/status` (tracks last rotation time per log path)
- **Scheduler**: run daily via `/etc/cron.daily/logrotate` or `logrotate.timer` (systemd)
- **Distro install**: `apt install logrotate` / `dnf install logrotate`

## Quick Start

```bash
sudo apt install logrotate
sudo systemctl enable --now logrotate.timer
logrotate -d /etc/logrotate.conf      # dry-run to validate config
logrotate -vf /etc/logrotate.d/myapp  # force-rotate a specific config
```

## Key Operations

| Task | Command |
|------|---------|
| Test config (dry-run, verbose) | `logrotate -d /etc/logrotate.conf` |
| Test a specific drop-in config | `logrotate -d /etc/logrotate.d/nginx` |
| Force rotation now (ignore schedule) | `logrotate -f /etc/logrotate.conf` |
| Force-rotate a single config | `logrotate -f /etc/logrotate.d/myapp` |
| Run with verbose output | `logrotate -v /etc/logrotate.conf` |
| Combine force + verbose | `logrotate -vf /etc/logrotate.conf` |
| Check state file (last rotation times) | `cat /var/lib/logrotate/status` |
| Show last rotation for one log | `grep myapp /var/lib/logrotate/status` |
| Validate config syntax only | `logrotate --debug /etc/logrotate.conf` |
| Run as a specific user | `sudo -u www-data logrotate -f /etc/logrotate.d/myapp` |
| Check systemd timer status | `systemctl status logrotate.timer` |

## Expected State
- State file updated daily; each line shows `"<path>" <ISO-date>`
- Daily cron or systemd timer runs without error output (silent on success)
- Rotated files named `app.log.1` (numbered) or `app.log-YYYYMMDD` (dateext)
- Compressed files have `.gz` suffix when `compress` is set

## Health Checks
1. `logrotate -d /etc/logrotate.conf 2>&1 | grep -i error` — no output means config is valid
2. `stat /var/lib/logrotate/status` — confirm file exists and mtime is recent (within 24–48h)
3. `grep -r 'error\|warning' /var/log/syslog | grep logrotate` — no recent failures in syslog

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| `error: error opening /var/log/app.log: Permission denied` | logrotate runs as root but postrotate script or create mode doesn't match log owner | Run `ls -la /var/log/app.log`; add `su <user> <group>` directive to config block |
| `postrotate script failed` | postrotate command exits non-zero (e.g., service not running, wrong path) | Run the postrotate command manually; check `$?`; add `sharedscripts` to avoid re-running on each matched file |
| `unknown option` or config parse error | Typo or unsupported directive in config file | Run `logrotate -d /etc/logrotate.d/<file>` and read the error line number |
| Rotation not happening despite age | Log path glob doesn't match actual file path | Run `logrotate -vd` and look for "no matches" or "skipping" messages; fix glob in config |
| `.gz` file is corrupted or missing | Compress fails because gzip not installed, or disk full | Check `which gzip`; check `df -h`; try running `logrotate -f` and observe stderr |
| Application keeps writing to old inode after rotation | Missing or broken postrotate reload signal | Add `postrotate ... endscript` with SIGHUP or restart; alternatively use `copytruncate` |
| Old rotated files not being deleted | `rotate` count too high, or `maxage` not set | Check `rotate N` value; add `maxage 30` to remove files older than 30 days |
| `stat of /var/lib/logrotate/status failed` | State file missing or wrong path | Create with `touch /var/lib/logrotate/status`; check if alternate state path is set with `-s` |

## Pain Points
- **Applications must reopen their log file descriptor after rotation.** Rotation renames the file; a running process keeps writing to the old inode (now `.log.1`). Fix: `postrotate` block sending SIGHUP (or equivalent) to reload the app, or use `copytruncate` as a fallback.
- **`copytruncate` risks losing log lines.** It copies the current log then truncates the original in two steps. Log lines written between copy and truncate are silently lost. Use SIGHUP-based rotation when the application supports it.
- **`delaycompress` is required when the application is still writing to `.log.1`.** Without it, logrotate compresses `.log.1` immediately while the app may still hold it open (especially relevant with `postrotate` that only restarts, not reloads).
- **Daily rotation runs via cron.daily, not at a precise time.** The actual run time depends on when cron.daily fires (commonly 06:25 on Debian systems). Logs are not rotated in real time; a 1 GB log can accumulate between runs.
- **`dateext` makes filenames substantially clearer than numbered suffixes.** Numbered rotation (`app.log.1`, `.2`) shifts all existing files on each run, making timestamp-based grep harder. `dateext` with `dateformat -%Y%m%d` avoids this and prevents name collisions.
- **`sharedscripts` is almost always wanted for glob patterns.** Without it, `postrotate` runs once per matched file, potentially sending SIGHUP dozens of times to the same process.

## See Also

- **journald** — systemd's structured logging subsystem; an alternative to file-based logs
- **systemd** — logrotate is often triggered by systemd timers instead of cron

## References
See `references/` for:
- `logrotate.conf.annotated` — full config with every directive explained, nginx and custom app examples
- `docs.md` — man pages, upstream documentation, and community resources

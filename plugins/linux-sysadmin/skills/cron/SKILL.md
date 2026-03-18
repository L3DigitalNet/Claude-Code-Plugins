---
name: cron
description: >
  cron daemon and crontab administration: scheduling jobs, cron expression
  syntax, user and system crontabs, drop-in directories, logging, and
  troubleshooting.
  MUST consult when installing, configuring, or troubleshooting cron.
triggerPhrases:
  - "cron"
  - "crontab"
  - "cron job"
  - "cron schedule"
  - "cron expression"
  - "scheduled task"
  - "crontab -e"
  - "at command"
  - "systemd timer alternative"
globs:
  - "**/crontab"
  - "**/cron.d/**"
  - "**/cron.daily/**"
  - "**/cron.hourly/**"
  - "**/cron.weekly/**"
  - "**/cron.monthly/**"
last_verified: "unverified"
---

## Identity

- **Daemon**: `cron` (Debian/Ubuntu) or `crond` (RHEL/Fedora/Arch)
- **Unit**: `cron.service` (Debian/Ubuntu) or `crond.service` (RHEL/Fedora)
- **User crontabs**: `crontab -e` — stored in `/var/spool/cron/crontabs/<user>`
- **System crontab**: `/etc/crontab` — includes a username field; read by cron directly
- **Drop-in dir**: `/etc/cron.d/` — same syntax as `/etc/crontab` (username field required)
- **Run-parts dirs**: `/etc/cron.hourly/`, `/etc/cron.daily/`, `/etc/cron.weekly/`, `/etc/cron.monthly/`
- **Logs**: `journalctl -u cron` or `journalctl -u crond`; also `/var/log/syslog` (Debian) or `/var/log/cron` (RHEL)
- **Distro install**: `apt install cron` / `dnf install cronie`

## Quick Start

```bash
sudo apt install cron
sudo systemctl enable --now cron
systemctl status cron
crontab -e                            # edit your user crontab
crontab -l                            # list your scheduled jobs
```

## Key Operations

| Task | Command |
|------|---------|
| List current user's crontab | `crontab -l` |
| Edit current user's crontab | `crontab -e` |
| Edit another user's crontab (root) | `crontab -u username -e` |
| List another user's crontab (root) | `crontab -u username -l` |
| Remove current user's crontab | `crontab -r` |
| Remove another user's crontab (root) | `crontab -u username -r` |
| List all user crontabs (root) | `ls /var/spool/cron/crontabs/` |
| View a user's raw crontab file (root) | `cat /var/spool/cron/crontabs/username` |
| View system crontab | `cat /etc/crontab` |
| View drop-in jobs | `ls /etc/cron.d/` |
| List run-parts scripts (daily) | `ls /etc/cron.daily/` |
| Check cron log (systemd) | `journalctl -u cron --since today` |
| Check cron log (RHEL syslog) | `grep CRON /var/log/cron` |
| Test a cron expression | Use `crontab.guru` (see references) |
| Run a run-parts dir manually | `run-parts /etc/cron.daily` |
| Force immediate run of one script | `bash /etc/cron.daily/myscript` |
| Check next scheduled execution | `systemctl list-timers` (if migrated to systemd) |

## Expected State
- `cron.service` (or `crond.service`) is active and enabled
- Each scheduled run produces a syslog entry: `CRON[pid]: (user) CMD (command)`
- Output not redirected to a file goes to the local mail spool (`/var/mail/user`) unless `MAILTO=""` is set

## Health Checks
1. `systemctl is-active cron || systemctl is-active crond` → `active`
2. `journalctl -u cron -n 20 --no-pager` → recent job entries visible, no permission errors
3. `crontab -l` → lists expected jobs without error

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| Job never runs | PATH not set; command not found | Use absolute paths; add `PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin` at crontab top |
| Job runs but produces wrong output | Wrong timezone | Set `TZ=America/New_York` (or correct zone) at crontab top |
| No visible output, nothing in logs | Output goes to mail; mail not configured | Redirect: `>> /var/log/myjob.log 2>&1` and set `MAILTO=""` |
| Script works manually, fails in cron | Minimal environment; missing env vars | Source profile or set all required vars in the crontab header |
| Wrong shell behaviour (`[[ ]]`, etc.) | Default shell is `/bin/sh`, not bash | Set `SHELL=/bin/bash` at crontab top |
| `/etc/cron.d/` job never runs | Missing username field | cron.d syntax requires a username: `* * * * * root /path/to/cmd` |
| Job runs but fails silently | Script not executable or wrong permissions | `chmod +x /path/to/script`; check script's shebang line |
| `crontab: installing new crontab` then nothing | File not saved (editor exited with error) | Re-run `crontab -e`; confirm the file is non-empty with `crontab -l` |

## Pain Points
- **PATH is minimal** — cron inherits almost no environment. Always use full paths to binaries (`/usr/bin/python3`, not `python3`). Alternatively, set `PATH=` at the top of the crontab.
- **No environment by default** — variables like `HOME`, `USER`, `LANG`, `DISPLAY` are not set. Scripts that depend on them must set their own or source a profile.
- **Output goes to mail** — all stdout/stderr is mailed to the crontab owner. On most servers mail is unconfigured, so output is silently lost. Always redirect to a log file.
- **Weekday 0 and 7 are both Sunday** — the DOW field accepts 0–7 where both 0 and 7 represent Sunday. `*/2` in the DOW field steps through 0,2,4,6, which skips Sunday (0) but hits Saturday (6) and Sunday-alias (0 mod 2).
- **`/etc/cron.d/` requires the username field** — unlike user crontabs, files in `/etc/cron.d/` use the same format as `/etc/crontab` and must include the running user between the schedule and the command. Omitting it causes the field to be silently misinterpreted.
- **`run-parts` strips dots from filenames** — scripts in `/etc/cron.daily/` etc. whose names contain dots (e.g., `backup.sh`) are silently skipped by `run-parts` on Debian-based systems. Use names without dots or extensions.
- **`crontab -r` has no confirmation** — it removes the entire crontab immediately. If you meant `crontab -e`, the job is gone. There is no undo; keep backups with `crontab -l > ~/crontab.bak`.

## See Also

- **systemd** — Systemd timers are the modern replacement for cron jobs
- **logrotate** — Log rotation often scheduled via cron or systemd timers

## References
See `references/` for:
- `crontab.annotated` — fully annotated example crontab with all syntax options
- `docs.md` — man pages, expression calculator, and systemd timer comparison

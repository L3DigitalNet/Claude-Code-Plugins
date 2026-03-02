---
name: journald
description: >
  systemd journal (journald) administration: log querying, filtering, storage
  configuration, disk usage management, log forwarding, and troubleshooting.
  Triggers on: journald, journalctl, systemd journal, system logs,
  journalctl -f, log query, log filter, persistent journal, journal storage,
  journal vacuum, journal disk usage, systemd-cat, journald.conf.
globs:
  - "**/journald.conf"
  - "**/journald.conf.d/**"
  - "**/systemd/journald.conf"
---

## Identity
- **Service**: `systemd-journald`
- **Unit**: `systemd-journald.service`
- **Config**: `/etc/systemd/journald.conf`, `/etc/systemd/journald.conf.d/*.conf`
- **Persistent storage**: `/var/log/journal/` (survives reboot; exists only if created or `Storage=persistent`)
- **Volatile storage**: `/run/log/journal/` (lost on reboot; always present while service runs)
- **Format**: binary (.journal files) — not directly grep-able
- **Namespace support**: `/run/log/journal/<machine-id>/` per-namespace subdirectories

## Key Operations

| Goal | Command |
|------|---------|
| Follow live logs | `journalctl -f` |
| All logs since current boot | `journalctl -b` |
| All logs from previous boot | `journalctl -b -1` |
| List available boots | `journalctl --list-boots` |
| Logs for a unit | `journalctl -u nginx.service` |
| Follow unit logs live | `journalctl -fu nginx.service` |
| Filter by priority | `journalctl -p err` (emerg alert crit err warning notice info debug) |
| Errors and above | `journalctl -p err..emerg` |
| Since a time | `journalctl --since "1 hour ago"` |
| Time range | `journalctl --since "2025-03-01 10:00" --until "2025-03-01 11:00"` |
| By PID | `journalctl _PID=1234` |
| By UID | `journalctl _UID=1000` |
| By systemd slice/cgroup | `journalctl _SYSTEMD_UNIT=user@1000.service` |
| Kernel messages only | `journalctl -k` |
| Kernel messages this boot | `journalctl -kb` |
| JSON output (one entry per line) | `journalctl -o json` |
| JSON pretty-printed | `journalctl -o json-pretty` |
| ISO timestamps | `journalctl -o short-iso` |
| Show catalog explanations | `journalctl -x` or `journalctl -xe` |
| Disk usage summary | `journalctl --disk-usage` |
| Vacuum by size | `journalctl --vacuum-size=500M` |
| Vacuum by time | `journalctl --vacuum-time=30d` |
| Vacuum by file count | `journalctl --vacuum-files=10` |
| Verify log integrity | `journalctl --verify` |
| Export to binary stream | `journalctl -o export > journal.bin` |
| Import binary stream | `systemd-journal-remote` or `journalctl --import journal.bin` |
| Show catalog entry for error | `journalctl -x -u <unit>` |
| Send a test log message | `systemd-cat echo "test message"` |
| Send with priority | `echo "test" \| systemd-cat -p warning` |
| Pipe command output to journal | `my-script 2>&1 \| systemd-cat -t my-script` |

## Expected State
- `systemctl is-active systemd-journald` returns `active`
- At least one of `/var/log/journal/` or `/run/log/journal/` exists and is readable
- `journalctl -b 0 -n 1` returns at least one entry (current boot)
- Disk usage within configured bounds: `journalctl --disk-usage`

## Health Checks
1. `systemctl is-active systemd-journald` → `active`
2. `journalctl -b -n 5 --no-pager` → recent log entries visible, no errors
3. `journalctl --disk-usage` → total size within `SystemMaxUse` limit

## Common Failures

| Symptom | Likely cause | Check/Fix |
|---------|-------------|-----------|
| Logs lost after reboot | Volatile storage only; `/var/log/journal/` absent | `mkdir -p /var/log/journal && systemd-tmpfiles --create --prefix /var/log/journal && systemctl restart systemd-journald` |
| `No journal files were found` | Storage dir missing or wrong permissions | Check `/run/log/journal/` and `/var/log/journal/` exist; `chown root:systemd-journal` on the dir |
| Journal growing without bound | `SystemMaxUse` not set; disk filling up | Set `SystemMaxUse=` in journald.conf; run `journalctl --vacuum-size=500M` to reclaim immediately |
| Timestamps wrong or in UTC | Timezone mismatch | `journalctl --utc` to display in UTC explicitly; system timezone: `timedatectl` |
| Remote journal not receiving logs | `ForwardToSyslog` or `systemd-journal-remote` misconfigured | Check receiver: `systemctl status systemd-journal-remote.service`; check `JOURNAL_REMOTE_URL` env |
| `Failed to determine timestamp` on import | Journal file corrupt or truncated | `journalctl --verify` to check integrity; recover from backup |
| Rate-limited: logs missing | `RateLimitBurst` exceeded by a noisy service | Increase `RateLimitBurst` or set `RateLimitIntervalSec=0` to disable (risk: disk exhaustion) |
| `Permission denied` reading journal | User not in `systemd-journal` group | `usermod -aG systemd-journal <username>` then re-login |
| Sealed journal fails `--verify` | FSSEAL keys missing or rotated | `journalctl --verify` reports which files are affected; reseal or accept the gap |

## Pain Points
- **Logs are volatile by default**: unless `/var/log/journal/` exists (or `Storage=persistent`), the journal lives in `/run/log/journal/` and is lost at every reboot. This is the most common support scenario.
- **Disk usage must be bounded explicitly**: by default the journal will use up to 10% of the filesystem. On a small root partition this can fill it. Set `SystemMaxUse` and `RuntimeMaxUse` in journald.conf.
- **Binary format means no grep**: you cannot `grep -r /var/log/journal/`. Use `journalctl -g <pattern>` (grep) or `-o json | jq` for structured filtering instead.
- **Rate limiting can silently suppress logs**: a service emitting bursts of messages will be rate-limited by default (`RateLimitBurst=10000` per `RateLimitIntervalSec=30s`). Messages are dropped with a single `systemd-journald[PID]: <service> suppressed N messages` entry.
- **Forwarding to syslog is opt-in**: `rsyslog` and `syslog-ng` do not automatically receive journal messages. Set `ForwardToSyslog=yes` in journald.conf, or configure rsyslog with `imjournal` to read the journal directly.
- **`-b -1` requires persistent storage**: `journalctl -b -1` (previous boot) only works if `/var/log/journal/` is present. With volatile storage, only the current boot is available.
- **Catalog entries are ID-based**: `journalctl -x` annotates entries that have a catalog entry (a `MESSAGE_ID` field). Not all entries have one — the annotation appears only when a matching catalog record exists.

## References
See `references/` for:
- `journald.conf.annotated` — full configuration file with every directive explained
- `docs.md` — official documentation links

---
name: auditd
description: >
  Linux Audit Framework (auditd) — audit rule management, file access monitoring,
  syscall auditing, user activity tracking, ausearch/aureport log analysis,
  compliance reporting, and troubleshooting.
  MUST consult when installing, configuring, or troubleshooting auditd.
triggerPhrases:
  - "auditd"
  - "audit"
  - "ausearch"
  - "aureport"
  - "auditctl"
  - "audit rules"
  - "audit log"
  - "file monitoring"
  - "syscall audit"
  - "compliance audit"
  - "security audit"
  - "audit.log"
  - "audit.rules"
globs:
  - "**/audit/auditd.conf"
  - "**/audit/audit.rules"
  - "**/audit/rules.d/*.rules"
last_verified: "2026-03"
---

## Identity
- **Unit**: `auditd.service` (manage with `service auditd` on RHEL; `systemctl` only for `enable`/`status`)
- **Config**: `/etc/audit/auditd.conf`
- **Rules**: `/etc/audit/audit.rules` (generated), `/etc/audit/rules.d/*.rules` (drop-in source files merged by `augenrules`)
- **Logs**: `/var/log/audit/audit.log`
- **Plugins**: `/etc/audit/plugins.d/` (audisp plugin configs)
- **Sample rules**: `/usr/share/audit/sample-rules/` (RHEL 8+) or `/usr/share/doc/auditd/examples/` (Debian)
- **Install**: `apt install auditd audispd-plugins` (Debian/Ubuntu) / `dnf install audit` (RHEL/Fedora; pre-installed on RHEL 7+)

## Quick Start

```bash
# Install (Debian/Ubuntu — already installed on RHEL by default)
sudo apt install auditd audispd-plugins

# Enable and start
sudo systemctl enable auditd
sudo service auditd start

# Add a file watch rule: monitor /etc/passwd for writes and attribute changes
sudo auditctl -w /etc/passwd -p wa -k identity

# Trigger the rule (any write/attribute change to /etc/passwd)
sudo useradd testaudit && sudo userdel testaudit

# Search audit log for events tagged with the "identity" key
sudo ausearch -k identity -i
```

## Key Operations

| Task | Command |
|------|---------|
| Audit subsystem status | `sudo auditctl -s` |
| List active rules | `sudo auditctl -l` |
| Add file watch rule | `sudo auditctl -w /path -p rwxa -k keyname` |
| Add syscall rule | `sudo auditctl -a always,exit -F arch=b64 -S openat -F auid>=1000 -F auid!=-1 -k file_open` |
| Delete all rules | `sudo auditctl -D` |
| Remove specific watch | `sudo auditctl -W /path -p wa -k keyname` |
| Search logs by key | `sudo ausearch -k keyname -i` |
| Search logs by time | `sudo ausearch -ts today -i` |
| Search by user (login UID) | `sudo ausearch -ul username -i` |
| Search by file | `sudo ausearch -f /etc/shadow -i` |
| Summary report | `sudo aureport --summary` |
| Failed authentication report | `sudo aureport --auth --failed` |
| File access report | `sudo aureport -f --summary` |
| Login report | `sudo aureport -l --failed` |
| Syscall report | `sudo aureport -s --summary` |
| Load rules from rules.d | `sudo augenrules --load` |
| Rotate log now | `sudo kill -USR1 $(pidof auditd)` |

## Expected Ports

None. auditd operates at the kernel level via the netlink audit socket. No network ports are opened unless `tcp_listen_port` is explicitly configured in `auditd.conf` for receiving remote audit events.

## Health Checks

1. **Subsystem status**: `sudo auditctl -s` -- verify `enabled 1` (or `enabled 2` if immutable), check `backlog` vs `backlog_limit` (backlog should be well below the limit)
2. **Service running**: `systemctl is-active auditd`
3. **Rules loaded**: `sudo auditctl -l` -- should show your expected rules; empty output means no rules are active
4. **Log file writable and rotating**: `ls -la /var/log/audit/audit.log` -- check size is not approaching `max_log_file` without rotation configured
5. **No lost events**: `sudo auditctl -s | grep lost` -- `lost 0` is healthy; non-zero means the backlog overflowed and events were dropped

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| `backlog limit exceeded` in dmesg | Kernel audit backlog too small for event volume | Increase backlog: `auditctl -b 8192` (or higher); persist in `/etc/audit/rules.d/10-base-config.rules` |
| Rules not loading after reboot | Rules in `/etc/audit/rules.d/` but `augenrules` not used, or syntax error in a rule file | Run `sudo augenrules --check` then `sudo augenrules --load`; check `/var/log/audit/audit.log` for LOAD_POLICY errors |
| `ausearch` returns nothing | Wrong key, wrong time range, or audit not enabled when events occurred | Verify key with `auditctl -l`; broaden time range with `-ts boot`; confirm `auditctl -s` shows `enabled 1` |
| `audit.log` growing unbounded | No `max_log_file_action` configured, or set to `ignore` | Set `max_log_file = 50` and `max_log_file_action = rotate` with `num_logs = 10` in `auditd.conf`; restart auditd |
| `Error sending enable request (EPERM)` | Immutable flag (`-e 2`) is active; rules cannot be changed until reboot | Reboot the system. Remove or comment out `-e 2` from rules.d files while testing, add it back when rules are finalized |
| `auditctl: audit support not in kernel` | Kernel compiled without `CONFIG_AUDIT` or audit disabled at boot | Add `audit=1` to kernel boot parameters in GRUB config |
| Rules load but no events generated | Rule uses wrong architecture (`b32` vs `b64`) or filter fields don't match | Always specify `-F arch=b64` (and `-F arch=b32` separately for 32-bit compat); test with `auditctl -l` and trigger manually |

## Pain Points

- **Immutable mode (`-e 2`)**: Once set, no rules can be added, deleted, or modified until the system is rebooted. Always place `-e 2` as the absolute last line in your rules (in `99-finalize.rules`). Test all rules thoroughly before enabling immutable mode.

- **Log volume**: A broad syscall rule (e.g., monitoring all `execve` calls system-wide) generates massive log volume. Scope rules tightly with `-F auid>=1000` (real users only) and `-F auid!=-1` (ignore unset login UIDs) to exclude system services. Use `aureport --summary` to identify noisy rules.

- **ausearch syntax**: Time filters use `-ts` (start) and `-te` (end) with natural-language shortcuts (`today`, `yesterday`, `this-week`, `boot`). Multiple filters are ANDed together. The `-i` flag interprets numeric UIDs/GIDs/syscalls into human-readable names; always use it for interactive searches.

- **Kernel backlog tuning**: The default kernel backlog limit is 64, which is far too low for any production system. Set `-b 8192` (or higher) in your base config rules. The `--backlog_wait_time` parameter controls how long the kernel waits when the backlog is full before dropping events (default: 60*HZ).

- **SELinux/AppArmor interaction**: When SELinux is enforcing, AVC denials generate audit events. This is expected and useful. CrowdSec and other tools may also consume audit events. If audit event throughput is a concern, use the `exclude` filter list to drop unwanted event types: `-a always,exclude -F msgtype=AVC`.

- **`service` vs `systemctl`**: On RHEL/CentOS, use `service auditd stop/start/restart/reload` instead of `systemctl`. The `service` command ensures the `auid` (login UID) is properly recorded in the audit trail. `systemctl` can be used for `enable` and `status` only.

- **augenrules vs auditctl -R**: `augenrules` merges all files in `/etc/audit/rules.d/` in lexical order into `/etc/audit/audit.rules`, then loads them. The numbering convention matters: 10-19 for base config, 20-29 for overrides/excludes, 30-39 for main policy (STIG, PCI-DSS, OSPP), 40-49 for optional/local rules, 70-79 for edge cases, 99 for finalize (immutable flag).

- **32-bit vs 64-bit syscalls**: On x86_64 systems, syscall numbers differ between 32-bit and 64-bit. Always create paired rules with `-F arch=b64` and `-F arch=b32` for each syscall you monitor. Omitting the arch filter may cause silent misses.

## See Also

- **journald** -- systemd journal; auditd events also appear in the journal when `log_group = root` is configured
- **fail2ban** -- intrusion prevention that can react to patterns in audit logs
- **crowdsec** -- collaborative IPS with audit log ingestion support
- **systemd** -- service management; auditd integrates with systemd for startup ordering

## References
See `references/` for:
- `docs.md` -- verified official links (Red Hat audit docs, man pages, upstream repo, STIG references)
- `audit.rules.annotated` -- annotated rules file with examples for file watches, syscall monitoring, user tracking
- `common-patterns.md` -- watch /etc/passwd changes, monitor sudo usage, track file deletions, PCI-DSS compliance rules, CIS benchmark rules, custom key-based filtering with ausearch

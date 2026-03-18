---
name: dmesg
description: >
  dmesg reads the kernel ring buffer and prints kernel messages including hardware
  errors, driver events, OOM kills, and boot messages. It is the first place to
  check for hardware faults, kernel panics, and device-level problems.
  MUST consult when reading kernel messages for hardware or driver issues.
triggerPhrases:
  - "dmesg"
  - "kernel messages"
  - "hardware error"
  - "kernel log"
  - "OOM killer"
  - "drive error"
  - "USB device"
  - "driver error"
  - "boot messages"
  - "kernel ring buffer"
  - "out of memory"
  - "NIC error"
  - "disk error"
  - "segfault in kernel"
globs: []
last_verified: "unverified"
---

## Identity

| Property | Value |
|----------|-------|
| **Binary** | `dmesg` |
| **Config** | No persistent config — invoked directly |
| **Logs** | Kernel ring buffer (volatile, lost on reboot); persistent history in `/var/log/kern.log` or via `journalctl -k` |
| **Type** | CLI tool (part of util-linux) |
| **Install** | `apt install util-linux` / `dnf install util-linux` (installed by default on all distributions) |

## Quick Start

```bash
# dmesg is pre-installed on all Linux systems (part of util-linux)
sudo dmesg -T                          # show kernel messages with human-readable timestamps
sudo dmesg --level err,warn            # filter to errors and warnings only
sudo dmesg -TLW --level err,warn       # follow new errors/warnings with color and timestamps
```

## Key Operations

| Task | Command |
|------|---------|
| Show all kernel messages | `dmesg` |
| Human-readable timestamps (wall clock) | `dmesg -T` |
| Follow new messages as they arrive | `dmesg -W` |
| Filter to errors and warnings only | `dmesg --level err,warn` |
| Filter to kernel facility only | `dmesg --facility kern` |
| Color output by severity | `dmesg -L` |
| Show last 50 lines | `dmesg \| tail -50` |
| Search for a pattern | `dmesg \| grep -i 'oom\|killed'` |
| Show messages since a relative time | `dmesg --since "1 hour ago"` |
| Show messages since an absolute time | `dmesg --since "2024-01-15 10:00:00"` |
| JSON output (machine-parseable) | `dmesg -J` |
| Clear the ring buffer | `dmesg -C` |
| Human timestamps + follow + color + errors | `dmesg -TLW --level err,warn` |

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| `dmesg: read kernel buffer failed: Operation not permitted` | `kernel.dmesg_restrict` is set to 1 | Run with `sudo`, or `sysctl kernel.dmesg_restrict=0` temporarily |
| Timestamps show seconds since boot (e.g. `[12345.678]`) | `-T` not used; default format is relative to boot | Use `dmesg -T` to convert to wall-clock times |
| Early boot messages are gone | Ring buffer overwritten by later messages on verbose or busy systems | Check `/var/log/kern.log` or `journalctl -k -b` for persistent logs |
| `dmesg -W` not available | util-linux version below 2.21 | Upgrade util-linux or use `watch -n 1 dmesg \| tail -20` as a fallback |
| `dmesg --since` not recognized | util-linux version below 2.33 | Upgrade, or pipe through `grep` with a timestamp pattern |
| OOM message shows a PID that is already gone | The killed process exited; the PID may have been reused | Correlate with system logs for the process name shown in the OOM line |
| `dmesg -J` fails | util-linux below 2.36 | Upgrade, or parse plain text output |

## Pain Points

- **Ring buffer is finite and volatile**: the kernel ring buffer holds a fixed amount of data (typically 512 KB to 16 MB depending on kernel config). On verbose or high-traffic systems, old messages are overwritten continuously. For persistent history across reboots and across time, use `journalctl -k` (systemd journals persist to disk) or `/var/log/kern.log`.
- **Default timestamps are meaningless without context**: `[12345.678]` means "12345 seconds after boot". This is useless without knowing when the system booted (`uptime`, `who -b`). Always use `dmesg -T` for human-readable wall-clock timestamps. Some older distros default to relative; make `-T` a habit.
- **OOM kill messages name the victim, not the cause**: when the OOM killer fires, it logs the killed PID and process name. The killed process is often not the one that caused the memory pressure — it is the one that was deemed most expendable by the kernel's scoring algorithm. Look at the full OOM log block for the memory map and zone info to identify the actual memory consumer.
- **`dmesg -W` requires util-linux 2.21+**: the `--follow` / `-W` flag was added in util-linux 2.21. On older systems (CentOS 7, Ubuntu 16.04), use `watch dmesg | tail -20` as a substitute.
- **`kernel.dmesg_restrict` limits access**: hardened distros (Ubuntu 20.04+, RHEL 8+) set `kernel.dmesg_restrict=1` by default, blocking dmesg output for non-root users. This is a security feature. For debugging, either use `sudo`, temporarily set it to 0, or add the user to the `adm` group (Ubuntu grants dmesg access to `adm` members).
- **Facility filtering narrows signal-to-noise**: the kernel sends messages from many facilities (kern, daemon, user, auth). For hardware diagnostics, `--facility kern` isolates kernel-originated messages. For USB events, `grep -i usb`; for drive errors, `grep -i 'sd\|nvme\|ata'`.

## See Also

- **journald** — Persistent structured logging that captures kernel messages across reboots via `journalctl -k`
- **smartctl** — Disk health diagnostics for investigating drive errors surfaced by dmesg
- **strace** — Process-level syscall tracing for debugging issues identified in kernel messages

## References

See `references/` for:
- `cheatsheet.md` — 10 task-organized patterns for common dmesg workflows
- `docs.md` — man pages and upstream documentation links

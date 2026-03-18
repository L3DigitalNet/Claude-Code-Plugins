---
name: iotop
description: >
  iotop monitors disk I/O usage per process in real time, similar to top for CPU.
  It shows which processes are reading and writing to disk and at what rates.
  MUST consult when identifying which processes are causing disk I/O.
triggerPhrases:
  - "iotop"
  - "disk I/O by process"
  - "io usage"
  - "what process is writing"
  - "high disk activity"
  - "process disk usage"
  - "who is writing to disk"
  - "disk write by pid"
globs: []
last_verified: "unverified"
---

## Identity

| Property | Value |
|----------|-------|
| **Binary** | `iotop` (Python, upstream abandoned) or `iotop-c` (C rewrite, actively maintained) |
| **Config** | No persistent config — invoked directly |
| **Logs** | No persistent logs — output to terminal |
| **Type** | CLI tool |
| **Install** | `apt install iotop` / `dnf install iotop` (Python version); `apt install iotop-c` / `dnf install iotop-c` (C version) |

## Quick Start

```bash
sudo apt install iotop-c              # install the maintained C rewrite
sudo iotop -o                          # show only processes with active I/O
sudo iotop -b -o -n 5                  # batch mode, 5 samples of active I/O
sudo iotop -a                          # show accumulated I/O totals
```

## Key Operations

| Task | Command |
|------|---------|
| Interactive mode (requires root) | `sudo iotop` |
| Show only processes with active I/O | `sudo iotop -o` |
| Non-interactive batch output | `sudo iotop -b` |
| Batch mode, only active, 5 iterations | `sudo iotop -b -o -n 5` |
| Accumulated I/O totals instead of rates | `sudo iotop -a` |
| Set refresh interval to 2 seconds | `sudo iotop -d 2` |
| Filter output to a specific PID | `sudo iotop -p 1234` |
| Filter output to a specific user | `sudo iotop -u www-data` |
| Show process arguments (full cmdline) | `sudo iotop -P` |
| Batch output to a file | `sudo iotop -b -o -n 10 > /tmp/io-snapshot.txt` |
| Capture 60 seconds of I/O at 2s intervals | `sudo iotop -b -o -d 2 -n 30` |
| Sort by read rate in interactive mode | press `r` while running |
| Quit interactive mode | press `q` |

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| `Permission denied` or no output | Not running as root | Prefix with `sudo`; or grant `CAP_SYS_ADMIN` to the binary |
| `iotop: command not found` | Package not installed | `apt install iotop-c` (preferred on modern distros) |
| `iotop` installed but exits immediately | Python version deprecated; kernel too new | Install `iotop-c` instead — it is the maintained fork |
| Kernel: `CONFIG_TASK_IO_ACCOUNTING not set` | Kernel compiled without per-task I/O accounting | Recompile kernel or use a distribution kernel; most modern distros enable this |
| FUSE filesystem I/O attributed to fuse process | FUSE kernel interface — all I/O passes through the fuse kernel helper | Identify the actual user-space FUSE process by PID from `-p` output |
| Loop devices or tmpfs showing high I/O | Backing files or memory-mapped operations; rarely the root cause | Check what is mounted on the loop device: `losetup -l`; tmpfs writes are expected |

## Pain Points

- **Requires root or CAP_SYS_ADMIN**: iotop reads per-task I/O accounting from the kernel's taskstats interface, which requires elevated privilege. Running without root produces no output or an immediate permission error.
- **Python version is abandoned upstream**: the original `iotop` is written in Python and has not been maintained since ~2016. On newer kernels it may crash or behave incorrectly. Prefer `iotop-c`, a C rewrite with the same interface and active maintenance.
- **Disk I/O only — not network**: iotop shows block device reads and writes. Network I/O, pipe I/O, and socket traffic do not appear. Use `nethogs` or `ss` for network per-process stats.
- **FUSE filesystem attribution**: I/O to FUSE-mounted filesystems (sshfs, rclone, etc.) appears under the FUSE kernel thread, not the user process initiating the access. The actual data mover is identified by correlating PID with the FUSE mount.
- **Batch mode is required for scripting**: interactive mode uses terminal control codes unsuitable for logging or pipelines. Always use `-b` when capturing output to a file or piping to another tool.

## See Also

- **iostat** — Per-device disk throughput and latency metrics (complements iotop's per-process view)
- **vmstat** — System-wide memory, swap, and I/O wait statistics for overall health assessment

## References

See `references/` for:
- `cheatsheet.md` — 10 task-organized patterns for common iotop workflows
- `docs.md` — man pages and upstream documentation links

---
name: iostat
description: >
  iostat reports CPU statistics and per-device disk throughput, IOPS, and latency
  metrics. It is part of the sysstat package and is the standard tool for diagnosing
  disk performance bottlenecks. Triggers on: iostat, disk throughput, disk latency,
  await, disk utilization, iops, disk performance, sysstat, read write MB/s, %util,
  nvme performance, block device stats.
globs: []
---

## Identity

| Property | Value |
|----------|-------|
| **Binary** | `iostat` |
| **Config** | No persistent config — invoked directly |
| **Logs** | No persistent logs — output to terminal |
| **Type** | CLI tool (part of sysstat) |
| **Install** | `apt install sysstat` / `dnf install sysstat` |

## Key Operations

| Task | Command |
|------|---------|
| Single snapshot (averages since boot) | `iostat` |
| Continuous output every 1 second | `iostat 1` |
| Extended stats (latency, queue depth, utilization) | `iostat -x 1` |
| Extended stats for a specific device | `iostat -x sda 1` |
| Extended stats for NVMe device | `iostat -x nvme0n1 1` |
| Human-readable sizes (KB/MB/GB) | `iostat -h 1` |
| Output in megabytes per second | `iostat -m 1` |
| Include timestamps on each line | `iostat -t 1` |
| Per-partition statistics | `iostat -p sda 1` |
| JSON output (machine-parseable) | `iostat -o JSON 1` |
| Extended + human-readable + timestamps | `iostat -xht 1` |
| 10 samples at 2-second intervals | `iostat -x 2 10` |

## Key Extended Columns (`-x`)

| Column | Meaning | Concern threshold |
|--------|---------|-------------------|
| `r/s` | Read operations per second | Depends on workload |
| `w/s` | Write operations per second | Depends on workload |
| `rkB/s` | Read throughput KB/s | Near device max = saturated |
| `wkB/s` | Write throughput KB/s | Near device max = saturated |
| `await` | Average I/O wait time (ms) | >20ms HDD, >1ms NVMe is concerning |
| `r_await` | Average read wait time (ms) | As above, separated by direction |
| `w_await` | Average write wait time (ms) | As above, separated by direction |
| `aqu-sz` | Average I/O queue depth | >1 sustained means device is busy |
| `%util` | % time device was busy | Near 100% = saturated (but see pain points) |

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| First interval shows unexpectedly low/high values | First row averages since boot, not current activity | Discard first line; use second interval onward |
| `iostat: command not found` | sysstat package not installed | `apt install sysstat` / `dnf install sysstat` |
| `await` looks fine but system is slow | High queue depth (`aqu-sz`) with moderate await means individual I/Os queue | Check `aqu-sz` alongside `await`; I/O scheduler may need tuning |
| NVMe shows as `nvme0n1` not `sdX` | NVMe uses its own namespace naming | Use `nvme0n1`, `nvme0n1p1` etc. in device arguments |
| `%util` near 100% but latency is low | SSDs and NVMe can saturate `%util` while serving queued I/Os efficiently | Rely on `await` and `aqu-sz` for SSDs — `%util` is less meaningful for parallel-IO devices |
| No output for a device | Device path wrong or not yet active | `lsblk` to list block devices; match name exactly in `-x <device>` |

## Pain Points

- **First interval is since-boot averages**: like vmstat, the first `iostat` output row covers the entire uptime. For current disk activity, always specify an interval and read from the second line onward.
- **`await` is the key latency metric**: average I/O wait in milliseconds is the most actionable single number. Over 20ms sustained on an HDD indicates queue buildup; over 1ms on NVMe is worth investigating. Cross-reference with `aqu-sz` to determine if latency is from queuing or from the device itself.
- **`%util` is misleading for NVMe and RAID**: `%util` measures the fraction of time the device had at least one I/O in flight. For devices with native command queuing (NVMe) or multiple spindles (RAID), 100% util does not mean saturated — they can still process more I/Os in parallel. Use `await` and `aqu-sz` instead.
- **sysstat must be installed separately**: unlike procps, sysstat is not part of most default installs. If `iostat` is missing, install `sysstat` explicitly.
- **NVMe device naming**: NVMe drives appear as `nvme0n1` (device), `nvme0n1p1` (partition), not as `sdX`. Pass the correct name to `-x` or `-p`; specifying `sda` on an NVMe-only system returns no output.

## References

See `references/` for:
- `cheatsheet.md` — 10 task-organized patterns for common iostat workflows
- `docs.md` — man pages and upstream documentation links

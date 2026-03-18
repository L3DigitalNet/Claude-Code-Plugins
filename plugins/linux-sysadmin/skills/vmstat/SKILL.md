---
name: vmstat
description: >
  vmstat reports virtual memory statistics, CPU activity, swap usage, and I/O wait
  in a compact tabular format. It is part of procps-ng and available on all Linux systems.
  MUST consult when checking virtual memory, CPU, and I/O statistics.
triggerPhrases:
  - "vmstat"
  - "virtual memory statistics"
  - "swap usage"
  - "memory pressure"
  - "system stats"
  - "io wait"
  - "cpu steal time"
  - "blocked processes"
  - "swap in out"
  - "si so columns"
globs: []
last_verified: "unverified"
---

## Identity

| Property | Value |
|----------|-------|
| **Binary** | `vmstat` |
| **Config** | No persistent config — invoked directly |
| **Logs** | No persistent logs — output to terminal |
| **Type** | CLI tool (part of procps-ng) |
| **Install** | `apt install procps` / `dnf install procps-ng` (usually pre-installed) |

## Quick Start

```bash
# vmstat is pre-installed on virtually all Linux systems (part of procps)
vmstat 1                    # continuous output every 1 second (ignore first line)
vmstat -tw 1                # wide output with timestamps every 1 second
vmstat -s                   # detailed memory summary
```

## Key Operations

| Task | Command |
|------|---------|
| Single snapshot (averages since boot) | `vmstat` |
| Continuous output every 1 second | `vmstat 1` |
| 10 samples at 1-second intervals | `vmstat 1 10` |
| Wide output (avoids column truncation) | `vmstat -w 1` |
| Include timestamps on each line | `vmstat -t 1` |
| Memory detail (totals in KB) | `vmstat -s` |
| Slab memory info (kernel cache usage) | `vmstat -m` |
| Disk statistics per device | `vmstat -d` |
| Per-partition I/O statistics | `vmstat -p sda1` |
| Active/inactive memory breakdown | `vmstat -a 1` |
| Output in megabytes | `vmstat -S M 1` |
| Timestamps + wide + continuous | `vmstat -tw 1` |

## Column Reference

| Column | Meaning | Concern threshold |
|--------|---------|-------------------|
| `r` | Processes waiting for CPU (run queue) | >4 × CPU count sustained |
| `b` | Processes blocked on I/O | >0 sustained indicates I/O saturation |
| `si` | Swap in (KB/s read from swap to RAM) | >0 means active memory pressure |
| `so` | Swap out (KB/s written from RAM to swap) | >0 means active memory pressure |
| `wa` | % CPU time waiting on I/O | >10% indicates disk bottleneck |
| `st` | % CPU time stolen by hypervisor | >0 on cloud VMs signals noisy-neighbor contention |
| `us` | % CPU time user-space | High with low `sy` is normal workload |
| `sy` | % CPU time kernel/system | High `sy` with moderate `us` may indicate kernel overhead |
| `id` | % CPU time idle | Low `id` + high `wa` = I/O bound; low `id` + low `wa` = CPU bound |

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| First output line looks wrong | First row is averages since boot, not current activity | Discard the first line; read from the second interval onward |
| `si`/`so` > 0 continuously | System is actively swapping — RAM exhausted | Identify memory hogs: `ps aux --sort=-%mem \| head`; add RAM or reduce workload |
| `wa` > 10% persistently | I/O wait saturating disk | Check which device with `iostat -x 1`; look for slow queries or backup jobs |
| `st` > 0 on a VM | Hypervisor CPU steal — host is oversubscribed | Escalate to hosting provider; consider instance type upgrade |
| `b` column > 0 sustained | Processes blocked on disk — I/O queue backed up | Check `iostat -x` `await` and `%util`; check for hung NFS mounts |
| `vmstat: command not found` | procps not installed | `apt install procps` / `dnf install procps-ng` |

## Pain Points

- **First line is since-boot averages**: the first output row of `vmstat` averages all activity since the system started. For current conditions, always run with an interval (e.g., `vmstat 1`) and read from the second line onward.
- **`si`/`so` are the key swap indicators**: non-zero values in the `si` (swap-in) and `so` (swap-out) columns indicate active memory pressure. The `free` and `buff/cache` columns show memory state but do not indicate whether swapping is occurring.
- **`wa` > 10% signals a disk bottleneck**: CPU time spent waiting for I/O completion means processes are stalled on disk. Follow up with `iostat -x` to identify which device and what latency (`await`) looks like.
- **`st` (steal) is a cloud VM signal**: non-zero steal time means the hypervisor is not delivering the CPU time the VM is entitled to. This is invisible from inside the guest and requires the host to be less oversubscribed.
- **`b` (blocked) > 0 means I/O saturation**: processes sitting in the uninterruptible sleep state waiting for I/O. Sustained `b` > 0 combined with high `wa` is a reliable sign the I/O subsystem is a bottleneck.

## See Also

- **iostat** — Per-device disk throughput, IOPS, and latency metrics for diagnosing I/O bottlenecks
- **iotop** — Per-process disk I/O usage to identify which processes are consuming disk bandwidth
- **perf** — Linux profiling tool for deep CPU and system performance analysis

## References

See `references/` for:
- `cheatsheet.md` — 10 task-organized patterns for common vmstat workflows
- `docs.md` — man pages and upstream documentation links

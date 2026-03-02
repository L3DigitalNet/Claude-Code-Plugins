---
name: perf
description: >
  perf is the Linux kernel performance profiling tool suite. It collects CPU
  performance counter data, call stacks, and tracepoints to identify hotspots
  and bottlenecks in applications and the kernel. Triggers on: perf, performance
  profiling, cpu profiling, flame graph, perf stat, perf record, perf top,
  hotspot, cpu cycles, profiling, kernel tracing, hardware counters.
globs: []
---

## Identity

| Property | Value |
|----------|-------|
| **Binary** | `perf` |
| **Config** | No persistent config — invoked directly |
| **Logs** | Saves recordings to `perf.data` in the current directory |
| **Type** | CLI tool |
| **Install** | `apt install linux-perf` / `dnf install perf` (must match kernel version) |

## Key Operations

| Task | Command |
|------|---------|
| Live top-like CPU hotspot view | `perf top` |
| Count hardware events for a command | `perf stat cmd` |
| Count events, attach to running PID | `perf stat -p 1234` |
| Record a CPU profile with call stacks | `perf record -g cmd` |
| Report from the last recording | `perf report` |
| Report in non-interactive mode | `perf report --stdio` |
| Annotate hottest function with source | `perf annotate` |
| System-wide profile (all CPUs) | `perf record -a -g -- sleep 10` |
| Profile specific hardware events | `perf record -e cycles,instructions cmd` |
| List available events | `perf list` |
| Attach recorder to a running PID | `perf record -g -p 1234 -- sleep 10` |
| Generate script output for flame graphs | `perf script > out.perf` |
| Memory access analysis | `perf mem record cmd && perf mem report` |

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| `perf: command not found` | Package not installed or wrong package for kernel | `apt install linux-perf` on Debian/Ubuntu; `dnf install perf` on Fedora |
| `Error: No kallsyms or vmlinux with build-id` | Kernel symbols not available | Install `linux-image-$(uname -r)-dbg` or enable `debuginfod` |
| `WARNING: perf not found for kernel ...` | perf binary version doesn't match running kernel | Install `linux-tools-$(uname -r)` matching the exact kernel version |
| `Permission denied` on `perf record` | `kernel.perf_event_paranoid` is too restrictive | Run as root, or `sysctl kernel.perf_event_paranoid=1` (0 for all events) |
| `perf top` refreshes too fast to read | Default 2-second delay is often too short on busy systems | Add `-d 5` for a 5-second refresh delay |
| Empty `perf report` after recording | Insufficient permissions, or recording ended before sampling | Run as root; ensure the workload ran long enough to collect samples |
| Container blocks perf_events | `perf_event` syscall blocked by seccomp or missing capability | Add `--cap-add=SYS_ADMIN` or `--privileged` to the container; not recommended for production |

## Pain Points

- **Kernel version coupling**: perf is tightly coupled to the running kernel. The `linux-tools-<version>` package must match `uname -r` exactly. On Ubuntu/Debian, `linux-perf` is a meta-package that tracks the current kernel; use it for rolling updates. After a kernel upgrade, reinstall the matching tools package before recording.
- **`kernel.perf_event_paranoid` controls access**: the default value (2 or 3 on hardened distros) blocks most perf operations for non-root users. Set it to 1 (`sysctl kernel.perf_event_paranoid=1`) to allow per-process profiling without root, or 0 to allow system-wide profiling. Reset to the original value after the debug session.
- **Kernel symbols require debug packages**: without kernel debug symbols (`linux-image-*-dbg` or `linux-image-*-dbgsym`), call stacks only show addresses. On Ubuntu, enable the `ddebs.ubuntu.com` repository. On Fedora, `debuginfo-install kernel` installs them automatically.
- **Flame graphs are not built in**: `perf report` shows a TUI hierarchy, but Brendan Gregg's `FlameGraph` scripts (https://github.com/brendangregg/FlameGraph) are required to produce the visual SVG. The pipeline is: `perf record -g → perf script → stackcollapse-perf.pl → flamegraph.pl > flame.svg`.
- **Container environments block perf_events by default**: Docker's default seccomp profile and Kubernetes pod security policies block the `perf_event_open` syscall. Either run perf on the host (targeting the container's PID namespace) or grant `SYS_ADMIN` capability — neither is appropriate for production.
- **`perf top` output is too noisy without filtering**: by default, `perf top` shows the entire system's CPU usage. Use `-p <PID>` to scope to a single process, or `-u <user>` to scope by user. Add `--call-graph dwarf` for stack-resolved symbols.

## References

See `references/` for:
- `cheatsheet.md` — 10 task-organized patterns for common perf workflows
- `docs.md` — man pages and upstream documentation links

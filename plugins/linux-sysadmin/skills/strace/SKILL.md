---
name: strace
description: >
  strace traces system calls and signals made by a process or command. It is the
  primary tool for diagnosing why a process fails to open files, connect to sockets,
  or behave unexpectedly at the OS boundary. Triggers on: strace, system calls,
  trace process, syscall, what is a process doing, debug process, file not found debug,
  permission denied debug, why is my process hanging, trace open read write.
globs: []
---

## Identity

| Property | Value |
|----------|-------|
| **Binary** | `strace` |
| **Config** | No persistent config — invoked directly |
| **Logs** | No persistent logs — output to terminal |
| **Type** | CLI tool |
| **Install** | `apt install strace` / `dnf install strace` |

## Key Operations

| Task | Command |
|------|---------|
| Trace a new process from launch | `strace cmd arg1 arg2` |
| Attach to a running PID | `strace -p 1234` |
| Follow child processes (threads, forks) | `strace -f cmd` |
| Filter to specific syscalls | `strace -e trace=open,read,write cmd` |
| Trace all file-related syscalls | `strace -e trace=file cmd` |
| Trace all network-related syscalls | `strace -e trace=network cmd` |
| Trace signal delivery | `strace -e signal=all cmd` |
| Add timestamps to each line | `strace -t cmd` |
| Show duration of each syscall | `strace -T cmd` |
| Summarize syscall counts and time | `strace -c cmd` |
| Write output to file (avoids terminal slowdown) | `strace -o /tmp/trace.txt cmd` |
| Increase string length shown | `strace -s 200 cmd` |
| Attach, follow children, filter file ops, write output | `strace -f -p 1234 -e trace=file -o /tmp/trace.txt` |

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| `attach: ptrace(PTRACE_SEIZE, ...): Operation not permitted` | Not running as root or `kernel.yama.ptrace_scope` is 1+ | Run with `sudo`, or `sysctl kernel.yama.ptrace_scope=0` temporarily |
| `strace: command not found` | Package not installed | `apt install strace` / `dnf install strace` |
| Process appears paused after attach | ptrace stops the target briefly on attach — normal for short operations, problematic for latency-sensitive services | Detach with `Ctrl-C`; use `-c` summary mode to reduce attach duration |
| Output is truncated with `...` in strings | Default string size is 32 bytes | Increase with `-s 200` or `-s 4096` for full path/data visibility |
| Tracing a setuid binary fails silently | ptrace is blocked on setuid binaries for non-root users | Run strace as root |
| No ptrace in container or sandbox | `seccomp` profile or `AppArmor` policy blocks `ptrace` | Add `--cap-add=SYS_PTRACE` to Docker; check `systemd` `NoNewPrivileges` |
| `-f` output is interleaved and unreadable | All threads write to the same output stream | Combine with `-o /tmp/trace.txt`; each line is prefixed with the PID |

## Pain Points

- **Output volume**: an unfiltered strace on any non-trivial process generates thousands of lines per second. Always filter with `-e trace=file`, `-e trace=network`, or a specific syscall list. Pipe or write to `-o` to avoid terminal rendering becoming the bottleneck.
- **Attaching pauses the target**: ptrace-attach briefly stops the traced process to inject the tracing context. On production services this manifests as a momentary latency spike. For long-running observations, prefer `-c` (count mode) which produces a summary only at exit.
- **`-f` is essential for multi-process apps but creates noise**: without `-f`, forked children and threads are invisible. With `-f`, every thread's syscalls appear interleaved; lines are prefixed with the PID. Write to `-o` and `grep` for specific PIDs afterward.
- **setuid and sandboxed processes are hard to trace**: setuid binaries (sudo, passwd) and processes inside systemd units with `NoNewPrivileges=true` or containers with restricted seccomp profiles block ptrace. Root is required, and even root may be blocked by the sandbox policy.
- **`seccomp` sandbox interference**: Docker's default seccomp profile permits ptrace, but custom profiles and rootless containers often do not. Add `--security-opt seccomp=unconfined` for debugging, then restore afterward.
- **Terminal output is slow for high-frequency syscalls**: for a process making thousands of syscalls per second, printing to a terminal throttles both strace and the target. Always use `-o /tmp/trace.txt` and inspect afterward when syscall rate is high.

## References

See `references/` for:
- `cheatsheet.md` — 10 task-organized patterns for common strace workflows
- `docs.md` — man pages and upstream documentation links

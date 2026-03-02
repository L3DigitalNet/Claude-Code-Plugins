---
name: lsof
description: >
  lsof (List Open Files) lists all open file descriptors on the system, including
  regular files, sockets, pipes, and devices. It is the standard tool for answering
  "which process has this file/port open". Triggers on: lsof, open files, what has
  file open, which process, port in use, file descriptor, deleted file still open,
  address in use, who is listening, socket in use, EADDRINUSE.
globs: []
---

## Identity

| Property | Value |
|----------|-------|
| **Binary** | `lsof` |
| **Config** | No persistent config — invoked directly |
| **Logs** | No persistent logs — output to terminal |
| **Type** | CLI tool |
| **Install** | `apt install lsof` / `dnf install lsof` |

## Key Operations

| Task | Command |
|------|---------|
| All open files on the system | `lsof` |
| Open files by a specific user | `lsof -u username` |
| Open files for a specific PID | `lsof -p 1234` |
| All files open under a directory (recursive) | `lsof +D /var/log` |
| All network connections | `lsof -i` |
| Listening TCP/UDP ports only | `lsof -i -sTCP:LISTEN` |
| What has port 80 open | `lsof -i :80` |
| Specific protocol connections | `lsof -i tcp` |
| Connections to a specific host | `lsof -i @10.0.0.1` |
| Deleted files still held open by a process | `lsof +L1` |
| Files open by process name | `lsof -c nginx` |
| Exclude a user (NOT operator) | `lsof -u ^root` |
| Repeat output every second | `lsof -r 1 -i :80` |
| Show file descriptor numbers | `lsof -d 1-10` |

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| Missing files for other users' processes | Not running as root; lsof only shows current user's files without it | Run with `sudo` for complete output |
| `WARNING: can't stat() fuse.gvfsd-fuse` messages | FUSE or network filesystems that don't support stat | Suppress with `-w`; the warnings are noise, not errors |
| Very slow on large systems | lsof is single-threaded and walks `/proc` serially | Add `-n` (skip hostname resolution) and `-P` (skip port-name resolution) to speed it up significantly |
| `lsof: command not found` | Package not installed | `apt install lsof` / `dnf install lsof` |
| `+D /path` takes very long | Recursively walks every subdirectory | Use `-D /path` for non-recursive, or narrow the path |
| Port shows as in use but nothing obvious | Deleted socket file or TIME_WAIT state | Check with `lsof +L1` for deleted descriptors; `ss -tnp` to see TIME_WAIT sockets |
| NFS-mounted file shows no process | NFS file locking happens on the server, not reported locally | Check NFS server with `lsof` there; locally see `nfsstat` |

## Pain Points

- **Root required for complete output**: without root, lsof only lists open files belonging to the current user. On multi-user systems or when diagnosing daemon processes, always use `sudo`. The output is silently incomplete otherwise.
- **`lsof +L1` solves "disk full but df shows space"**: when a large file is deleted while a process still holds an open descriptor, the disk space is not reclaimed until the process closes or exits. `lsof +L1` lists all file descriptors with a link count below 1 — these are the deleted-but-still-open files. Truncate the file via `/proc/<PID>/fd/<FD>` or restart the process to reclaim space immediately.
- **`-n` and `-P` are essential for performance**: by default, lsof resolves every IP address to a hostname and every port to a service name via DNS and `/etc/services`. On systems with many open sockets, this adds seconds. `-n` skips hostname resolution; `-P` skips port-to-name resolution. Use both when running on busy servers.
- **Combining filters with NOT (`^`)**: lsof allows combining `-u`, `-p`, and `-c` filters. Prefix with `^` to negate: `-u ^root` excludes root's files. Multiple positive terms are OR'd by default; add `-a` to AND them.
- **lsof is single-threaded and slow on large `/proc` trees**: on systems with thousands of open file descriptors, a full `lsof` run can take 5-10 seconds. Scope queries as narrowly as possible (`-p`, `-u`, or `-i :port`) rather than running a system-wide dump.

## References

See `references/` for:
- `cheatsheet.md` — 10 task-organized patterns for common lsof workflows
- `docs.md` — man pages and upstream documentation links

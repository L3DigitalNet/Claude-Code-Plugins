---
name: ss
description: >
  Socket statistics utility that replaces the deprecated netstat, displaying
  TCP/UDP listening ports, established connections, Unix sockets, and socket
  memory. Triggers on: ss, netstat, socket statistics, open ports, listening
  ports, network connections, established connections, ss -tulpn.
globs: []
---

## Identity

| Property | Value |
|----------|-------|
| **Binary** | `ss` |
| **Config** | `No persistent config — invoked directly` |
| **Logs** | `No persistent logs — output to terminal` |
| **Type** | CLI tool (part of iproute2) |
| **Install** | `apt install iproute2` / `dnf install iproute` (usually pre-installed) |

## Key Operations

| Task | Command |
|------|---------|
| All listening TCP/UDP with PID (most common) | `ss -tulpn` |
| All established TCP connections | `ss -t state established` |
| Filter by local port | `ss -tlnp sport = :443` |
| Filter by remote port | `ss -tnp dport = :22` |
| Filter by remote host | `ss -tnp dst 192.168.1.1` |
| Show socket memory usage | `ss -tm` |
| Show raw sockets | `ss -w` |
| Unix domain sockets | `ss -x` |
| Show socket timers (keepalive, retransmit) | `ss -to` |
| Resolve hostnames (inverse of -n) | `ss -tr` |
| Numeric output, no name resolution | `ss -tn` |
| Count connections per state | `ss -s` |
| Continuous watch of listening ports | `watch -n1 ss -tulpn` |
| Show all sockets (TCP + UDP + listening + established) | `ss -a` |

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| PID column shows `-` for other users' sockets | `-p` requires root to read `/proc` of other users | Run with `sudo ss -tulpn` |
| `ss` not found | Old system has `net-tools` (netstat) but not iproute2 | `apt install iproute2` or `dnf install iproute`; or use `netstat -tulpn` as a fallback |
| Expected port not showing as LISTEN | Service not started, wrong bind address, or non-default port | Check `systemctl status <service>`; look for bind errors in service logs |
| IPv6 entry shown for IPv4 service | Socket bound to `::` (dual-stack) serves both IPv4 and IPv6 | Normal — `:::80` means the process listens on port 80 for both address families |
| Filter returns no output despite connections existing | Filter syntax error — ss filters are strict | Use `ss -tnp dst 10.0.0.1` not `ss -tnp | grep 10.0.0.1`; check `man ss` FILTER section |
| Script breaks after migrating from netstat | ss output format and column names differ | Rewrite using ss-native filters rather than piping to grep/awk on netstat output |

## Pain Points

- **`netstat` is deprecated but widely documented**: Most online tutorials, Stack Overflow answers, and legacy runbooks reference `netstat -tulpn`. The equivalent is `ss -tulpn`. Both work on most systems today, but `netstat` is from the unmaintained `net-tools` package and may not be installed by default on newer distros.
- **`-p` requires root for other users' sockets**: `ss -p` reads process information from `/proc/<pid>/fd`. Without root, it can only show PIDs for sockets owned by the current user. Run with `sudo` when auditing listening services.
- **Output format breaks netstat-based scripts**: Column order, state names, and address formatting all differ from `netstat`. Scripts that parse `netstat` output with `awk '{print $4}'` will produce wrong results against `ss` output without modification.
- **Dual-stack `::` confuses IPv4 expectations**: When a service binds to `0.0.0.0` (IPv4 wildcard) on a system with IPv6 enabled, Linux may promote it to `::` (dual-stack wildcard). The service is still reachable on IPv4 — the display is just different.
- **Filter syntax is not grep**: ss has a built-in filter language (`sport`, `dport`, `src`, `dst`, `state`). Piping to grep works but misses rows when addresses are in different formats. Learn the native filter syntax for reliable scripting.

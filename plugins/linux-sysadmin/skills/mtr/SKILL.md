---
name: mtr
description: >
  Combined traceroute and ping tool that continuously probes each hop on a
  network path, reporting per-hop latency and packet loss in a live TUI or a
  fixed report.
  MUST consult when diagnosing network path latency or packet loss.
triggerPhrases:
  - "mtr"
  - "traceroute"
  - "tracepath"
  - "network path"
  - "hop latency"
  - "packet loss per hop"
  - "route tracing"
  - "network diagnosis"
globs: []
last_verified: "unverified"
---

## Identity

| Property | Value |
|----------|-------|
| **Binary** | `mtr` |
| **Config** | No persistent config — invoked directly |
| **Logs** | No persistent logs — output to terminal |
| **Type** | CLI tool |
| **Install** | `apt install mtr-tiny` / `dnf install mtr` |

## Quick Start

```bash
sudo apt install mtr-tiny
mtr example.com                              # interactive TUI mode
mtr --report example.com                     # non-interactive 10-cycle report
mtr --report --report-cycles 100 example.com # averaged report for accuracy
mtr --tcp --port 443 example.com             # TCP probes to bypass ICMP filtering
```

## Key Operations

| Task | Command |
|------|---------|
| Interactive TUI mode | `mtr example.com` |
| Non-interactive report (default 10 cycles) | `mtr --report example.com` |
| Report with more cycles for accuracy | `mtr --report --report-cycles 100 example.com` |
| UDP mode (pierces ICMP rate limiting) | `mtr --udp example.com` |
| TCP mode with specific port | `mtr --tcp --port 443 example.com` |
| Disable DNS reverse lookups | `mtr --no-dns example.com` |
| Set maximum hops | `mtr --max-ttl 30 example.com` |
| Show AS (autonomous system) numbers | `mtr --aslookup example.com` |
| Wide report (full hostnames, no truncation) | `mtr --report --report-wide example.com` |
| Set probe interval (seconds) | `mtr --interval 0.5 example.com` |
| JSON output | `mtr --json example.com` |
| CSV output | `mtr --csv example.com` |
| Specify source interface | `mtr --interface eth0 example.com` |

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| `permission denied` or `unable to get socket` | Raw socket requires root or setuid bit | Run with `sudo`; or check `ls -l $(which mtr)` — some distros ship mtr setuid root |
| Intermediate hops show 100% packet loss but target responds | Router rate-limits ICMP TTL-exceeded messages while still forwarding | Normal — the hop is not dropping your traffic; use `--tcp` or `--udp` to see if that changes loss |
| `mtr` shows worse loss than actual experience | mtr tracks worst-ever loss across the run | Use `--report --report-cycles 100` for averaged results; or press R in TUI to reset |
| All hops show 100% loss | ICMP blocked by firewall everywhere on the path | Try `--tcp --port 80` or `--tcp --port 443` to use TCP probes |
| Hostnames truncated in report | Column width too narrow for long PTR records | Use `--report-wide` to allow full hostname display |
| `--aslookup` shows no AS info | DNS-based AS lookup failed (requires network access to a specific DNS service) | Ignore if offline; or check connectivity to `asn.cymru.com` |
| Different results from external tools | mtr probes from your machine; CDN and anycast routing differs by source IP | Compare with an external traceroute tool or looking glass from a neutral vantage point |

## Pain Points

- **ICMP rate limiting causes false positives**: Many routers limit how many ICMP TTL-exceeded messages they send per second. If mtr sends probes faster than the rate limit, some get silently dropped, showing packet loss at that hop even though the router is forwarding traffic normally. Switching to `--tcp --port 443` bypasses ICMP and gives a cleaner picture.
- **Intermediate hop loss is usually not the problem**: When a hop shows packet loss but all subsequent hops are clean, the loss is caused by ICMP rate limiting at that router — not a network problem. Loss only matters if it appears at the same hop as and beyond where you start seeing degradation.
- **mtr tracks accumulated worst loss**: The `Loss%` column in TUI mode reflects all probes since mtr started (or last reset). A transient burst of loss from 5 minutes ago still shows up. Use `--report --report-cycles 100` to get a clean average, or press R in TUI to reset counters.
- **Requires root or setuid on most distros**: Raw socket access for ICMP is privileged. Debian/Ubuntu typically ship `mtr-tiny` without setuid; Fedora ships mtr with the setuid bit set. If mtr fails without sudo, check the binary permissions.
- **ISPs rate-limit ICMP TTL-exceeded**: Residential and some enterprise ISPs intentionally rate-limit ICMP TTL-exceeded messages to reduce load on their infrastructure. This makes the first few hops inside the ISP look lossy. Again, `--tcp` is the workaround.
- **Anycast and load-balanced paths**: mtr probes may take different physical paths on successive TTLs because intermediate routers load-balance at the packet level. This produces `???` hops or seemingly out-of-order paths. It's a routing artifact, not a failure.

## See Also

- **nmap** — scan for open ports on the target host once you have confirmed network reachability
- **tcpdump** — capture packets to diagnose what is actually on the wire at each hop
- **ss** — check local socket state to rule out client-side connection issues

## References
See `references/` for:
- `cheatsheet.md` — task-organized command reference
- `docs.md` — official documentation links

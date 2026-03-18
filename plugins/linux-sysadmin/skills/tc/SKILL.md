---
name: tc
description: >
  Linux traffic control (tc) for kernel-level traffic shaping: qdisc types
  (htb, tbf, netem, fq_codel), class-based hierarchy, filters, netem for
  latency/loss simulation, bandwidth limiting, and tc show/add/del commands.
  MUST consult when installing, configuring, or troubleshooting tc.
triggerPhrases:
  - "tc"
  - "traffic control"
  - "traffic shaping"
  - "qdisc"
  - "htb"
  - "tbf"
  - "netem"
  - "fq_codel"
  - "bandwidth limit"
  - "rate limit network"
  - "simulate latency"
  - "simulate packet loss"
  - "network emulation"
  - "traffic class"
  - "tc filter"
globs: []
last_verified: "2026-03"
---

## Identity

| Property | Value |
|----------|-------|
| **Binary** | `tc` (part of `iproute2`) |
| **Config** | No persistent config; invoked directly or scripted |
| **Logs** | No persistent logs; use `-s` flag for statistics |
| **Type** | CLI tool |
| **Install** | `apt install iproute2` / `dnf install iproute` (installed by default on most distros) |
| **Man pages** | `man tc`, `man tc-htb`, `man tc-tbf`, `man tc-netem`, `man tc-fq_codel` |

## Quick Start

```bash
# Show current qdiscs on all interfaces
tc qdisc show

# Add 100ms delay to eth0 (netem)
sudo tc qdisc add dev eth0 root netem delay 100ms

# Limit bandwidth to 1 Mbit/s (tbf)
sudo tc qdisc add dev eth0 root tbf rate 1mbit burst 32kbit latency 400ms

# Remove all tc rules from eth0
sudo tc qdisc del dev eth0 root
```

## Key Operations

| Task | Command |
|------|---------|
| Show all qdiscs | `tc qdisc show` |
| Show qdiscs on interface | `tc qdisc show dev eth0` |
| Show classes | `tc class show dev eth0` |
| Show classes as tree | `tc -g class show dev eth0` |
| Show filters | `tc filter show dev eth0` |
| Show statistics | `tc -s qdisc show dev eth0` |
| Add qdisc | `sudo tc qdisc add dev eth0 root <qdisc> [params]` |
| Change qdisc params | `sudo tc qdisc change dev eth0 root <qdisc> [params]` |
| Replace qdisc (add or change) | `sudo tc qdisc replace dev eth0 root <qdisc> [params]` |
| Delete qdisc | `sudo tc qdisc del dev eth0 root` |
| Add class | `sudo tc class add dev eth0 parent 1: classid 1:1 htb rate 10mbit` |
| Add filter | `sudo tc filter add dev eth0 parent 1: protocol ip prio 1 u32 match ip dport 80 0xffff flowid 1:10` |
| Add netem delay | `sudo tc qdisc add dev eth0 root netem delay 100ms` |
| Add netem delay + jitter | `sudo tc qdisc add dev eth0 root netem delay 100ms 20ms distribution normal` |
| Add netem packet loss | `sudo tc qdisc add dev eth0 root netem loss 5%` |
| Add netem duplication | `sudo tc qdisc add dev eth0 root netem duplicate 1%` |
| Add netem corruption | `sudo tc qdisc add dev eth0 root netem corrupt 0.1%` |
| Add netem reordering | `sudo tc qdisc add dev eth0 root netem delay 10ms reorder 25% 50%` |
| Limit bandwidth (tbf) | `sudo tc qdisc add dev eth0 root tbf rate 1mbit burst 32kbit latency 400ms` |
| Set fq_codel as default | `sudo tc qdisc replace dev eth0 root fq_codel` |

## Qdisc Types

### Classless (simple, attach to root)

| Qdisc | Purpose |
|-------|---------|
| **pfifo_fast** | Default qdisc on most distros; three-band priority queue using TOS bits |
| **fq_codel** | Fair Queuing + CoDel AQM; default on RHEL/Fedora; best general-purpose qdisc for low-latency |
| **tbf** | Token Bucket Filter; precise rate limiting with burst tolerance |
| **netem** | Network emulator; simulates delay, loss, duplication, corruption, reordering |
| **sfq** | Stochastic Fairness Queueing; per-flow fairness without rate guarantees |
| **ingress** | Special qdisc for policing incoming traffic (attach with `handle ffff:`) |

### Classful (hierarchical, contain child classes)

| Qdisc | Purpose |
|-------|---------|
| **htb** | Hierarchical Token Bucket; bandwidth guarantees per class with borrowing from parent |
| **prio** | Priority scheduler; strict priority ordering between bands |
| **hfsc** | Hierarchical Fair Service Curve; real-time latency guarantees + bandwidth sharing |
| **drr** | Deficit Round Robin; weighted fair scheduling |

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| `RTNETLINK answers: File exists` | Qdisc already attached to the device | Use `tc qdisc change` or `tc qdisc replace` instead of `add`; or delete first with `tc qdisc del dev eth0 root` |
| `RTNETLINK answers: No such file or directory` | Trying to change/delete a qdisc that does not exist | Use `add` first; check with `tc qdisc show dev eth0` |
| `RTNETLINK answers: Invalid argument` | Wrong parameters for the qdisc type | Check `man tc-<qdisc>` for required parameters; tbf needs `rate`, `burst`, and `latency` or `limit` |
| netem has no effect | Applied to wrong interface, or traffic goes through a different path | Verify interface with `ip route get <dest>`; netem applies to egress only (use `ifb` for ingress) |
| tc rules lost after reboot | tc rules are not persistent | Script them in a systemd unit, NetworkManager dispatcher, or `/etc/rc.local` |
| htb class not shaping | No filter directing traffic to the class | Add a filter: `tc filter add dev eth0 parent 1: protocol ip ...` |
| Permission denied | tc requires root or CAP_NET_ADMIN | Run with `sudo` |
| tbf drops everything | `burst` too small for the `rate` | Burst must be at least `rate / HZ`; increase burst size |

## Pain Points

- **tc rules are not persistent**: Every rule added with tc is lost on reboot. You need to script them in a startup service, a NetworkManager dispatcher script, or a dedicated tool like `tc-setup`. There is no built-in persistence mechanism.

- **netem only affects egress**: netem shapes outgoing traffic. To simulate delay or loss on incoming packets, you need an Intermediate Functional Block (IFB) device: create it with `ip link add ifb0 type ifb`, then redirect ingress to it with `tc filter add dev eth0 parent ffff: protocol ip u32 match u32 0 0 action mirred egress redirect dev ifb0`, and apply netem to ifb0.

- **HTB hierarchy requires filters**: Unlike simpler qdiscs, HTB classes do nothing without filters to classify packets into them. A common beginner mistake is defining the class tree but forgetting the filters, resulting in all traffic going to the default class.

- **Handle and classid notation**: Handles use a `major:minor` notation (e.g., `1:0`, `1:10`). The root qdisc handle is `major:0` (shortened to `major:`). Classes are `major:minor`. Filters reference `flowid major:minor`. Getting the numbering wrong silently routes traffic to the wrong class.

- **fq_codel vs pfifo_fast**: Modern kernels default to fq_codel on many distros (RHEL, Fedora), while older distros still use pfifo_fast. fq_codel provides much better latency under load. If you are troubleshooting bufferbloat, check which qdisc is active with `tc qdisc show`.

- **Units matter**: `tc` accepts `kbit`, `mbit`, `gbit` (powers of 1000) and `kbps`, `mbps`, `gbps` (bytes, powers of 1000). `1mbit` = 1,000,000 bits/s. `1mbps` = 1,000,000 bytes/s = 8 mbit. Confusing them produces 8x over/under-shaping.

- **Combining qdiscs**: You can chain netem under htb as a leaf qdisc to combine bandwidth shaping with latency simulation. Attach htb as root, then add netem to a specific class: `tc qdisc add dev eth0 parent 1:10 handle 10: netem delay 50ms`.

## See Also

- **ss** — inspect local socket state, connections, and buffer sizes
- **nmap** — actively scan for open ports and services on the network
- **iperf3** — measure bandwidth between two hosts to verify shaping is working

## References
See `references/` for:
- `docs.md` — official documentation links (man pages, kernel docs, LARTC HOWTO)
- `common-patterns.md` — practical recipes: HTB bandwidth sharing, netem simulation, ingress policing with IFB, and persistence scripts

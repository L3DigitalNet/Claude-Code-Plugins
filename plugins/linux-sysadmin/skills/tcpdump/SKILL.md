---
name: tcpdump
description: >
  Command-line packet capture tool for capturing, filtering, and inspecting
  network traffic in real time or writing to pcap files for later analysis with
  Wireshark or tshark.
  MUST consult when capturing or analyzing network traffic.
triggerPhrases:
  - "tcpdump"
  - "packet capture"
  - "network traffic"
  - "wireshark"
  - "pcap"
  - "packet analysis"
  - "capture traffic"
  - "sniff"
globs: []
last_verified: "unverified"
---

## Identity

| Property | Value |
|----------|-------|
| **Binary** | `tcpdump` |
| **Config** | No persistent config — invoked directly |
| **Logs** | No persistent logs — output to terminal or pcap file |
| **Type** | CLI tool |
| **Install** | `apt install tcpdump` / `dnf install tcpdump` |

## Quick Start

```bash
sudo apt install tcpdump
sudo tcpdump -D                           # list available interfaces
sudo tcpdump -i eth0 -nn -c 20           # capture 20 packets, no DNS lookups
sudo tcpdump -i eth0 -nn port 443        # filter by port
sudo tcpdump -i eth0 -w capture.pcap     # write to pcap file for Wireshark
```

## Key Operations

| Task | Command |
|------|---------|
| Capture on default interface | `sudo tcpdump` |
| Capture on specific interface | `sudo tcpdump -i eth0` |
| List available interfaces | `sudo tcpdump -D` |
| Write to pcap file | `sudo tcpdump -i eth0 -w capture.pcap` |
| Read from pcap file | `tcpdump -r capture.pcap` |
| Filter by host | `sudo tcpdump -i eth0 host 192.168.1.1` |
| Filter by port | `sudo tcpdump -i eth0 port 443` |
| Filter by protocol | `sudo tcpdump -i eth0 icmp` |
| No DNS / no port name resolution | `sudo tcpdump -nn` |
| Show hex and ASCII payload | `sudo tcpdump -X` |
| Limit packet count | `sudo tcpdump -c 100` |
| Verbose output (more header details) | `sudo tcpdump -v` / `-vv` / `-vvv` |
| Rotating capture files (100MB each) | `sudo tcpdump -i eth0 -w capture-%Y%m%d-%H%M%S.pcap -C 100` |
| Capture size limit per packet (snaplen) | `sudo tcpdump -s 128 -i eth0` |

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| `permission denied` | Requires root or `CAP_NET_RAW` capability | Run with `sudo`; or add user to `pcap` group on systems that support it |
| Capture is extremely slow / hangs | DNS reverse lookups blocking on each packet | Always use `-nn` to disable both IP and port name resolution |
| pcap file grows to fill disk | No size limit set | Use `-C <MB>` to rotate files by size, `-W <count>` to limit number of files kept |
| `no suitable device found` | Wrong interface name or interface doesn't exist | List interfaces: `sudo tcpdump -D` or `ip link show` |
| Traffic visible on wrong interface | Capturing on loopback or wrong NIC | Specify interface explicitly: `-i eth0` or `-i any` to capture all interfaces |
| BPF filter rejected with `syntax error` | tcpdump uses BPF syntax, not Wireshark display filter syntax | Refer to `man pcap-filter` for BPF syntax; Wireshark filters only work in Wireshark |
| SSH session freezes during capture | Capturing SSH traffic creates feedback loop: each packet triggers more packets | Add `not port 22` to the filter: `sudo tcpdump -i eth0 -nn not port 22` |

## Pain Points

- **Always use `-nn`**: Without it, tcpdump performs a reverse DNS lookup for every source and destination IP address, and a name lookup for every port number. On a busy interface this adds seconds of latency per packet and can make the capture nearly unusable. `-n` disables IP resolution; `-nn` disables both IP and port resolution.
- **Requires root or CAP_NET_RAW**: Reading raw packets from a network interface requires elevated privileges. On Debian-based systems, adding a user to the `wireshark` group with the right setcap permissions can allow non-root capture, but this is not the default.
- **BPF syntax differs from Wireshark display filters**: `host 1.2.3.4 and port 80` is BPF (tcpdump). `ip.addr == 1.2.3.4 && tcp.port == 80` is Wireshark. Mixing them up produces cryptic syntax errors or silently wrong captures.
- **pcap files grow fast**: Full-packet captures on a gigabit interface can fill disk in minutes. Use `-s 96` to capture only headers (usually sufficient for diagnosis), `-C 100` to rotate at 100MB, and `-W 10` to keep only 10 files.
- **`not port 22` is essential over SSH**: When you're connected to a remote server via SSH and you start a tcpdump capture without filtering, every tcpdump output line generates an SSH packet which is also captured, which generates another tcpdump output line. The session floods, lags, and may disconnect.
- **Promiscuous mode may be blocked**: Cloud instances (AWS, GCP, Azure) and some hypervisors block promiscuous mode at the virtual switch level. tcpdump will appear to capture but only sees traffic addressed to the local MAC, not traffic between other VMs on the same host.

## See Also

- **nmap** — actively scan for open ports and services rather than passively capturing traffic
- **ss** — inspect local socket state and connections without capturing packets
- **mtr** — trace the network path to a remote host to identify latency or loss at specific hops

## References
See `references/` for:
- `cheatsheet.md` — task-organized command reference
- `docs.md` — official documentation links

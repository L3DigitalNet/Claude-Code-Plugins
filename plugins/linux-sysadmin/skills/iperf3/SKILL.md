---
name: iperf3
description: >
  Network throughput and bandwidth measurement tool requiring an iperf3 server
  on one end and a client on the other. Triggers on: iperf3, iperf, network
  bandwidth, throughput test, network speed test, latency test, network
  performance.
globs: []
---

## Identity

| Property | Value |
|----------|-------|
| **Binary** | `iperf3` |
| **Config** | `No persistent config — invoked directly` |
| **Logs** | `No persistent logs — output to terminal` |
| **Type** | CLI tool |
| **Install** | `apt install iperf3` / `dnf install iperf3` |

## Key Operations

| Task | Command |
|------|---------|
| Start server (listens on port 5201) | `iperf3 -s` |
| Run TCP throughput test (client side) | `iperf3 -c <server-ip>` |
| Run UDP test with bandwidth limit | `iperf3 -c <server-ip> -u -b 100M` |
| Set test duration (default 10s) | `iperf3 -c <server-ip> -t 30` |
| Parallel streams (saturate high-BW links) | `iperf3 -c <server-ip> -P 8` |
| Reverse mode (server sends to client) | `iperf3 -c <server-ip> -R` |
| Test both directions simultaneously | `iperf3 -c <server-ip> --bidir` |
| JSON output for scripting | `iperf3 -c <server-ip> -J` |
| Bind to specific interface/IP | `iperf3 -c <server-ip> -B 192.168.1.10` |
| Set custom port | `iperf3 -s -p 5202` / `iperf3 -c <server-ip> -p 5202` |
| Set TCP window size | `iperf3 -c <server-ip> -w 256K` |
| Verbose per-interval output | `iperf3 -c <server-ip> -V` |
| Run server as daemon | `iperf3 -s -D` |

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| `unable to connect to server` | Server not running or port 5201 blocked by firewall | Verify `iperf3 -s` is running on the server; open port 5201 TCP/UDP |
| UDP result shows 0 Mbps transfer | UDP bandwidth not set (defaults to 1 Mbit/s) | Always set `-b` with UDP: `iperf3 -u -b 100M` or `-b 0` to remove limit |
| Server exits after one test | iperf3 server default: accept one connection then exit | Use `iperf3 -s --one-off` explicitly, or restart; use `-D` for persistent daemon mode |
| `incompatible iperf3 version` | iperf3 is not backwards-compatible with iperf2 | Install iperf3 on both ends; iperf2 and iperf3 cannot communicate |
| Result is much lower than expected link speed | Single TCP stream can't saturate high-BW links due to TCP window limits | Use `-P 4` or higher to run parallel streams |
| `error - control socket has closed unexpectedly` | Network disruption mid-test or firewall timeout | Check for stateful firewall dropping the long-lived control connection; increase idle timeout |
| `bind failed: cannot assign requested address` | `-B` address not on this host | Verify the interface IP with `ip addr`; use the correct local IP |

## Pain Points

- **iperf3 is not compatible with iperf2**: The protocols are fundamentally different. Both tools share similar flags but cannot talk to each other. Verify which version is installed on both ends before testing.
- **UDP bandwidth must be set explicitly**: iperf3's UDP default bandwidth is 1 Mbit/s — intentionally conservative. If you run a UDP test without `-b`, the result is meaningless for assessing link capacity. Use `-b 0` to remove the cap entirely, or set a realistic target like `-b 1G`.
- **Single stream TCP cannot saturate fast links**: A single TCP stream is bounded by the bandwidth-delay product (BDP). On a 10Gbps LAN with any non-trivial RTT, one stream will plateau well below line rate. Use `-P 4` or `-P 8` to run parallel streams.
- **Reverse mode tests download, not upload**: `-R` flips who sends data — the server sends to the client. This matters when the uplink and downlink speeds differ (e.g., asymmetric ISP links, one-way congestion).
- **Server exits after one test**: The default iperf3 server mode exits after serving one client. Use `-D` to run as a background daemon, or wrap it in a `while true; do iperf3 -s; done` loop for repeated testing.
- **Port 5201 must be open in both directions**: TCP tests need 5201 open; UDP tests need 5201 UDP open. Stateful firewalls sometimes allow the TCP control channel but block the UDP data channel — always test the specific protocol you care about.

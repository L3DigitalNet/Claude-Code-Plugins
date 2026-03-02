# iperf3 Command Reference

iperf3 requires two endpoints: a server (`iperf3 -s`) and a client
(`iperf3 -c <server>`). Run the server command first, then the client.

---

## 1. Basic TCP Throughput Test

The simplest measurement: how fast can data move between two hosts over TCP.

```bash
# Server side (run first)
iperf3 -s

# Client side — 10 second test to server at 192.168.1.100
iperf3 -c 192.168.1.100

# Output includes: interval, transfer, bitrate (Mbps/Gbps), and retransmits
# "Bitrate" in the SUM row is the key result
```

---

## 2. UDP Throughput Test

UDP tests measure loss and jitter as well as throughput. Always set `-b`
explicitly — the default of 1 Mbit/s is not a meaningful ceiling.

```bash
# Server side (same as TCP — iperf3 handles both)
iperf3 -s

# Client: UDP test with 500 Mbit/s target bandwidth, 30 second duration
iperf3 -c 192.168.1.100 -u -b 500M -t 30

# Remove bandwidth cap entirely (test actual maximum)
iperf3 -c 192.168.1.100 -u -b 0

# Output adds: jitter (ms) and packet loss (%) — key metrics for VoIP/streaming
```

---

## 3. Parallel Streams

A single TCP stream is limited by the TCP window size and RTT (bandwidth-delay
product). Use parallel streams to saturate high-bandwidth links.

```bash
# 4 parallel streams — typical for gigabit links
iperf3 -c 192.168.1.100 -P 4

# 8 parallel streams — for 10G+ or high-latency links
iperf3 -c 192.168.1.100 -P 8

# Parallel UDP streams with bandwidth split across them
iperf3 -c 192.168.1.100 -u -b 1G -P 4
# Note: -b 1G is the PER-STREAM bandwidth, so total target is 4G
```

---

## 4. Reverse Mode (Download Speed)

In normal mode, the client sends data (measures upload). Reverse mode flips it:
the server sends, client receives (measures download from the client's perspective).

```bash
# Reverse: server sends to client (client's download speed)
iperf3 -c 192.168.1.100 -R

# Bidirectional: test upload and download simultaneously
iperf3 -c 192.168.1.100 --bidir

# Reverse + parallel streams for saturating a fast downlink
iperf3 -c 192.168.1.100 -R -P 4
```

---

## 5. Custom Duration and Interval

Control how long a test runs and how frequently interim results are printed.

```bash
# 60 second test (default is 10s)
iperf3 -c 192.168.1.100 -t 60

# Print interval results every 1 second instead of default (usually 1s already)
iperf3 -c 192.168.1.100 -i 1

# 5 minute test with 5 second intervals (useful for spotting intermittent drops)
iperf3 -c 192.168.1.100 -t 300 -i 5
```

---

## 6. JSON Output for Scripting

Machine-readable output for logging, graphing, or comparison.

```bash
# JSON output to stdout
iperf3 -c 192.168.1.100 -J

# JSON output saved to file
iperf3 -c 192.168.1.100 -J > result_$(date +%F_%H%M%S).json

# Extract summary bitrate from JSON (requires jq)
iperf3 -c 192.168.1.100 -J | jq '.end.sum_received.bits_per_second / 1e6 | round'
# Output: Mbps as an integer

# Extract loss percentage from UDP test
iperf3 -c 192.168.1.100 -u -b 500M -J | jq '.end.sum.lost_percent'
```

---

## 7. Bind to Specific Interface

Force iperf3 to use a specific local IP or interface — useful on multi-homed
hosts or when testing a specific network path.

```bash
# Client: bind to specific local IP (controls which interface packets leave from)
iperf3 -c 192.168.1.100 -B 192.168.1.10

# Server: listen only on a specific IP (not all interfaces)
iperf3 -s -B 192.168.1.100

# Test a specific route: bind client to interface facing the path under test
iperf3 -c 10.0.0.1 -B 10.0.0.50
```

---

## 8. Custom Port

Use a non-default port when 5201 is blocked or to run multiple servers.

```bash
# Server on port 9000
iperf3 -s -p 9000

# Client connecting to port 9000
iperf3 -c 192.168.1.100 -p 9000

# Run multiple servers on different ports (each in background)
iperf3 -s -p 5201 -D
iperf3 -s -p 5202 -D
```

---

## 9. Persistent Server Daemon

The default server exits after one test. Use `-D` for a persistent background
daemon, or a systemd unit for reliability.

```bash
# Daemon mode (server stays up after test completes)
iperf3 -s -D

# Check if iperf3 is listening
ss -tlnp | grep 5201

# Stop the daemon
pkill iperf3

# Minimal systemd unit at /etc/systemd/system/iperf3.service:
# [Unit]
# Description=iperf3 server
# After=network.target
#
# [Service]
# ExecStart=/usr/bin/iperf3 -s
# Restart=always
#
# [Install]
# WantedBy=multi-user.target
```

---

## 10. Window Size and Buffer Tuning

TCP window size affects how much data can be in-flight. On high-latency links,
the default window may be the bottleneck even before parallel streams help.

```bash
# Set TCP socket buffer size (window size hint — kernel may adjust)
iperf3 -c 192.168.1.100 -w 256K

# Large window for high-latency links (e.g., transcontinental)
iperf3 -c 192.168.1.100 -w 4M

# Set send and receive buffer (socket buffer, not TCP window directly)
iperf3 -c 192.168.1.100 --set-mss 1400

# Check current TCP buffer settings on Linux
sysctl net.core.rmem_max net.core.wmem_max net.ipv4.tcp_rmem net.ipv4.tcp_wmem
```

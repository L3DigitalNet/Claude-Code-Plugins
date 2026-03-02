# tcpdump Command Reference

tcpdump uses BPF (Berkeley Packet Filter) syntax for filtering. This is
different from Wireshark display filter syntax. Always use `-nn` to
prevent DNS lookups from slowing the capture.

---

## 1. Basic Capture on an Interface

```bash
# List available interfaces before choosing one
sudo tcpdump -D

# Capture all traffic on eth0 (ctrl-c to stop)
sudo tcpdump -i eth0 -nn

# Capture on all interfaces simultaneously (useful when unsure which NIC)
sudo tcpdump -i any -nn

# Capture loopback traffic (local service communication)
sudo tcpdump -i lo -nn
```

---

## 2. Write to File / Read from File

pcap files can be opened in Wireshark, tshark, or read back with tcpdump.

```bash
# Write capture to file (no output to terminal while writing)
sudo tcpdump -i eth0 -nn -w capture.pcap

# Write with timestamp in filename (useful for long-running captures)
sudo tcpdump -i eth0 -nn -w "capture-$(date +%F_%H%M%S).pcap"

# Read pcap back and display with tcpdump filters
tcpdump -r capture.pcap -nn

# Read pcap and apply a filter to reduce output
tcpdump -r capture.pcap -nn 'port 443'

# Open in Wireshark (GUI)
wireshark capture.pcap &

# Open in tshark (terminal Wireshark)
tshark -r capture.pcap
```

---

## 3. Filter by Host, Port, Protocol

BPF filter expressions. Combine with `and`, `or`, `not` (or `&&`, `||`, `!`).

```bash
# Traffic to or from a host
sudo tcpdump -i eth0 -nn host 192.168.1.1

# Traffic between two specific hosts
sudo tcpdump -i eth0 -nn 'src 192.168.1.10 and dst 192.168.1.1'

# Traffic on a specific port (either direction)
sudo tcpdump -i eth0 -nn port 443

# Traffic on a port range
sudo tcpdump -i eth0 -nn 'portrange 8000-9000'

# Traffic by protocol
sudo tcpdump -i eth0 -nn icmp
sudo tcpdump -i eth0 -nn arp
sudo tcpdump -i eth0 -nn udp

# Combine: HTTP traffic from a specific host
sudo tcpdump -i eth0 -nn 'host 10.0.0.5 and port 80'

# Exclude SSH to avoid feedback loop when capturing over SSH
sudo tcpdump -i eth0 -nn 'not port 22'

# Capture DNS queries and responses
sudo tcpdump -i eth0 -nn 'port 53'
```

---

## 4. Show Packet Content (Hex + ASCII)

```bash
# Show packet headers + hex + ASCII payload
sudo tcpdump -i eth0 -nn -X port 80

# Hex only (no ASCII)
sudo tcpdump -i eth0 -nn -x port 80

# ASCII printable characters only (good for plain-text protocols)
sudo tcpdump -i eth0 -nn -A port 80

# Verbose header info (TTL, IP flags, checksum, etc.)
sudo tcpdump -i eth0 -nn -v port 80

# Very verbose (decode all headers including protocol-specific fields)
sudo tcpdump -i eth0 -nn -vvv port 80
```

---

## 5. Limit Capture Size and Count

```bash
# Stop after capturing 500 packets
sudo tcpdump -i eth0 -nn -c 500

# Capture only the first 96 bytes of each packet (enough for most headers)
# Full packet = default snaplen of 262144 bytes
sudo tcpdump -i eth0 -nn -s 96

# Combine: 200 packets, headers only, written to file
sudo tcpdump -i eth0 -nn -c 200 -s 96 -w headers.pcap
```

---

## 6. Rotating Capture Files

For long-running captures without filling disk. Use `-C` (size in MB) or
`-G` (time in seconds) for rotation, and `-W` to cap the number of files kept.

```bash
# Rotate every 100MB, keep 5 files (oldest deleted when 6th is created)
sudo tcpdump -i eth0 -nn -w /tmp/cap.pcap -C 100 -W 5

# Rotate every 60 seconds with timestamp in filename
sudo tcpdump -i eth0 -nn -w /tmp/cap-%Y%m%d-%H%M%S.pcap -G 60

# Rotate every 60 seconds, keep 10 files maximum
sudo tcpdump -i eth0 -nn -w /tmp/cap-%Y%m%d-%H%M%S.pcap -G 60 -W 10

# Background capture to file, rotate every 10 minutes
sudo nohup tcpdump -i eth0 -nn -w /tmp/cap-%H%M%S.pcap -G 600 -W 6 &
```

---

## 7. Application-Layer Protocol Captures

Common capture filters for specific protocols. Combine with `-A` for payload.

```bash
# HTTP (plain text — see full request/response)
sudo tcpdump -i eth0 -nn -A 'port 80'

# HTTPS (headers only — payload is encrypted)
sudo tcpdump -i eth0 -nn 'port 443'

# DNS queries and responses
sudo tcpdump -i eth0 -nn -vvv 'port 53'

# ICMP (ping requests and replies)
sudo tcpdump -i eth0 -nn icmp

# DHCP traffic (uses broadcast, capture from client interface)
sudo tcpdump -i eth0 -nn 'port 67 or port 68'

# NTP
sudo tcpdump -i eth0 -nn 'port 123'

# SMTP
sudo tcpdump -i eth0 -nn -A 'port 25 or port 587 or port 465'
```

---

## 8. Advanced BPF Filters

```bash
# TCP SYN packets only (connection initiation)
sudo tcpdump -i eth0 -nn 'tcp[tcpflags] & tcp-syn != 0'

# TCP RST packets (connections being reset — sign of problems)
sudo tcpdump -i eth0 -nn 'tcp[tcpflags] & tcp-rst != 0'

# ICMP echo requests (pings sent TO this host)
sudo tcpdump -i eth0 -nn 'icmp[icmptype] == icmp-echo'

# Filter by VLAN tag
sudo tcpdump -i eth0 -nn 'vlan 100'

# IPv6 traffic only
sudo tcpdump -i eth0 -nn ip6

# Packets larger than 1400 bytes (catching fragmentation or large packets)
sudo tcpdump -i eth0 -nn 'greater 1400'

# Packets smaller than 64 bytes (undersized frames — potential issue)
sudo tcpdump -i eth0 -nn 'less 64'
```

---

## 9. Capture for Remote Analysis

Capture on a remote server and pipe to Wireshark on your local machine.

```bash
# SSH pipe to local Wireshark — analyze in real time without storing a file
ssh user@remote-host "sudo tcpdump -i eth0 -nn -s 0 -U -w - 'not port 22'" | wireshark -k -i -

# SSH pipe to local tshark (terminal)
ssh user@remote-host "sudo tcpdump -i eth0 -nn -s 0 -U -w - 'not port 22'" | tshark -r -

# Flags used: -U (packet-buffered output), -w - (write to stdout), -s 0 (full packets)
# 'not port 22' is critical — filters SSH traffic to avoid feedback loop
```

---

## 10. Timestamping and Statistics

```bash
# Default timestamp format: HH:MM:SS.microseconds
sudo tcpdump -i eth0 -nn port 80

# Absolute timestamp (epoch seconds)
sudo tcpdump -i eth0 -nn --time-stamp-type adapter

# Human-readable date+time (--time-stamp-type monotonic-raw doesn't work everywhere)
sudo tcpdump -i eth0 -nn -tttt port 80
# -t: no timestamp  -tt: raw epoch  -ttt: delta  -tttt: date+time

# Packet count summary on ctrl-c
# tcpdump always prints: X packets captured, Y received by filter, Z dropped by kernel
# Kernel drops mean the capture buffer was too small — try -B 4096 to increase buffer

# Increase kernel capture buffer (default is 2MB on most systems)
sudo tcpdump -i eth0 -nn -B 4096 port 80
```

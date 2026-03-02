# ss Command Reference

`ss` is the modern replacement for `netstat`. It reads socket state directly
from the kernel via netlink, making it faster and more accurate than netstat's
`/proc/net` parsing.

---

## 1. Listening Ports (The Most Common Use Case)

```bash
# Show all listening TCP and UDP sockets with process info, numeric addresses
# -t: TCP  -u: UDP  -l: listening  -p: process  -n: no name resolution
sudo ss -tulpn

# Same but include Unix domain sockets
sudo ss -tulpnx

# Just TCP listeners
sudo ss -tlpn

# Just UDP listeners
sudo ss -ulpn
```

---

## 2. Established Connections

```bash
# All established TCP connections
ss -t state established

# Established connections with process info
sudo ss -tp state established

# Established connections to a specific remote host
ss -t state established dst 203.0.113.10

# Count established connections
ss -t state established | wc -l

# Established connections grouped by remote address (quick top-talkers view)
ss -tn state established | awk '{print $5}' | cut -d: -f1 | sort | uniq -c | sort -rn | head
```

---

## 3. Filter by Port

ss has a native filter language — use it instead of piping to grep.

```bash
# Sockets with local port 443
ss -tnp sport = :443

# Sockets with remote port 5432 (connections TO postgres)
ss -tnp dport = :5432

# Port range: local ports 8000-9000
ss -tnp 'sport >= :8000 and sport <= :9000'

# Connections FROM a specific source port
ss -tnp sport = :22

# Negation: all connections NOT to port 443
ss -tnp 'dport != :443'
```

---

## 4. Filter by Address

```bash
# Connections to a specific remote host
ss -tnp dst 192.168.1.1

# Connections from a specific source IP
ss -tnp src 10.0.0.5

# Connections within a subnet
ss -tnp dst 10.0.0.0/24

# Both address and port combined
ss -tnp 'dst 192.168.1.1 and dport = :3306'
```

---

## 5. Socket States

```bash
# Show sockets in a specific state
ss -t state time-wait
ss -t state close-wait
ss -t state syn-recv

# All non-established states (useful to spot connection backlog issues)
ss -t state syn-sent
ss -t state fin-wait-1
ss -t state fin-wait-2

# Summary count by state
ss -s
# Output: Total, TCP (estab/closed/orphaned/timewait), UDP
```

---

## 6. Socket Memory and Buffer Usage

```bash
# Show memory usage per socket
ss -tm

# TCP sockets with memory details
ss -tm state established

# Columns: r=receive buffer used, w=send buffer used, f=forward alloc, o=option mem
# High 'w' values mean the send buffer is filling — possible congestion or slow receiver

# System-wide socket memory limits
sysctl net.core.rmem_max net.core.wmem_max
sysctl net.ipv4.tcp_rmem net.ipv4.tcp_wmem
```

---

## 7. Unix Domain Sockets

```bash
# All Unix domain sockets
ss -x

# Listening Unix sockets with process info
sudo ss -xlp

# Filter by socket path
ss -x src /var/run/docker.sock

# Common Unix sockets to know:
# /var/run/docker.sock     — Docker daemon API
# /run/systemd/journal/stdout — journald
# /tmp/.s.PGSQL.5432       — PostgreSQL default socket
# /var/run/mysql/mysql.sock — MySQL/MariaDB
```

---

## 8. Timer Information

```bash
# Show socket timers (keepalive, retransmit, time-wait)
ss -to

# TCP sockets with timer details
ss -to state established

# Timer output format: timer:(type,expire_time,retransmits)
# type: keepalive | on (retransmit) | timewait | persist
# Example: timer:(keepalive,90sec,0) — keepalive probe in 90 seconds, 0 retransmits so far
```

---

## 9. Continuous Monitoring

```bash
# Watch listening ports refresh every second
watch -n1 'ss -tulpn'

# Watch with color highlighting (requires watch 3.3+)
watch -c -n1 'ss -tulpn'

# Watch connection count to a specific port
watch -n1 'ss -tn state established dport = :443 | wc -l'

# One-liner: count connections per remote IP to port 80
watch -n2 "ss -tn state established dport = :80 | awk '{print \$5}' | cut -d: -f1 | sort | uniq -c | sort -rn"
```

---

## 10. Comparison with netstat (Migration Reference)

Common `netstat` commands and their `ss` equivalents.

```bash
# netstat: show listening TCP/UDP ports with PID
netstat -tulpn
# ss equivalent:
sudo ss -tulpn

# netstat: show all connections
netstat -an
# ss equivalent:
ss -an

# netstat: show routing table
netstat -r
# NOT ss — use: ip route show

# netstat: interface statistics
netstat -i
# NOT ss — use: ip -s link show

# netstat: continuous display
netstat -c
# ss equivalent: wrap in watch
watch -n1 ss -tnp
```

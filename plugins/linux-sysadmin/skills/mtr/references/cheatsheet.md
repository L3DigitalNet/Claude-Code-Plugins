# mtr Command Reference

mtr combines ping and traceroute into a continuously updating view of per-hop
latency and loss. Key insight: packet loss at an intermediate hop is usually
ICMP rate-limiting, not a real problem — watch for loss that starts at a hop
AND persists in all subsequent hops.

---

## 1. Interactive TUI Mode

The default mode: live-updating table of each hop's statistics.

```bash
# Basic interactive run (ctrl-c to quit)
mtr example.com

# Disable reverse DNS (faster startup, cleaner output)
mtr --no-dns example.com

# With AS number lookup (identifies which ISP/carrier owns each hop)
mtr --aslookup example.com

# TUI keyboard shortcuts:
# d — toggle display fields (latency, loss, sent/received, jitter)
# n — toggle DNS resolution on/off
# r — reset all counters
# p — pause/resume probing
# q — quit
```

---

## 2. Report Mode (Non-Interactive)

Runs a fixed number of probe cycles, prints a summary, and exits. Use this
for saving results, pasting into bug reports, or scripting.

```bash
# Default report (10 cycles)
mtr --report example.com

# More cycles for statistical accuracy (100 probes per hop)
mtr --report --report-cycles 100 example.com

# Report without DNS (faster)
mtr --report --no-dns example.com

# Wide report (full hostnames, no truncation)
mtr --report --report-wide example.com

# Full diagnostic report for sharing:
mtr --report --report-wide --no-dns --report-cycles 100 example.com
```

---

## 3. TCP Mode (Bypass ICMP Filtering)

Routers that rate-limit ICMP TTL-exceeded messages cause false packet loss in
mtr. TCP probes often pierce through where ICMP gets dropped.

```bash
# TCP probe to port 80 (HTTP)
sudo mtr --tcp --port 80 example.com

# TCP probe to port 443 (HTTPS) — most reliable to public web servers
sudo mtr --tcp --port 443 example.com

# TCP + report mode
sudo mtr --tcp --port 443 --report --report-cycles 50 example.com

# Note: TCP probes require root (raw socket)
```

---

## 4. UDP Mode

UDP probes behave differently from ICMP at each hop. Some networks that filter
ICMP pass UDP, and vice versa. Useful when ICMP and TCP modes give conflicting
results.

```bash
# UDP mode
sudo mtr --udp example.com

# UDP to specific port (default UDP port is 33434)
sudo mtr --udp --port 5353 example.com

# UDP report
sudo mtr --udp --report --report-cycles 100 example.com
```

---

## 5. Adjusting Probe Rate and Hop Limit

```bash
# Probe every 0.1 seconds (10 per second — aggressive, may trigger rate limiting)
sudo mtr --interval 0.1 example.com

# Probe every 2 seconds (gentler on production infrastructure)
mtr --interval 2 example.com

# Limit maximum hops (default 30 — reduce for faster results on short paths)
mtr --max-ttl 15 example.com

# Set the first TTL (skip the first N hops — useful when local hops are known good)
mtr --first-ttl 5 example.com
```

---

## 6. Machine-Readable Output

```bash
# JSON output (structured, suitable for parsing)
mtr --report --json example.com

# JSON with more cycles for statistical reliability
mtr --report --json --report-cycles 100 example.com

# CSV output
mtr --report --csv example.com

# Extract just the final-hop loss from JSON (requires jq)
mtr --report --json example.com | jq '.report.hubs[-1].Loss'

# Extract all hops: host, loss, avg latency
mtr --report --json example.com | jq '.report.hubs[] | {host: .host, loss: .Loss, avg: .Avg}'
```

---

## 7. Source Interface and Address

```bash
# Force mtr to probe from a specific interface
sudo mtr --interface eth0 example.com

# Bind to a specific source IP (useful on multi-homed hosts)
sudo mtr --address 192.168.1.10 example.com

# Useful when testing which path a specific interface takes
sudo mtr --interface bond0 --report 8.8.8.8
```

---

## 8. AS Number Lookup

Shows which autonomous system (network operator) owns each hop — useful for
identifying where a problem crosses from one carrier to another.

```bash
# Enable AS lookup in TUI mode
mtr --aslookup example.com

# AS lookup in report mode
mtr --report --aslookup --report-wide example.com

# Note: --aslookup makes DNS queries to asn.cymru.com for each hop IP
# Results may be slow or unavailable if DNS is restricted
```

---

## 9. Diagnosing Intermediate Hop Loss

How to distinguish real loss from ICMP rate-limiting artifacts.

```bash
# Step 1: run ICMP mtr and note which hops show loss
mtr --report --report-cycles 100 example.com

# Step 2: run TCP mtr to the same target
sudo mtr --tcp --port 443 --report --report-cycles 100 example.com

# Interpretation:
# Loss at hop N but NOT at hop N+1 → rate-limiting at hop N router (not a real problem)
# Loss at hop N AND all subsequent hops → real congestion or drop at hop N
# Loss only in ICMP mode, clean in TCP mode → ICMP is being rate-limited or deprioritized
# Loss in both ICMP and TCP → genuine packet loss on that segment

# Step 3: repeat from a different vantage point using a public looking glass
# to confirm whether the issue is in the path from your location or universal
```

---

## 10. Saving and Sharing Results

```bash
# Save a full diagnostic report to a text file
mtr --report --report-wide --no-dns --report-cycles 100 example.com > mtr_result.txt

# Append timestamp to the file
echo "=== $(date) ===" >> mtr_results.log
mtr --report --no-dns example.com >> mtr_results.log

# Generate JSON and process with jq
mtr --report --json --report-cycles 50 8.8.8.8 | \
  jq -r '.report.hubs[] | "\(.count). \(.host // "???") loss=\(.Loss)% avg=\(.Avg)ms"'

# Run mtr in background and log every 10 minutes
while true; do
  echo "=== $(date -u +%Y-%m-%dT%H:%M:%SZ) ===" >> /tmp/mtr_log.txt
  mtr --report --no-dns --report-cycles 20 8.8.8.8 >> /tmp/mtr_log.txt
  sleep 600
done &
```

# nmap Command Reference

Each block below is copy-paste-ready. Substitute IP addresses, ranges, and
filenames for your actual targets.

---

## 1. Host Discovery (Ping Sweep)

Find live hosts on a subnet without port scanning. Useful before a targeted scan.

```bash
# ICMP echo + TCP SYN to 443 + TCP ACK to 80 + ICMP timestamp (default probe set)
sudo nmap -sn 192.168.1.0/24

# Ping sweep — list only IPs nmap considers up
sudo nmap -sn 192.168.1.0/24 | grep 'Nmap scan report' | awk '{print $NF}'

# Disable ping entirely — scan every host regardless of whether it responds to ping
# Useful when ICMP is blocked by firewalls
sudo nmap -Pn 192.168.1.0/24 -p 22,80,443 --open
```

---

## 2. TCP SYN Scan (Stealth Scan)

Fastest and most common scan type. Sends SYN, reads SYN-ACK/RST response, never
completes the handshake. Requires root.

```bash
# SYN scan top 1000 ports (default)
sudo nmap -sS 192.168.1.1

# SYN scan specific ports
sudo nmap -sS -p 22,80,443,3306,5432,6379,8080 192.168.1.1

# Non-root alternative: full TCP connect (slower, more logged)
nmap -sT 192.168.1.1
```

---

## 3. Full Port Scan

Scan all 65535 ports. Slow on remote hosts; combine with `-T4` and `--min-rate`
to speed up on fast links.

```bash
# All ports, SYN scan
sudo nmap -sS -p- 192.168.1.1

# All ports with minimum packet rate (1000 packets/sec) — faster on LAN
sudo nmap -sS -p- --min-rate=1000 192.168.1.1

# Show only open ports (skip filtered/closed output)
sudo nmap -sS -p- --open 192.168.1.1
```

---

## 4. Service and Version Detection

Probes open ports to determine the application and version running behind them.

```bash
# Version detection on top 1000 ports
nmap -sV 192.168.1.1

# Combine with SYN scan (requires root)
sudo nmap -sS -sV 192.168.1.1

# Intensity: 0 (light) to 9 (try everything) — default is 7
nmap -sV --version-intensity 5 192.168.1.1

# Full aggressive scan: OS + version + default scripts + traceroute
sudo nmap -A 192.168.1.1
```

---

## 5. OS Detection

Fingerprints the target OS based on TCP/IP stack behavior. Requires root and at
least one open and one closed port for best accuracy.

```bash
# OS detection
sudo nmap -O 192.168.1.1

# OS detection with increased retries when accuracy is low
sudo nmap -O --osscan-guess --max-os-tries 5 192.168.1.1

# Combined: OS + version
sudo nmap -O -sV 192.168.1.1
```

---

## 6. NSE Script Scanning

Nmap Scripting Engine scripts extend nmap's capabilities. Scripts live in
`/usr/share/nmap/scripts/`.

```bash
# Run default scripts (safe, commonly useful)
nmap -sC 192.168.1.1

# Run a specific named script
nmap --script http-title 192.168.1.1

# Run all scripts in a category
nmap --script vuln 192.168.1.1

# Run multiple scripts
nmap --script "http-headers,http-methods" 192.168.1.1

# Pass arguments to a script
nmap --script http-brute --script-args brute.firstonly=true 192.168.1.1

# List all scripts in a category without running them
ls /usr/share/nmap/scripts/ | grep '^smb'
```

---

## 7. UDP Scan

UDP is stateless — open ports are often silent. Limit to well-known UDP services
to keep scan times manageable.

```bash
# UDP scan common ports (requires root)
sudo nmap -sU 192.168.1.1

# UDP scan specific service ports
sudo nmap -sU -p 53,67,68,69,123,161,162,514,1194 192.168.1.1

# Combine UDP and TCP in one run
sudo nmap -sS -sU -p T:80,443,U:53,161 192.168.1.1
```

---

## 8. Scan from File / Exclude Hosts

```bash
# Read targets from file (one per line: IPs, ranges, or hostnames)
nmap -iL targets.txt

# Exclude specific hosts from a subnet scan
nmap 192.168.1.0/24 --exclude 192.168.1.1,192.168.1.254

# Exclude hosts listed in a file
nmap 192.168.1.0/24 --excludefile exclude.txt
```

---

## 9. Output Formats

Save results for later analysis. Use `-oA` to write all three formats at once.

```bash
# Normal text output (human-readable)
nmap -sV 192.168.1.1 -oN scan_normal.txt

# XML output (parseable by tools like ndiff, metasploit)
nmap -sV 192.168.1.1 -oX scan.xml

# Grepable format (one host per line, easy to parse with grep/awk)
nmap -sV 192.168.1.1 -oG scan.gnmap

# All three formats at once (creates scan.nmap, scan.xml, scan.gnmap)
nmap -sV 192.168.1.1 -oA scan_results

# Extract open ports from grepable output
grep 'open' scan.gnmap | awk -F/ '{for(i=1;i<=NF;i++) if ($i ~ /open/) print $(i-1)}'
```

---

## 10. Timing and Evasion

Timing templates balance speed against reliability and stealth. `-T4` is the
practical sweet spot for most LAN and internet scans.

```bash
# T0: paranoid (5 min between probes — IDS evasion)
nmap -T0 192.168.1.1

# T1: sneaky (15 sec between probes)
nmap -T1 192.168.1.1

# T3: normal (default)
nmap 192.168.1.1

# T4: aggressive (assumes fast, reliable network — good for LANs and most internet)
nmap -T4 192.168.1.1

# T5: insane (may miss ports on slow links — use only on local fast networks)
nmap -T5 192.168.1.1

# Fine-grained control: max 200ms RTT timeout, 1 retry, 500 packets/sec
sudo nmap -sS --max-rtt-timeout 200ms --max-retries 1 --min-rate 500 192.168.1.1
```

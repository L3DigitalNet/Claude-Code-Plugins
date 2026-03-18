---
name: nmap
description: >
  Network scanner for port scanning, host discovery, service version detection,
  OS fingerprinting, and NSE scripting.
  MUST consult when scanning networks or detecting services.
triggerPhrases:
  - "nmap"
  - "port scan"
  - "host discovery"
  - "network scan"
  - "open ports"
  - "service detection"
  - "OS fingerprint"
  - "nmap script"
globs: []
last_verified: "unverified"
---

## Identity

| Property | Value |
|----------|-------|
| **Binary** | `nmap` |
| **Config** | No persistent config — invoked directly |
| **Logs** | No persistent logs — output to terminal |
| **Type** | CLI tool |
| **Install** | `apt install nmap` / `dnf install nmap` |

## Quick Start

```bash
sudo apt install nmap
nmap -sn 192.168.1.0/24            # ping sweep to discover hosts
nmap -sV 192.168.1.1               # detect service versions on open ports
sudo nmap -sS -T4 192.168.1.1      # fast SYN scan (requires root)
nmap -p 22,80,443 192.168.1.1      # scan specific ports
```

## Key Operations

| Task | Command |
|------|---------|
| Ping sweep a subnet | `nmap -sn 192.168.1.0/24` |
| TCP SYN scan (requires root) | `sudo nmap -sS 192.168.1.1` |
| Full port scan (all 65535 ports) | `nmap -p- 192.168.1.1` |
| Service version detection | `nmap -sV 192.168.1.1` |
| OS detection (requires root) | `sudo nmap -O 192.168.1.1` |
| Aggressive scan (OS + version + scripts + traceroute) | `sudo nmap -A 192.168.1.1` |
| Scan targets from file | `nmap -iL targets.txt` |
| Run NSE script | `nmap --script http-headers 192.168.1.1` |
| UDP scan (requires root, slow) | `sudo nmap -sU 192.168.1.1` |
| Output to normal file | `nmap -oN scan.txt 192.168.1.1` |
| Output to XML | `nmap -oX scan.xml 192.168.1.1` |
| Output to grepable format | `nmap -oG scan.gnmap 192.168.1.1` |
| Timing template (0=paranoid to 5=insane) | `nmap -T4 192.168.1.1` |
| Exclude specific hosts | `nmap 192.168.1.0/24 --exclude 192.168.1.1,192.168.1.254` |
| Scan specific port range | `nmap -p 22,80,443,8080-8090 192.168.1.1` |

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| `Operation not permitted` on SYN scan | `-sS` requires root for raw sockets | Run with `sudo`, or use `-sT` (TCP connect scan) as non-root |
| All ports show `filtered` | Firewall drops packets instead of rejecting | Add `--reason` to see why; `filtered` means no response received (timeout); try `-Pn` to skip host discovery |
| UDP scan takes hours | UDP has no handshake; nmap waits for timeout on each port | Limit port range: `-sU -p 53,67,123,161`; combine with `-T4` |
| `-T5` misses open ports | Aggressive timing drops responses on slow/loaded hosts | Fall back to `-T4`; add `--max-retries 3` |
| `WARNING: No targets were specified` | Target argument missing or wrong format | Verify subnet notation: `192.168.1.0/24`, not `192.168.1.*` |
| No results despite host being up | Cloud provider firewall blocks at network level before host | Check provider security groups/ACLs; nmap cannot scan through cloud-level firewalls |
| NSE script triggers IDS alert | Intrusive scripts generate anomalous traffic | Use `--script-args=safe` or select only safe category scripts: `--script safe` |

## Pain Points

- **SYN scan requires root**: `-sS` is nmap's default and fastest scan, but it needs raw socket access. Non-root users fall back to `-sT` (full TCP connect), which is slower and more easily logged by targets.
- **UDP is fundamentally slow**: UDP ports only respond when closed (ICMP port-unreachable) or when the service replies. Open UDP ports are silent. nmap must wait out the full timeout for each open port. Scanning all 65535 UDP ports on one host can take hours.
- **Drop vs. reject ambiguity**: Firewalls that silently drop packets cause nmap to wait for the full timeout per port before marking it `filtered`. A `rejected` port (ICMP unreachable or TCP RST) resolves in milliseconds. A scan against a well-firewalled host is orders of magnitude slower than one against an open network.
- **-T5 reliability**: The `insane` timing template can cause missed ports on any link with latency above ~50ms or moderate packet loss. `-T4` is the practical maximum for reliable results on internet-facing scans.
- **NSE script scope creep**: Scripts in the `intrusive`, `exploit`, or `vuln` categories actively probe services in ways that may crash unstable software, trigger alerts, or constitute unauthorized access on systems you don't own. Always review what a script does before running it.
- **Cloud network firewalls are invisible**: AWS security groups, GCP firewall rules, and Azure NSGs operate at the hypervisor level. nmap scanning from outside sees a wall of `filtered` regardless of what the OS firewall allows — and the host never sees the packets.

## See Also

- **ss** — list listening ports and established connections on the local host without scanning
- **tcpdump** — capture and inspect packets to understand what nmap is sending and receiving
- **mtr** — trace the network path to a target to diagnose routing or latency issues before scanning

## References
See `references/` for:
- `cheatsheet.md` — task-organized command reference
- `docs.md` — official documentation links

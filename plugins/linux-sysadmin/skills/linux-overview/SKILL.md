---
name: linux-overview
description: >
  Third-person: Linux service and tool discovery for users who don't know
  the specific tool name. Helps identify the right software for web serving,
  DNS, databases, monitoring, VPN, backup, containers, filesystems, and
  other infrastructure needs. Triggers on broad queries like "web server",
  "database", "what should I use for", "monitoring solution", "backup tool",
  "VPN", "firewall", "reverse proxy", "file system", "container runtime",
  "set up a server", "which tool", "recommend", "alternatives to".
---

When the user asks a broad infrastructure question without naming a specific tool, use this index to present relevant options. Keep recommendations brief; point to the per-service skill for depth.

## Web / Reverse Proxy

| Tool | Best for |
|------|----------|
| **nginx** | High-performance reverse proxy, static files, mature ecosystem |
| **Caddy** | Auto-HTTPS, simplest config; good default for homelabs and small deployments |
| **Apache** | .htaccess support, shared hosting compat, mod_php legacy apps |
| **Traefik** | Container-native reverse proxy; auto-discovers Docker/Kubernetes services |
| **HAProxy** | Pure TCP/HTTP load balancer with the highest throughput |

## Containers / Virtualization

| Tool | Best for |
|------|----------|
| **Docker** | Industry standard container runtime |
| **Docker Compose** | Multi-container app definitions in YAML |
| **Podman** | Rootless, daemonless Docker alternative; same CLI |
| **Proxmox VE** | Full virtualization platform (KVM VMs + LXC containers) with a web UI |
| **LXC/LXD** | System containers; lightweight VMs without full hypervisor overhead |

## DNS

| Tool | Best for |
|------|----------|
| **Pi-hole** | Network-wide ad blocking via DNS sinkhole |
| **unbound** | Recursive resolver; pairs with Pi-hole for privacy-focused full-stack DNS |
| **dnsmasq** | Lightweight DNS + DHCP combo for small networks |
| **BIND9** | Authoritative DNS with zone management; enterprise scale |
| **CoreDNS** | Kubernetes-native DNS; plugin-based and extensible |

## Security / Firewall

| Tool | Best for |
|------|----------|
| **ufw** | Simple iptables frontend; good default for single-host firewalls |
| **firewalld/nftables** | Zone-based firewall; default on RHEL/Fedora |
| **fail2ban** | Bans IPs after repeated auth failures; essential for SSH |
| **CrowdSec** | Collaborative threat intelligence; community-driven IP blocklists |
| **WireGuard** | Modern VPN; simple config, fast, kernel-level performance |
| **OpenVPN** | Mature VPN; wider client compat than WireGuard |
| **Tailscale** | Zero-config mesh VPN built on WireGuard; no port forwarding needed |

## Databases

| Tool | Best for |
|------|----------|
| **PostgreSQL** | Full-featured relational DB; default choice for new projects |
| **MariaDB/MySQL** | WordPress, legacy apps, wide hosting support |
| **Redis** | In-memory key-value store; caching, sessions, queues |
| **SQLite** | Embedded DB; single-file, zero config, great for small apps and dev |

## Monitoring

| Tool | Best for |
|------|----------|
| **Prometheus** | Metrics collection and alerting; pull-based, PromQL queries |
| **Grafana** | Dashboards and visualization; works with Prometheus, Loki, and others |
| **Node Exporter** | System metrics exporter for Prometheus (CPU, RAM, disk, network) |
| **Loki** | Log aggregation; Grafana's companion for logs (like Prometheus but for text) |
| **Netdata** | Real-time monitoring with zero config; lightweight, good for homelabs |

## System Services

| Tool | Best for |
|------|----------|
| **systemd** | Init system, service management, timers, journaling |
| **journald/journalctl** | Structured system log querying |
| **cron / systemd-timers** | Scheduled task execution |
| **logrotate** | Automatic log file rotation and compression |
| **chrony** | NTP time synchronization (replaced ntpd on most distros) |
| **OpenSSH** | Remote access, tunneling, key-based auth |

## Storage / Backup

| Tool | Best for |
|------|----------|
| **rsync** | Efficient file sync and incremental backup |
| **Borg** | Deduplicated, encrypted backup with versioning |
| **Rclone** | Cloud storage sync (S3, GDrive, Backblaze, 70+ backends) |

## Filesystems

| Filesystem | Best for |
|------------|----------|
| **ZFS** | Snapshots, checksums, RAID-Z, send/receive replication; needs RAM |
| **Btrfs** | Copy-on-write snapshots, built into Linux kernel, subvolumes |
| **ext4** | Rock-solid default; best compat, lowest overhead, widest tooling |
| **XFS** | Large files, high throughput; default on RHEL |
| **LVM** | Logical volume management; resize, snapshot, span disks |
| **mdadm** | Software RAID (mirror, stripe, RAID-5/6) below any filesystem |
| **exFAT/NTFS** | External drives shared with Windows/macOS |

## Network Services

| Tool | Best for |
|------|----------|
| **NFS** | Linux-to-Linux file sharing; simple, fast |
| **Samba** | SMB/CIFS file sharing; Windows/macOS interop |
| **DHCP (isc-dhcp)** | IP address assignment for local networks |
| **Avahi** | mDNS/zeroconf; `.local` hostname resolution without DNS |

## Mail

| Tool | Best for |
|------|----------|
| **Postfix** | MTA (sending/receiving mail); reliable, well-documented |
| **Dovecot** | IMAP/POP3 server; mailbox access |
| **OpenDKIM** | DKIM signing for outbound mail authentication |

## Self-Hosted Apps

| App | Best for |
|-----|----------|
| **Nextcloud** | File sync, calendar, contacts; self-hosted Google Drive/Office alternative |
| **Gitea/Forgejo** | Lightweight self-hosted Git with web UI |
| **Vaultwarden** | Self-hosted Bitwarden-compatible password manager |
| **Jellyfin** | Media streaming (movies, TV, music); open source Plex alternative |
| **Immich** | Self-hosted Google Photos alternative with ML-powered organization |

## IoT / Home Automation

| Tool | Best for |
|------|----------|
| **Mosquitto** | Lightweight MQTT broker for IoT messaging |
| **Zigbee2MQTT** | Bridge Zigbee devices to MQTT without vendor hubs |
| **Z-Wave JS** | Z-Wave device control via JS driver |
| **Node-RED** | Visual flow-based automation; connects APIs, services, and hardware |

## Certificates

| Tool | Best for |
|------|----------|
| **Certbot** | Free HTTPS certificates from Let's Encrypt; auto-renewal |
| **step-ca** | Internal/private certificate authority for homelab or org |

## CLI Monitoring Tools

| Tool | Best for |
|------|----------|
| **btop** | Modern interactive process/resource monitor (replaces htop for many) |
| **htop/top** | Classic interactive process viewer |
| **glances** | All-in-one system overview (CPU, RAM, disk, network, containers) |
| **iotop** | I/O usage by process |
| **vmstat** | Virtual memory, CPU, and I/O statistics snapshot |
| **iostat** | Disk I/O throughput and latency |

## Network Diagnostics

| Tool | Best for |
|------|----------|
| **nmap** | Port scanning, host discovery, service detection |
| **iperf3** | Network bandwidth testing between two hosts |
| **ss/netstat** | Current network connections and listening ports |
| **tcpdump** | Packet capture and analysis |
| **mtr** | Combined traceroute + ping with per-hop statistics |
| **dig/nslookup/host** | DNS query tools (bind-utils package) |

## Disk / Storage Tools

| Tool | Best for |
|------|----------|
| **df** | Disk space usage per filesystem |
| **ncdu** | Interactive disk usage browser (find what's eating space) |
| **lsblk** | Block device listing (disks, partitions, mount points) |
| **smartctl** | Drive health monitoring via S.M.A.R.T. data |
| **fdisk/parted** | Partition table creation and management |

## Process / Debug

| Tool | Best for |
|------|----------|
| **strace** | Trace system calls made by a process |
| **lsof** | List open files and the processes using them |
| **perf** | CPU performance profiling and analysis |
| **dmesg** | Kernel ring buffer messages (hardware, driver events) |

## Text / Data

| Tool | Best for |
|------|----------|
| **jq** | JSON parsing and transformation from the command line |
| **ripgrep** | Fast recursive text search (better grep) |
| **awk/sed** | Stream-based text processing and transformation |
| **column** | Format text into aligned columns |

## Misc Utilities

| Tool | Best for |
|------|----------|
| **curl/wget** | HTTP requests and file downloads |
| **tmux** | Terminal multiplexer; persistent sessions, splits, detach/reattach |
| **openssl** | Certificate inspection, key generation, encryption testing |
| **age** | Simple file encryption (modern GPG alternative) |
| **ssh-keygen** | SSH key pair generation and management |

# Design: `linux-sysadmin` Plugin

**Date:** 2026-03-01
**Replaces:** `linux-sysadmin-mcp` (TypeScript MCP server)
**Approach:** Pure markdown skills — no build step, no MCP server

## Motivation

The existing `linux-sysadmin-mcp` plugin wraps shell commands in an MCP server that provides structured output, knowledge profiles, and safety gating. Analysis showed that Claude's Bash tool + skill-provided knowledge achieves the same outcomes with zero infrastructure overhead. The MCP server's 18 remaining tools (after an earlier cull of 18 redundant ones) reduce to skills that give Claude the same knowledge directly.

## Architecture

One plugin containing:

| Component | Count | Purpose |
|-----------|-------|---------|
| Discovery skill | 1 | `linux-overview`: broad triggers, categorized index of all tools/services |
| Service skills | ~30 | nginx, sshd, Docker, PostgreSQL, etc. |
| CLI tool skills | ~25 | nmap, btop, strace, tcpdump, etc. |
| Filesystem skills | ~7 | ZFS, Btrfs, ext4, XFS, LVM, mdadm, exFAT/NTFS |
| Other skills | ~13 | systemd, cron, Certbot, self-hosted apps, IoT |
| Command | 1 | `/sysadmin`: guided system architecture workflow |
| Reference files | ~150+ | Annotated configs, cheatsheets, property refs, doc links |

### Plugin Structure

```
plugins/linux-sysadmin/
├── .claude-plugin/
│   └── plugin.json
├── commands/
│   └── sysadmin.md
├── skills/
│   ├── linux-overview/
│   │   └── SKILL.md
│   ├── nginx/
│   │   ├── SKILL.md
│   │   └── references/
│   │       ├── nginx.conf.annotated
│   │       ├── common-patterns.md
│   │       └── docs.md
│   ├── docker/
│   │   ├── SKILL.md
│   │   └── references/
│   │       ├── daemon.json.annotated
│   │       ├── dockerfile-patterns.md
│   │       ├── compose-patterns.md
│   │       └── docs.md
│   ├── zfs/
│   │   ├── SKILL.md
│   │   └── references/
│   │       ├── zfs-properties.md
│   │       ├── common-operations.md
│   │       └── docs.md
│   ├── nmap/
│   │   ├── SKILL.md
│   │   └── references/
│   │       ├── cheatsheet.md
│   │       └── docs.md
│   └── ...
├── README.md
└── CHANGELOG.md
```

### Skill Triggering

- **Discovery skill** (`linux-overview`): triggers on broad terms ("web server", "database", "what should I use for", "monitoring", "backup solution")
- **Service skills**: trigger on service name + closely related keywords (e.g., nginx skill triggers on "nginx", "reverse proxy", "vhost")
- **CLI tool skills**: trigger on tool name + task keywords (e.g., nmap triggers on "nmap", "port scan", "network scan")
- **Filesystem skills**: trigger on filesystem name + related operations (e.g., ZFS triggers on "zfs", "zpool", "zfs snapshot")

Skills only enter context when triggered. Installing ~75 skills has zero cost until a relevant query arrives.

## Skill Formats

### Service Skill Template

Sections: Identity (unit, config paths, logs, user), Key Operations (validate, reload, test), Expected Ports, Health Checks, Common Failures (table: symptom/cause/check), Pain Points, References pointer.

Target length: 100-200 lines.

### CLI Tool Skill Template

Sections: Install (per-distro), Essential Invocations (table: goal/command), Output Interpretation, Gotchas, References pointer.

Target length: 60-120 lines.

### Filesystem Skill Template

Sections: Core Concepts, Key Commands (table: operation/command), Important Properties (table: property/values/default/notes), Gotchas, References pointer.

Target length: 80-150 lines.

## Reference File Formats

### Annotated Config Files (`*.annotated`)

Complete default config with every directive commented. Each option includes: what it does, default value, recommended value, and when to change it. Named after the actual config file (e.g., `nginx.conf.annotated`, `daemon.json.annotated`).

### Invocation Cheatsheets (`cheatsheet.md`)

For CLI tools. Organized by task (not alphabetically). Tables with command + what it does. Includes output format options where relevant.

### Property/Operations References

For filesystems and tools with extensive option sets. Tables with property/values/default/notes. Separate file for common operations with step-by-step commands.

### Documentation Links (`docs.md`)

Every skill gets one. Sections: Official (reference docs, guides), Community (tutorials, generators), Man pages. Links only, no duplicated content.

## `/sysadmin` Command

Interactive guided workflow for system architecture. Phases:

1. **Purpose**: homelab, VPS, dedicated server, dev machine, edge gateway
2. **Requirements**: multi-select capabilities (web, DB, DNS, VPN, monitoring, backups, containers, mail, file sharing, media, home automation, CI/CD)
3. **Security posture**: minimal (home network), moderate (some exposed), hardened (public-facing)
4. **Constraints**: existing stack, distro, hardware limits
5. **Experience level**: adjusts recommendation complexity (Caddy vs nginx, docker-compose vs bare-metal)
6. **Output**: recommended stack with rationale, ordered setup sequence, offer to deep-dive into any component

The command does not execute setup. It consults, recommends, and hands off to individual skills.

## Service/Tool/Filesystem Inventory

### Web / Proxy
nginx, Apache (httpd), Caddy, Traefik, HAProxy

### Containers / Virtualization
Docker, Docker Compose, Podman, Proxmox VE, LXC/LXD

### DNS
unbound, Pi-hole, BIND9, dnsmasq, CoreDNS

### Security / Firewall
ufw, firewalld/nftables, fail2ban, CrowdSec, WireGuard, OpenVPN, Tailscale

### Databases
PostgreSQL, MariaDB/MySQL, Redis, SQLite

### Monitoring
Prometheus, Grafana, Node Exporter, Loki, Netdata

### System Services
systemd, journald/journalctl, cron + systemd-timers, logrotate, chrony/NTP, OpenSSH (sshd)

### Storage / Backup
rsync, Borg, Rclone

### Filesystems
ZFS, Btrfs, ext4, XFS, LVM, mdadm/RAID, exFAT/NTFS

### Network Services
NFS, Samba (SMB), DHCP (isc-dhcp-server), Avahi (mDNS)

### Mail
Postfix, Dovecot, OpenDKIM

### Self-Hosted Apps
Nextcloud, Gitea/Forgejo, Vaultwarden, Jellyfin, Immich

### IoT / Home Automation
Mosquitto (MQTT), Zigbee2MQTT, Z-Wave JS, Node-RED

### Certificates
Certbot (Let's Encrypt), step-ca

### System Monitoring Tools
btop, htop/top, glances, iotop, vmstat, iostat

### Network Diagnostics
nmap, iperf3, ss/netstat, tcpdump, mtr, dig/bind-utils (nslookup, host)

### Disk Tools
df, ncdu, lsblk, smartctl, fdisk/parted

### Process / Debug
strace, lsof, perf, dmesg

### Text / Data
jq, ripgrep, awk/sed, column

### Misc Utilities
curl/wget, tmux, openssl (CLI), age, ssh-keygen

**Total: ~75 skills + 1 discovery skill + 1 command**

## Migration Plan

1. Delete `plugins/linux-sysadmin-mcp/` entirely
2. Remove its entry from `.claude-plugin/marketplace.json`
3. Remove its CI workflow from `.github/workflows/`
4. Create `plugins/linux-sysadmin/` with new structure
5. Add new marketplace entry for `linux-sysadmin`
6. No new CI needed (markdown-only plugin)

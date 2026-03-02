# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [1.0.0] - 2026-03-01

### Added

- 94 per-service skills across all categories: web/proxy, containers, DNS, security/VPN,
  databases, system services, monitoring, filesystems, storage/backup, network services,
  mail, self-hosted apps, IoT/home automation, certificates, CLI monitoring tools, network
  diagnostics, disk/storage tools, process/debug tools, text/data tools, and misc utilities
- Each skill includes: Key Operations table, Health Checks, Common Failures table, Pain Points,
  annotated config files (daemons) or task-organized cheatsheets (CLI tools), and doc links
- Annotated configs for: nginx, sshd, fail2ban, ufw, wireguard, openvpn, apache, caddy,
  bind9, dnsmasq, postgresql, mariadb, redis, systemd, cron, chrony, lvm, mdadm, samba,
  dhcp, dovecot, opendkim, postfix, mosquitto, zigbee2mqtt, node-red, and more
- Docker Compose annotated files for: Nextcloud, Gitea, Vaultwarden, Jellyfin, Immich
- Filesystem property references for: ZFS, Btrfs, ext4, XFS, exFAT/NTFS
- Task-organized cheatsheets for: rsync, borg, rclone, nmap, tcpdump, tmux, jq, and more

## [0.1.0] - 2026-03-01

### Added

- Plugin scaffold with discovery skill and `/sysadmin` guided workflow command
- `linux-overview` discovery skill: categorized index of all services, tools, and filesystems
- `/sysadmin` command: interactive system architecture interview with stack recommendations
- Design document and implementation plan for ~75 service/tool/filesystem skills

### Removed

- Replaced `linux-sysadmin-mcp` (TypeScript MCP server with 18 tools) with pure-markdown skills approach

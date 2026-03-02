# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [1.1.0] - 2026-03-02

### Added
- `ansible` skill: playbooks, inventory, ad-hoc commands, roles, vault, galaxy, and ansible-lint
  with annotated `ansible.cfg`, annotated playbook, common patterns, and docs references
- `restic` skill: repository management, backup, restore, forget/prune, FUSE mount, and all
  major backends (local, SFTP, S3/MinIO, Backblaze B2, REST server) with cheatsheet, common
  patterns including systemd timer automation, and docs references
- `skill-inventory-and-gaps.md`: comprehensive gap analysis of existing 95 skills with 40+
  candidates tiered by priority for future development

## [1.0.0] - 2026-03-02

### Added
- Phase 19 — text, data, and misc CLI tool skills (8 tools)
- Phase 18 — disk and process debug tool skills (9 tools)
- Phase 17 — network diagnostic tool skills (6 tools)
- Phase 16 — CLI monitoring tool skills (6 tools)
- Phase 11 — network service skills (4 services)
- Phase 15 — certificate management skills (2 tools)
- Phase 14 — IoT and home automation skills (4 services)
- Phase 13 — self-hosted app skills (5 apps)
- Phase 12 — mail server skills (3 services)
- Phase 10 — storage and backup skills (3 tools)
- Phase 9 — filesystem skills (7 filesystems)
- Phase 8 — monitoring skills (5 services)
- Phase 7 — container and virtualization skills (3 platforms)
- Phase 6 — system service skills (5 services)
- Phase 5 — database skills (4 services)
- Phase 4 — web/proxy and DNS skills (7 services)
- Phase 3 — security and VPN skills (5 services)
- Phase 2 — core service skills (8 services)
- replace MCP server with skills-based plugin

### Changed
- update all documentation for v1.0.0
- v1.0.0 — 94 skills complete

### Fixed
- commit lingering openvpn reference file changes


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

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [1.1.0] - 2026-03-04

### Added
- add ansible and restic skills (v1.1.0)

### Changed
- update org references from L3Digital-Net to L3DigitalNet
- add skill gap analysis and ansible+restic design doc

### Fixed
- apply audit findings — CHANGELOG, README, sysadmin command


## [Unreleased]

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
- 95 per-service skills across all categories: web/proxy, containers, DNS, security/VPN,
  databases, system services, monitoring, filesystems, storage/backup, network services,
  mail, self-hosted apps, IoT/home automation, certificates, CLI monitoring tools, network
  diagnostics, disk/storage tools, process/debug tools, text/data tools, and misc utilities
- `iperf3` skill: network throughput and bandwidth testing with cheatsheet and docs references
- Each skill includes: Key Operations table, Health Checks, Common Failures table, Pain Points,
  annotated config files (daemons) or task-organized cheatsheets (CLI tools), and doc links
- Annotated configs for: nginx, sshd, fail2ban, ufw, wireguard, openvpn, apache, caddy,
  bind9, dnsmasq, postgresql, mariadb, redis, systemd, cron, chrony, lvm, mdadm, samba,
  dhcp, dovecot, opendkim, postfix, mosquitto, zigbee2mqtt, node-red, and more
- Docker Compose annotated files for: Nextcloud, Gitea, Vaultwarden, Jellyfin, Immich
- Filesystem property references for: ZFS, Btrfs, ext4, XFS, exFAT/NTFS
- Task-organized cheatsheets for: rsync, borg, rclone, nmap, tcpdump, tmux, jq, and more
- Replace MCP server with skills-based plugin (no build step, no runtime process)

### Changed
- Updated all documentation for v1.0.0

### Fixed
- Committed lingering OpenVPN reference file changes

## [0.1.0] - 2026-03-01

### Added

- Plugin scaffold with discovery skill and `/sysadmin` guided workflow command
- `linux-overview` discovery skill: categorized index of all services, tools, and filesystems
- `/sysadmin` command: interactive system architecture interview with stack recommendations
- Design document and implementation plan for ~75 service/tool/filesystem skills

### Removed

- Replaced `linux-sysadmin-mcp` (TypeScript MCP server with 18 tools) with pure-markdown skills approach

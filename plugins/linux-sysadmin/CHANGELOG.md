# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [2.1.1] - 2026-04-09

### Changed
- update all references from 137 to 163 guides


## [2.1.0] - 2026-03-27

### Added
- add 26 new guides, version tracking on all 163


## [2.0.0] - 2026-03-26

### Changed
- **Architecture: single dispatcher skill replaces 137 individual skills.** The `sysadmin` skill contains a topic index of all 137 services and loads the right guide file on demand. This eliminates skill list pollution while preserving all service knowledge.
- Skill content moved to `guides/{topic}/guide.md` (YAML frontmatter stripped, content preserved verbatim)
- SessionStart hook now references the single `linux-sysadmin:sysadmin` skill
- README updated to reflect new architecture

### Removed
- 137 individual per-service skills (replaced by guide files under `guides/`)

## [1.2.0] - 2026-03-18

### Added
- SessionStart hook that detects sysadmin working directories (`/home/chris`, `~/git-luminous3d/homelab`) and injects a context reminder to consult service-specific skills before running installation or configuration commands

### Changed
- All 137 skill descriptions now use assertive "MUST consult when..." trigger language instead of passive descriptions, matching the pattern used by python-dev and home-assistant-dev skills that get invoked reliably
- Service skills: "MUST consult when installing, configuring, or troubleshooting {service}"
- Tool/diagnostic skills: custom verb patterns (e.g., "MUST consult when writing jq expressions...")
- Updated skill count from 97 to 137 in plugin.json and marketplace.json descriptions

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

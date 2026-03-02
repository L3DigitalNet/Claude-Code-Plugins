# Implementation Plan: `linux-sysadmin` Plugin

**Design doc:** `docs/plans/2026-03-01-linux-sysadmin-design.md`
**Branch:** `testing`

## Scope

~75 service/tool/filesystem skills, 1 discovery skill, 1 command, 150+ reference files. This is multi-session work. The plan is structured so each phase produces a committable, functional increment.

---

## Phase 1: Scaffold and Remove Old Plugin

### Task 1.1: Delete `linux-sysadmin-mcp`
- Remove `plugins/linux-sysadmin-mcp/` directory entirely
- Remove its entry from `.claude-plugin/marketplace.json`
- Remove its CI workflow from `.github/workflows/` (if a dedicated one exists)
- Verify: `git status` shows deletions only

### Task 1.2: Create plugin scaffold
- Create `plugins/linux-sysadmin/.claude-plugin/plugin.json`
- Create `plugins/linux-sysadmin/README.md` (from template, fill required sections)
- Create `plugins/linux-sysadmin/CHANGELOG.md`
- Verify: `./scripts/validate-marketplace.sh` passes after adding marketplace entry

### Task 1.3: Add marketplace entry
- Add `linux-sysadmin` entry to `.claude-plugin/marketplace.json`
- Run `./scripts/validate-marketplace.sh`
- Verify: passes

### Task 1.4: Create discovery skill (`linux-overview`)
- Create `plugins/linux-sysadmin/skills/linux-overview/SKILL.md`
- Categorized index of all ~75 tools/services with one-line "best for" descriptions
- Broad trigger phrases: "web server", "database", "what should I use for", "monitoring", etc.
- Verify: file exists, frontmatter valid

### Task 1.5: Create `/sysadmin` command
- Create `plugins/linux-sysadmin/commands/sysadmin.md`
- Guided interview workflow: purpose → requirements → constraints → experience → stack recommendation
- Uses `AskUserQuestion` for structured choices
- Verify: file exists, frontmatter valid

### Task 1.6: Commit Phase 1
- Commit all changes with descriptive message
- Verify: `git status` clean

---

## Phase 2: Core Service Skills (from existing MCP profiles)

These 8 services had YAML profiles in the old MCP plugin. Migrate the knowledge.

### Task 2.1: nginx skill + references
- `skills/nginx/SKILL.md` — identity, operations, ports, health checks, failures, pain points
- `skills/nginx/references/nginx.conf.annotated` — full annotated default config
- `skills/nginx/references/common-patterns.md` — vhost, reverse proxy, load balancer, SSL
- `skills/nginx/references/docs.md` — official + community doc links

### Task 2.2: sshd skill + references
- `skills/sshd/SKILL.md`
- `skills/sshd/references/sshd_config.annotated`
- `skills/sshd/references/hardening.md` — key-only auth, fail2ban integration, port changes
- `skills/sshd/references/docs.md`

### Task 2.3: docker skill + references
- `skills/docker/SKILL.md`
- `skills/docker/references/daemon.json.annotated`
- `skills/docker/references/dockerfile-patterns.md`
- `skills/docker/references/docs.md`

### Task 2.4: docker-compose skill + references
- `skills/docker-compose/SKILL.md`
- `skills/docker-compose/references/compose-patterns.md` — multi-service, networking, volumes, healthchecks
- `skills/docker-compose/references/docs.md`

### Task 2.5: ufw skill + references
- `skills/ufw/SKILL.md`
- `skills/ufw/references/common-rules.md` — allow/deny patterns, app profiles, logging
- `skills/ufw/references/docs.md`

### Task 2.6: fail2ban skill + references
- `skills/fail2ban/SKILL.md`
- `skills/fail2ban/references/jail.local.annotated`
- `skills/fail2ban/references/custom-filters.md`
- `skills/fail2ban/references/docs.md`

### Task 2.7: pihole skill + references
- `skills/pihole/SKILL.md`
- `skills/pihole/references/setup-vars.md` — configuration reference
- `skills/pihole/references/docs.md`

### Task 2.8: unbound skill + references
- `skills/unbound/SKILL.md`
- `skills/unbound/references/unbound.conf.annotated`
- `skills/unbound/references/docs.md`

### Task 2.9: Commit Phase 2

---

## Phase 3: Security and Networking Skills

### Task 3.1: crowdsec skill + references
### Task 3.2: firewalld skill + references
### Task 3.3: wireguard skill + references
### Task 3.4: openvpn skill + references
### Task 3.5: tailscale skill + references
### Task 3.6: Commit Phase 3

---

## Phase 4: Web / Proxy and DNS Skills

### Task 4.1: apache skill + references
### Task 4.2: caddy skill + references
### Task 4.3: traefik skill + references
### Task 4.4: haproxy skill + references
### Task 4.5: bind9 skill + references
### Task 4.6: dnsmasq skill + references
### Task 4.7: coredns skill + references
### Task 4.8: Commit Phase 4

---

## Phase 5: Databases

### Task 5.1: postgresql skill + references
### Task 5.2: mariadb skill + references
### Task 5.3: redis skill + references
### Task 5.4: sqlite skill + references
### Task 5.5: Commit Phase 5

---

## Phase 6: System Services

### Task 6.1: systemd skill + references
### Task 6.2: journald skill + references
### Task 6.3: cron skill + references (include cron expression calculator pattern)
### Task 6.4: logrotate skill + references
### Task 6.5: chrony skill + references
### Task 6.6: Commit Phase 6

---

## Phase 7: Containers and Virtualization

### Task 7.1: podman skill + references
### Task 7.2: proxmox skill + references
### Task 7.3: lxc-lxd skill + references
### Task 7.4: Commit Phase 7

---

## Phase 8: Monitoring

### Task 8.1: prometheus skill + references
### Task 8.2: grafana skill + references
### Task 8.3: node-exporter skill + references
### Task 8.4: loki skill + references
### Task 8.5: netdata skill + references
### Task 8.6: Commit Phase 8

---

## Phase 9: Filesystems

### Task 9.1: zfs skill + references (properties, operations, send/receive)
### Task 9.2: btrfs skill + references
### Task 9.3: ext4 skill + references
### Task 9.4: xfs skill + references
### Task 9.5: lvm skill + references
### Task 9.6: mdadm skill + references
### Task 9.7: exfat-ntfs skill + references
### Task 9.8: Commit Phase 9

---

## Phase 10: Storage and Backup

### Task 10.1: rsync skill + references
### Task 10.2: borg skill + references
### Task 10.3: rclone skill + references
### Task 10.4: Commit Phase 10

---

## Phase 11: Network Services

### Task 11.1: nfs skill + references
### Task 11.2: samba skill + references
### Task 11.3: dhcp skill + references
### Task 11.4: avahi skill + references
### Task 11.5: Commit Phase 11

---

## Phase 12: Mail

### Task 12.1: postfix skill + references
### Task 12.2: dovecot skill + references
### Task 12.3: opendkim skill + references
### Task 12.4: Commit Phase 12

---

## Phase 13: Self-Hosted Apps

### Task 13.1: nextcloud skill + references
### Task 13.2: gitea skill + references
### Task 13.3: vaultwarden skill + references
### Task 13.4: jellyfin skill + references
### Task 13.5: immich skill + references
### Task 13.6: Commit Phase 13

---

## Phase 14: IoT / Home Automation

### Task 14.1: mosquitto skill + references
### Task 14.2: zigbee2mqtt skill + references
### Task 14.3: zwave-js skill + references
### Task 14.4: node-red skill + references
### Task 14.5: Commit Phase 14

---

## Phase 15: Certificates

### Task 15.1: certbot skill + references
### Task 15.2: step-ca skill + references
### Task 15.3: Commit Phase 15

---

## Phase 16: System Monitoring CLI Tools

### Task 16.1: btop skill + references
### Task 16.2: htop skill + references
### Task 16.3: glances skill + references
### Task 16.4: iotop skill + references
### Task 16.5: vmstat skill + references
### Task 16.6: iostat skill + references
### Task 16.7: Commit Phase 16

---

## Phase 17: Network Diagnostic CLI Tools

### Task 17.1: nmap skill + references
### Task 17.2: iperf3 skill + references
### Task 17.3: ss-netstat skill + references
### Task 17.4: tcpdump skill + references
### Task 17.5: mtr skill + references
### Task 17.6: bind-utils skill + references (dig, nslookup, host)
### Task 17.7: Commit Phase 17

---

## Phase 18: Disk and Debug CLI Tools

### Task 18.1: df skill + references
### Task 18.2: ncdu skill + references
### Task 18.3: lsblk skill + references
### Task 18.4: smartctl skill + references
### Task 18.5: fdisk-parted skill + references
### Task 18.6: strace skill + references
### Task 18.7: lsof skill + references
### Task 18.8: perf skill + references
### Task 18.9: dmesg skill + references
### Task 18.10: Commit Phase 18

---

## Phase 19: Text/Data and Misc CLI Tools

### Task 19.1: jq skill + references
### Task 19.2: ripgrep skill + references
### Task 19.3: awk-sed skill + references
### Task 19.4: curl-wget skill + references
### Task 19.5: tmux skill + references
### Task 19.6: openssl-cli skill + references
### Task 19.7: age skill + references
### Task 19.8: ssh-keygen skill + references
### Task 19.9: Commit Phase 19

---

## Phase 20: Final Polish

### Task 20.1: Review README.md for completeness
### Task 20.2: Run marketplace validation
### Task 20.3: Final commit
### Task 20.4: Merge to main when ready

---
allowed-tools: AskUserQuestion, Read, Glob, Grep, Bash
description: Guided system architecture interview — identify needs and recommend a complete server stack
argument-hint: "[purpose]  (e.g., 'homelab media server', 'production web app')"
---

# System Architecture Workflow

Walk the user through designing a Linux server stack. Ask structured questions to understand their needs, then recommend specific tools with rationale and an ordered setup sequence.

If the user provided an argument (e.g., `/sysadmin homelab media server`), skip Phase 1 and use it as the stated purpose.

## Phase 1 — Purpose

Use `AskUserQuestion` with these options:

**"What kind of system are you building?"**
- Homelab / self-hosted services (home network, personal use)
- Production VPS or cloud VM (public-facing, reliability matters)
- Dedicated / bare metal server (full control, maximum performance)
- Development machine (local dev, CI, testing)
- Edge device or IoT gateway (Raspberry Pi, constrained hardware)

## Phase 2 — Capabilities

Use `AskUserQuestion` with `multiSelect: true`:

**"Which capabilities do you need?"**
- Web serving / reverse proxy
- Databases
- DNS / ad blocking
- VPN / remote access
- Monitoring / alerting
- Backup / disaster recovery
- Containers / virtualization
- File sharing (NFS/Samba)
- Media streaming
- Home automation / IoT
- Mail server
- CI/CD
- Certificate management

## Phase 3 — Constraints

Use `AskUserQuestion` for each:

**"What OS/distro?"**
- Ubuntu / Debian
- Fedora / RHEL / AlmaLinux
- Arch Linux
- Already decided (specify)
- Need a recommendation

**"Security posture?"**
- Minimal (home network only, no exposed services)
- Moderate (some services exposed, basic hardening)
- Hardened (public-facing, active threat mitigation)

**"Any existing stack to work around?"**
- Starting fresh
- Already running Docker / Podman
- Already running Proxmox
- Other (specify)

**"Hardware constraints?"**
- No constraints (plenty of RAM/CPU/storage)
- Limited RAM (< 4 GB, e.g., Raspberry Pi)
- Limited storage (< 100 GB)
- Other (specify)

## Phase 4 — Experience Calibration

Use `AskUserQuestion`:

**"Linux admin experience?"**
- New to Linux (recommend simpler tools with good defaults)
- Comfortable (standard tools are fine)
- Experienced (give me the most capable options)

This affects recommendations:
- **New**: Caddy over nginx, Docker Compose over bare-metal, ufw over nftables, Netdata over Prometheus+Grafana
- **Comfortable**: Standard choices with clear docs
- **Experienced**: Full-featured options, performance-oriented, manual config expected

## Phase 5 — Stack Recommendation

Based on the answers, produce a recommendation structured as:

```
## Recommended Stack: [Purpose Summary]

### [Category 1]
**[Tool]** — [One sentence: why this tool for their situation]

### [Category 2]
**[Tool]** — [One sentence: why this tool for their situation]

...

### Setup Order
1. [First thing to install/configure] — [why first]
2. [Second thing] — [dependency on #1]
3. ...

### Security Baseline
- [Key hardening steps for their security posture]

### Backup Strategy
- [What to back up and how]
```

Guidelines for recommendations:
- Recommend ONE tool per category (not "nginx or Caddy"). Be opinionated based on their answers.
- Include rationale tied to their specific constraints and experience.
- The setup order should reflect real dependencies (firewall before exposing services, reverse proxy before app servers, etc.)
- Always include a security baseline section, even for "minimal" posture.
- Always include a backup strategy, even if brief.

## Phase 6 — Deep Dive

After presenting the recommendation:

> "Want to set up any of these? Pick a component and I'll walk you through it."

When the user picks a component, the relevant per-service skill loads naturally. Proceed with hands-on setup guidance using Bash commands informed by the skill's knowledge.

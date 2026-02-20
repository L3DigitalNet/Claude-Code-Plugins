# Linux Sysadmin MCP

A comprehensive Linux system administration MCP server for Claude Code. Provides ~107 tools across 15 modules for managing packages, services, users, firewall, networking, containers, storage, security, performance, logs, cron, backups, SSH, and documentation — all through a unified, distro-agnostic interface.

## Summary

Linux Sysadmin MCP gives Claude Code a structured, risk-aware interface for administering Linux systems. Tools are grouped into modules by domain, classified by risk level, and require explicit confirmation for state-changing operations above a configurable threshold. YAML knowledge profiles encode service-specific expertise (config paths, health checks, restart risks) so Claude can make informed decisions without requiring you to explain your stack each session.

## Principles

**[P1] Composable, Not Monolithic** — Each tool does one thing well. Complex workflows are assembled from atomic tools at runtime, not baked into mega-commands.

**[P2] Universal Knowledge, Not Environment Configuration** — Embedded knowledge contains only facts true for any standard installation of a tool. IP addresses, hostnames, custom scripts, and environment-specific details are the user's responsibility.

**[P3] Documentation-Driven Reproducibility** — Every system Claude administers must be fully reproducible from its documentation alone. Documentation is a first-class output of every state-changing operation — the disaster recovery plan, not an afterthought.

**[P4] Distro-Agnostic** — Abstract over package managers, init systems, firewall backends, and filesystem conventions. Detect and adapt at runtime; never assume a specific distro.

**[P5] Gate Genuine Irreversibility** — Gate only on operations that are truly irreversible at the system level: data destruction, partition changes, user deletion. Routine state-changing operations — service restarts, config edits, package installs — execute on clear intent.

**[P6] Graceful Coexistence** — Detect and defer to existing MCP servers when present. Fill gaps rather than duplicate.

**[P7] Observable** — Every tool returns structured output Claude can reason over. No silent failures; no ambiguous states.

**[P8] Least Privilege** — Request only the permissions needed for the specific operation. Escalate explicitly and visibly.

**[P9] Sudo-First Execution** — All commands requiring elevated privileges are executed via `sudo`. The plugin never assumes it is running as root.

## Installation

```bash
npm install
npm run build
```

Add to Claude Code config (`~/.claude/settings.json` under `mcpServers`):

```json
{
  "mcpServers": {
    "linux-sysadmin": {
      "command": "node",
      "args": ["/path/to/linux-sysadmin-mcp/dist/server.bundle.cjs"]
    }
  }
}
```

## Installation Notes

On first run, a default configuration file is generated at `~/.config/linux-sysadmin/config.yaml`. Review it before first use — particularly `safety.confirmation_threshold` and `documentation.repo_path` if you want git-backed host documentation.

## Usage

Once the MCP server is running, Claude can invoke any of the ~100 tools directly in conversation. Tools that modify system state require `confirmed: true`; use `dry_run: true` to preview changes without applying them.

Example prompts:
- "Show me which services are failing"
- "Install nginx and enable it on boot"
- "Check for SUID binaries and security misconfigurations"
- "Generate a host README for this server"

## Tools

| Module | Count | Example Tools |
|--------|-------|--------------|
| Session | 1 | `sysadmin_session_info` |
| Packages | 10 | `pkg_install`, `pkg_search`, `pkg_rollback` |
| Services | 10 | `svc_status`, `svc_restart`, `svc_logs` |
| Performance | 7 | `perf_overview`, `perf_bottleneck` |
| Logs | 4 | `log_query`, `log_search`, `log_summary` |
| Security | 7 | `sec_audit`, `sec_harden_ssh`, `sec_check_suid` |
| Storage | 8 | `disk_usage`, `mount_add`, `lvm_resize` |
| Users | 10 | `user_create`, `group_list`, `perms_set` |
| Firewall | 6 | `fw_add_rule`, `fw_status`, `fw_enable` |
| Networking | 8 | `net_interfaces`, `net_test`, `net_dns_modify` |
| Containers | 12 | `ctr_list`, `ctr_compose_up`, `ctr_logs` |
| Cron | 5 | `cron_list`, `cron_add`, `cron_validate` |
| Backup | 5 | `bak_create`, `bak_restore`, `bak_schedule` |
| SSH | 6 | `ssh_test_connection`, `ssh_key_generate` |
| Documentation | 8 | `doc_generate_host`, `doc_backup_config` |

## Knowledge Profiles

Built-in YAML profiles for: nginx, sshd, docker, ufw, fail2ban, pihole, unbound, crowdsec.

Profiles provide:
- Config file locations and validation commands
- Health checks (auto-run by `svc_status` and `sec_audit`)
- Port definitions and dependencies
- Risk escalation triggers (e.g., "restarting nginx drops connections")
- Troubleshooting guides

Add custom profiles to `~/.config/linux-sysadmin/profiles/` or configure `knowledge.additional_paths`.

## Safety System

Every state-changing tool has a risk level: `read-only` → `low` → `moderate` → `high` → `critical`.

Operations at or above the configured threshold (default: `moderate`) require explicit `confirmed: true`. Knowledge profiles can escalate risk (e.g., restarting a database service escalates from moderate to high).

All destructive tools support `dry_run: true` to preview changes.

## Configuration

`~/.config/linux-sysadmin/config.yaml` — auto-generated on first run. Key settings:

```yaml
safety:
  confirmation_threshold: moderate    # Gate level
  dry_run_bypass_confirmation: true   # dry_run skips gate

documentation:
  repo_path: /path/to/infra-docs     # Git repo for host docs
  auto_suggest: true                  # Suggest doc updates after changes
```

## Requirements

- Node.js 20+
- Linux system (Debian/RHEL-based; other distros may have limited tool support)
- `sudo` access for state-changing tools (the server never assumes root)

## Architecture

```
┌──────────────────────────────────────────┐
│           MCP Server (stdio)             │
├──────────────────────────────────────────┤
│         Tool Registry (~100 tools)       │
├──────┬───────┬───────┬───────┬───────────┤
│ Pkgs │ Svcs  │ Users │ Fire  │ Net  │... │
├──────┴───────┴───────┴───────┴───────────┤
│   Safety Gate  │  Knowledge Base (YAML)  │
├────────────────┼─────────────────────────┤
│ DistroCommands │  Executor (local/SSH)   │
│ (Debian/RHEL)  │                         │
└────────────────┴─────────────────────────┘
```

## Design Principles

1. **Composable, not monolithic** — Atomic tools that Claude composes into workflows
2. **Universal tool knowledge** — YAML knowledge profiles describe services, not environments
3. **Documentation-driven reproducibility** — Git-backed host/service READMEs for disaster recovery
4. **Distro-agnostic** — Automatic Debian/RHEL detection with unified command abstraction
5. **Safety by default** — Risk-classified tools with confirmation gates and dry-run support
6. **Graceful coexistence** — Works alongside other MCP servers
7. **Observable** — Structured JSON responses with consistent envelope
8. **Least privilege** — Degrades gracefully without sudo
9. **Sudo-first** — Never assumes root; always uses explicit sudo

## Response Format

Every tool returns a consistent JSON envelope:

```json
{
  "status": "success|error|blocked|confirmation_required",
  "tool": "tool_name",
  "target_host": "hostname",
  "duration_ms": 42,
  "command_executed": "the actual command run",
  "data": { ... }
}
```

## Planned Features

- **Remote SSH execution** — target remote hosts directly from tool calls without a local SSH session
- **Additional knowledge profiles** — PostgreSQL, Apache, Redis, Nginx Unit, Podman, and Wireguard
- **WSL (Windows Subsystem for Linux) support** — detect WSL environment and adjust distro commands accordingly
- **Ansible playbook generation** — convert a session's executed commands into a reproducible playbook
- **Multi-host batch operations** — run the same tool against a list of hosts in parallel

## Known Issues

- **Sudo escalation is not automatic** — tools that require root will return a `permission_denied` error rather than prompting for a password; run `sudo -v` in your shell before starting a session if elevated access is needed
- **Docker container tools assume upstream Docker** — systems using Podman with a Docker compatibility shim may return unexpected output from container inspection tools
- **Knowledge profiles are not auto-updated** — built-in profiles (nginx, sshd, etc.) reflect the state at release time; service config paths may drift between distro versions
- **`dry_run` is best-effort** — not all tools support true dry-run simulation; some will skip the operation silently rather than printing a preview

## License

Apache-2.0

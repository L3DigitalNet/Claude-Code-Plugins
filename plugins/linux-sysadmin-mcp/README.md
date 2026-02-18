# linux-sysadmin-mcp

A comprehensive Linux system administration MCP server for Claude Code. Provides ~100 tools across 15 modules for managing packages, services, users, firewall, networking, containers, storage, security, performance, logs, cron, backups, SSH, and documentation — all through a unified, distro-agnostic interface.

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

## Quick Start

```bash
# Install
npm install

# Build
npm run build

# Add to Claude Code config (~/.claude/claude_desktop_config.json)
{
  "mcpServers": {
    "linux-sysadmin": {
      "command": "node",
      "args": ["/path/to/linux-sysadmin-mcp/dist/server.js"]
    }
  }
}
```

On first run, a default config is generated at `~/.config/linux-sysadmin/config.yaml`.

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

## Tool Modules

| Module | Tools | Examples |
|--------|-------|---------|
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

## License

Apache-2.0

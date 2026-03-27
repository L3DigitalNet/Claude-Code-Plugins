# linux-sysadmin

Linux system administration knowledge base: per-service skills with annotated configs, troubleshooting guides, and a guided `/sysadmin` stack design workflow.

## Summary

When debugging nginx, setting up WireGuard, or tuning ZFS, the hard part isn't running commands; it's knowing *which* commands, *what the output means*, and *what the gotchas are*. This plugin gives Claude that domain knowledge through a single dispatcher skill backed by 163 per-service guide files.

A single `sysadmin` skill triggers on service-related queries and contains a topic index. When a topic matches, Claude reads the corresponding guide file, which contains config paths, expected ports, health checks, common failure modes, and pain points. Reference files provide full annotated configs (every directive commented), invocation cheatsheets, and upstream doc links.

The `/sysadmin` command takes a different approach: it runs an interactive interview to understand your needs, then recommends a complete server stack with setup order.

## Principles

Design decisions in this plugin are evaluated against these principles.

**[P1] Knowledge Over Tooling**: Provide information Claude needs to reason, not tools that replace reasoning. A skill that teaches Claude what sshd_config options mean is more valuable than an MCP tool that wraps `systemctl status sshd`.

**[P2] One Guide, One Service**: Each service gets its own guide file. No categories, no bundling. The `linux-overview` guide handles cross-cutting "what should I use?" queries.

**[P3] Complete Config References**: Annotated config files document *every* directive with its default, recommended value, and when to change it. Partial references force Claude to guess or search the internet.

**[P4] Task-Organized, Not Alphabetical**: Cheatsheets and reference files are organized by what you're trying to accomplish, not by flag name. "How do I scan a subnet?" beats `-sn` as an entry point.

## Requirements

- Claude Code (any recent version)
- Linux system (for Bash commands in skills to be useful)
- No build step, no dependencies, no MCP server

## Installation

```bash
/plugin marketplace add L3DigitalNet/Claude-Code-Plugins
/plugin install linux-sysadmin@l3digitalnet-plugins
```

For local development or testing:

```bash
claude --plugin-dir ./plugins/linux-sysadmin
```

No post-install steps required.

## How It Works

```mermaid
flowchart TD
    User([User]) -->|"mentions a service<br/>or tool by name"| Trigger{Sysadmin skill<br/>triggers}
    Trigger --> Index[Topic index matched]
    Index --> ReadGuide[Claude reads<br/>guides/topic/guide.md]
    ReadGuide --> Knowledge[Claude has: config paths,<br/>ports, health checks,<br/>failure modes, gotchas]
    Knowledge --> Action[Claude runs Bash<br/>commands informed<br/>by guide knowledge]
    Action --> Result((Informed<br/>diagnosis or setup))

    User2([User]) -->|"/sysadmin"| Interview[Guided interview:<br/>purpose, workloads,<br/>constraints, experience]
    Interview --> Recommend[Stack recommendation<br/>with setup order]
    Recommend -->|"user picks a component"| ReadGuide
```

## Usage

**Natural language** (skills load automatically):

> "My nginx keeps returning 502"
> "How do I set up WireGuard?"
> "What filesystem should I use for my NAS?"

**Guided workflow**:

```
/sysadmin
/sysadmin homelab media server
```

The `/sysadmin` command walks through:

1. **Purpose**: what kind of system you're building
2. **Workloads**: which capabilities you need (web, DB, VPN, monitoring, etc.)
3. **Constraints**: hardware, distro, existing stack, security posture
4. **Experience level**: adjusts recommendation complexity
5. **Output**: recommended stack with rationale and ordered setup sequence

## Commands

| Command | Description |
|---------|-------------|
| `/sysadmin` | Interactive system architecture interview with stack recommendations |

## Skills

| Skill | Loaded when |
|-------|-------------|
| `sysadmin` | Any Linux service, tool, or filesystem query. Contains a topic index of 163 guides covering web/proxy, containers, DNS, security, databases, monitoring, system services, storage, filesystems, backup, mail, self-hosted apps, IoT, certificates, CLI tools, networking, and more. |

Each guide lives in `guides/{topic}/guide.md` with an optional `references/` subdirectory for annotated configs, cheatsheets, and documentation links.

## Design Decisions

- **Skills over MCP**: The predecessor plugin (`linux-sysadmin-mcp`) was a TypeScript MCP server with 18 tools. It was replaced because Claude's Bash tool plus skill-provided knowledge achieves the same outcomes without the build step, runtime process, or MCP overhead.
- **Full annotated configs over curated subsets**: larger files, but Claude can find any option without needing to search upstream docs. Context is only loaded when the skill triggers.

## Planned Features

See [`skill-inventory-and-gaps.md`](docs/skill-inventory-and-gaps.md) for the full prioritized backlog.

## Known Issues

- **`## Health Checks` coverage**: CLI tool guides (awk, sed, curl, tmux, jq, etc.) lack a Health Checks section; the concept doesn't translate to stateless tools with no daemon to verify. Daemon guides all include Health Checks.

## Links

- Repository: [L3DigitalNet/Claude-Code-Plugins](https://github.com/L3DigitalNet/Claude-Code-Plugins)
- Changelog: [`CHANGELOG.md`](CHANGELOG.md)
- Issues and feedback: [GitHub Issues](https://github.com/L3DigitalNet/Claude-Code-Plugins/issues)
- Design document: [`docs/plans/2026-03-01-linux-sysadmin-design.md`](../../docs/plans/2026-03-01-linux-sysadmin-design.md)

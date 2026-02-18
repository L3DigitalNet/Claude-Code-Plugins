# Claude Code Plugins Marketplace

My collection of Claude Code plugins for fun and pleasure.

## Installation

Add this marketplace to your Claude Code installation:

```bash
/plugin marketplace add L3DigitalNet/Claude-Code-Plugins
```

Or using the full URL:

```bash
/plugin marketplace add https://github.com/L3DigitalNet/Claude-Code-Plugins.git
```

### Staying Up to Date

**Auto-update** keeps plugins current automatically. To verify it's enabled:

1. Run `/plugin` in Claude Code
2. Go to the **Marketplaces** tab
3. Select **l3digitalnet-plugins**
4. Look for **Disable auto-update** (meaning it's already on)

When auto-update is enabled, Claude Code refreshes the marketplace catalog and updates
installed plugins at the start of each session.

**Manual update** if you prefer to control when updates happen:

```bash
# Refresh the marketplace catalog
/plugin marketplace update l3digitalnet-plugins

# Then update individual plugins via /plugin → Installed tab → Update now
```

## Available Plugins

### Agent Orchestrator

**General-purpose agent team orchestration** with automatic context management, file
isolation via git worktrees, and mechanical enforcement hooks.

**Features:**

- Triage gate for simple vs complex tasks
- Parallel execution via agent teams (or sequential fallback)
- Git worktree isolation for concurrent work
- Context degradation prevention via hooks
- Quality gate with integration checking

**Install:**

```bash
/plugin install agent-orchestrator@l3digitalnet-plugins
```

**Learn more:**
[plugins/agent-orchestrator/README.md](plugins/agent-orchestrator/README.md)

### Home Assistant Dev

**Comprehensive Home Assistant integration development toolkit** with 19 AI skills, an
MCP server for live HA connections, automated validation, example integrations, and
project templates.

**Features:**

- 19 context-aware skills covering architecture, config flows, coordinators, entities,
  testing, and more
- 3 specialized agents (development, review, debugging)
- MCP server with 12 tools for live HA connection and documentation search
- 5 validation scripts with PostToolUse hook enforcement
- 3 example integrations (Bronze/Silver/Gold tier)
- 9 project templates for CI/CD, testing, and documentation
- Full Integration Quality Scale coverage (all 52 rules)

**Install:**

```bash
/plugin install home-assistant-dev@l3digitalnet-plugins
```

**Learn more:**
[plugins/home-assistant-dev/README.md](plugins/home-assistant-dev/README.md)

### GitHub Repo Manager

**Conversational GitHub repository maintenance** — assess and fix repo health
interactively, with owner approval at every step.

**Features:**

- Wiki sync — keeps wiki pages in sync with in-repo docs and code
- Community health — audits and updates CONTRIBUTING, SECURITY, CODE_OF_CONDUCT,
  issue/PR templates
- PR triage — conflict detection, staleness checks, review summaries
- Issue triage — labels, assignees, staleness, linked PRs
- Release health — unreleased commits, changelog drift, draft releases
- Security posture — Dependabot alerts, code scanning, secret scanning
- Dependency audit — outdated packages, license concerns
- Notifications & discussions — triage and summarise
- Cross-repo mode — scan all accessible repos for a specific concern and fix in batch
- Structured maintenance report generated at session end

**Install:**

```bash
/plugin install github-repo-manager@l3digitalnet-plugins
```

**Learn more:**
[plugins/github-repo-manager/docs/USAGE.md](plugins/github-repo-manager/docs/USAGE.md)

### Release Pipeline

**Autonomous release pipeline** — quick merge or full semver release with parallel
pre-flight checks, changelog generation, and GitHub release creation.

**Features:**

- Two modes: quick merge (testing → main) or full versioned release
- Parallel pre-flight agents (test runner, docs auditor, git validator)
- Automatic changelog generation from conventional commits
- Version bumping across Python, Node.js, Rust, and plugin manifests
- GitHub release creation with release notes
- Human-in-the-loop approval gates at critical stages
- Fail-fast with rollback guidance on errors

**Install:**

```bash
/plugin install release-pipeline@l3digitalnet-plugins
```

**Learn more:** [plugins/release-pipeline/README.md](plugins/release-pipeline/README.md)

### Design Refine

**Iterative design document refinement** through structured gap analysis, collaborative
review, and consistency auditing.

**Features:**

- 5-phase loop: comprehension, gap analysis, recommendations, implementation, audit
- Severity-labeled findings (Critical, Moderate, Minor)
- Terminology uniformity and cross-reference validation
- Stays within existing scope — strengthens designs without expanding them
- User approval required before every edit

**Install:**

```bash
/plugin install design-refine@l3digitalnet-plugins
```

**Learn more:** [plugins/design-refine/README.md](plugins/design-refine/README.md)

### Linux SysAdmin MCP

**Comprehensive Linux system administration MCP server** with ~100 tools across 15
modules for managing packages, services, users, firewall, networking, security, storage,
containers, and more.

**Features:**

- ~100 tools organized across 15 modules (packages, services, users, firewall,
  networking, security, storage, performance, logs, containers, SSH, cron, backup, docs,
  session)
- Distro-agnostic command abstraction (Debian/RHEL auto-detection)
- 5-tier risk classification with confirmation gates
- YAML knowledge profiles for 8 services (sshd, nginx, docker, ufw, fail2ban, pihole,
  unbound, crowdsec)
- SSH remote execution support
- Git-backed documentation generation

**Install:**

```bash
/plugin install linux-sysadmin-mcp@l3digitalnet-plugins
```

**Learn more:**
[plugins/linux-sysadmin-mcp/README.md](plugins/linux-sysadmin-mcp/README.md)

## Plugin Development

This repository also serves as a development workspace for creating new plugins. See
[CLAUDE.md](CLAUDE.md) for architectural guidance and [docs/](docs/) for comprehensive
documentation.

### Quick Start

1. **Create a new plugin:**

   ```bash
   mkdir -p plugins/my-plugin/.claude-plugin
   cd plugins/my-plugin
   ```

2. **Add manifest:**

   ```json
   {
     "name": "my-plugin",
     "version": "0.1.0",
     "description": "Plugin description"
   }
   ```

3. **Test locally:**

   ```bash
   claude --plugin-dir ./plugins/my-plugin
   ```

4. **Add to marketplace catalog** (`.claude-plugin/marketplace.json`)

### Documentation

- **[docs/plugins.md](docs/plugins.md)** - Plugin development guide
- **[docs/plugin-marketplaces.md](docs/plugin-marketplaces.md)** - Marketplace creation
- **[docs/plugins-reference.md](docs/plugins-reference.md)** - Technical reference
- **[docs/skills.md](docs/skills.md)** - Creating AI-invoked skills
- **[docs/sub-agents.md](docs/sub-agents.md)** - Custom agent definitions
- **[docs/hooks.md](docs/hooks.md)** - Lifecycle event handlers
- **[docs/mcp.md](docs/mcp.md)** - MCP server integration

## Repository Structure

```
Claude-Code-Plugins/
├── .claude-plugin/
│   └── marketplace.json        # Marketplace catalog
├── plugins/                     # All plugin implementations
│   ├── agent-orchestrator/      # Agent team orchestration
│   ├── home-assistant-dev/      # Home Assistant integration dev toolkit
│   ├── github-repo-manager/     # Conversational GitHub repo maintenance
│   ├── release-pipeline/        # Autonomous release pipeline
│   ├── design-refine/           # Design document refinement
│   └── linux-sysadmin-mcp/      # Linux sysadmin MCP server
├── scripts/
│   └── validate-marketplace.sh  # Marketplace validation
├── docs/                        # Comprehensive documentation
├── CLAUDE.md                    # Development guidance for AI agents
├── BRANCH_PROTECTION.md         # Branch protection and workflow guide
└── README.md                    # This file
```

## Contributing

To add a plugin to this marketplace:

1. **Work on the `testing` branch** (all development happens here)
2. Create plugin in `plugins/` directory
3. Add entry to `.claude-plugin/marketplace.json`
4. Update marketplace version (semver)
5. Validate with `./scripts/validate-marketplace.sh`
6. Commit and push to `testing` branch
7. When ready to deploy, merge `testing` → `main`

**Branch workflow:**

- **`main`** - Protected production branch (GitHub blocks direct pushes)
- **`testing`** - Development branch (direct commits allowed)

**Deployment:**

```bash
git checkout testing
./scripts/validate-marketplace.sh
git checkout main
git merge testing --no-ff -m "Deploy: <description>"
git push origin main
git checkout testing
```

See [BRANCH_PROTECTION.md](BRANCH_PROTECTION.md) for detailed workflow documentation.

**Marketplace versioning:**

- **Major** (2.0.0) - Breaking changes to marketplace structure
- **Minor** (1.1.0) - New plugins added
- **Patch** (1.0.1) - Plugin updates, metadata fixes

## License

MIT - See [LICENSE](LICENSE) file for details

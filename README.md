# Claude Code Plugins Marketplace

A Claude Code plugin marketplace covering orchestration, release automation, design review, Home Assistant development, Linux system administration, GitHub repository management, and plugin testing.

## Installation

Add this marketplace to your Claude Code installation:

```bash
/plugin marketplace add L3DigitalNet/Claude-Code-Plugins
```

Or using the full URL:

```bash
/plugin marketplace add https://github.com/L3DigitalNet/Claude-Code-Plugins.git
```

Then install individual plugins:

```bash
/plugin install agent-orchestrator@l3digitalnet-plugins
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

| Plugin | Type | Command | Description |
|--------|------|---------|-------------|
| [Agent Orchestrator](#agent-orchestrator) | Commands + Hooks | `/orchestrate` | Delegates complex tasks to agent teams with context management |
| [Design Assistant](#design-assistant) | Commands + Skills | `/design-draft`, `/design-review` | Guided design document authoring and principle-enforced review |
| [GitHub Repo Manager](#github-repo-manager) | Commands + Skills | `/repo-manager` | Conversational GitHub repo health assessment and maintenance |
| [Home Assistant Dev](#home-assistant-dev) | Commands + Skills + MCP | varies | Full HA integration development toolkit with 19 skills |
| [Linux SysAdmin MCP](#linux-sysadmin-mcp) | MCP | ~100 tools | Linux system administration across 15 modules |
| [Plugin Test Harness](#plugin-test-harness) | MCP | 18 tools | Iterative test/fix/reload loop for plugin development |
| [Release Pipeline](#release-pipeline) | Commands + Skills | `/release` | Semver releases with pre-flight checks and changelog generation |

## Principles

These principles apply across all plugins in this collection. Individual plugins may define additional principles scoped to their domain.

**[P1] Composable Over Monolithic** — Functionality is partitioned into focused, independently useful units. Complex workflows emerge from combining atomic components at runtime — not from monolithic mega-commands or mega-documents. Each unit does one thing well; orchestration is assembled from the outside, not baked in.

**[P2] Scope Fidelity** — A plugin does exactly what it was invoked to do — no more. Observations outside the declared scope are surfaced as notes, never acted upon. Mutations outside the session's stated purpose require explicit re-invocation. Scope creep is a trust violation.

**[P3] Safe Default, Explicit Escalation** — The default posture of every operation is the minimal, reversible, lowest-impact option available. Destructive modes, broad scopes, and irreversible paths are never the default; the user must take an explicit step to reach them. Dry-run before live, read before write, preview before execute, narrow scope before wide.

**[P4] Human Consent Before Consequence** — No plugin autonomously performs a destructive or irreversible action. Every high-impact operation is announced with enough context to make an informed decision, and irreversible actions are flagged unmissably before execution. Silent mutations — deployments, deletions, pushes, or state changes — are not possible. Confirming once in one context does not authorise the same action in another.

**[P5] Explainability Precedes Action** — Before a plugin acts, it explains what it is about to do and why — in plain language, with technical jargon translated on first mention and consequences surfaced before execution. A user's understanding of an operation is a prerequisite for meaningful consent, not a bonus. Explanations are proportionate: brief for routine actions, detailed for high-impact ones.

**[P6] Conversation-Native Interaction** — Plugins are experienced through Claude Code's terminal conversation, and every UX decision must honour that medium. Prefer bounded `AskUserQuestion` choices over open-ended text prompts. Lead with the answer — most important information first, context after. Use progressive disclosure over walls of text; any output longer than ~10 lines should be restructured or chunked. Format purposefully (headers, bold, status symbols) but never decoratively. Smart defaults eliminate questions the user shouldn't need to answer. Errors are actionable: say what went wrong and what to do about it — never a raw stack trace.

**[P7] Fail Fast, Never Silently** — When something goes wrong, stop immediately and surface the complete failure. Raw output is always shown alongside any interpretation; errors are never swallowed or softened into ambiguity. No autonomous recovery attempts, no continuing past a known failure. The user should never wonder whether an operation succeeded.

**[P8] Done is Measured, Not Declared** — Plugins that perform iterative work define completion as a measurable state — zero findings, all checks green, all tests passing — and drive toward that state across successive cycles. Success is not declared after a single pass; the plugin reports the trend and continues until the criterion is met or the user stops it.

---

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

---

### Design Assistant

**Full design document lifecycle in two commands** — guided authoring from blank page through
principle-enforced iterative review.

**Features:**

- `/design-draft` — 5-phase interview: context deep dive, principles discovery, scope
  confirmation, gap-filling, and draft generation
- Principle stress-testing and tension resolution before any architecture is committed
- `/design-review` — multi-pass principle enforcement, gap analysis, and optional auto-fix
- Principle Conflict Screening: all proposed fixes checked against established principles
  before presentation
- Automatic warm handoff from draft to review (principles registry transferred)
- Runs until the document converges to zero findings across all review tracks

**Install:**

```bash
/plugin install design-assistant@l3digitalnet-plugins
```

**Learn more:**
[plugins/design-assistant/README.md](plugins/design-assistant/README.md)

---

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
[plugins/github-repo-manager/README.md](plugins/github-repo-manager/README.md)

---

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

---

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

---

### Plugin Test Harness

**Iterative plugin testing framework** — generates tests, records pass/fail results,
applies source fixes, reloads the target plugin, and retests until convergence.

**Features:**

- Auto-generates tests from plugin source and schema introspection
- Test/fix/reload loop with convergence tracking (improving, plateau, oscillating,
  diverging)
- Dedicated git branch per session for a complete audit trail of fixes
- Sessions persist to disk and can be resumed after interruption
- Native MCP client for MCP-mode plugins; source analysis for hook/command plugins
- 18 tools across session management, test management, execution, and fix management

**Install:**

```bash
/plugin install plugin-test-harness@l3digitalnet-plugins
```

**Learn more:**
[plugins/plugin-test-harness/README.md](plugins/plugin-test-harness/README.md)

---

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

---

## Coming Soon

These plugins are in development and not yet available in the marketplace.

| Plugin | Description |
|--------|-------------|
| `performance-profiler` | Latency measurement, flamegraph generation, and regression tracking for MCP servers |
| `docs-manager` | Documentation lifecycle management — audit, index, and organise project docs |

---

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
│   ├── design-assistant/        # Design document lifecycle
│   ├── docs-manager/            # Documentation management (in development)
│   ├── github-repo-manager/     # Conversational GitHub repo maintenance
│   ├── home-assistant-dev/      # Home Assistant integration dev toolkit
│   ├── linux-sysadmin-mcp/      # Linux sysadmin MCP server (~100 tools)
│   ├── performance-profiler/    # MCP performance profiling (in development)
│   ├── plugin-test-harness/     # Iterative plugin testing framework
│   └── release-pipeline/        # Autonomous release pipeline
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
4. Validate with `./scripts/validate-marketplace.sh`
5. Commit and push to `testing` branch
6. When ready to deploy, merge `testing` → `main`

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

## License

MIT - See [LICENSE](LICENSE) file for details

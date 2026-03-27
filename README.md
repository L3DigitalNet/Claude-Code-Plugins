# Claude Code Plugins Marketplace

A Claude Code plugin marketplace. Plugins cover the full development lifecycle: release automation, design review, infrastructure verification, Home Assistant integration dev, Linux system administration, GitHub repo health, and plugin testing.

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
/plugin install design-assistant@l3digitalnet-plugins
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
| [Design Assistant](#design-assistant) | Commands + Skills | `/design-draft`, `/design-review` | Guided design document authoring and principle-enforced review |
| [Docs Manager](#docs-manager) | Commands + Agents + Hooks | `/docs` | Documentation lifecycle management with drift detection |
| [GitHub Repo Manager](#github-repo-manager) | Commands + Skills | `/repo-manager` | Conversational GitHub repo health assessment and maintenance |
| [Home Assistant Dev](#home-assistant-dev) | Commands + Skills + MCP | varies | Full HA integration development toolkit with 27 skills |
| [Linux SysAdmin](#linux-sysadmin) | Skills + Commands | 163 guides | Per-service knowledge for daemons, CLI tools, and filesystems; guided `/sysadmin` stack interview |
| [Nominal](#nominal) | Commands | `/preflight`, `/postflight`, `/abort` | Infrastructure verification session contract: 11 systems check security, reachability, backups, monitoring, and more |
| [Plugin Test Harness](#plugin-test-harness) | MCP | 18 tools | Iterative test/fix/reload loop for plugin development |
| [Python Dev](#python-dev) | Commands + Skills | `/python-code-review` | Contextual Python domain guidance: 11 skills load automatically, plus a comprehensive multi-domain code audit |
| [Release Pipeline](#release-pipeline) | Commands + Skills | `/release` | Semver releases with pre-flight checks and changelog generation |
| [Repo Hygiene](#repo-hygiene) | Commands | `/hygiene` | Autonomous maintenance sweep for .gitignore, manifests, and READMEs |
| [Qt Suite](#qt-suite) | MCP + Commands + Skills + Agents | `/qt-suite:scaffold`, `/qt-suite:coverage`, `/qt-suite:visual` | Complete Qt development and testing toolkit: proactive agents, 16 skills, scaffolding, and headless GUI testing |
| [Opus Context](#opus-context) | Skills + Hooks | always-on | Teaches Opus 4.6 to use its full 1M context window instead of conservative small-model defaults |
| [Test Driver](#test-driver) | Commands + Skills | `/test-driver:analyze`, `/test-driver:status` | Proactive testing via gap analysis, convergence loops, and persistent status tracking |

## Principles

These principles apply across all plugins in this collection. Individual plugins may define additional principles scoped to their domain.

**[P1] Act on Intent**: Invoking a command is consent to its implied scope. When intent is ambiguous, clarify scope before executing, not after. When intent is clear, execute without narration or confirmation of the obvious. A confirmation gate is warranted only when an operation is both truly irreversible and its scope materially exceeds what the invocation implies, not for operations that are merely large or look dangerous. If scope materially changes mid-execution, stop and re-confirm. Routine friction is a tax, not a safeguard.

**[P2] Scope Fidelity**: Execute the full scope of what was asked, completely, without routine sub-task confirmation gates. When a sub-task's scope is genuinely ambiguous, clarify before proceeding rather than assuming. Do not act beyond the declared scope; surface only material out-of-scope findings as notes; routine adjacent observations are not worth raising. Scope undershoot triggers additional iteration; scope overshoot violates the consent established at invocation.

**[P3] Succeed Quietly, Fail Transparently**: Lead with findings, not intent or preamble. Output results, not narration. Emit a compact factual summary at task completion, not after every step. On transient or infrastructure errors, retry silently. On critical failures, stop immediately and surface the complete failure (raw output included) with a recovery plan; do not attempt autonomous workarounds.

**[P4] Use the Full Toolkit**: When interaction is required, prefer structured choices over open-ended prompts; bound the user's decision space before presenting it. Use Claude Code's interaction primitives: bounded choices (`AskUserQuestion`), markdown previews for side-by-side comparisons, multi-select for non-exclusive options.

**[P5] Convergence is the Contract**: Iterative work defines completion as a measurable criterion (set by the plugin, the user, or collaboratively) and drives toward it without check-ins. Proceed quietly when converging normally. Surface immediately if progress stalls or regresses unexpectedly. If the cycle begins oscillating (making and undoing the same changes repeatedly), flag the pattern and stop rather than continuing. Stop only when the criterion is met, oscillation is detected, or the user intervenes.

**[P6] Composable, Focused Units**: Every plugin component (command, skill, hook) does one thing and is independently useful. Complex workflows emerge from combining atomic units at runtime; orchestration is assembled from the outside, not baked in.

---

### Design Assistant

**Full design document lifecycle in two commands**: guided authoring from blank page through
principle-enforced iterative review.

**Features:**

- `/design-draft`: 5-phase interview: context deep dive, principles discovery, scope
  confirmation, gap-filling, and draft generation
- Principle stress-testing and tension resolution before any architecture is committed
- `/design-review`: multi-pass principle enforcement, gap analysis, and optional auto-fix
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

**Conversational GitHub repository maintenance**: assess and fix repo health
interactively, with owner approval at every step.

**Features:**

- Wiki sync: keeps wiki pages in sync with in-repo docs and code
- Community health: audits and updates CONTRIBUTING, SECURITY, CODE_OF_CONDUCT,
  issue/PR templates
- PR triage: conflict detection, staleness checks, review summaries
- Issue triage: labels, assignees, staleness, linked PRs
- Release health: unreleased commits, changelog drift, draft releases
- Security posture: Dependabot alerts, code scanning, secret scanning
- Dependency audit: outdated packages, license concerns
- Notifications & discussions: triage and summarise
- Cross-repo mode: scan all accessible repos for a specific concern and fix in batch
- Structured maintenance report generated at session end

**Install:**

```bash
/plugin install github-repo-manager@l3digitalnet-plugins
```

**Learn more:**
[plugins/github-repo-manager/README.md](plugins/github-repo-manager/README.md)

---

### Home Assistant Dev

**Home Assistant integration development toolkit**: 27 AI skills, an MCP server for live
HA connections, automated validation, example integrations, and project templates.

**Features:**

- 27 context-aware skills covering architecture, config flows, coordinators, entities,
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

### Linux SysAdmin

**Linux system administration knowledge base**: 163 per-service guides covering daemons, CLI tools, and filesystems. Guides load automatically when you mention a service by name; no commands required for most usage.

**Features:**

- 163 per-service guides across web/proxy, DNS, databases, security/VPN, containers, monitoring, networking, filesystems, storage, backup, mail, self-hosted apps, IoT, and 30+ CLI tools
- Annotated configs for daemons (nginx, sshd, samba, postfix, mosquitto, and more) with every directive documented
- Task-organized cheatsheets for CLI tools (nmap, tcpdump, jq, rsync, borg, tmux, and more)
- `/sysadmin` command: guided interview to design a complete server stack with rationale and setup order
- No build step, no MCP server, no dependencies

**Install:**

```bash
/plugin install linux-sysadmin@l3digitalnet-plugins
```

**Learn more:**
[plugins/linux-sysadmin/README.md](plugins/linux-sysadmin/README.md)

---

### Nominal

**Structured verification routine for infrastructure changes**: three slash commands
enforce a session contract ensuring every change begins with a validated environment
and ends with a fully verified outcome.

**Features:**

- `/preflight`: automated environment discovery (Mission Survey), go/no-go poll,
  rollback readiness confirmation
- `/postflight`: runs all 11 verification systems covering operational scripts, backup
  integrity, secrets hygiene, reachability, security posture, performance baselines,
  boot ordering, observability, DNS/certs, network routing, and documentation state
- `/abort`: confirmed rollback execution with step-by-step verification and
  post-abort go/no-go poll
- Multi-environment support in a single profile
- Append-only flight log based on the OpenTelemetry Log Data Model
- Fix-forward flow with regression sweep to catch side effects
- Grounded in ITIL, CIS Controls v8, NIST SP 800-190, Google SRE PRR, and
  HashiCorp/OWASP secrets management

**Install:**

```bash
/plugin install nominal@l3digitalnet-plugins
```

**Learn more:**
[plugins/nominal/README.md](plugins/nominal/README.md)

---

### Plugin Test Harness

**Iterative plugin testing framework**: generates tests, records pass/fail results,
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

**Autonomous release pipeline**: quick merge or full semver release with parallel
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

### Docs Manager

**Documentation lifecycle management**: monitors file changes via hooks, accumulates
documentation tasks into a persistent queue without interrupting active work, and
surfaces the queue for batch review at session end.

**Features:**

- Hook-driven change detection: queues documentation tasks as files are written
- Persistent queue across sessions with no item loss between restarts
- Central library index with per-document freshness tracking
- Third-party doc verification against upstream authoritative sources
- Batch review at session end rather than interrupting active work
- `/docs` command for manual queue management and auditing

**Install:**

```bash
/plugin install docs-manager@l3digitalnet-plugins
```

**Learn more:**
[plugins/docs-manager/README.md](plugins/docs-manager/README.md)

---

### Python Dev

**Contextual Python domain guidance**: 11 skills load automatically when you work on
Python code, covering async patterns, anti-patterns, type safety, testing, resilience,
observability, configuration, design patterns, resource management, code style, and
background jobs.

**Features:**

- 11 always-on skills that activate based on what you are working on
- `/python-code-review`: comprehensive multi-domain code audit across all 11 quality
  domains with severity-sorted findings
- Covers async/await, type hints, pytest fixtures, retry/backoff, logging/tracing,
  pydantic-settings, context managers, Celery/RQ, ruff/black, composition vs.
  inheritance, and common Python traps
- No build step, no MCP server, no dependencies

**Install:**

```bash
/plugin install python-dev@l3digitalnet-plugins
```

**Learn more:**
[plugins/python-dev/README.md](plugins/python-dev/README.md)

---

### Repo Hygiene

**Autonomous maintenance sweep**: five parallel mechanical checks plus a semantic
README pass, with safe corrections applied automatically and destructive changes
requiring explicit approval.

**Features:**

- `.gitignore` pattern validation against actual repo contents
- `marketplace.json` path and format checks
- Orphaned plugin cache detection
- Stale `enabledPlugins` entry cleanup
- Semantic README freshness scan with inline AI reasoning
- `--dry-run` flag shows full plan without touching anything

**Install:**

```bash
/plugin install repo-hygiene@l3digitalnet-plugins
```

**Learn more:**
[plugins/repo-hygiene/README.md](plugins/repo-hygiene/README.md)

---

### Qt Suite

**Complete Qt development and testing toolkit**: proactive specialist agents, 16 domain skills, scaffolding commands, and headless GUI testing via the bundled Qt Pilot MCP server. Covers PySide6, PyQt6, and C++/Qt.

**Features:**

- 4 proactive agents: development specialist, debugger, code reviewer, and UX advisor
- 16 context-aware skills covering signals/slots, layouts, Model/View, threading, QML, styling, and more
- `/qt-suite:scaffold`: generates a complete PySide6 project with pyproject.toml, src layout, and test config
- `/qt-suite:generate`: scans codebase and generates unit tests for untested files
- `/qt-suite:coverage`: gcov/lcov (C++) or coverage.py (Python) report with gap-targeted test generation
- `/qt-suite:visual`: launches app headlessly via Xvfb, drives UI via the bundled Qt Pilot MCP server

**Install:**

```bash
/plugin install qt-suite@l3digitalnet-plugins
```

**Learn more:**
[plugins/qt-suite/README.md](plugins/qt-suite/README.md)

---

### Opus Context

**1M context window optimizer for Opus 4.6**: always-on behavioral rules that override
conservative small-model defaults (partial reads, excessive delegation, re-reading).

**Features:**

- Whole-file reading by default (no offset/limit for files under 4000 lines)
- Direct reading over subagent delegation
- Dependency pre-loading before editing
- Budget-aware context pressure management

**Install:**

```bash
/plugin install opus-context@l3digitalnet-plugins
```

**Learn more:**
[plugins/opus-context/README.md](plugins/opus-context/README.md)

---

### Test Driver

**Proactive testing awareness and gap filling**: always-on testing mindset that suggests
gap analysis at natural breakpoints, finds missing tests across six categories, and
iterates through a convergence loop until everything passes.

**Features:**

- Always-on testing-mindset skill triggers at natural breakpoints
- Six-category gap analysis (unit, integration, e2e, contract, security, UI)
- Convergence loop with oscillation detection
- Stack profiles for FastAPI, Django, PySide6, Home Assistant, and Swift
- Persistent test status tracking across sessions

**Install:**

```bash
/plugin install test-driver@l3digitalnet-plugins
```

**Learn more:**
[plugins/test-driver/README.md](plugins/test-driver/README.md)

---

## Plugin Development

This repository also serves as a development workspace for creating new plugins. See
[CLAUDE.md](CLAUDE.md) for architectural guidance and [docs/](docs/) for the full
reference.

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
│   ├── design-assistant/        # Design document lifecycle
│   ├── docs-manager/            # Documentation lifecycle management
│   ├── github-repo-manager/     # Conversational GitHub repo maintenance
│   ├── home-assistant-dev/      # Home Assistant integration dev toolkit
│   ├── linux-sysadmin/          # Linux sysadmin skills (163 per-service guides)
│   ├── nominal/                 # Infrastructure verification (preflight/postflight/abort)
│   ├── opus-context/            # 1M context window optimizer for Opus 4.6
│   ├── plugin-test-harness/     # Iterative plugin testing framework
│   ├── python-dev/              # Python development skills (11 domain skills)
│   ├── qt-suite/                # Qt development and testing toolkit (agents, skills, MCP)
│   ├── release-pipeline/        # Autonomous release pipeline
│   ├── repo-hygiene/            # Autonomous repo maintenance sweep
│   └── test-driver/             # Proactive testing via gap analysis and convergence
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

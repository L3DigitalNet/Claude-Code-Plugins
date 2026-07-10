# Claude Code Plugins Marketplace

A Claude Code plugin marketplace. Plugins cover the full development lifecycle: release automation, Home Assistant integration dev, Qt UI development, deep web research, three-layer documentation propagation, and Python tooling standardization.

## Table of Contents

- [Claude Code Plugins Marketplace](#claude-code-plugins-marketplace)
  - [Table of Contents](#table-of-contents)
    - [Staying Up to Date](#staying-up-to-date)
  - [Available Plugins](#available-plugins)
  - [Principles](#principles)
    - [Home Assistant Dev](#home-assistant-dev)
    - [Qt Suite](#qt-suite)
    - [qdev](#qdev)
    - [Test Driver](#test-driver)
    - [Up Docs](#up-docs)
    - [uv-strict-python](#uv-strict-python)
  - [Testing \& Validation](#testing--validation)
  - [Plugin Development](#plugin-development)
    - [Quick Start](#quick-start)
    - [Documentation](#documentation)
  - [Repository Structure](#repository-structure)
  - [Contributing](#contributing)
  - [License](#license)

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
/plugin install home-assistant-dev@l3digitalnet-plugins
```

### Staying Up to Date

**Auto-update** keeps plugins current automatically. To verify it's enabled:

1. Run `/plugin` in Claude Code
2. Go to the **Marketplaces** tab
3. Select **l3digitalnet-plugins**
4. Look for **Disable auto-update** (meaning it's already on)

When auto-update is enabled, Claude Code refreshes the marketplace catalog and updates installed plugins at the start of each session.

**Manual update** if you prefer to control when updates happen:

```bash
# Refresh the marketplace catalog
/plugin marketplace update l3digitalnet-plugins

# Then update individual plugins via /plugin → Installed tab → Update now
```

## Available Plugins

| Plugin | Type | Command | Description |
| --- | --- | --- | --- |
| [Home Assistant Dev](#home-assistant-dev) | Commands + Skills + MCP | varies | Full HA integration development toolkit with 27 skills |
| [qdev](#qdev) | Commands + Agents | `/research` | Deep web research for development decisions: dual-source sweeps with Context7 docs gating, persisted as cited reports under `docs/research/` |
| [Qt Suite](#qt-suite) | MCP + Commands + Skills + Agents | `/qt-suite:scaffold`, `/qt-suite:coverage`, `/qt-suite:visual` | Complete Qt development and testing toolkit: proactive agents, 16 skills, scaffolding, and headless GUI testing |
| [Test Driver](#test-driver) | Commands + Skills | `/test-driver:analyze`, `/test-driver:status` | Proactive testing via gap analysis, convergence loops, and persistent status tracking |
| [Up Docs](#up-docs) | Skills + Agents | `/up-docs:repo`, `/up-docs:wiki`, `/up-docs:notion`, `/up-docs:all`, `/up-docs:drift` | Update documentation across three layers via dispatched sub-agents (all Sonnet: repo, wiki, Notion propagators & drift auditor) from session context, plus full infrastructure drift analysis |
| [uv-strict-python](#uv-strict-python) | Skills | (AI-invoked) | Configures Python projects to the Python Tooling SSOT Standard (uv, Ruff, BasedPyright strict, pytest+coverage, pip-audit) |

## Principles

These principles apply across all plugins in this collection. Individual plugins may define additional principles scoped to their domain.

**[P1] Act on Intent**: Invoking a command is consent to its implied scope. When intent is ambiguous, clarify scope before executing, not after. When intent is clear, execute without narration or confirmation of the obvious. A confirmation gate is warranted only when an operation is both truly irreversible and its scope materially exceeds what the invocation implies, not for operations that are merely large or look dangerous. If scope materially changes mid-execution, stop and re-confirm. Routine friction is a tax, not a safeguard.

**[P2] Scope Fidelity**: Execute the full scope of what was asked, completely, without routine sub-task confirmation gates. When a sub-task's scope is genuinely ambiguous, clarify before proceeding rather than assuming. Do not act beyond the declared scope; surface only material out-of-scope findings as notes; routine adjacent observations are not worth raising. Scope undershoot triggers additional iteration; scope overshoot violates the consent established at invocation.

**[P3] Succeed Quietly, Fail Transparently**: Lead with findings, not intent or preamble. Output results, not narration. Emit a compact factual summary at task completion, not after every step. On transient or infrastructure errors, retry silently. On critical failures, stop immediately and surface the complete failure (raw output included) with a recovery plan; do not attempt autonomous workarounds.

**[P4] Use the Full Toolkit**: When interaction is required, prefer structured choices over open-ended prompts; bound the user's decision space before presenting it. Use Claude Code's interaction primitives: bounded choices (`AskUserQuestion`), markdown previews for side-by-side comparisons, multi-select for non-exclusive options.

**[P5] Convergence is the Contract**: Iterative work defines completion as a measurable criterion (set by the plugin, the user, or collaboratively) and drives toward it without check-ins. Proceed quietly when converging normally. Surface immediately if progress stalls or regresses unexpectedly. If the cycle begins oscillating (making and undoing the same changes repeatedly), flag the pattern and stop rather than continuing. Stop only when the criterion is met, oscillation is detected, or the user intervenes.

**[P6] Composable, Focused Units**: Every plugin component (command, skill, hook) does one thing and is independently useful. Complex workflows emerge from combining atomic units at runtime; orchestration is assembled from the outside, not baked in.

---

### Home Assistant Dev

**Home Assistant integration development toolkit**: 27 AI skills, an MCP server for live HA connections, automated validation, example integrations, and project templates.

**Features:**

- 27 context-aware skills covering architecture, config flows, coordinators, entities, testing, and more
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

**Learn more:** [plugins/home-assistant-dev/README.md](plugins/home-assistant-dev/README.md)

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

**Learn more:** [plugins/qt-suite/README.md](plugins/qt-suite/README.md)

---

### qdev

**Deep web research**: a single user-initiated command that sweeps current sources before you design or build.

**Features:**

- `/research`: dual-source sweep (Tavily-first recall, Brave/Serper cross-checks, Context7 docs gating, footgun corroboration) persisted as a cited, frontmatter-indexed report under `docs/research/`

**Install:**

```bash
/plugin install qdev@l3digitalnet-plugins
```

**Learn more:** [plugins/qdev/README.md](plugins/qdev/README.md)

---

### Test Driver

**Proactive testing awareness and gap filling**: always-on testing mindset that suggests gap analysis at natural breakpoints, finds missing tests across six categories, and iterates through a convergence loop until everything passes.

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

**Learn more:** [plugins/test-driver/README.md](plugins/test-driver/README.md)

---

### Up Docs

**Three-layer documentation updater via sub-agent dispatch**: infers what changed during a session and updates repo docs, llm-wiki, and Notion at the right level of detail for each layer. Also provides comprehensive drift analysis that SSHes into live infrastructure.

**Features:**

- Parallel sub-agent architecture: three Sonnet propagators (repo, wiki, notion) run in isolated context windows; Sonnet audit ensures drift detection quality
- `/up-docs:repo`, `/up-docs:wiki`, `/up-docs:notion`, `/up-docs:all`: dispatch targeted propagators from session context
- `/up-docs:drift`: four-phase convergence loop that gathers live server state via SSH, syncs llm-wiki, resolves internal contradictions, verifies and enriches links, then updates Notion
- Wall-clock time to completion reduced to `max(repo, wiki, notion)` via parallel dispatch; sequential drift audit phases protect data integrity

**Install:**

```bash
/plugin install up-docs@l3digitalnet-plugins
```

**Learn more:** [plugins/up-docs/README.md](plugins/up-docs/README.md)

---

### uv-strict-python

**Python tooling standard enforcer**: configures Python projects to the Python Tooling SSOT Standard — uv for package/env management, Ruff for linting and formatting, BasedPyright strict for type checking, pytest+coverage for testing, and pip-audit for dependency auditing.

**Features:**

- Skill-driven: AI invokes the skill when creating projects, writing scripts, configuring pyproject.toml, or migrating from pip/Poetry/mypy/black/flake8
- Covers pyproject.toml setup, lockfile generation, CI integration, Docker patterns, and pre-commit wiring
- Audits existing projects for conformance to the standard

**Install:**

```bash
/plugin install uv-strict-python@l3digitalnet-plugins
```

**Learn more:** [plugins/uv-strict-python/README.md](plugins/uv-strict-python/README.md)

---

## Testing & Validation

The marketplace standardizes test frameworks per language — bats for bash, pytest for Python, Jest for TypeScript. See [docs/handoff/conventions.md](docs/handoff/conventions.md) (TEST-001) for the canonical frameworks and per-language naming conventions.

**Quick reference:**

```bash
# Bash plugins
cd plugins/up-docs && ./tests/run-bats.sh

# Python plugins
pytest plugins/home-assistant-dev/tests/ -m unit

# Marketplace schema validation (always run before merging to main)
./scripts/validate-marketplace.sh
```

Each plugin's tests live under its own [`plugins/<plugin>/tests/`](plugins/) directory.

## Plugin Development

This repository also serves as a development workspace for creating new plugins. See [CLAUDE.md](CLAUDE.md) for architectural guidance and [docs/](docs/) for the full reference.

### Quick Start

1. **Create a new plugin:**

   ```bash
   mkdir -p plugins/my-plugin/.claude-plugin
   cd plugins/my-plugin
   ```

2. **Add manifest:**

   ```json
   { "name": "my-plugin", "version": "0.1.0", "description": "Plugin description" }
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

```text
Claude-Code-Plugins/
├── .claude-plugin/
│   └── marketplace.json        # Marketplace catalog
├── plugins/                     # All plugin implementations (7 plugins)
│   ├── home-assistant-dev/      # Home Assistant integration dev toolkit
│   ├── qdev/                    # Deep web research (research sweeps via qdev-researcher)
│   ├── qt-suite/                # Qt development and testing toolkit (agents, skills, MCP)
│   ├── test-driver/             # Proactive testing via gap analysis and convergence
│   ├── up-docs/                 # Three-layer documentation updater (repo, wiki, Notion)
│   └── uv-strict-python/        # Python tooling standard (uv, Ruff, BasedPyright strict)
├── scripts/
│   └── validate-marketplace.sh  # Marketplace validation
├── docs/                        # Comprehensive documentation
├── CLAUDE.md                    # Development guidance for AI agents
├── BRANCH_PROTECTION.md         # Branch protection and workflow guide
└── README.md                    # This file
```

## Contributing

To add a plugin to this marketplace:

1. Create plugin in `plugins/` directory
2. Add entry to `.claude-plugin/marketplace.json` (version must match the plugin's own `plugin.json`)
3. Validate with `./scripts/validate-marketplace.sh`
4. Commit directly to `main` and push
5. To publish a tagged release: bump `plugin.json` + `marketplace.json`, update the CHANGELOG, commit, then `git tag <name>/vX.Y.Z && git push --tags && gh release create <name>/vX.Y.Z` (see [BRANCH_PROTECTION.md](BRANCH_PROTECTION.md))

**Branch workflow:** Direct commit to `main`. There is no `testing` branch. Local pre-commit hooks (noreply email enforcement, marketplace validation) provide guardrails. See [BRANCH_PROTECTION.md](BRANCH_PROTECTION.md) for full rules.

```bash
git pull origin main
# (make edits)
./scripts/validate-marketplace.sh
git add <specific files>
git commit -m "..."
git push origin main
```

## License

MIT - See [LICENSE](LICENSE) file for details

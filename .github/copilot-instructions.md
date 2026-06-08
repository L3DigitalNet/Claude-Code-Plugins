# AI Agent Instructions for Claude Code Plugins Marketplace

## Repository Purpose

This is a **dual-purpose repository**:

1. **Plugin marketplace** - Distributes Claude Code plugins via `/plugin marketplace add L3DigitalNet/Claude-Code-Plugins`
2. **Development workspace** - Creates and tests new plugins before publication

## Architecture Overview

### Branch Strategy

Direct commit to `main`. There is no `testing` branch — that convention was retired 2026-05-07.

**Local guardrails** (replace what server-side branch protection used to provide):

- Noreply email pre-commit hook (rejects non-noreply commit authors)
- `./scripts/validate-marketplace.sh` (manifest + marketplace consistency)
- `/release-pipeline:release` pre-flight (3 parallel agents check tests/docs/git before any tag)

### Directory Structure

````
├── .claude-plugin/marketplace.json  # Marketplace catalog (source of truth)
├── plugins/                         # All plugins
│   ├── release-pipeline/            # Tagged-release orchestrator
│   └── ...                          # Other plugins
├── scripts/
│   └── validate-marketplace.sh      # Marketplace validation
└── BRANCH_PROTECTION.md             # Branch workflow doc

## Development Workflow

### Creating New Plugins

```bash
git pull origin main

# Create plugin structure
mkdir -p plugins/my-plugin/.claude-plugin
mkdir -p plugins/my-plugin/{commands,skills,agents,hooks}

# Create manifest
cat > plugins/my-plugin/.claude-plugin/plugin.json << 'EOF'
{
  "name": "my-plugin",
  "version": "1.0.0",
  "description": "Brief description"
}
EOF

# Test locally
claude --plugin-dir ./plugins/my-plugin

# Add to marketplace catalog (version must match plugin.json)
vim .claude-plugin/marketplace.json

# Validate
./scripts/validate-marketplace.sh

# Commit + push directly to main
git add plugins/my-plugin .claude-plugin/marketplace.json
git commit -m "Add my-plugin v1.0.0"
git push origin main

# To publish a tagged release with GitHub release notes:
# /release-pipeline:release  → pick "Plugin Release"
````

### Updating Existing Plugins

```bash
git pull origin main

# Make changes
vim plugins/agent-orchestrator/commands/orchestrate.md

# Either bump versions manually...
vim plugins/agent-orchestrator/.claude-plugin/plugin.json    # 1.0.0 → 1.0.1
vim .claude-plugin/marketplace.json                          # match it

# ...or let the release pipeline bump them in Phase 2
# Then commit + push:
./scripts/validate-marketplace.sh
git add plugins/agent-orchestrator .claude-plugin/marketplace.json
git commit -m "Update agent-orchestrator to v1.0.1"
git push origin main

# To tag + publish: /release-pipeline:release  → pick "Plugin Release"
```

## Key Architectural Patterns

### Context Management Philosophy

**Critical insight from agent-orchestrator design**: Claude Code sessions degrade on complex tasks due to context filling. Effective plugins minimize context footprint by:

1. **External execution** - Hooks and scripts run outside context; only stdout returns
2. **Template externalization** - Large instruction sets live in template files, not inline prompts
3. **On-demand loading** - Skills load only when relevant; commands load on invocation
4. **Disposable subagents** - Exploration happens in separate context windows that get discarded

### Component Context Cost

When designing plugins, understand what enters the AI's context window:

| Component         | Loads into context? | When?                               |
| ----------------- | ------------------- | ----------------------------------- |
| Command markdown  | Yes                 | On `/command` invocation            |
| Skill markdown    | Conditionally       | When AI deems relevant              |
| Agent definitions | No (for parent)     | Loaded by spawned agent itself      |
| Hooks JSON config | No                  | Processed at plugin install         |
| Hook scripts      | No                  | Run externally, only stdout returns |
| Templates         | No                  | Copied to disk, read independently  |

**Design principle**: Keep inline content minimal. Move large instruction sets to templates. Use hooks for enforcement rather than lengthy behavioral instructions.

### Enforcement Layers

Effective plugins use three enforcement layers (strongest to weakest):

1. **Mechanical** - Hooks that deterministically block/warn regardless of AI behavior
2. **Structural** - Architectural constraints (e.g., git worktrees for file isolation)
3. **Behavioral** - Instructions in prompts (weakest, but covers widest surface)

Don't rely solely on behavioral instructions ("NEVER do X"). Add mechanical enforcement where critical.

## Plugin Structure

Every plugin requires `.claude-plugin/plugin.json`:

```json
{ "name": "plugin-identifier", "version": "1.0.0", "description": "Brief description" }
```

**Plugin components** (all optional except manifest):

- **commands/** - User-invocable slash commands (e.g., `/orchestrate`)
- **skills/** - AI-invoked domain knowledge (trigger based on context relevance)
- **agents/** - Custom subagent definitions with tool restrictions
- **hooks/** - Lifecycle event handlers (PreToolUse, PostToolUse, PreCompact, etc.)
- **scripts/** - External shell scripts (for hooks or commands)
- **templates/** - Files copied to projects during plugin operation

## Validation

Always validate before creating PR:

```bash
# Comprehensive validation
./scripts/validate-marketplace.sh

# Checks:
# - JSON syntax
# - Required fields (name, version, description)
# - Semver format
# - Plugin directory existence
# - Version consistency (plugin ↔ marketplace)
# - No duplicate names
```

## Versioning

Use semantic versioning for both marketplace and plugins:

**Plugin versions**:

- **Major** (1.0.0 → 2.0.0) - Breaking changes to plugin API
- **Minor** (1.0.0 → 1.1.0) - New features, backwards compatible
- **Patch** (1.0.0 → 1.0.1) - Bug fixes, documentation updates

**Marketplace version**:

- **Major** (2.0.0) - Breaking changes to marketplace structure
- **Minor** (1.1.0) - New plugins added
- **Patch** (1.0.1) - Plugin updates, metadata fixes

**Version synchronization**: When updating a plugin, both files must be updated together:

1. Bump version in `plugins/<name>/.claude-plugin/plugin.json`
2. Update matching version in `.claude-plugin/marketplace.json`
3. Commit both changes together

## Learning from agent-orchestrator

The `agent-orchestrator` plugin is a comprehensive reference implementation:

**Problem it solves**: Context degradation on complex multi-file tasks

**Solution approach**:

- Triage gate (skip orchestration for simple tasks)
- Plan mode for exploration (disposable context)
- Git worktrees for file isolation (structural enforcement)
- Single-writer ledger pattern (prevent concurrent writes)
- Read counter hook (warn when approaching context limits)
- Lead write guard hook (prevent coordinator from implementing)

**File organization**:

- DESIGN.md documents architecture decisions and rationale
- README.md provides user-facing usage guide
- Scripts stay external (never enter context)
- Templates copied to disk (read independently by agents)
- Hooks registered declaratively (hooks.json)

## Documentation Reference

- **docs/plugins.md** - Plugin development guide and quick start
- **docs/plugin-marketplaces.md** - Creating and hosting marketplaces
- **docs/plugins-reference.md** - Complete manifest schema, CLI commands
- **docs/skills.md** - Skill YAML frontmatter, trigger patterns
- **docs/sub-agents.md** - Custom agent definitions, tool restrictions
- **docs/hooks.md** - All hook types, event schemas, debugging
- **docs/mcp.md** - MCP server integration in plugins
- **BRANCH_PROTECTION.md** - Complete workflow guide

## Common Tasks

### Test Plugin Locally

```bash
claude --plugin-dir ./plugins/plugin-name

# Verify in session
/plugin list
/help  # Shows commands from all loaded plugins
```

### Validate Marketplace

```bash
./scripts/validate-marketplace.sh
```

### Tagged Release

```bash
# Run the release pipeline; it handles version bump + changelog + tag + GitHub release
/release-pipeline:release
# Pick mode based on scope:
#   "Plugin Release" — release a single plugin
#   "Batch Release"  — release every plugin with unreleased commits
```

## Important Rules

1. **Direct commit to `main`** — no `testing` branch (retired 2026-05-07)
2. **Validate marketplace consistency** — `./scripts/validate-marketplace.sh` before pushing changes that touch any plugin manifest
3. **Version synchronization** — `plugins/<name>/.claude-plugin/plugin.json` and the matching entry in `.claude-plugin/marketplace.json` must always agree
4. **Test locally first** — `claude --plugin-dir ./plugins/<name>` before pushing
5. **Use the release pipeline for tagged releases** — `/release-pipeline:release` handles bump + changelog + tag + GitHub release together

See [BRANCH_PROTECTION.md](../BRANCH_PROTECTION.md) for complete workflow documentation.

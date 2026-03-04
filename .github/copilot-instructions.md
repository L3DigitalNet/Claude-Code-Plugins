# AI Agent Instructions for Claude Code Plugins Marketplace

## Repository Purpose

This is a **dual-purpose repository**:

1. **Plugin marketplace** - Distributes Claude Code plugins via
   `/plugin marketplace add L3DigitalNet/Claude-Code-Plugins`
2. **Development workspace** - Creates and tests new plugins before publication

## Architecture Overview

### Branch Strategy

```
main     ← Protected production branch (marketplace distribution)
testing  ← Development branch (all work happens here)
```

**IMPORTANT**: Always work on the `testing` branch. The `main` branch is protected and requires manual merge (GitHub blocks direct pushes).

### Directory Structure

```
├── .claude-plugin/marketplace.json  # Marketplace catalog (source of truth)
├── plugins/                         # All plugins (development + production)
│   └── agent-orchestrator/          # Reference implementation
├── scripts/
│   └── validate-marketplace.sh      # Marketplace validation
└── BRANCH_PROTECTION.md             # Workflow documentation
```

### Branch Protection

**`main` branch protection**:
- Direct pushes blocked by GitHub
- Requires manual merge from `testing`
- Prevents accidental production changes

**Development workflow**:
1. Work on `testing` branch with direct commits
2. Validate with `./scripts/validate-marketplace.sh`
3. Merge `testing` → `main` when ready to deploy
4. GitHub enforces protection (blocks accidental pushes)

## Development Workflow

### Creating New Plugins

```bash
# Ensure on testing branch
git checkout testing
git pull origin testing

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

# Add to marketplace catalog
vim .claude-plugin/marketplace.json
# Add entry with version 1.0.0

# Validate
./scripts/validate-marketplace.sh

# Commit to testing
git add plugins/my-plugin .claude-plugin/marketplace.json
git commit -m "Add my-plugin v1.0.0"
git push origin testing

# When ready to deploy
git checkout main
git pull origin main
git merge testing --no-ff -m "Deploy my-plugin v1.0.0"
git push origin main
git checkout testing
```

### Updating Existing Plugins

```bash
# Work on testing branch
git checkout testing

# Make changes
vim plugins/agent-orchestrator/commands/orchestrate.md

# Bump version in manifest
vim plugins/agent-orchestrator/.claude-plugin/plugin.json
# "version": "1.0.0" → "1.0.1"

# Update marketplace catalog
vim .claude-plugin/marketplace.json
# Update matching entry version

# Validate
./scripts/validate-marketplace.sh

# Commit and push
git add plugins/agent-orchestrator .claude-plugin/marketplace.json
git commit -m "Update agent-orchestrator to v1.0.1"
git push origin testing

# When ready to deploy
git checkout main
git pull origin main
git merge testing --no-ff -m "Deploy agent-orchestrator v1.0.1"
git push origin main
git checkout testing
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

| Component | Loads into context? | When? |
|-----------|---------------------|-------|
| Command markdown | Yes | On `/command` invocation |
| Skill markdown | Conditionally | When AI deems relevant |
| Agent definitions | No (for parent) | Loaded by spawned agent itself |
| Hooks JSON config | No | Processed at plugin install |
| Hook scripts | No | Run externally, only stdout returns |
| Templates | No | Copied to disk, read independently |

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
{
  "name": "plugin-identifier",
  "version": "1.0.0",
  "description": "Brief description"
}
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

### Deploy to Production

```bash
# From testing branch
git checkout testing
./scripts/validate-marketplace.sh

# Deploy to main
git checkout main
git pull origin main
git merge testing --no-ff -m "Deploy: <description>"
git push origin main
git checkout testing
```

## Important Rules

1. **Never push directly to `main`** - GitHub branch protection prevents this
2. **Always work on `testing` branch** - This is your development workspace
3. **Validate before deploy** - Run `./scripts/validate-marketplace.sh` before merging to main
4. **Version synchronization** - Update both plugin manifest and marketplace.json together
5. **Test locally first** - Use `claude --plugin-dir` before pushing
6. **Deploy via merge** - Use `git merge testing --no-ff` when moving to production

See [BRANCH_PROTECTION.md](../BRANCH_PROTECTION.md) for complete workflow documentation.

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This is a **Claude Code plugin marketplace and development repository**. It serves two functions:
1. Development workspace for creating new Claude Code plugins
2. Distribution point (marketplace) for installing plugins via `/plugin marketplace add`

## Branch Strategy

**IMPORTANT**: This repository uses branch protection to prevent accidental production changes.

- **`main`** - Protected production branch (marketplace distribution)
- **`testing`** - Development branch (all work happens here)

**Always work on the `testing` branch**. Changes to `main` require pull request approval.

## Repository Structure

```
Claude-Code-Plugins/
├── .claude-plugin/
│   └── marketplace.json        # Marketplace catalog (defines available plugins)
├── plugins/                     # All plugins (development and production)
│   └── agent-orchestrator/      # Example: full-featured orchestration plugin
├── scripts/
│   └── validate-marketplace.sh  # Marketplace integrity validation
├── docs/                        # Comprehensive plugin development documentation
├── CLAUDE.md                    # This file (AI agent guidance)
├── BRANCH_PROTECTION.md         # Branch protection and workflow guide
└── README.md                    # Marketplace installation and usage
```

## Marketplace Management

### Adding this Marketplace to Claude Code

Users install this marketplace with:

```bash
/plugin marketplace add L3DigitalNet/Claude-Code-Plugins
# or
/plugin marketplace add https://github.com/L3DigitalNet/Claude-Code-Plugins.git
```

Then install individual plugins:

```bash
/plugin install agent-orchestrator@claude-code-plugins
```

### Adding a New Plugin to the Marketplace

1. **Create plugin in `plugins/` directory**
2. **Add entry to `.claude-plugin/marketplace.json`**:
   ```json
   {
     "name": "plugin-name",
     "displayName": "Human Readable Name",
     "description": "Brief description (1-2 sentences)",
     "version": "1.0.0",
     "author": "Author Name",
     "license": "MIT",
     "keywords": ["tag1", "tag2"],
     "homepage": "https://github.com/L3DigitalNet/Claude-Code-Plugins/tree/main/plugins/plugin-name",
     "repository": "https://github.com/L3DigitalNet/Claude-Code-Plugins",
     "source": {
       "type": "github",
       "owner": "L3DigitalNet",
       "repo": "Claude-Code-Plugins",
       "ref": "main"
     }
   }
   ```
3. **Bump marketplace version** (semver in marketplace.json)
4. **Update README.md** with plugin description

### Marketplace Validation

```bash
# Validate JSON syntax
jq . .claude-plugin/marketplace.json

# Validate structure
jq -e '.name and .version and .plugins' .claude-plugin/marketplace.json && echo "✓ Valid marketplace"
```

## Working with Plugins

### Testing Plugins Locally

```bash
# Test a plugin from this repository
claude --plugin-dir ./plugins/plugin-name

# Within a Claude Code session, verify plugin loaded
/plugin list
/help  # Shows all available commands including plugin commands
```

### Plugin Structure

Every plugin requires `.claude-plugin/manifest.json` (or `plugin.json`):

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

### Validation

```bash
# Validate manifest JSON syntax
jq . plugins/plugin-name/.claude-plugin/manifest.json

# Validate marketplace catalog
jq . .claude-plugin/marketplace.json
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

### Hooks Best Practices

From agent-orchestrator implementation:

**PreToolUse hooks** - Mechanical enforcement (blocking unwanted tool calls)
```bash
# Return JSON with exit code 2 to block
echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","decision":"block","reason":"..."}}'
exit 2
```

**PostToolUse hooks** - Monitoring and warnings (inject context)
```bash
# stdout gets injected into agent context
echo "⚠️ Warning: You have read 10 files in this session"
exit 0
```

**Session-aware enforcement** - Use environment variables to distinguish agent roles
```bash
# Example: ORCHESTRATOR_LEAD=1 blocks writes for lead, allows for teammates
if [ "$ORCHESTRATOR_LEAD" = "1" ]; then
    # block write
fi
```

### Enforcement Layers

Effective plugins use three enforcement layers (strongest to weakest):

1. **Mechanical** - Hooks that deterministically block/warn regardless of AI behavior
2. **Structural** - Architectural constraints (e.g., git worktrees for file isolation)
3. **Behavioral** - Instructions in prompts (weakest, but covers widest surface)

Don't rely solely on behavioral instructions ("NEVER do X"). Add mechanical enforcement where critical.

## Documentation Reference

- **docs/plugins.md** - Plugin development guide and quick start
- **docs/plugin-marketplaces.md** - Creating and hosting marketplaces
- **docs/plugins-reference.md** - Complete manifest schema, CLI commands
- **docs/skills.md** - Skill YAML frontmatter, trigger patterns
- **docs/sub-agents.md** - Custom agent definitions, tool restrictions
- **docs/hooks.md** - All hook types, event schemas, debugging
- **docs/mcp.md** - MCP server integration in plugins
- **docs/quickstart.md** - Claude Code installation and basics
- **BRANCH_PROTECTION.md** - Branch protection and workflow guide

## Plugin Development Workflow

**All development happens on the `testing` branch**. Changes to `main` require PR approval.

### Creating a New Plugin

```bash
# Ensure you're on testing branch
git checkout testing
git pull origin testing

# Create plugin structure
mkdir -p plugins/my-plugin/.claude-plugin
mkdir -p plugins/my-plugin/{commands,skills,agents,hooks}

# Create manifest
cat > plugins/my-plugin/.claude-plugin/manifest.json << 'EOF'
{
  "name": "my-plugin",
  "version": "1.0.0",
  "description": "Plugin description"
}
EOF

# Test locally
claude --plugin-dir ./plugins/my-plugin

# Add to marketplace catalog
vim .claude-plugin/marketplace.json
# Add entry with version 1.0.0

# Validate before committing
./scripts/validate-marketplace.sh

# Commit to testing branch
git add plugins/my-plugin .claude-plugin/marketplace.json
git commit -m "Add my-plugin v1.0.0"
git push origin testing

# Create PR to main
gh pr create --base main --title "Add my-plugin v1.0.0" \
  --body "New plugin: [description]"
```

### Updating an Existing Plugin

```bash
# Work on testing branch
git checkout testing
git pull origin testing

# Make changes
vim plugins/agent-orchestrator/commands/orchestrate.md

# Bump version in plugin manifest
vim plugins/agent-orchestrator/.claude-plugin/plugin.json
# Change: "version": "1.0.0" → "1.0.1"

# Update marketplace catalog
vim .claude-plugin/marketplace.json
# Update matching entry version

# Validate
./scripts/validate-marketplace.sh

# Commit and push
git add plugins/agent-orchestrator .claude-plugin/marketplace.json
git commit -m "Update agent-orchestrator to v1.0.1

- Fixed bug in orchestrate command
- Updated documentation"
git push origin testing

# Create PR to main
gh pr create --base main --title "Update agent-orchestrator to v1.0.1"
```

See [BRANCH_PROTECTION.md](BRANCH_PROTECTION.md) for detailed workflows including emergency hotfixes.

## Learning from agent-orchestrator

The `agent-orchestrator` plugin is a comprehensive reference implementation. Key lessons:

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

## Distribution Strategy

This repository serves as a marketplace that can be installed with:

```bash
/plugin marketplace add owner/Claude-Code-Plugins
```

Users can then install individual plugins:

```bash
/plugin install agent-orchestrator@Claude-Code-Plugins
```

## Branch Protection

This repository uses GitHub branch protection to prevent accidental changes to production plugins:

**`main` branch** (Protected):
- Direct pushes blocked
- Requires pull request with approval
- Status checks must pass (if configured)
- Production plugins distributed from here

**`testing` branch** (Development):
- All development happens here
- Free to commit and push
- Create PR to merge into `main`

**Validation before PR**:
```bash
# Always validate before creating PR
./scripts/validate-marketplace.sh

# Checks:
# - JSON syntax
# - Required fields
# - Version formats
# - Plugin directory existence
# - Version consistency
# - Duplicate names
```

**Version synchronization**:
When updating a plugin, both files must change together:
1. Bump version in `plugins/<name>/.claude-plugin/plugin.json`
2. Update matching version in `.claude-plugin/marketplace.json`
3. Commit both files together

See [BRANCH_PROTECTION.md](BRANCH_PROTECTION.md) for complete workflow documentation.

## Versioning

Use semantic versioning for both:
- **Marketplace version** - Bump when adding/removing/updating plugin entries
- **Plugin versions** - Each plugin has independent versioning

**Marketplace versioning**:
- **Major** (2.0.0) - Breaking changes to marketplace structure
- **Minor** (1.1.0) - New plugins added
- **Patch** (1.0.1) - Plugin updates, metadata fixes

**Plugin versioning**:
- **Major** (1.0.0 → 2.0.0) - Breaking changes to plugin API
- **Minor** (1.0.0 → 1.1.0) - New features, backwards compatible
- **Patch** (1.0.0 → 1.0.1) - Bug fixes, documentation updates

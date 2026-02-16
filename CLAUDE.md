# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This is a **Claude Code plugin marketplace and development repository**. It serves two functions:
1. Development workspace for creating new Claude Code plugins
2. Distribution point (marketplace) for installing plugins via `/plugin marketplace add`

## Repository Structure

```
Claude-Code-Plugins/
├── .claude-plugin/
│   └── marketplace.json        # Marketplace catalog (defines available plugins)
├── .githooks/
│   └── pre-commit               # Version enforcement hook (run ./scripts/setup-hooks.sh)
├── plugins/                     # Production plugins (PROTECTED by pre-commit hook)
│   └── agent-orchestrator/      # Example: full-featured orchestration plugin
├── plugins-dev/                 # Development plugins (unrestricted)
│   └── README.md
├── scripts/
│   ├── setup-hooks.sh           # One-time hook installation
│   ├── validate-marketplace.sh  # Marketplace integrity validation
│   └── promote-plugin.sh        # Dev→production promotion automation
├── docs/                        # Comprehensive plugin development documentation
├── CLAUDE.md                    # This file (AI agent guidance)
├── PROTECTION_SYSTEM.md         # Complete protection system guide
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
- **PROTECTION_SYSTEM.md** - Complete protection system guide with workflows and troubleshooting

## Plugin Development Workflow

### Initial Setup (One-time)

```bash
# Enable git hooks for production plugin protection
./scripts/setup-hooks.sh
```

### Development Workflow

**For new plugins** (recommended approach):

1. **Create in development directory**:
   ```bash
   mkdir -p plugins-dev/my-plugin/.claude-plugin
   mkdir -p plugins-dev/my-plugin/{commands,skills,agents,hooks}
   ```

2. **Create manifest**:
   ```bash
   cat > plugins-dev/my-plugin/.claude-plugin/manifest.json << 'EOF'
   {
     "name": "my-plugin",
     "version": "0.1.0",
     "description": "Plugin description"
   }
   EOF
   ```

3. **Develop and test**:
   ```bash
   # No version constraints, no pre-commit warnings
   claude --plugin-dir ./plugins-dev/my-plugin
   ```

4. **Promote to production** when ready:
   ```bash
   ./scripts/promote-plugin.sh my-plugin --version 1.0.0
   # This automatically:
   # - Copies to plugins/
   # - Adds to marketplace catalog
   # - Sets version
   # - Bumps marketplace version
   ```

**For direct production development** (use cautiously):

1. **Create directly in plugins/**:
   ```bash
   mkdir -p plugins/my-plugin/.claude-plugin
   ```

2. **Pre-commit hook will enforce**:
   - Version bump required for any changes
   - Marketplace catalog must be updated
   - Prevents accidental modifications

**Legacy workflow (for reference)**:
   ```json
   {
     "plugins": [
       {
         "name": "my-plugin",
         "displayName": "My Plugin",
         "description": "Does something useful",
         "version": "0.1.0",
         "author": "Your Name",
         "source": {
           "type": "github",
           "owner": "username",
           "repo": "Claude-Code-Plugins",
           "ref": "main"
         }
       }
     ]
   }
   ```

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

## Protection Features

This repository implements multiple layers of protection for production plugins:

### 1. Directory Separation

- **`plugins/`** - Production plugins in marketplace (protected)
- **`plugins-dev/`** - Development plugins (unrestricted)

### 2. Git Pre-Commit Hook

**Location**: `.githooks/pre-commit`

**Protections**:
- ❌ **Blocks** commits to production plugins without version bump
- ⚠️ **Warns** when modifying production plugins
- ✓ **Validates** marketplace.json version bumps
- ✓ **Checks** version consistency between plugin and marketplace
- 💡 **Suggests** promotion for ready dev plugins

**Enable**: `./scripts/setup-hooks.sh`

**Bypass** (not recommended): `git commit --no-verify`

### 3. Validation Scripts

**`scripts/validate-marketplace.sh`** - Comprehensive validation:
```bash
./scripts/validate-marketplace.sh
# Checks:
# - JSON syntax
# - Required fields
# - Version formats
# - Plugin directory existence
# - Version consistency
# - Duplicate names
```

**`scripts/promote-plugin.sh`** - Safe promotion workflow:
```bash
./scripts/promote-plugin.sh <plugin-name> --version <version>
# Automates:
# - Version setting
# - Directory copying
# - Marketplace entry creation
# - Version bumping
```

### 4. Workflow Enforcement

**Modifying production plugins requires**:
1. Bump version in plugin manifest
2. Update version in marketplace catalog
3. Stage both files together
4. Pre-commit hook validates changes

**Example**:
```bash
# Wrong: Will be blocked
vim plugins/agent-orchestrator/commands/orchestrate.md
git commit -am "Update orchestrator"  # ❌ BLOCKED

# Right: Version bump first
vim plugins/agent-orchestrator/.claude-plugin/plugin.json
# Change: "version": "1.0.0" → "1.0.1"

vim .claude-plugin/marketplace.json
# Update plugin version: "version": "1.0.1"

git add plugins/agent-orchestrator .claude-plugin/marketplace.json
git commit -m "Update agent-orchestrator to v1.0.1"  # ✓ ALLOWED
```

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

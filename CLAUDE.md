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

**Always work on the `testing` branch**. Changes to `main` require manual merge (GitHub blocks direct pushes).

## Repository Structure

```
Claude-Code-Plugins/
├── .claude-plugin/
│   └── marketplace.json        # Marketplace catalog (defines available plugins)
├── plugins/                     # All plugins (development and production)
│   ├── agent-orchestrator/      # Agent team orchestration
│   ├── home-assistant-dev/      # Home Assistant integration dev toolkit
│   ├── github-repo-manager/     # Conversational GitHub repo maintenance
│   ├── release-pipeline/        # Autonomous release pipeline
│   ├── design-refine/           # Design document refinement
│   └── linux-sysadmin-mcp/      # Linux sysadmin MCP server (~100 tools)
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
/plugin install agent-orchestrator@l3digitalnet-plugins
```

### Adding a New Plugin to the Marketplace

1. **Create plugin in `plugins/` directory**
2. **Add entry to `.claude-plugin/marketplace.json`**:
   ```json
   {
     "name": "plugin-name",
     "description": "Brief description (1-2 sentences)",
     "version": "1.0.0",
     "author": {
       "name": "L3DigitalNet",
       "url": "https://github.com/L3DigitalNet"
     },
     "source": "./plugins/plugin-name",
     "category": "development",
     "homepage": "https://github.com/L3DigitalNet/Claude-Code-Plugins/tree/main/plugins/plugin-name"
   }
   ```
3. **Update README.md** with plugin description

### Marketplace Validation

```bash
# Validate JSON syntax
jq . .claude-plugin/marketplace.json

# Validate structure
jq -e '.name and .owner and .plugins' .claude-plugin/marketplace.json && echo "✓ Valid marketplace"
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
- **.mcp.json** - MCP server config (at plugin root, not inside `.claude-plugin/`)

**MCP server plugins** additionally require `.mcp.json` at the plugin root:
```json
{
  "server-name": {
    "command": "node",
    "args": ["dist/server.js"]
  }
}
```
For npm-published servers, use `"command": "npx", "args": ["-y", "@scope/package"]`.
For HTTP-based servers, use `"type": "http", "url": "...", "headers": {...}`.

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

From agent-orchestrator implementation. Reference: `plugins/agent-orchestrator/hooks/hooks.json`

**hooks.json schema** — `hooks` must be a **record** (object keyed by event name), NOT an array:
```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit|MultiEdit|NotebookEdit",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/my-hook.sh"
          }
        ]
      }
    ]
  }
}
```

**Hook scripts receive JSON on stdin** with tool context (not variable substitution):
```bash
# Extract file path from stdin JSON — only ${CLAUDE_PLUGIN_ROOT} is available in command strings
FILE_PATH=$(cat | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('tool_input', {}).get('file_path') or d.get('tool_input', {}).get('path') or '')
")
```

**Dispatcher pattern** — prefer one hook per event type with a bash dispatcher that routes by file path, rather than multiple hooks with custom file pattern matching (which doesn't exist in the schema).

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

**All development happens on the `testing` branch**. Deploy to `main` via manual merge when ready.

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

# When ready to deploy
git checkout main
git pull origin main
git merge testing --no-ff -m "Deploy my-plugin v1.0.0"
git push origin main
git checkout testing
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

# When ready to deploy
git checkout main
git pull origin main
git merge testing --no-ff -m "Deploy agent-orchestrator v1.0.1"
git push origin main
git checkout testing
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
/plugin marketplace add L3DigitalNet/Claude-Code-Plugins
```

Users can then install individual plugins:

```bash
/plugin install agent-orchestrator@l3digitalnet-plugins
```

## Branch Protection

This repository uses GitHub branch protection to prevent accidental changes to production plugins:

**`main` branch** (Protected):
- Direct pushes blocked by GitHub
- Manual merge from `testing` required
- Production plugins distributed from here

**`testing` branch** (Development):
- All development happens here
- Direct commits and pushes allowed
- Merge to `main` when ready to deploy

**Validation before deploy**:
```bash
# Always validate before merging to main
./scripts/validate-marketplace.sh

# Checks:
# - JSON syntax
# - Required root fields (name, owner, plugins)
# - Invalid root fields (version, homepage, repository, license)
# - Required plugin fields (name, description, source)
# - Invalid plugin fields (displayName, keywords, license)
# - author is object (not string)
# - Plugin directory and manifest existence
# - Version consistency (marketplace vs plugin.json)
# - Duplicate plugin names
```

**Deployment workflow**:
```bash
# Validate on testing
git checkout testing
./scripts/validate-marketplace.sh

# Merge to main
git checkout main
git merge testing --no-ff -m "Deploy: <description>"
git push origin main
git checkout testing
```

**Version synchronization**:
When updating a plugin, both files must change together:
1. Bump version in `plugins/<name>/.claude-plugin/plugin.json`
2. Update matching version in `.claude-plugin/marketplace.json`
3. Commit both files together

See [BRANCH_PROTECTION.md](BRANCH_PROTECTION.md) for complete workflow documentation.

## Versioning

Plugin versions use semantic versioning:
- **Major** (1.0.0 → 2.0.0) - Breaking changes to plugin API
- **Minor** (1.0.0 → 1.1.0) - New features, backwards compatible
- **Patch** (1.0.0 → 1.0.1) - Bug fixes, documentation updates

## Marketplace Schema Reference

**The Claude Code marketplace validator (Zod-based) enforces a strict schema** that differs from some community documentation. When in doubt, reference these working marketplaces installed locally:

- `~/.claude/plugins/marketplaces/claude-plugins-official/` (Anthropic's official)

### Key schema rules

**Ground truth**: Always compare against `~/.claude/plugins/marketplaces/claude-plugins-official/.claude-plugin/marketplace.json` — the Anthropic official marketplace is the authoritative schema reference.

**Reserved names**: Names like `claude-code-plugins` are reserved for official Anthropic marketplaces (repos under `github.com/anthropics/`). Use a unique prefix like `l3digitalnet-plugins`.

**Root level** — required fields: `name`, `owner` (object), `plugins` (array). Optional: `description`.
**Root level — INVALID fields** (Zod rejects these): `version`, `homepage`, `repository`, `license`.

```json
{
  "name": "marketplace-name",
  "description": "...",
  "owner": { "name": "...", "url": "..." },
  "plugins": []
}
```

**Plugin entries** — required: `name`, `description`, `source`. Optional valid: `version`, `author` (object), `category`, `homepage`, `tags`, `strict`.
**Plugin entries — INVALID fields** (Zod rejects these): `displayName`, `keywords`, `license`.

**Plugin manifests (plugin.json) are lenient** — unlike marketplace.json, the plugin.json schema tolerates extra fields like `keywords`, `license`, `repository`, `homepage`. The strict Zod validation only applies to marketplace.json entries.

```json
{
  "name": "plugin-name",
  "description": "...",
  "version": "1.0.0",
  "author": { "name": "...", "url": "..." },
  "source": "./plugins/plugin-name"
}
```

**External plugin sources** use `{"source": "url", "url": "https://..."}` (note: the key is `source`, not `type`).

## Gotchas

- **Installed marketplace cache is stale** — `~/.claude/plugins/marketplaces/<name>/` doesn't auto-update from the source repo. After changing marketplace.json, users must re-add the marketplace or manually update the cached copy.
- **Marketplace cache is a full git clone** — updating one file in the cache doesn't update the tree. Use `cd ~/.claude/plugins/marketplaces/<name> && git fetch origin && git reset --hard origin/main` to properly refresh.
- **settings.json `enabledPlugins` has stale refs** — removing a marketplace doesn't clean up enabled plugin entries. Stale entries like `"plugin@removed-marketplace": true` cause "failed to load" errors. Manually remove from `~/.claude/settings.json`.
- **Bash `((var++))` with `set -e`** — returns exit code 1 when var=0 (pre-increment value is falsy). Use `var=$((var + 1))` instead in scripts with `set -e`.
- **MCP server plugins need `npm install`** — the plugin install process doesn't install Node.js dependencies. Ensure `node_modules/` exists or use `npx` in `.mcp.json`.

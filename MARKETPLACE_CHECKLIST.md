# Marketplace Checklist

This checklist ensures the repository adheres to Claude Code marketplace requirements.

## Required Files ✓

- [x] `.claude-plugin/marketplace.json` - Marketplace catalog
- [x] `README.md` - Installation and usage instructions
- [x] `LICENSE` - License file

## Marketplace JSON Structure ✓

Required fields in `.claude-plugin/marketplace.json`:
- [x] `name` - Marketplace identifier
- [x] `version` - Semantic versioning
- [x] `description` - One-line summary
- [x] `plugins` - Array of plugin entries

Optional but recommended:
- [x] `author` - Author information
- [x] `homepage` - Repository URL
- [x] `repository` - Git repository URL
- [x] `license` - License identifier

## Plugin Entries ✓

Each plugin in the `plugins` array must have:
- [x] `name` - Plugin identifier (matches plugin manifest)
- [x] `displayName` - Human-readable name
- [x] `description` - Brief description
- [x] `version` - Plugin version
- [x] `author` - Plugin creator
- [x] `source` - Download location with type, owner, repo

Optional:
- [x] `keywords` - Search tags
- [x] `homepage` - Plugin documentation URL
- [x] `repository` - Repository URL
- [x] `license` - License identifier

## Plugin Structure

Each plugin in `plugins/` directory must have:
- [x] `.claude-plugin/manifest.json` (or `plugin.json`)
- [x] `README.md` - Plugin documentation
- [ ] At least one component (commands/, skills/, agents/, hooks/)

Current plugins:
- agent-orchestrator ✓

## Validation Commands

```bash
# Validate marketplace JSON syntax
jq . .claude-plugin/marketplace.json

# Check required fields
jq -e '.name and .version and .description and .plugins' .claude-plugin/marketplace.json

# Validate each plugin entry
jq -e '.plugins[] | .name and .displayName and .description and .version and .author and .source' .claude-plugin/marketplace.json

# Check plugin manifest
jq . plugins/agent-orchestrator/.claude-plugin/plugin.json
```

## Testing Installation

```bash
# Add marketplace locally
/plugin marketplace add /path/to/Claude-Code-Plugins

# Install plugin
/plugin install agent-orchestrator@claude-code-plugins

# Verify plugin loaded
/plugin list
```

## Distribution

Once pushed to GitHub, users can install with:

```bash
/plugin marketplace add L3DigitalNet/Claude-Code-Plugins
/plugin install agent-orchestrator@claude-code-plugins
```

## Updating the Marketplace

When adding or updating plugins:

1. Update plugin files in `plugins/`
2. Update plugin entry in `.claude-plugin/marketplace.json`
3. Bump marketplace version:
   - **Patch** (1.0.1) - Plugin updates, fixes
   - **Minor** (1.1.0) - New plugins added
   - **Major** (2.0.0) - Breaking changes
4. Update `README.md` if needed
5. Commit and push to GitHub

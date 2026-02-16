# Claude Code Plugins Marketplace

A curated collection of Claude Code plugins for enhanced development workflows, featuring advanced agent orchestration, context management, and automation capabilities.

## Installation

Add this marketplace to your Claude Code installation:

```bash
/plugin marketplace add L3DigitalNet/Claude-Code-Plugins
```

Or using the full URL:

```bash
/plugin marketplace add https://github.com/L3DigitalNet/Claude-Code-Plugins.git
```

## Available Plugins

### Agent Orchestrator

**General-purpose agent team orchestration** with automatic context management, file isolation via git worktrees, and mechanical enforcement hooks.

**Features:**
- Triage gate for simple vs complex tasks
- Parallel execution via agent teams (or sequential fallback)
- Git worktree isolation for concurrent work
- Context degradation prevention via hooks
- Quality gate with integration checking

**Install:**
```bash
/plugin install agent-orchestrator@claude-code-plugins
```

**Learn more:** [plugins/agent-orchestrator/README.md](plugins/agent-orchestrator/README.md)

## Plugin Development

This repository also serves as a development workspace for creating new plugins. See [CLAUDE.md](CLAUDE.md) for architectural guidance and [docs/](docs/) for comprehensive documentation.

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
│   └── marketplace.json      # Marketplace catalog
├── plugins/                   # All plugin implementations
│   └── agent-orchestrator/    # Agent team orchestration plugin
├── scripts/
│   └── validate-marketplace.sh # Marketplace validation
├── docs/                      # Comprehensive documentation
├── CLAUDE.md                  # Development guidance for AI agents
├── BRANCH_PROTECTION.md       # Branch protection and workflow guide
└── README.md                  # This file
```

## Contributing

To add a plugin to this marketplace:

1. **Work on the `testing` branch** (all development happens here)
2. Create plugin in `plugins/` directory
3. Add entry to `.claude-plugin/marketplace.json`
4. Update marketplace version (semver)
5. Validate with `./scripts/validate-marketplace.sh`
6. Push to `testing` branch
7. Create pull request to `main` for review

**Branch workflow:**
- **`main`** - Protected production branch (requires PR approval)
- **`testing`** - Development branch (unrestricted)

See [BRANCH_PROTECTION.md](BRANCH_PROTECTION.md) for detailed workflow documentation.

**Marketplace versioning:**
- **Major** (2.0.0) - Breaking changes to marketplace structure
- **Minor** (1.1.0) - New plugins added
- **Patch** (1.0.1) - Plugin updates, metadata fixes

## License

MIT - See [LICENSE](LICENSE) file for details
---
title: Plugins Technical Reference
category: reference
target_platform: linux
audience: ai_agent
keywords: [reference, schema, manifest, cli, debugging]
---

# Plugins Technical Reference

## Component Overview

| Component | Location        | Purpose                | Details                          |
| --------- | --------------- | ---------------------- | -------------------------------- |
| Skills    | `skills/`       | Domain knowledge       | [skills.md](./skills.md)         |
| Agents    | `agents/`       | Specialized assistants | [sub-agents.md](./sub-agents.md) |
| Hooks     | `hooks/`        | Lifecycle events       | [hooks.md](./hooks.md)           |
| MCP       | `.mcp.json`     | External tools         | [mcp.md](./mcp.md)               |
| LSP       | `.lsp.json`     | Code intelligence      | See below                        |
| Commands  | `commands/`     | User commands          | Slash commands (see plugins.md)  |

## manifest.json Schema

**Location:** `.claude-plugin/plugin.json`

The manifest uses Zod strict mode — unknown fields are rejected. Only the fields listed here are valid.

### Complete Schema

```json
{
  // Required
  "name": string,              // Unique ID (lowercase-hyphenated)
  "version": string,           // Semver (e.g., "1.0.0")
  "description": string,       // One-line summary

  // Optional
  "author": {                  // Author info
    "name": string,
    "url": string              // or "email": string
  },
  "homepage": string           // Plugin homepage URL
}
```

MCP servers are configured in `.mcp.json` at plugin root (not in `plugin.json`).
LSP servers are configured in `.lsp.json` at plugin root (not in `plugin.json`).

- **author**: Object with `name` and `url` (or `email`). Plugin creator information.
- **homepage**: String. URL to plugin documentation or repository.

### Complete example

```json
{
  "name": "my-plugin",
  "version": "1.2.0",
  "description": "One-line description of what this plugin does.",
  "author": {
    "name": "Your Name",
    "url": "https://github.com/your-org"
  },
  "homepage": "https://github.com/your-org/your-repo/tree/main/plugins/my-plugin"
}
```

## MCP configuration

Configure MCP servers in `.mcp.json` at plugin root (not inside `.claude-plugin/`):

```json
{
  "server-name": {
    "command": "node",
    "args": ["dist/server.js"]
  }
}
```

For npx-based servers:

```json
{
  "server-name": {
    "command": "npx",
    "args": ["-y", "@scope/package"]
  }
}
```

For HTTP servers:

```json
{
  "server-name": {
    "type": "http",
    "url": "https://api.example.com/mcp"
  }
}
```

Note: Plugin install does **not** run `npm install`. Dependencies must be pre-built or use `npx`.

See [MCP](./mcp.md) for complete documentation on server types, authentication, and
advanced configuration.

## LSP servers

Language Server Protocol integrations give Claude code intelligence. Configure them in
`manifest.json`:

```json
{
  "lspServers": {
    "typescript": {
      "command": "typescript-language-server",
      "args": ["--stdio"],
      "filetypes": ["typescript", "typescriptreact", "javascript", "javascriptreact"]
    }
  }
}
```

### Configuration fields

- **command**: String (required). The LSP server executable.
- **args**: Array of strings. Command-line arguments.
- **filetypes**: Array of strings. File extensions that trigger this server.
- **rootPatterns**: Array of strings. Files/directories that identify project root
  (e.g., `["package.json"]`).
- **initializationOptions**: Object. Server-specific initialization options.
- **env**: Object. Environment variables.

### Example: Python LSP

```json
{
  "lspServers": {
    "python": {
      "command": "pylsp",
      "args": [],
      "filetypes": ["python"],
      "rootPatterns": ["pyproject.toml", "setup.py", "requirements.txt"],
      "initializationOptions": {
        "plugins": {
          "pycodestyle": { "enabled": false },
          "pylint": { "enabled": true }
        }
      }
    }
  }
}
```

### Common LSP servers

| Language              | Server                     | Command                              | Installation                                 |
| --------------------- | -------------------------- | ------------------------------------ | -------------------------------------------- |
| TypeScript/JavaScript | typescript-language-server | `typescript-language-server --stdio` | `npm i -g typescript-language-server`        |
| Python                | pylsp                      | `pylsp`                              | `pip install python-lsp-server`              |
| Go                    | gopls                      | `gopls`                              | `go install golang.org/x/tools/gopls@latest` |
| Rust                  | rust-analyzer              | `rust-analyzer`                      | via rustup                                   |
| Java                  | jdtls                      | `jdtls`                              | via Eclipse JDT                              |

## CLI commands

Manage plugins from within Claude Code using the `/plugin` command.

### Install plugins

```bash
# Install from marketplace
/plugin install plugin-name@marketplace-name

# Install with specific scope
/plugin install plugin-name@marketplace-name --scope user
/plugin install plugin-name@marketplace-name --scope project
/plugin install plugin-name@marketplace-name --scope local
```

### Manage plugins

```bash
# List installed plugins
/plugin list

# Disable a plugin
/plugin disable plugin-name

# Enable a disabled plugin
/plugin enable plugin-name

# Uninstall a plugin
/plugin uninstall plugin-name@marketplace-name

# Update a plugin
/plugin update plugin-name@marketplace-name
```

### Marketplace management

```bash
# Add a marketplace
/plugin marketplace add owner/repo
/plugin marketplace add https://github.com/owner/repo
/plugin marketplace add /path/to/local/marketplace
/plugin marketplace add https://example.com/marketplace.json

# List marketplaces
/plugin marketplace list

# Update marketplace catalog
/plugin marketplace update marketplace-name

# Remove a marketplace
/plugin marketplace remove marketplace-name
```

### Shortcuts

- Use `/plugin market` instead of `/plugin marketplace`
- Use `rm` instead of `remove`
- Use `ls` instead of `list`

## Directory structure

A complete plugin with all component types:

```
my-plugin/
├── .claude-plugin/
│   └── plugin.json            # Required: plugin metadata (only this file goes here)
├── commands/                  # Optional: slash commands
│   └── my-command.md
├── skills/                    # Optional: AI skills (one folder per skill)
│   └── my-skill/
│       └── SKILL.md
├── agents/                    # Optional: custom subagents
│   └── my-agent.md
├── hooks/                     # Optional: lifecycle hooks
│   ├── hooks.json             # Hook configuration (JSON record keyed by event)
│   └── (scripts are in scripts/)
├── scripts/                   # Optional: hook scripts and utilities
│   └── my-hook.sh
├── .mcp.json                  # Optional: MCP server config (at plugin root)
├── .lsp.json                  # Optional: LSP server config (at plugin root)
└── README.md                  # Documentation
```

**Important:** Only `plugin.json` goes inside `.claude-plugin/`. All other directories are at plugin root.

## Configuration scopes

Plugins can be installed at different scopes:

- **User scope**: Available across all your projects
  - Location: `~/.claude/plugins/`
- **Project scope**: Shared with all collaborators via git
  - Location: `<project>/.claude/plugins/`
- **Local scope**: Only for you in this project (gitignored)
  - Location: `<project>/.claude-local/plugins/`

## Plugin caching

Plugins installed from remote sources are cached locally:

**Cache location**: `~/.claude/plugins/cache/<marketplace-name>/<plugin-name>/`

When you install a plugin from a marketplace, Claude:

1. Downloads the plugin source
2. Copies it to the cache directory
3. Loads components from the cached copy

This means:

- Offline access after first install
- Faster load times
- Must run `/plugin update` to get new versions

## Debugging plugins

### View plugin errors

Run `/plugin` and go to the Errors tab to see loading issues.

Common errors:

- Invalid JSON in `plugin.json`
- Missing required fields (`name`, `version`, `description`)
- Unknown fields in `plugin.json` (strict mode rejects them)
- Skill frontmatter syntax errors
- `hooks.json` `hooks` field is an array instead of a record

### Check what's loaded

```bash
# List all plugins and their status
/plugin list

# See detailed plugin info
/plugin info plugin-name
```

### Test individual components

- **Skills**: Check `skills/<name>/SKILL.md` files have valid YAML frontmatter
- **Agents**: Try invoking with `/agent-name` command
- **Hooks**: Check hook events are firing (see [Hooks debugging](./hooks.md#debugging))
- **MCP servers**: Test with MCP inspector tools

### Common issues

**Plugin not appearing after install**:

1. Check `/plugin list` to confirm installation
2. Verify scope is correct for your use case
3. Restart Claude Code
4. Check the Errors tab in `/plugin`

**Commands not working**:

1. Verify plugin is enabled (`/plugin list`)
2. Check command syntax: `/plugin-name:command-name`
3. Some plugins require additional setup (check README)

**Skills not being invoked**:

1. Check skill frontmatter is valid YAML
2. Verify `applyTo` patterns match your context
3. Skills are loaded on-demand based on relevance

**MCP server failures**:

1. Check server binary is installed
2. Verify environment variables are set
3. Check server logs (see [MCP debugging](./mcp.md#debugging))

## Plugin development workflow

1. **Create plugin directory**:

   ```bash
   mkdir -p my-plugin/.claude-plugin
   cd my-plugin
   ```

2. **Create manifest**:

   ```bash
   cat > .claude-plugin/plugin.json << 'EOF'
   {
     "name": "my-plugin",
     "version": "0.1.0",
     "description": "My custom plugin"
   }
   EOF
   ```

3. **Add components** (skills, agents, hooks) as needed

4. **Test locally**:

   ```bash
   claude --plugin-dir ./my-plugin
   ```

5. **Iterate**: Make changes and restart Claude Code to reload

6. **Distribute** via marketplace (see [Plugin marketplaces](./plugin-marketplaces.md))

## Best practices

### Naming conventions

- **Plugin names**: lowercase-with-hyphens
- **Skill names**: descriptive-action-names
- **Agent names**: single-word or hyphenated
- **Hook config**: `hooks/hooks.json` — a JSON record keyed by event name

### Version management

Use semantic versioning:

- **Major** (1.0.0): Breaking changes
- **Minor** (0.1.0): New features, backwards compatible
- **Patch** (0.0.1): Bug fixes

### Documentation

Include a README.md with:

- What the plugin does
- Installation instructions
- Configuration requirements
- Usage examples
- Troubleshooting tips

### Security considerations

- Don't commit secrets in manifest files
- Use environment variables for API keys
- Document required permissions
- Test in isolated environments first

## Next steps

- [Create skills](./skills.md) for domain knowledge
- [Build custom agents](./sub-agents.md) for specialized tasks
- [Add hooks](./hooks.md) to customize behavior
- [Bundle MCP servers](./mcp.md) for external integrations
- [Distribute via marketplace](./plugin-marketplaces.md) to share your plugin

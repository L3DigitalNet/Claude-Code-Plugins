---
title: Plugin Discovery and Installation
category: user-guide
target_platform: linux
audience: ai_agent
keywords: [plugins, installation, marketplace, discovery]
---

# Plugin Discovery and Installation

## Quick Reference

**Browse official plugins:**

```bash
claude
/plugin  # Opens plugin manager UI
```

**Install plugin:**

```bash
/plugin install <plugin-name>@<marketplace-id>
# Example:
/plugin install python@claude-plugins-official
```

**Add marketplace:**

```bash
/marketplace add <url>
```

**List installed:**

```bash
/plugin list
```

## Marketplace Workflow

1. Add marketplace → registers catalog (no plugins installed)
2. Browse catalog → view available plugins
3. Install plugins → download and activate individual plugins

**Marketplace storage:** `~/.config/claude/marketplaces.json` **Plugin storage:**
`~/.cache/claude/plugins/`

## Official Marketplace

**ID:** `claude-plugins-official` **Auto-registered:** Yes (available by default)
**Install syntax:** `/plugin install <name>@claude-plugins-official`

### Available Plugin Categories

#### LSP (Language Server Protocol)

**Purpose:** Code intelligence (definitions, references, type checking) **Requires:**
Language server binary installed on system

**Linux installation examples:**

```bash
# Python
sudo apt install python3-pip
pip3 install python-lsp-server
/plugin install python@claude-plugins-official

# TypeScript/JavaScript
sudo npm install -g typescript-language-server typescript
/plugin install typescript@claude-plugins-official

# Rust
rustup component add rust-analyzer
/plugin install rust@claude-plugins-official

# Go
go install golang.org/x/tools/gopls@latest
/plugin install go@claude-plugins-official
```

**Configuration:** See [plugins-reference.md](./plugins-reference.md#lsp-servers)

#### MCP Integrations

**Purpose:** External service connections via Model Context Protocol

| Plugin      | Service         | Install Command                                     |
| ----------- | --------------- | --------------------------------------------------- |
| `github`    | GitHub API      | `/plugin install github@claude-plugins-official`    |
| `gitlab`    | GitLab API      | `/plugin install gitlab@claude-plugins-official`    |
| `atlassian` | Jira/Confluence | `/plugin install atlassian@claude-plugins-official` |
| `linear`    | Linear API      | `/plugin install linear@claude-plugins-official`    |
| `notion`    | Notion API      | `/plugin install notion@claude-plugins-official`    |
| `slack`     | Slack API       | `/plugin install slack@claude-plugins-official`     |
| `figma`     | Figma API       | `/plugin install figma@claude-plugins-official`     |
| `vercel`    | Vercel API      | `/plugin install vercel@claude-plugins-official`    |
| `firebase`  | Firebase        | `/plugin install firebase@claude-plugins-official`  |
| `supabase`  | Supabase        | `/plugin install supabase@claude-plugins-official`  |
| `sentry`    | Sentry          | `/plugin install sentry@claude-plugins-official`    |

**Configuration:** See [mcp.md](./mcp.md)

#### Development Workflows

| Plugin              | Purpose            | Install Command                                             |
| ------------------- | ------------------ | ----------------------------------------------------------- |
| `commit-commands`   | Git workflows      | `/plugin install commit-commands@claude-plugins-official`   |
| `pr-review-toolkit` | PR review agents   | `/plugin install pr-review-toolkit@claude-plugins-official` |
| `agent-sdk-dev`     | Agent SDK tools    | `/plugin install agent-sdk-dev@claude-plugins-official`     |
| `plugin-dev`        | Plugin development | `/plugin install plugin-dev@claude-plugins-official`        |

#### Output Customization

| Plugin                     | Purpose              | Install Command                                                    |
| -------------------------- | -------------------- | ------------------------------------------------------------------ |
| `explanatory-output-style` | Educational insights | `/plugin install explanatory-output-style@claude-plugins-official` |
| `learning-output-style`    | Interactive learning | `/plugin install learning-output-style@claude-plugins-official`    |

## Demo Marketplace

**ID:** `anthropics-claude-code` **Auto-registered:** No (manual add required)
**Repository:** `anthropics/claude-code`

```bash
/plugin marketplace add anthropics/claude-code
```

## Plugin Manager UI

**Command:** `/plugin`

**Tabs:**

- **Discover** - Browse available plugins from all marketplaces
- **Installed** - View/manage installed plugins
- **Marketplaces** - Add/remove/update marketplace sources
- **Errors** - View plugin loading errors

## Marketplace Sources

**Add marketplace command:** `/plugin marketplace add <source>` **Aliases:**
`/plugin market add`, `/plugin marketplace rm`

**Supported source types:**

| Type       | Format                        | Example                                |
| ---------- | ----------------------------- | -------------------------------------- |
| GitHub     | `owner/repo`                  | `anthropics/claude-code`               |
| Git URL    | Full git URL                  | `https://gitlab.com/user/plugins.git`  |
| Local path | Directory or file path        | `/home/user/my-marketplace`            |
| Remote URL | HTTPS URL to marketplace.json | `https://example.com/marketplace.json` |

**Storage:** `~/.config/claude/marketplaces.json`

## Installation Scopes

| Scope   | Affects                        | Storage Location                      |
| ------- | ------------------------------ | ------------------------------------- |
| User    | All projects for current user  | `~/.config/claude/plugins/`           |
| Project | All users in repository        | `.claude-plugins/` (git tracked)      |
| Local   | Current user + current project | `.claude-plugins-local/` (gitignored) |

**Default scope:** User

**Scope selection:**

- Interactive: `/plugin` → Discover tab → select plugin
- CLI: `/plugin install <name>@<marketplace>`

## CLI Commands

```bash
# Marketplace management
/plugin marketplace add <source>
/plugin marketplace remove <marketplace-id>
/plugin marketplace list
/plugin marketplace update <marketplace-id>

# Plugin installation
/plugin install <plugin>@<marketplace>
/plugin uninstall <plugin>@<marketplace>

# Plugin management
/plugin list
/plugin enable <plugin>@<marketplace>
/plugin disable <plugin>@<marketplace>

# Open UI
/plugin
```

## Command Invocation

**Namespaced format:** `/plugin-name:command-name`

Example after installing commit-commands:

```bash
/commit-commands:commit
/commit-commands:push
```

## Security Note

Plugins can include MCP servers, hooks, and arbitrary code. Verify trust before
installation. Anthropic does not audit third-party plugins.

## Troubleshooting

### /plugin command not recognized

If you see "unknown command" or the `/plugin` command doesn't appear:

1. Check your version: Run `claude --version`. Plugins require version 1.0.33 or later.
2. Update Claude Code
3. Restart Claude Code

### Common issues

- **Marketplace not loading**: Verify the URL is accessible and that
  `.claude-plugin/marketplace.json` exists
- **Plugin installation failures**: Check that plugin source URLs are accessible
- **Files not found after installation**: Plugins are copied to a cache, so paths
  referencing files outside the plugin directory won't work

For detailed troubleshooting, see [Troubleshooting](./troubleshooting.md).

## Next steps

- **Build your own plugins**: See [Plugins](./plugins.md) to create skills, agents, and
  hooks
- **Create a marketplace**: See [Create a plugin marketplace](./plugin-marketplaces.md)
  to distribute plugins
- **Technical reference**: See [Plugins reference](./plugins-reference.md) for complete
  specifications

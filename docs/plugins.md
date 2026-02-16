---
title: Plugin Development Guide
category: development
target_platform: linux
audience: ai_agent
keywords: [plugins, skills, agents, hooks, mcp, development]
version: 1.0.33+
---

# Plugin Development

## Overview

**Plugin Types:**

- Skills: Domain knowledge and workflows
- Agents: Specialized subprocesses with tool restrictions
- Hooks: Lifecycle event handlers
- MCP Servers: External tool integrations
- LSP Servers: Language protocol integrations

**Architecture Comparison:**

| Component  | Location          | Namespace         | Scope               |
| ---------- | ----------------- | ----------------- | ------------------- |
| Standalone | `.claude/`        | Global `/command` | Project-only        |
| Plugin     | `.claude-plugin/` | `/plugin:command` | Shareable/versioned |

## Quick Start

### Minimum Viable Plugin

```bash
mkdir -p my-plugin/.claude-plugin
cd my-plugin
```

**manifest.json:**

```json
{
  "name": "my-plugin",
  "version": "1.0.0",
  "description": "Plugin description"
}
```

**Directory structure:**

```
my-plugin/
├── .claude-plugin/
│   └── manifest.json
├── skills/
│   └── example/
│       └── SKILL.md
└── commands/
    └── hello.md
```

### Testing

```bash
claude --plugin-dir ./my-plugin

# In session:
/my-plugin:hello
/help  # List all commands
```

## Prerequisites

```bash
# Verify Claude Code installation
claude --version
# Required: >= 1.0.33

```

## Manifest Schema

**Required fields (.claude-plugin/manifest.json):**

```json
{
  "name": "plugin-identifier", // lowercase-hyphenated
  "version": "1.0.0", // semver
  "description": "Brief description" // one-line summary
}
```

**Optional fields:**

```json
{
  "author": "Name or {name, email, url}",
  "homepage": "https://...",
  "repository": "https://github.com/...",
  "license": "MIT",
  "keywords": ["tag1", "tag2"],
  "mcpServers": {}, // See MCP section
  "lspServers": {} // See LSP section
}
```

## Component Types

### Commands

**Location:** `commands/*.md` **Format:** Markdown files with optional YAML frontmatter
**Invocation:** `/plugin-name:command-name`

```markdown
---
description: Command description
---

Command instructions using $ARGUMENTS placeholder for user input.
```

### Skills

**Location:** `skills/*/SKILL.md` **Format:** Folder per skill with SKILL.md file
**Invocation:** Auto-invoked by AI based on context

```yaml
---
name: skill-name
description: When to use this skill
applyTo:
  - '**/*.py'
---
Skill implementation instructions.
```

See [skills.md](./skills.md) for complete reference.

### Agents

**Location:** `agents/*.md` **Purpose:** Specialized subprocesses with tool restrictions
**Invocation:** `/agent-name`

See [sub-agents.md](./sub-agents.md) for complete reference.

### Hooks

**Location:** `hooks/hooks.json` **Purpose:** Lifecycle event handlers **Events:**
SessionStart, SessionEnd, PreToolUse, PostToolUse, etc.

See [hooks.md](./hooks.md) for complete reference.

### MCP Servers

**Location:** Configured in manifest.json **Purpose:** External tool integrations via
Model Context Protocol

See [mcp.md](./mcp.md) for complete reference.

### LSP Servers

**Location:** Configured in `.lsp.json` or manifest.json **Purpose:** Language Server
Protocol for code intelligence

```json
{
  "python": {
    "command": "pylsp",
    "args": [],
    "extensionToLanguage": {
      ".py": "python"
    }
  }
}
```

## Directory Structure

```
plugin-name/
├── .claude-plugin/
│   └── manifest.json          # Required metadata
├── commands/                  # Optional command skills
│   └── command-name.md
├── skills/                    # Optional AI skills
│   └── skill-folder/
│       └── SKILL.md
├── agents/                    # Optional custom agents
│   └── agent-name.md
├── hooks/                     # Optional hooks
│   └── hooks.json
├── .lsp.json                  # Optional LSP config
└── README.md                  # Documentation
```

**Important:** Only `manifest.json` goes inside `.claude-plugin/`. All other directories
are at plugin root.

## Development Workflow

### 1. Create Plugin

```bash
mkdir -p my-plugin/.claude-plugin
cat > my-plugin/.claude-plugin/manifest.json << 'EOF'
{
  "name": "my-plugin",
  "version": "0.1.0",
  "description": "Description"
}
EOF
```

### 2. Add Components

```bash
# Add a command
mkdir -p my-plugin/commands
cat > my-plugin/commands/hello.md << 'EOF'
---
description: Greet user
---
Greet the user named "$ARGUMENTS" warmly.
EOF

# Add a skill
mkdir -p my-plugin/skills/example
cat > my-plugin/skills/example/SKILL.md << 'EOF'
---
name: example
description: Example skill
---
Skill implementation.
EOF
```

### 3. Test Locally

```bash
claude --plugin-dir ./my-plugin
```

### 4, Update and Reload

```bash
# Make changes
# Restart Claude to reload
claude --plugin-dir ./my-plugin
```

## Testing

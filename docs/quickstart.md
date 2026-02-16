---
title: Claude Code Quickstart
category: getting-started
target_platform: linux
audience: ai_agent
keywords: [installation, setup, authentication, basic-usage]
---

# Quickstart

## Installation (Linux)

### Package Manager Installation

```bash
# Debian/Ubuntu
wget <package-url>.deb
sudo dpkg -i claude-code_*.deb

# Or use npm
npm install -g claude-code
```

### Verification

```bash
claude --version
# Expected output: claude version X.X.X
```

### Environment Setup

```bash
# Ensure binary is in PATH
which claude
# Expected: /usr/local/bin/claude or /usr/bin/claude
```

## Authentication

```bash
# Initial login
claude login

# Verify authentication status
claude status
```

**Authentication Flow:**

1. Command opens browser for OAuth
2. Auth token stored in `~/.config/claude/auth`
3. Token auto-refreshed on subsequent runs

## Basic Usage

```bash
# Start interactive session
claude

# Execute single command
claude "Analyze this codebase structure"

# With specific plugin directory
claude --plugin-dir ./my-plugins
```

## Core Capabilities

**Code Analysis:**

```bash
# Query codebase structure
"Analyze authentication implementation"

# Find patterns
"List all database query locations"
```

**Code Modification:**

```bash
# Direct changes
"Add error handling to src/auth.py"

# Refactoring
"Extract validation logic to separate module"
```

**Command Execution:**

```bash
/test                    # Run test suite
/build                   # Build project
/commit                  # Create commit with AI message
/plugin list             # List installed plugins
```

## Plugin Management

```bash
# List available plugins
/plugin

# Install plugin
/plugin install <name>@<marketplace>

# Load local plugin directory
claude --plugin-dir /path/to/plugin
```

## Configuration\n\n### File Locations (Linux)\n\n`bash\n# User configuration\n~/.config/claude/settings.json\n\n# Authentication tokens\n~/.config/claude/auth\n\n# Plugin cache\n~/.cache/claude/plugins/\n\n# User plugins\n~/.config/claude/plugins/\n`\n\n### Environment Variables\n\n`bash\nexport CLAUDE_API_KEY=\"your-key\"           # Optional API key\nexport CLAUDE_CONFIG_DIR=\"~/.config/claude\" # Override config location\nexport DEBUG=\"claude:*\"                     # Enable debug logging\n`\n\n## Further Reading

- [Create plugins](./plugins.md) - Plugin development guide
- [Plugin discovery](./discover-plugins.md) - Find and install plugins
- [Troubleshooting](./troubleshooting.md) - Common issues and solutions
- [Technical reference](./plugins-reference.md) - Complete API specifications

## Command Reference

```bash
# Session management
claude                           # Start interactive session
claude --version                 # Show version
claude --debug                   # Run with debug output
claude diagnose                  # Generate diagnostic report

# Plugin management
claude --plugin-dir <path>       # Load plugins from directory
/plugin list                     # List installed plugins
/plugin install <name>@<market>  # Install plugin
/plugin disable <name>           # Disable plugin

# Built-in commands
/help                            # Show available commands
/test                            # Run tests
/build                           #Build project
/commit                          # Create commit with AI message
```

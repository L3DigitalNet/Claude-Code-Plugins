---
title: Plugin Marketplace Creation
category: distribution
target_platform: linux
audience: ai_agent
keywords: [marketplace, distribution, publishing, catalog]
---

# Plugin Marketplace Creation

## Quick Reference

**Purpose:** Catalog of plugins and where to install them from
**File:** `.claude-plugin/marketplace.json`
**Format:** JSON — validated with Zod strict mode (unknown fields are rejected)
**Distribution:** Git repository (GitHub/GitLab), HTTP URL, or local path

**Minimum viable marketplace:**

```bash
mkdir -p my-marketplace/.claude-plugin
cat > my-marketplace/.claude-plugin/marketplace.json << 'EOF'
{
  "name": "my-marketplace",
  "description": "My plugin catalog",
  "owner": { "name": "Your Name", "url": "https://github.com/your-org" },
  "plugins": []
}
EOF
```

## marketplace.json Schema

The validator uses **Zod strict mode** — unknown fields cause validation failure. Only the fields listed here are accepted.

### Root Fields

```json
{
  "name": "my-marketplace",
  "description": "My collection of Claude Code plugins",
  "owner": {
    "name": "Your Name or Org",
    "url": "https://github.com/your-org"
  },
  "plugins": []
}
```

**Required:** `name`, `owner`, `plugins`
**Optional:** `description`

`owner` accepts either `{name, url}` or `{name, email}`.

**Invalid at root level** (rejected by validator): `version`, `homepage`, `repository`, `license`, `author`, `keywords`

### Plugin Entry Fields

```json
{
  "name": "plugin-name",
  "description": "One or two sentence description.",
  "version": "1.0.0",
  "author": { "name": "Your Name", "url": "https://github.com/your-org" },
  "category": "development",
  "homepage": "https://github.com/your-org/your-repo/tree/main/plugins/plugin-name",
  "tags": ["tag1", "tag2"],
  "source": "./plugins/plugin-name"
}
```

**Required:** `name`, `description`, `source`
**Optional:** `version`, `author` (object), `category`, `homepage`, `tags`, `strict`

**Invalid in plugin entries** (rejected by validator): `displayName`, `keywords`, `license`

## Plugin Source Field

The `source` field tells Claude Code where to download the plugin.

### Same-repository plugin (recommended for monorepos)

Use a relative path:

```json
"source": "./plugins/plugin-name"
```

### External URL

Use an object with `source` and `url` keys:

```json
"source": { "source": "url", "url": "https://github.com/owner/repo" }
```

## Complete Marketplace Example

This is the canonical format used by L3DigitalNet:

```json
{
  "name": "l3digitalnet-plugins",
  "description": "Claude Code plugins by L3DigitalNet",
  "owner": {
    "name": "L3DigitalNet",
    "url": "https://github.com/L3DigitalNet"
  },
  "plugins": [
    {
      "name": "design-assistant",
      "description": "Principled design document authoring and enforcement.",
      "version": "0.4.0",
      "author": { "name": "L3DigitalNet", "url": "https://github.com/L3DigitalNet" },
      "homepage": "https://github.com/L3DigitalNet/Claude-Code-Plugins/tree/main/plugins/design-assistant",
      "source": "./plugins/design-assistant"
    },
    {
      "name": "external-tool",
      "description": "An external plugin hosted in a separate repository.",
      "version": "1.0.0",
      "author": { "name": "Someone", "url": "https://github.com/someone" },
      "source": { "source": "url", "url": "https://github.com/someone/external-tool" }
    }
  ]
}
```

## Hosting Your Marketplace

### GitHub (Recommended)

1. **Create repository** with `.claude-plugin/marketplace.json`
2. **Users add with**:
   ```bash
   /plugin marketplace add username/my-marketplace
   ```

### GitLab, Bitbucket, self-hosted Git

Same structure, users install with full URL:

```bash
/plugin marketplace add https://gitlab.com/username/my-marketplace.git
```

### Static hosting

Host `marketplace.json` on any web server:

```bash
/plugin marketplace add https://example.com/path/to/marketplace.json
```

### Local testing

Test locally before publishing:

```bash
/plugin marketplace add /path/to/my-marketplace
```

## Validation

Always validate before publishing:

```bash
# If you have the validate script (monorepo pattern):
./scripts/validate-marketplace.sh

# Manual JSON syntax check:
python3 -m json.tool .claude-plugin/marketplace.json
```

The validator uses Zod strict mode — it will reject unknown fields and missing required fields. Run validation after every change to `marketplace.json` or any `plugin.json`.

## Installed Marketplace Cache

When users add a marketplace via `/plugin marketplace add`, Claude Code clones it to:

```
~/.claude/plugins/marketplaces/<name>/
```

This cache does **not** auto-update. Users must run `/plugin marketplace update <name>` to pull changes. As a publisher, bump your plugin `version` field to signal that an update is available.

## Best Practices

### Curate quality plugins

- Test plugins before adding them
- Remove abandoned or broken plugins
- Pin to specific versions or release tags when possible

### Keep metadata minimal and accurate

Only include fields the validator accepts. Don't add decorative metadata — it causes validation failures.

### Provide a README.md

Include a README alongside `marketplace.json` describing:

- Marketplace purpose and theme
- How to add it (`/plugin marketplace add ...`)
- Featured plugins
- Contribution guidelines (if accepting external plugins)

## User Commands

```bash
# Add a marketplace
/plugin marketplace add owner/repo
/plugin marketplace add https://github.com/owner/repo
/plugin marketplace add /path/to/local/marketplace

# List marketplaces
/plugin marketplace list

# Update marketplace catalog
/plugin marketplace update marketplace-name

# Remove a marketplace
/plugin marketplace remove marketplace-name
```

Shortcuts: `/plugin market` instead of `/plugin marketplace`, `rm` instead of `remove`, `ls` instead of `list`.

## Next Steps

- [Create plugins](./plugins.md) to add to your marketplace
- [Plugins reference](./plugins-reference.md) for full plugin.json schema
- [Discover plugins](./discover-plugins.md) to learn about plugin installation

---
title: Plugin Marketplace Creation
category: distribution
target_platform: linux
audience: ai_agent
keywords: [marketplace, distribution, publishing, catalog]
---

# Plugin Marketplace Creation

## Quick Reference

**Purpose:** Catalog of plugin download locations **File:**
`.claude-plugin/marketplace.json` **Format:** JSON schema **Distribution:** Git
repository (GitHub/GitLab), HTTP URL, or local path

**Minimum viable marketplace:**

```bash
mkdir -p my-marketplace/.claude-plugin
cat > my-marketplace/.claude-plugin/marketplace.json << 'EOF'
{
  "name": "my-marketplace",
  "version": "1.0.0",
  "description": "Plugin catalog",
  "plugins": []
}
EOF
```

## marketplace.json Schema

### Required Fields

```json
{
  "name": "my-marketplace",
  "version": "1.0.0",
  "description": "My collection of Claude Code plugins",
  "author": "Your Name",
  "plugins": [
    {
      "name": "my-plugin",
      "displayName": "My Plugin",
      "description": "Does something useful",
      "version": "1.0.0",
      "author": "Your Name",
      "source": {
        "type": "github",
        "owner": "username",
        "repo": "my-plugin"
      }
    }
  ]
}
```

### 3. Add plugins to catalog

Each plugin entry in the `plugins` array describes a plugin and where to get it.

```json
{
  "name": string,          // Unique ID (lowercase-hyphenated)
  "version": string,       // Semver
  "description": string,   // One-line summary
  "plugins": []            // Plugin array
}
```

### Optional Fields

```json
{
  "author": string | {name, email, url},
  "homepage": string,
  "repository": string,
  "license": string
}
```

## Plugin Entry Schema

### Required Fields

```json
{
  "name": string,          // Plugin identifier
  "displayName": string,   // Human-readable name
  "description": string,   // Purpose
  "version": string,       // Semver
  "author": string,        // Author name
  "source": {              // Download location
    "type": string,        // "github" | "git" | "http" | "local"
    "owner": "username",
    "repo": "plugin-repo"
  }
}
```

#### Required plugin fields

- **name**: Plugin identifier (must match plugin's manifest.json name)
- **displayName**: Human-readable name shown in UI
- **description**: Brief description (1-2 sentences)
- **version**: Plugin version (semantic versioning)
- **author**: Plugin creator
- **source**: Where to download the plugin (see [Plugin sources](#plugin-sources))

#### Optional plugin fields

```json
{
  "homepage": "https://example.com/docs",
  "repository": "https://github.com/username/plugin",
  "license": "MIT",
  "keywords": ["git", "automation"],
  "icon": "https://example.com/icon.png",
  "screenshots": ["https://example.com/screenshot1.png"]
}
```

## Plugin sources

The `source` field tells Claude Code where to download the plugin. Multiple source types
are supported:

### GitHub repositories

```json
{
  "source": {
    "type": "github",
    "owner": "username",
    "repo": "my-plugin",
    "ref": "main"
  }
}
```

- **type**: `"github"`
- **owner**: GitHub username or organization
- **repo**: Repository name
- **ref**: Optional branch/tag (default: `"main"`)

The plugin must be in the repository root or have a `.claude-plugin` directory.

### Git repositories

```json
{
  "source": {
    "type": "git",
    "url": "https://gitlab.com/username/my-plugin.git",
    "ref": "v1.0.0"
  }
}
```

- **type**: `"git"`
- **url**: Git repository URL (any git host)
- **ref**: Optional branch/tag/commit

Works with GitLab, Bitbucket, self-hosted Git servers, etc.

### npm packages

```json
{
  "source": {
    "type": "npm",
    "package": "@username/my-plugin",
    "version": "1.0.0"
  }
}
```

- **type**: `"npm"`
- **package**: Package name
- **version**: Optional version specifier (default: `"latest"`)

The package must contain a `.claude-plugin` directory.

### Direct URLs

```json
{
  "source": {
    "type": "url",
    "url": "https://example.com/plugins/my-plugin.tar.gz"
  }
}
```

- **type**: `"url"`
- **url**: Direct URL to plugin archive (`.tar.gz`, `.zip`)

## Complete marketplace example

```json
{
  "name": "awesome-plugins",
  "version": "2.1.0",
  "description": "Curated collection of Claude Code plugins",
  "author": {
    "name": "Your Name",
    "email": "you@example.com",
    "url": "https://example.com"
  },
  "homepage": "https://example.com/marketplace",
  "repository": "https://github.com/username/awesome-plugins",
  "plugins": [
    {
      "name": "commit-commands",
      "displayName": "Git Commit Commands",
      "description": "Streamlined git commit workflow with AI-generated messages",
      "version": "1.2.0",
      "author": "Your Name",
      "license": "MIT",
      "keywords": ["git", "commit", "workflow"],
      "homepage": "https://github.com/username/commit-commands",
      "repository": "https://github.com/username/commit-commands",
      "source": {
        "type": "github",
        "owner": "username",
        "repo": "commit-commands",
        "ref": "v1.2.0"
      }
    },
    {
      "name": "python-lsp",
      "displayName": "Python Language Server",
      "description": "Python code intelligence with pylsp",
      "version": "1.0.0",
      "author": "Your Name",
      "keywords": ["python", "lsp", "code-intelligence"],
      "source": {
        "type": "github",
        "owner": "username",
        "repo": "python-lsp-plugin"
      }
    }
  ]
}
```

## Hosting your marketplace

### GitHub (Recommended)

1. **Create repository**:

   ```bash
   git init
   git add .claude-plugin/marketplace.json README.md
   git commit -m "Initial marketplace"
   git remote add origin https://github.com/username/my-marketplace.git
   git push -u origin main
   ```

2. **Users install with**:
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

Validate your marketplace.json before publishing:

```bash
# Check JSON syntax
jq . .claude-plugin/marketplace.json

# Validate structure (Python)
python -c "
import json
with open('.claude-plugin/marketplace.json') as f:
    data = json.load(f)
    assert 'name' in data
    assert 'version' in data
    assert 'plugins' in data
    for plugin in data['plugins']:
        assert 'name' in plugin
        assert 'source' in plugin
print('✓ Valid marketplace.json')
"
```

## Versioning

Use semantic versioning for your marketplace:

- **Major** (2.0.0): Breaking changes to marketplace structure
- **Minor** (1.1.0): New plugins added
- **Patch** (1.0.1): Plugin updates, metadata fixes

Update version when adding/removing plugins:

```json
{
  "version": "1.2.0"
}
```

Users can update with:

```bash
/plugin marketplace update marketplace-name
```

## Best practices

### Curate quality plugins

- Test plugins before adding to marketplace
- Verify plugins work as documented
- Remove abandoned or broken plugins

### Organize by category

Use keywords for discoverability:

```json
{
  "keywords": ["git", "workflow", "automation"]
}
```

### Provide documentation

Include README.md with:

- Marketplace purpose/theme
- How to add the marketplace
- Featured plugins
- Contribution guidelines

### Use stable versions

Pin plugins to stable versions or tags:

```json
{
  "source": {
    "ref": "v1.2.0"
  }
}
```

Avoid pointing to branches that may have breaking changes.

### Keep metadata updated

Regularly update:

- Plugin versions
- Descriptions
- Links

### Security considerations

- Only include plugins you trust
- Review plugin code before adding
- Warn users about plugins requiring credentials
- Document required environment variables

## Submission to official marketplace

Want your plugin in the official Anthropic marketplace?

1. Ensure plugin meets quality standards:
   - Clear documentation
   - Meaningful tests
   - Follows best practices
   - Active maintenance

2. Submit pull request to official marketplace repository

3. Anthropic team will review and provide feedback

## Example: Language-specific marketplace

Create a themed marketplace for Python developers:

```json
{
  "name": "python-dev-tools",
  "version": "1.0.0",
  "description": "Essential plugins for Python development",
  "keywords": ["python", "development"],
  "plugins": [
    {
      "name": "python-lsp",
      "displayName": "Python LSP",
      "description": "Code intelligence with pylsp",
      "version": "1.0.0",
      "author": "Community",
      "keywords": ["python", "lsp"],
      "source": {
        "type": "github",
        "owner": "python-tools",
        "repo": "python-lsp-plugin"
      }
    },
    {
      "name": "pytest-runner",
      "displayName": "Pytest Runner",
      "description": "Run and debug pytest tests",
      "version": "1.0.0",
      "author": "Community",
      "keywords": ["python", "testing", "pytest"],
      "source": {
        "type": "github",
        "owner": "python-tools",
        "repo": "pytest-plugin"
      }
    }
  ]
}
```

## Updating your marketplace

When you add, remove, or update plugins:

1. Update `marketplace.json`
2. Bump marketplace version
3. Commit and push changes
4. Users run `/plugin marketplace update` to get changes

## Next steps

- [Create plugins](./plugins.md) to add to your marketplace
- [Discover plugins](./discover-plugins.md) to learn about plugin installation
- [Plugins reference](./plugins-reference.md) for technical specifications

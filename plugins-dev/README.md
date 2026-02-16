# Development Plugins Directory

This directory contains plugins that are **under development** and not yet ready for production/marketplace distribution.

## Purpose

- **Isolation**: Develop new plugins without affecting production plugins in `plugins/`
- **Safety**: Pre-commit hooks won't block changes to plugins in this directory
- **Flexibility**: Experiment freely without version constraints

## Workflow

### 1. Create New Plugin

```bash
mkdir -p plugins-dev/my-new-plugin/.claude-plugin
cd plugins-dev/my-new-plugin

# Create manifest
cat > .claude-plugin/manifest.json << 'EOF'
{
  "name": "my-new-plugin",
  "version": "0.1.0",
  "description": "Plugin description"
}
EOF

# Add components
mkdir -p commands skills agents hooks
```

### 2. Test Locally

```bash
claude --plugin-dir ./plugins-dev/my-new-plugin
```

### 3. Promote to Production

When ready for marketplace distribution:

```bash
./scripts/promote-plugin.sh my-new-plugin --version 1.0.0
```

This script will:
- Copy plugin to `plugins/` directory
- Add entry to marketplace catalog
- Set initial version
- Update marketplace version

### 4. Continue Development

After promotion, you can:
- **Remove dev version**: `rm -rf plugins-dev/my-new-plugin`
- **Keep both**: Continue development in `plugins-dev/`, promote updates as needed

## Guidelines

- Use semantic versioning: `0.x.y` for pre-release, `1.0.0` for first stable release
- Document features in plugin's README.md before promoting
- Test thoroughly before promoting to production
- Consider creating a DESIGN.md for complex plugins (see `plugins/agent-orchestrator/DESIGN.md`)

## Directory Structure Example

```
plugins-dev/
├── README.md (this file)
└── my-new-plugin/
    ├── .claude-plugin/
    │   └── manifest.json
    ├── commands/
    │   └── my-command.md
    ├── skills/
    │   └── my-skill/
    │       └── SKILL.md
    ├── README.md
    └── ... other components
```

## Protection Features

Plugins in this directory:
- ✓ Can be modified freely without pre-commit warnings
- ✓ Don't require version bumps for changes
- ✓ Won't trigger marketplace validation errors
- ✓ Can be promoted to production when ready

## See Also

- [../CLAUDE.md](../CLAUDE.md) - Development guidance
- [../docs/plugins.md](../docs/plugins.md) - Plugin creation guide
- [../scripts/promote-plugin.sh](../scripts/promote-plugin.sh) - Promotion script

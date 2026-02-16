# Plugin Protection System

This document describes the multi-layered protection system that prevents accidental modifications to production plugins in the marketplace.

## Overview

**Problem**: Once plugins are published in the marketplace and users have installed them, accidental changes can break user installations or cause version mismatches.

**Solution**: Four-layer protection system combining directory separation, git hooks, validation scripts, and documented workflows.

## Protection Layers

### Layer 1: Directory Separation

```
Claude-Code-Plugins/
├── plugins/              # ⚠️ PROTECTED - Production plugins in marketplace
│   └── agent-orchestrator/
└── plugins-dev/          # ✅ UNRESTRICTED - Development plugins
    └── my-new-plugin/
```

**Protection**: Physical separation prevents accidental edits to production code

**Workflow**: Develop in `plugins-dev/`, promote to `plugins/` when ready

### Layer 2: Git Pre-Commit Hook

**File**: `.githooks/pre-commit`

**Activation**: `./scripts/setup-hooks.sh` (one-time setup)

**Protection Rules**:

1. **Version Enforcement**
   - ❌ Blocks commits to production plugins without version bump
   - Compares plugin version vs marketplace catalog version
   - Requires both to be updated together

2. **Marketplace Validation**
   - ⚠️ Warns when marketplace.json changes without version bump
   - Checks semver format
   - Validates consistency

3. **Development Plugin Detection**
   - 💡 Suggests promotion when dev plugins are ready
   - No restrictions on `plugins-dev/` changes

**Bypass**: `git commit --no-verify` (not recommended)

**Example Output**:

```bash
$ git commit -m "Update orchestrator"
🔒 Checking for changes to production plugins...
✗ ERROR: Modifying production plugin 'agent-orchestrator' without version bump
  Current version: 1.0.0
  You must bump the version before modifying a production plugin
❌ Commit blocked: Fix errors above before committing
```

### Layer 3: Validation Scripts

#### `scripts/validate-marketplace.sh`

**Purpose**: Comprehensive marketplace validation

**Checks**:
- ✓ JSON syntax validity
- ✓ Required fields present
- ✓ Semver format compliance
- ✓ Plugin directory existence
- ✓ Version consistency (plugin ↔ marketplace)
- ✓ No duplicate plugin names
- ✓ Git commit status

**Usage**:
```bash
./scripts/validate-marketplace.sh
# Run before pushing to catch errors early
```

**Exit codes**:
- `0` - All validations passed
- `1` - Errors found (commit will fail in CI)

#### `scripts/promote-plugin.sh`

**Purpose**: Safe promotion from development to production

**Actions**:
1. Validates plugin structure
2. Sets version
3. Copies to production directory
4. Creates marketplace entry
5. Bumps marketplace version (minor)
6. Provides next steps

**Usage**:
```bash
./scripts/promote-plugin.sh my-plugin --version 1.0.0
```

**Benefits**:
- Ensures all required metadata is present
- Automates error-prone manual steps
- Maintains version consistency
- Documents the promotion process

### Layer 4: Documented Workflows

**Protection**: Clear documentation prevents "I didn't know" errors

**Key Documents**:
- [CLAUDE.md](CLAUDE.md) - AI agent guidance with workflow examples
- [plugins-dev/README.md](plugins-dev/README.md) - Development directory guide
- [MARKETPLACE_CHECKLIST.md](MARKETPLACE_CHECKLIST.md) - Validation checklist
- This document - Complete protection overview

## Workflows

### Workflow 1: New Plugin Development

```bash
# 1. Create in development directory
mkdir -p plugins-dev/my-plugin/.claude-plugin
cd plugins-dev/my-plugin

# 2. Create manifest
cat > .claude-plugin/manifest.json << 'EOF'
{
  "name": "my-plugin",
  "version": "0.1.0",
  "description": "My awesome plugin"
}
EOF

# 3. Add components
mkdir -p commands skills

# 4. Test locally (no restrictions)
claude --plugin-dir ./plugins-dev/my-plugin

# 5. Promote when ready
./scripts/promote-plugin.sh my-plugin --version 1.0.0

# 6. Review and commit
git diff
git add plugins/ .claude-plugin/marketplace.json
git commit -m "Add my-plugin v1.0.0"
```

### Workflow 2: Updating Production Plugin

```bash
# ❌ WRONG - Will be blocked
vim plugins/agent-orchestrator/commands/orchestrate.md
git commit -am "Update orchestrator"  # BLOCKED BY HOOK

# ✅ RIGHT - Version bump first
# 1. Bump version in plugin
vim plugins/agent-orchestrator/.claude-plugin/plugin.json
# Change: "version": "1.0.0" → "1.0.1"

# 2. Update marketplace catalog
vim .claude-plugin/marketplace.json
# Find agent-orchestrator entry, update: "version": "1.0.1"

# 3. Make your changes
vim plugins/agent-orchestrator/commands/orchestrate.md

# 4. Stage all together
git add plugins/agent-orchestrator .claude-plugin/marketplace.json

# 5. Commit (hook will validate)
git commit -m "Update agent-orchestrator to v1.0.1

- Fixed typo in orchestrate command
- Updated documentation"

# 6. Validate before push
./scripts/validate-marketplace.sh
```

### Workflow 3: Emergency Fix (Bypass Hook)

**When to use**: Critical production bug, CI/CD failure, hook malfunction

**Risk**: Can break marketplace, use only when necessary

```bash
# Make fix
vim plugins/agent-orchestrator/scripts/bootstrap.sh

# Bypass hook (DANGEROUS)
git commit --no-verify -m "Emergency fix: bootstrap script syntax error"

# IMMEDIATELY after:
# 1. Validate manually
./scripts/validate-marketplace.sh

# 2. Follow up with proper version bump
vim plugins/agent-orchestrator/.claude-plugin/plugin.json
# Bump patch version

vim .claude-plugin/marketplace.json
# Update version

git add .
git commit -m "Bump version for emergency fix"
```

## Protection Features Summary

| Protection | Type | Blocks | Warns | Suggests |
|------------|------|--------|-------|----------|
| Directory separation | Structural | - | - | ✓ |
| Pre-commit hook | Mechanical | ✓ | ✓ | ✓ |
| Validation script | Mechanical | ✓ (exit 1) | ✓ | - |
| Promotion script | Automation | - | - | ✓ |
| Documentation | Educational | - | - | ✓ |

## Enforcement Philosophy

Following the three-layer enforcement pattern from `agent-orchestrator`:

1. **Mechanical** (hooks, scripts) - Deterministic enforcement
2. **Structural** (directory separation) - Architectural constraints
3. **Behavioral** (documentation) - Human understanding

The protection system uses all three layers to maximize reliability while remaining flexible for legitimate use cases.

## Testing the Protection System

### Test 1: Version Enforcement

```bash
# Should BLOCK
vim plugins/agent-orchestrator/README.md
echo "test change" >> plugins/agent-orchestrator/README.md
git add plugins/agent-orchestrator/README.md
git commit -m "Test: modify without version bump"
# Expected: ❌ Commit blocked
```

### Test 2: Proper Version Bump

```bash
# Should ALLOW
vim plugins/agent-orchestrator/.claude-plugin/plugin.json
# Bump version: 1.0.0 → 1.0.1

vim .claude-plugin/marketplace.json
# Update matching entry version

git add plugins/agent-orchestrator .claude-plugin/marketplace.json
git commit -m "Bump agent-orchestrator to v1.0.1"
# Expected: ✅ Commit allowed
```

### Test 3: Development Plugin

```bash
# Should ALLOW (no warnings)
echo "# My Plugin" > plugins-dev/test-plugin/README.md
git add plugins-dev/test-plugin/README.md
git commit -m "Add test plugin docs"
# Expected: ✅ Commit allowed, suggestion to promote
```

### Test 4: Validation Script

```bash
# Should PASS
./scripts/validate-marketplace.sh
# Expected: ✅ All validations passed

# Break something
vim .claude-plugin/marketplace.json
# Remove "version" field

./scripts/validate-marketplace.sh
# Expected: ✗ Validation failed with errors
```

## Maintenance

### Adding New Protection Rules

To add new rules to the pre-commit hook:

1. Edit `.githooks/pre-commit`
2. Add check logic (follow existing pattern)
3. Test with various scenarios
4. Update this document
5. Commit with `--no-verify` (meta!)

### Disabling Protections

**Temporary** (single commit):
```bash
git commit --no-verify
```

**Permanent** (not recommended):
```bash
git config core.hooksPath ""
```

**Per-session**:
```bash
# Work without hooks
git config --local core.hooksPath ""

# Re-enable
./scripts/setup-hooks.sh
```

## Troubleshooting

### Hook Not Running

```bash
# Check configuration
git config core.hooksPath
# Should show: .githooks

# Re-run setup
./scripts/setup-hooks.sh
```

### False Positives

If hook blocks legitimate changes:

1. Check version numbers match
2. Ensure marketplace.json is staged
3. Validate JSON syntax with `jq`
4. Review hook output carefully

### Hook Errors

If hook crashes or shows errors:

```bash
# Test hook manually
bash -x .githooks/pre-commit

# Check dependencies
which jq git

# Bypass and file bug
git commit --no-verify
```

## See Also

- [CLAUDE.md](CLAUDE.md) - Development workflow guidance
- [MARKETPLACE_CHECKLIST.md](MARKETPLACE_CHECKLIST.md) - Pre-push validation checklist
- [plugins-dev/README.md](plugins-dev/README.md) - Development plugin guidelines
- [docs/plugin-marketplaces.md](docs/plugin-marketplaces.md) - Marketplace specification

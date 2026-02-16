# Branch Protection and Development Workflow

This repository uses GitHub branch protection on `main` to prevent accidental modifications to production plugins.

## Branch Strategy

### `main` Branch (Protected)

**Purpose**: Production-ready plugins distributed via the marketplace

**Protection rules**:
- Direct pushes blocked (GitHub enforces this)
- Direct commits blocked (GitHub rejects push)
- Manual merge from `testing` required for updates

**Access**: Read-only for development, manual merge only when deploying

### `testing` Branch (Development)

**Purpose**: Active development and testing of all plugins

**Protection**: None - direct commits and pushes allowed

**Workflow**:
1. All development happens here via direct commits
2. Test changes locally
3. Validate with `./scripts/validate-marketplace.sh`
4. When ready to deploy, manually merge to `main`

## Development Workflows

### Workflow 1: Creating a New Plugin

```bash
# Ensure you're on testing branch
git checkout testing
git pull origin testing

# Create plugin structure
mkdir -p plugins/my-plugin/.claude-plugin
cd plugins/my-plugin

# Create manifest
cat > .claude-plugin/manifest.json << 'EOF'
{
  "name": "my-plugin",
  "version": "1.0.0",
  "description": "My awesome plugin"
}
EOF

# Add components (commands, skills, agents, hooks)
mkdir -p commands skills

# Test locally
claude --plugin-dir ./plugins/my-plugin

# Add to marketplace catalog
vim ../../.claude-plugin/marketplace.json
# Add entry with version 1.0.0

# Validate
cd ../..
./scripts/validate-marketplace.sh

# Commit and push to testing
git add plugins/my-plugin .claude-plugin/marketplace.json
git commit -m "Add my-plugin v1.0.0"
git push origin testing

# When ready to deploy to production
git checkout main
git pull origin main
git merge testing --no-ff -m "Deploy my-plugin v1.0.0"
git push origin main

# Return to testing branch
git checkout testing
```

### Workflow 2: Updating Existing Plugin

```bash
# Work on testing branch
git checkout testing
git pull origin testing

# Make changes
vim plugins/agent-orchestrator/commands/orchestrate.md

# Bump version
vim plugins/agent-orchestrator/.claude-plugin/plugin.json
# Update: "version": "1.0.0" → "1.0.1"

# Update marketplace catalog
vim .claude-plugin/marketplace.json
# Update matching entry version

# Test changes
claude --plugin-dir ./plugins/agent-orchestrator

# Validate marketplace
./scripts/validate-marketplace.sh

# Commit and push
git add plugins/agent-orchestrator .claude-plugin/marketplace.json
git commit -m "Update agent-orchestrator to v1.0.1

- Fixed bug in orchestrate command
- Updated documentation"
git push origin testing

# When ready to deploy
git checkout main
git pull origin main
git merge testing --no-ff -m "Deploy agent-orchestrator v1.0.1"
git push origin main
git checkout testing
```

### Workflow 3: Emergency Hotfix

For critical bugs that need immediate deployment:

```bash
# Work on testing as usual
git checkout testing
git pull origin testing

# Make minimal fix
vim plugins/agent-orchestrator/scripts/bootstrap.sh

# Bump patch version
vim plugins/agent-orchestrator/.claude-plugin/plugin.json
# Update: "version": "1.0.0" → "1.0.1"

vim .claude-plugin/marketplace.json
# Update version

# Commit and push
git add .
git commit -m "Hotfix: Fix critical bootstrap script error"
git push origin testing

# Immediately deploy to main
git checkout main
git pull origin main
git merge testing --no-ff -m "Emergency deploy: Fix critical bootstrap bug"
git push origin main
git checkout testing
```

## Setting Up Branch Protection

### GitHub Branch Protection Rules for `main`

1. Go to repository **Settings** → **Branches**
2. Add rule for branch `main`
3. Enable these protection settings:

**Required settings**:
- ✅ **Lock branch** - Make the branch read-only (users can't push directly)
  - This is the key setting that prevents accidental commits/pushes to main

**Alternative approach** (if "Lock branch" not available):
- ✅ Require a pull request before merging
- ✅ Allow specified actors to bypass (add yourself)
- This allows you to merge manually but blocks accidental direct pushes

**Optional but recommended**:
- ✅ Do not allow bypassing the above settings
- ✅ Require status checks to pass before merging (if CI/CD configured)

### Preventing Accidental Edits on Main

GitHub branch protection prevents **pushing** to main, but won't stop you from accidentally **checking out** main and editing locally. Two approaches:

**Option 1: Visual reminder** (simplest)
Configure your shell prompt to show the current branch prominently:
```bash
# Add to ~/.bashrc or ~/.zshrc
parse_git_branch() {
    git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/(\1)/'
}
PS1='\u@\h \w $(parse_git_branch)\$ '
```

**Option 2: Simple pre-commit hook** (warning only)
```bash
#!/bin/bash
# .githooks/pre-commit-warning
BRANCH=$(git rev-parse --abbrev-ref HEAD)

if [ "$BRANCH" = "main" ]; then
    echo "⚠️  WARNING: You are committing to the 'main' branch!"
    echo "   Development should happen on 'testing' branch."
    echo ""
    read -p "Are you sure you want to commit to main? (yes/no): " response
    if [ "$response" != "yes" ]; then
        echo "❌ Commit cancelled"
        exit 1
    fi
fi
```

Enable with:
```bash
mkdir -p .githooks
# Create the file above
chmod +x .githooks/pre-commit-warning
git config core.hooksPath .githooks
```

This hook **warns** but doesn't block (you can still confirm and commit).

## Deployment Checklist

Before merging `testing` → `main`:

```bash
# 1. Ensure you're on testing with latest changes
git checkout testing
git pull origin testing

# 2. Validate marketplace
./scripts/validate-marketplace.sh

# 3. Check git status (should be clean)
git status

# 4. Verify versions match
jq -r '.plugins[] | "\(.name): \(.version)"' .claude-plugin/marketplace.json
# Compare with actual plugin versions

# 5. Test plugins locally
claude --plugin-dir ./plugins/<plugin-name>

# 6. Deploy to main
git checkout main
git pull origin main
git merge testing --no-ff -m "Deploy: <description>"
git push origin main
git checkout testing
```

## Validation Before Deploy

Always run these checks before merging to main:

```bash
# 1. Validate marketplace structure
./scripts/validate-marketplace.sh

# 2. Check for uncommitted changes
git status

# 3. Verify version consistency
jq -r '.plugins[] | "\(.name): \(.version)"' .claude-plugin/marketplace.json

# 4. Review changes being deployed
git log main..testing --oneline
git diff main..testing
```

## Versioning Guidelines

### Semantic Versioning

Both **marketplace** and **plugins** use semantic versioning:

**Plugin versions**:
- **Major** (1.0.0 → 2.0.0) - Breaking changes to plugin API, user must update usage
- **Minor** (1.0.0 → 1.1.0) - New features, backwards compatible
- **Patch** (1.0.0 → 1.0.1) - Bug fixes, documentation updates

**Marketplace version**:
- **Major** (2.0.0) - Breaking changes to marketplace structure itself
- **Minor** (1.1.0) - New plugins added
- **Patch** (1.0.1) - Plugin updates, metadata fixes

### Version Synchronization

When updating a plugin:
1. Bump version in `plugins/<name>/.claude-plugin/plugin.json`
2. Update matching version in `.claude-plugin/marketplace.json`
3. Both changes must be committed together

## Troubleshooting

### Accidentally Checked Out Main

If you realize you're on main before making changes:

```bash
# Just switch back to testing
git checkout testing
```

### Accidentally Committed to Main Locally

If you committed to main but haven't pushed:

```bash
# Move commits to testing
git checkout main
git log -1  # Note the commit hash

git checkout testing
git cherry-pick <commit-hash>
git push origin testing

# Reset main
git checkout main
git reset --hard origin/main
```

### Accidentally Pushed to Main

If GitHub branch protection is configured correctly, this should be **blocked automatically**. You'll see:

```
! [remote rejected] main -> main (protected branch hook declined)
error: failed to push some refs
```

If push was rejected:
```bash
# Good - protection worked! Just merge properly:
git checkout testing
# Your changes are still on testing, deploy properly:
git checkout main
git merge testing --no-ff -m "Deploy: <description>"
git push origin main
```

### Merge Conflicts

If `testing` and `main` have diverged:

```bash
git checkout main
git merge testing
# If conflicts occur:
git status  # See conflicting files
# Edit files to resolve conflicts
git add .
git commit -m "Merge testing into main, resolve conflicts"
git push origin main
git checkout testing
```

## Benefits of This Approach

### Simple
- Direct commits to testing (no PR overhead)
- Familiar git workflow
- Deploy when ready with manual merge

### Safe
- Production branch (`main`) protected at server level
- Can't accidentally push to main
- GitHub blocks unauthorized changes

### Flexible
- Work at your own pace on testing
- Test locally before deploying
- Deploy multiple changes at once or individually

### Fast
- No waiting for PR approvals
- No PR creation overhead
- Direct push to testing for rapid iteration

## Common Operations

### Check which branch you're on

```bash
git branch --show-current
# or
git status
```

### Quick switch between branches

```bash
# Go to testing for development
git checkout testing

# Go to main for deployment
git checkout main
```

### See what's different between branches

```bash
# See commits on testing not yet on main
git log main..testing --oneline

# See file changes
git diff main..testing
```

### Undo accidental checkout of main

```bash
# If you're on main and haven't made changes
git checkout testing

# If you made changes on main
git stash
git checkout testing
git stash pop
```

## See Also

- [CLAUDE.md](CLAUDE.md) - AI agent development guidance
- [README.md](README.md) - Marketplace installation and usage
- [scripts/validate-marketplace.sh](scripts/validate-marketplace.sh) - Marketplace validation
- [docs/plugins.md](docs/plugins.md) - Plugin development guide

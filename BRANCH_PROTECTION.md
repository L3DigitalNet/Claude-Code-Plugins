# Branch Protection and Development Workflow

This repository uses a **testing branch workflow** with GitHub branch protection rules to prevent accidental modifications to production plugins.

## Branch Strategy

### `main` Branch (Protected)

**Purpose**: Production-ready plugins distributed via the marketplace

**Protection rules**:
- Direct pushes blocked
- Requires pull request for all changes
- Requires review approval before merge
- Status checks must pass (if configured)

**Access**: Read-only for development, write access only via approved PRs

### `testing` Branch (Development)

**Purpose**: Active development and testing of all plugins

**Protection**: None - free to push, commit, and experiment

**Workflow**:
1. All development happens here
2. Test changes locally
3. Validate with `./scripts/validate-marketplace.sh`
4. Create PR to merge into `main`
5. After review approval, merge to deploy

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

# Commit and push to testing
git add plugins/my-plugin .claude-plugin/marketplace.json
git commit -m "Add my-plugin v1.0.0"
git push origin testing

# Create PR to main
gh pr create --base main --title "Add my-plugin v1.0.0" --body "New plugin: [description]"
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

# Create PR to main
gh pr create --base main --title "Update agent-orchestrator to v1.0.1" \
  --body "## Changes
- Fixed bug in orchestrate command
- Updated documentation

## Testing
- [ ] Tested locally
- [ ] Validated marketplace catalog"
```

### Workflow 3: Emergency Hotfix

For critical bugs that need immediate deployment:

```bash
# Option A: Hotfix from main (preferred)
git checkout main
git pull origin main
git checkout -b hotfix/critical-bug

# Make minimal fix
vim plugins/agent-orchestrator/scripts/bootstrap.sh

# Bump patch version
vim plugins/agent-orchestrator/.claude-plugin/plugin.json
# Update: "version": "1.0.0" → "1.0.1"

vim .claude-plugin/marketplace.json
# Update version

# Commit and create PR
git add .
git commit -m "Hotfix: Fix critical bootstrap script error"
git push origin hotfix/critical-bug
gh pr create --base main --title "Hotfix: Fix critical bootstrap script error"

# After merge to main, sync back to testing
git checkout testing
git merge main
git push origin testing

# Option B: Quick fix on testing, fast-track PR
git checkout testing
# Make fix, bump version, commit
# Create PR with [HOTFIX] label for priority review
```

## Setting Up Branch Protection

### GitHub Branch Protection Rules for `main`

1. Go to repository **Settings** → **Branches**
2. Add rule for branch `main`
3. Enable these protection settings:

**Required settings**:
- ✅ Require a pull request before merging
- ✅ Require approvals (at least 1)
- ✅ Dismiss stale pull request approvals when new commits are pushed
- ✅ Require review from Code Owners (optional, if CODEOWNERS file exists)

**Optional settings**:
- ✅ Require status checks to pass before merging
  - Add check: `validate-marketplace` (if CI/CD configured)
- ✅ Require conversation resolution before merging
- ✅ Include administrators (apply rules to admins too)

**Not recommended**:
- ❌ Require linear history (makes rebasing difficult)
- ❌ Require signed commits (unless already enforced organization-wide)

### Local Git Configuration

No special git configuration needed! The protection happens server-side via GitHub.

## Pull Request Guidelines

### PR Title Format

Use conventional commit style:

```
feat(plugin-name): Add new feature
fix(plugin-name): Fix bug description
docs(plugin-name): Update documentation
chore: Update marketplace catalog
```

### PR Description Template

```markdown
## Summary
Brief description of changes

## Changes
- Change 1
- Change 2
- Change 3

## Version Updates
- plugin-name: 1.0.0 → 1.0.1
- marketplace: 1.2.0 → 1.2.1

## Testing
- [ ] Tested locally with `claude --plugin-dir`
- [ ] Validated marketplace with `./scripts/validate-marketplace.sh`
- [ ] Checked for conflicts with other plugins

## Breaking Changes
List any breaking changes or migration notes
```

## Validation Before PR

Always run these checks before creating a PR:

```bash
# 1. Validate marketplace structure
./scripts/validate-marketplace.sh

# 2. Check git status
git status

# 3. Verify versions match
jq -r '.plugins[] | "\(.name): \(.version)"' .claude-plugin/marketplace.json
# Compare with actual plugin versions

# 4. Test plugin locally
claude --plugin-dir ./plugins/<plugin-name>
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

### Accidentally Pushed to Main

If you accidentally push to main (unlikely with protection enabled):

```bash
# If push was rejected by GitHub
# No action needed - protection worked!

# If you have direct write access and bypassed protection
git checkout main
git reset --hard origin/main  # Reset to last known good state
git checkout testing
# Continue work on testing branch
```

### PR Conflicts with Main

```bash
# Update testing branch with latest main
git checkout testing
git pull origin testing
git merge main

# Resolve conflicts
git status
# Edit conflicting files

git add .
git commit -m "Merge main into testing, resolve conflicts"
git push origin testing
```

### Version Mismatch Errors

If marketplace validation fails due to version mismatch:

```bash
# Find the mismatch
./scripts/validate-marketplace.sh

# Fix the version in marketplace.json
vim .claude-plugin/marketplace.json

# Or fix the version in plugin manifest
vim plugins/<name>/.claude-plugin/plugin.json

# Re-validate
./scripts/validate-marketplace.sh
```

## Benefits of This Approach

### Simple
- No git hooks to install or maintain
- No complex scripts to run
- Standard GitHub workflow familiar to all developers

### Safe
- Production branch (`main`) protected at server level
- Can't accidentally push breaking changes
- All changes reviewed before deployment

### Flexible
- Free to experiment on `testing` branch
- Easy to test locally before PR
- Can create feature branches from `testing` for complex work

### Maintainable
- GitHub enforces rules automatically
- No per-machine setup required
- Clear separation between dev and production

## See Also

- [CLAUDE.md](CLAUDE.md) - AI agent development guidance
- [README.md](README.md) - Marketplace installation and usage
- [scripts/validate-marketplace.sh](scripts/validate-marketplace.sh) - Marketplace validation
- [docs/plugins.md](docs/plugins.md) - Plugin development guide

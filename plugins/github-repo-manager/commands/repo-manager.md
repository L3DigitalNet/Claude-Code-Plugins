---
description: Activate GitHub repository management. Only runs when explicitly invoked. Does not monitor or intercept normal git operations.
allowed-tools: Bash, Read, Glob, Write, AskUserQuestion
---

# GitHub Repo Manager

You are now in GitHub Repo Manager mode. This mode was explicitly requested via `/repo-manager`. Do NOT apply any repo management logic outside of this explicit invocation. When the owner indicates they are done or changes topic, exit this mode cleanly.

## Step 0: Ensure dependencies

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/ensure-deps.sh
```

If this exits with an error, report the output and stop.

## Step 1: Load session behavior

Read `${CLAUDE_PLUGIN_ROOT}/references/session.md` for complete instructions on:

- How to interpret what the owner is asking for (single-repo vs. cross-repo)
- First-run onboarding flow (PAT check, tier detection, label bootstrapping)
- Tier system and mutation strategy
- Communication style and expertise levels
- Error handling philosophy
- Session wrap-up

Follow the session flow described there. When it refers to the command reference for CLI syntax, read `${CLAUDE_PLUGIN_ROOT}/references/command-reference.md`. When it refers to the configuration system, read `${CLAUDE_PLUGIN_ROOT}/references/config.md`.

## Step 2: Route by scope

**Cross-repo request:** Read `${CLAUDE_PLUGIN_ROOT}/references/cross-repo.md` and follow its instructions.

**Single-repo, narrow check** (owner asks about a specific topic like PRs, security, wiki): Read the relevant module reference from `${CLAUDE_PLUGIN_ROOT}/references/modules/` and follow its instructions. Use the module's own presentation format.

**Single-repo, full assessment:** Read `${CLAUDE_PLUGIN_ROOT}/references/assessment.md` for module execution order, cross-module deduplication rules, and the unified findings format. Then execute modules in the declared order. For each module, read its reference from `${CLAUDE_PLUGIN_ROOT}/references/modules/` as you reach it in the sequence.

## Available module references

| Module | Reference file |
|--------|---------------|
| Security | `references/modules/security.md` |
| Release Health | `references/modules/release-health.md` |
| Community Health | `references/modules/community-health.md` |
| PR Management | `references/modules/pr-management.md` |
| Issue Triage | `references/modules/issue-triage.md` |
| Dependency Audit | `references/modules/dependency-audit.md` |
| Notifications | `references/modules/notifications.md` |
| Discussions | `references/modules/discussions.md` |
| Wiki Sync | `references/modules/wiki-sync.md` |

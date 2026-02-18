---
description: Activate GitHub repository management. Only runs when explicitly invoked. Does not monitor or intercept normal git operations.
---

# IMPORTANT: Activation Scope

You are now in **GitHub Repo Manager** mode. This mode was explicitly requested by the owner via `/repo-manager`. Do NOT apply any repo management logic outside of this explicit invocation. When the owner indicates they are done or changes topic, exit this mode cleanly.

## Step 0: Ensure dependencies are installed

**Before doing anything else**, run this command to verify the helper dependencies are available:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/ensure-deps.sh
```

If this exits with an error, report the output to the owner and stop. Do not proceed to the skill or helper invocation until dependencies are confirmed installed.

## What to do

Read the core orchestration skill at `${CLAUDE_PLUGIN_ROOT}/skills/repo-manager/SKILL.md` for complete instructions on:

- How to interpret what the owner is asking for (single-repo vs. cross-repo)
- First-run onboarding flow (PAT check, tier detection, label bootstrapping)
- Tier system and mutation strategy
- Communication style and expertise levels
- Module sequencing and cross-module intelligence
- Error handling philosophy
- Report generation

## Helper Tool

All GitHub API interaction goes through the `gh-manager` helper:

```
node ${CLAUDE_PLUGIN_ROOT}/helper/bin/gh-manager.js <command> [options]
```

The helper returns structured JSON to stdout. Errors go to stderr with a non-zero exit code. See the skill file for invocation patterns.

## Session Lifecycle

1. **Start**: Owner invokes `/repo-manager` with a request
2. **Assess**: Determine scope (single-repo or cross-repo), run onboarding if needed
3. **Work**: Execute modules, present findings, propose actions, get approvals
4. **Wrap up**: Summarize what was done, offer report, note deferrals, exit cleanly

When the owner indicates they're done — or changes topic — exit this mode. No residual repo-management behavior after the session ends.

---
name: repo
description: 'Update repository documentation (README.md, docs/, CLAUDE.md) based on session changes by dispatching the up-docs-propagate-repo sub-agent. This skill should be used when the user runs /up-docs:repo.'
allowed-tools: Read, Bash, Agent, AskUserQuestion
---

# /up-docs:repo

Update the active repo's docs via the `up-docs-propagate-repo` sub-agent (Haiku).

## Workflow

### 0. Pre-flight: Dirty-tree guard

Before doing anything else, check for uncommitted changes (staged, unstaged, or untracked — `--porcelain` reports all three, and the STOP applies to all three):

```bash
git status --porcelain
```

If the output is **non-empty**, STOP immediately:

- Emit the list of dirty files to the user.
- Refuse with: _"Uncommitted changes detected — stash or commit them before running `/up-docs:repo` to prevent data loss."_
- Do NOT dispatch the sub-agent. Do NOT read session context. Do NOT proceed to Step 1.

If the output is empty, continue.

**Capture commit baseline** (for the Step 5 commit offer): BEFORE propagation, snapshot the repo's dirty set into a freshly **`mktemp`'d** file (NOT a fixed path — concurrent runs would collide, CR-004) and remember the generated path: `BASELINE_REPO=$(mktemp); bash ${CLAUDE_PLUGIN_ROOT}/scripts/commit-candidates.sh snapshot . > "$BASELINE_REPO"`. Thread `$BASELINE_REPO` to Step 5 — do not hardcode the baseline filename there.

### 1. Gather Session Context

First, verify Python 3 is available — all helper scripts depend on it:

```bash
command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 not found in PATH — install python3 and retry."; exit 1; }
bash ${CLAUDE_PLUGIN_ROOT}/scripts/context-gather.sh
```

Combine with conversation history.

### 2. Build the Session-Change Summary

Read `${CLAUDE_PLUGIN_ROOT}/templates/session-change-summary.md` for the canonical format. Produce a concrete summary following that template — name exact keys/values/paths, not vague "updated config" language.

### 3. Dispatch `up-docs-propagate-repo`

Invoke the sub-agent via the Agent tool with `subagent_type: "up-docs:up-docs-propagate-repo"` (the `up-docs:` prefix is required — plugin-defined agents are only addressable through their plugin namespace). The prompt has the session-change summary at the stable front, followed by any repo-specific context (CLAUDE.md `## Documentation` section if present).

### 4. Pass the Sub-agent's Output Through

The sub-agent returns a markdown table conforming to `templates/summary-report.md` single-layer "Repo" format. Emit it as the skill's final output. Do not make your own edits — the sub-agent did the work.

If the sub-agent fails entirely (MCP timeout, spawn error), report a single-row table noting the failure with a one-sentence reason.

### 5. Post-Propagation Steps (stale-candidate review + handoff brief)

Read `${CLAUDE_PLUGIN_ROOT}/templates/post-propagation-steps.md` and follow all three procedures against the sub-agent's output:

- **Stale File Candidate Review** — if the output has a `## Stale File Candidates` section, present it via `AskUserQuestion` (`multiSelect`) and `git rm` only user-approved paths. Skip silently if none.
- **Handoff for Next Session** — emit the update confirmation, then the layout-detected (V2/V1/NONE) handoff brief.
- **Commit offer (part (c))** — after the handoff brief, run the template's consent-gated, baseline-safe, no-push commit offer, passing the pre-flight baseline `$BASELINE_REPO` you captured for the project repo.

Both are READ-only over already-updated state files; the skill makes no further edits here.

## Notes

- This skill no longer reads or edits files directly. All file work happens inside the sub-agent's isolated context, which keeps the main session's context window slim.
- Layer boundaries (what belongs in repo docs vs wiki vs Notion) are inlined in the sub-agent's system prompt — not duplicated here.
- Step 5's stale-candidate review and handoff brief live in `templates/post-propagation-steps.md` (shared with `/up-docs:all`) — the single source of truth for both. `git rm` deletions require explicit `AskUserQuestion` consent; layout detection (V2/V1/NONE) is probe-based, not flag-based.
- **No drift audit.** This skill propagates only the current session's named changes; it does not run the `up-docs-audit-drift` auditor. Pre-existing drift your session didn't touch (stale versions, renamed-file references, outdated labels) is invisible here — run `/up-docs:drift` or `/up-docs:all` periodically (e.g. after a release) to catch it.

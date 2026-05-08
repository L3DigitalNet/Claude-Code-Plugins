---
name: up-repo
description: "Update repository documentation (README.md, docs/, CLAUDE.md) based on session changes by dispatching the up-docs-propagate-repo sub-agent. This skill should be used when the user runs /up-docs:repo."
argument-hint: ""
allowed-tools: Read, Bash, Agent, AskUserQuestion
---

# /up-docs:repo

Update the active repo's docs via the `up-docs-propagate-repo` sub-agent (Haiku).

## Workflow

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

### 5. Review Stale File Candidates (conditional)

If the sub-agent's output includes a `## Stale File Candidates` section, present the listed paths to the user via `AskUserQuestion` and execute deletions only on explicit approval:

1. Parse the candidate rows from the sub-agent's markdown table. Each row has a path, reason, and confidence.
2. Build an `AskUserQuestion` with `multiSelect: true`, one option per candidate (up to 4 — if more candidates than 4, batch in subsequent questions or use the first 4 with a "Delete 4; rerun to review remaining" label on the 4th option).
3. Each option label is the filename (basename, not full path, for readability); description carries the reason + confidence verbatim from the agent.
4. For every path the user selects, run `git rm <path>` (do NOT use plain `rm` — staying inside git keeps history recoverable). Report what was deleted.
5. For paths the user does NOT select, leave them alone — no follow-up, no retry.
6. If the user cancels the question entirely, skip deletions and continue to Step 6.

If the sub-agent emitted zero stale candidates (or omitted the section entirely), skip Step 5 silently.

### 6. Confirm Updates + Emit Handoff Brief

After the sub-agent's table is displayed (and after any Step 5 deletions), emit both of these in the skill's final output:

**(a) Explicit update confirmation.** One or two lines summarizing the table: files changed vs. files audited-but-unchanged vs. files deleted (if any). Example: `"Updated: docs/state.md, docs/deployed.md, docs/bugs/016-*.md, docs/sessions/2026-04.md. Deleted: 2 stale plans (user-approved). Audited no-change: README.md, CLAUDE.md."`

**(b) Handoff for Next Session brief.** Detect the repo's handoff layout and source from the corresponding files:

- **V2 (handoff-system-v2, post-2026-04-24):** `docs/state.md` exists. Read it + `docs/deployed.md` + `docs/bugs/INDEX.md`.
- **V1 (legacy):** `docs/handoff.md` exists (and no `docs/state.md`). Read it.
- **NONE:** neither file exists. Skip this subsection silently.

Emit the brief using this structure (fields sourced per layout):

```markdown
## 📋 Handoff for Next Session

**Last work:** <V2: top row of docs/sessions/<current-month>.md | V1: top Last Updated line>

**Currently deployed:**
- <V2: docs/deployed.md rows, one per row, name + version + state>
- <V1: docs/handoff.md What Is Deployed bullets>

**Open items — what remains:**
- <V2: docs/deployed.md ## What Remains bullets | V1: docs/handoff.md What Remains bullets>

**Active incidents:** <V2: docs/state.md Session Instructions 🔴/🟡/🟢 block | V1: skip>

**Open bugs:** <V2: docs/bugs/INDEX.md rows with status != fixed | V1: docs/handoff.md Bugs table with unresolved items. "None" if all are fixed.>
```

Keep it scannable — no narrative prose, no full-file dump. If neither layout is present, skip this subsection silently (the repo has not adopted the handoff pattern yet).

## Notes

- This skill no longer reads or edits files directly. All file work happens inside the sub-agent's isolated context, which keeps the main session's context window slim.
- Layer boundaries (what belongs in repo docs vs wiki vs Notion) are inlined in the sub-agent's system prompt — not duplicated here.
- The handoff brief in Step 6 is a READ-only excerpt of the already-updated state files; the skill does not edit them at this stage.
- Step 5 stale-file deletion uses `git rm` (not plain `rm`) so deletions stay in git history and can be reverted. The skill never deletes without explicit `AskUserQuestion` consent, even for candidates the agent marked `high` confidence.
- **Handoff layout detection is probe-based, not flag-based.** The sub-agent detects V1/V2/NONE via file existence (`docs/state.md` present = V2; `docs/handoff.md` present without state.md = V1); this skill's Step 6 uses the same probe. No CLI flag needed.

---
name: wiki
description: 'Update the llm-wiki knowledge base (remote LXC CT 103, /srv/workspaces/llm-wiki, over SSH) with implementation-level details from the current session by dispatching the up-docs-propagate-wiki sub-agent. This skill should be used when the user runs /up-docs:wiki.'
allowed-tools: Read, Bash, Agent, AskUserQuestion
---

# /up-docs:wiki

Update llm-wiki via the `up-docs-propagate-wiki` sub-agent (Sonnet).

## Workflow

### 0. Pre-flight: Capture wiki commit baseline

The wiki repo is REMOTE (CT 103, `/srv/workspaces/llm-wiki`) — propagated pages land in its working tree and stay uncommitted unless this skill offers the commit. BEFORE propagation, snapshot the remote repo's dirty set into a freshly **`mktemp`'d** file (NOT a fixed path — concurrent runs would collide, CR-004): `BASELINE_WIKI=$(mktemp); ssh llm-wiki 'bash -s' snapshot /srv/workspaces/llm-wiki < ${CLAUDE_PLUGIN_ROOT}/scripts/commit-candidates.sh > "$BASELINE_WIKI"`. If the snapshot fails (host unreachable), note it and continue — the Step 5 guard refuses commits without a baseline, and the sub-agent's own pre-flight handles the unreachable host. Thread `$BASELINE_WIKI` to Step 5.

### 1. Gather Session Context

First, verify Python 3 is available — all helper scripts depend on it:

```bash
command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 not found in PATH — install python3 and retry."; exit 1; }
bash ${CLAUDE_PLUGIN_ROOT}/scripts/context-gather.sh
```

Combine with conversation history.

### 2. Build the Session-Change Summary

Read `${CLAUDE_PLUGIN_ROOT}/templates/session-change-summary.md` for the canonical format. Produce a concrete summary following that template. Focus on items that have implementation-reference depth (configs, procedures, integration points) — the sub-agent filters further on its own.

### 3. Dispatch `up-docs-propagate-wiki`

Invoke the sub-agent via the Agent tool with `subagent_type: "up-docs:up-docs-propagate-wiki"` (the `up-docs:` prefix is required — plugin-defined agents are only addressable through their plugin namespace). Put the session-change summary at the stable front of the prompt; add wiki-specific context (CLAUDE.md `## Documentation` llm-wiki `wiki/` path mapping, if present) at the end for cache-friendliness.

### 4. Pass the Sub-agent's Output Through

The sub-agent returns a markdown table conforming to `templates/summary-report.md` single-layer "Wiki (llm-wiki)" format. Emit it as the skill's final output.

If the sub-agent fails entirely, report a single-row table noting the failure with a one-sentence reason.

### 5. Commit offer (part (c), wiki-scoped)

Read `${CLAUDE_PLUGIN_ROOT}/templates/post-propagation-steps.md` and run **only part (c)** — the consent-gated, baseline-safe, no-push **Commit offer (part (c))** — for the remote wiki repo, passing the pre-flight baseline `$BASELINE_WIKI`. All helper and git commands use the remote-runner form documented in the template (`ssh llm-wiki 'bash -s' … < commit-candidates.sh`, `ssh llm-wiki 'git -C /srv/workspaces/llm-wiki …'`). Skip the template's stale-candidate review and handoff brief — those belong to the repo propagator's output, which this skill does not produce. Without this step, draft pages written by the sub-agent would sit uncommitted on CT 103 with nothing surfacing that fact.

## Notes

- This skill no longer searches, reads, or edits llm-wiki pages directly. That work happens inside the sub-agent.
- Layer boundaries and ground-truth rules (live server > wiki) are inlined in the sub-agent's system prompt.
- The wiki commit is **commit-only, never pushed** — it stays on CT 103, which `vzdump`/restic back up; the operator pushes to GitHub separately.

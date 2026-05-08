---
name: up-wiki
description: "Update Outline wiki documentation with implementation-level details from the current session by dispatching the up-docs-propagate-wiki sub-agent. This skill should be used when the user runs /up-docs:wiki."
argument-hint: ""
allowed-tools: Read, Bash, Agent
---

# /up-docs:wiki

Update the Outline wiki via the `up-docs-propagate-wiki` sub-agent (Haiku).

## Workflow

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

Invoke the sub-agent via the Agent tool with `subagent_type: "up-docs:up-docs-propagate-wiki"` (the `up-docs:` prefix is required — plugin-defined agents are only addressable through their plugin namespace). Put the session-change summary at the stable front of the prompt; add wiki-specific context (CLAUDE.md `## Documentation` collection mapping, if present) at the end for cache-friendliness.

### 4. Pass the Sub-agent's Output Through

The sub-agent returns a markdown table conforming to `templates/summary-report.md` single-layer "Wiki (Outline)" format. Emit it as the skill's final output.

If the sub-agent fails entirely, report a single-row table noting the failure with a one-sentence reason.

## Notes

- This skill no longer reads pages, fetches collections, or edits documents directly. That work happens inside the sub-agent.
- Layer boundaries and ground-truth rules (live server > wiki) are inlined in the sub-agent's system prompt.

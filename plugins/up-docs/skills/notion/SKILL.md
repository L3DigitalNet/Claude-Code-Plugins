---
name: notion
description: 'Update Notion pages with strategic and organizational context from the current session by dispatching the up-docs-propagate-notion sub-agent. This skill should be used when the user runs /up-docs:notion.'
allowed-tools: Read, Bash, Agent
---

# /up-docs:notion

Update Notion via the `up-docs-propagate-notion` sub-agent (Haiku).

## Workflow

### 1. Gather Session Context

First, verify Python 3 is available — all helper scripts depend on it:

```bash
command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 not found in PATH — install python3 and retry."; exit 1; }
bash ${CLAUDE_PLUGIN_ROOT}/scripts/context-gather.sh
```

Combine with conversation history.

### 2. Build the Session-Change Summary

Read `${CLAUDE_PLUGIN_ROOT}/templates/session-change-summary.md` for the canonical format. Produce a concrete summary following that template. Focus on strategic/organizational items — what exists, why, who depends on it, status changes. The sub-agent filters further on its own (config values never propagate to Notion).

### 3. Dispatch `up-docs-propagate-notion`

Invoke the sub-agent via the Agent tool with `subagent_type: "up-docs:up-docs-propagate-notion"` (the `up-docs:` prefix is required — plugin-defined agents are only addressable through their plugin namespace). Put the session-change summary at the stable front of the prompt; add Notion-specific context (CLAUDE.md `## Documentation` Notion mapping, if present) at the end.

Notion content guidelines (tone, structure, layer boundaries) live in the sub-agent's system prompt — you do not need to attach anything separately.

### 4. Pass the Sub-agent's Output Through

The sub-agent returns a markdown table conforming to `templates/summary-report.md` single-layer "Notion" format. Emit it as the skill's final output.

If the sub-agent fails entirely, report a single-row table noting the failure with a one-sentence reason.

## Notes

- This skill no longer fetches pages or writes updates directly. That work happens inside the sub-agent.
- Layer boundaries (Notion = strategic/organizational; no configs, no commands, no procedures) are inlined in the sub-agent's system prompt.

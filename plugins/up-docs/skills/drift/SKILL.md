---
name: up-drift
description: "Comprehensive documentation drift analysis across infrastructure and wiki by dispatching the up-docs-audit-drift sub-agent. This skill should be used when the user runs /up-docs:drift."
argument-hint: "[wiki-subtree-or-tag]"
allowed-tools: Read, Bash, Agent, AskUserQuestion
---

# /up-docs:drift [wiki-subtree-or-tag]

Run drift analysis via the `up-docs-audit-drift` sub-agent (Sonnet). Read-only by design: the auditor surfaces findings; the user decides whether to re-invoke propagators to fix them.

If a wiki subtree or tag is provided, scope the analysis to that llm-wiki `wiki/` subtree. Otherwise, analyze the whole `wiki/`.

## Architecture

The auditor sub-agent runs the full four-phase drift flow in its own isolated context:
1. Infrastructure → Wiki sync (SSH/pct/curl against live state)
2. Wiki internal consistency (cross-reference map)
3. Link integrity & enrichment
4. Notion-relevance review

The phase mechanics (`scripts/convergence-tracker.sh`, `scripts/server-inspect.sh`, `scripts/link-audit.sh`) still live in this plugin — the sub-agent invokes them directly from its Bash tool.

## Workflow

### 1. Gather Session Context

First, verify Python 3 is available — all helper scripts depend on it:

```bash
command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 not found in PATH — install python3 and retry."; exit 1; }
bash ${CLAUDE_PLUGIN_ROOT}/scripts/context-gather.sh
bash ${CLAUDE_PLUGIN_ROOT}/scripts/convergence-tracker.sh init
```

Combine with conversation history.

### 2. Build the Session-Change Summary

Read `${CLAUDE_PLUGIN_ROOT}/templates/session-change-summary.md` for the canonical format. This grounds the auditor's scan — it starts from the summary items and expands to adjacent infrastructure that might be transitively affected.

### 3. Dispatch `up-docs-audit-drift`

Invoke via the Agent tool with `subagent_type: "up-docs:up-docs-audit-drift"` (the `up-docs:` prefix is required — plugin-defined agents are only addressable through their plugin namespace). The prompt:
- Session-change summary at the stable front
- Wiki subtree/tag scope argument (if provided) at the end
- The reference docs `skills/drift/references/convergence-tracking.md` and `skills/drift/references/server-inspection.md` are read by the sub-agent itself; do not duplicate their content into the prompt.

### 4. Pass Findings Through

The sub-agent returns both a JSON findings block (canonical artifact) and a markdown findings table (for human reading). Emit both in the skill's final output.

If the sub-agent includes an `⚠ ESCALATION RECOMMENDED` block, include it verbatim.

### 5. Offer Next Step (bounded choice)

After findings land, use AskUserQuestion to offer:
- Re-invoke propagators with findings as a new session-change summary (fixes them at propagator cost (wiki on Sonnet, repo/Notion on Haiku))
- Re-run the audit with Opus (if escalation was recommended)
- Accept findings as advisory and exit

Do not auto-invoke any of the above.

## Notes

- This skill no longer runs SSH/pct/curl directly — the sub-agent does.
- Convergence + oscillation detection live in `scripts/convergence-tracker.sh`. The default state-file path is `${TMPDIR:-/tmp}/up-docs-tracker-${CLAUDE_CODE_SESSION_ID:-default}.json` so that the 6+ separate invocations in one drift session share state. Override with `UP_DOCS_TRACKER_STATE` for tests or for non-session usage.
- Findings are advisory: the auditor has no write tools for llm-wiki or Notion. Fixes go through the propagators on a follow-up pass with the user's explicit consent.

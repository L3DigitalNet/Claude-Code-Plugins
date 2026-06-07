# Session Change Summary Template

Canonical format for the session-change summary produced by the `/up-docs:all` orchestrator and consumed by every up-docs sub-agent (propagators and drift auditor).

This is the **critical artifact** of the orchestrator-dispatch architecture. Garbage in, garbage out — if the orchestrator produces a vague summary, the propagators will miss changes or over-edit. Spend orchestrator tokens to produce this well.

## Format

```markdown
# Session Change Summary

**Session scope:** <1 sentence describing the session's overall goal or theme>

**Source signals:**
- context-gather.sh: <branch, N commits, M files touched>
- Conversation: <brief characterization of the work done in-conversation>

## Changes

### 1. <Short descriptive title>
- **Change:** <the concrete what — config key rebind, file added, service replaced, etc.>
- **Reason:** <the why — incident, compliance, optimization, user ask>
- **Affected area:** <system / stack / host / repo scope>
- **Files touched:** <path/to/file1>, <path/to/file2>
- **Verifiable against:** <how a reader could confirm this — SSH command, file to read, API call>

### 2. <Short descriptive title>
- **Change:** ...
- **Reason:** ...
- **Affected area:** ...
- **Files touched:** ...
- **Verifiable against:** ...

### 3. <continues...>
```

## Field Rules

| Field | Rule |
|-------|------|
| Session scope | One sentence. Helps sub-agents filter what's worth propagating to Notion vs Wiki. |
| Source signals | Always names both `context-gather.sh` and "Conversation". Sub-agents use this to calibrate how much signal to trust. |
| Change title | Imperative or noun phrase. Short enough to fit in a table row. |
| Change | The concrete action. Name exact keys/values/paths. Not "updated config" — instead "`BAO_ADDR=127.0.0.1` → `100.90.121.89` in `/usr/local/bin/backup-dumps.sh`". |
| Reason | The motivating event or decision. Include a date when relevant. |
| Affected area | Describes blast radius. Sub-agents use this to decide which docs are candidates. |
| Files touched | Absolute or repo-relative paths. Empty if the change happened on a live host with no repo artifact. |
| Verifiable against | A command/query a reader could run to confirm the claim. Required — the drift auditor uses this to cross-check evidence. |

## Orchestrator Guidance

When assembling the summary from `context-gather.sh` output and conversation history:

1. **One numbered item per semantically independent change.** A single commit may produce multiple summary items; a single summary item may span multiple commits.
2. **Be specific about values.** Configuration propagation fails silently when summaries say "updated the port" instead of "port 8080 → 8443".
3. **List files touched even when the change is live-only.** If the session ran `systemctl edit foo` and that produced an override file, name that override file.
4. **Preserve chronological order** unless there's a reason to regroup (same subsystem items next to each other, for example).

## Caching Structure

Put this summary at the **stable front** of every sub-agent prompt. Layer-specific detail (which files to search, which collections to browse) goes at the end. This maximizes prompt-cache hits across the three propagator calls in a single `/up-docs:all` run.

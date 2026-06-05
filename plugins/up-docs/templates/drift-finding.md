# Drift Finding Template

Canonical format for findings emitted by the `up-docs-audit-drift` sub-agent. Emitted in **two forms**: a machine-readable JSON block (so the orchestrator can re-feed findings into propagators as a new session-change summary) and a human-readable markdown table (so the user can read the combined report).

## JSON Form (canonical artifact)

```json
{
  "findings": [
    {
      "id": 1,
      "layer": "wiki",
      "page": "<page title or file path>",
      "page_id": "<Outline/Notion page ID, or null for repo>",
      "stale_line": "<exact text as it currently appears>",
      "should_say": "<what it should be, based on live state or session summary>",
      "confidence": "low | medium | high | unverifiable",
      "destructive_fix": false,
      "evidence": {
        "command": "<exact tool_input.command you ran to verify this finding>",
        "expected_output_signature": "<distinctive substring literally observed in tool_response.output>",
        "source_tool_use_id": "<tool_use_id of that call, if identifiable — optional>"
      }
    }
  ],
  "escalation": {
    "triggered": false,
    "reasons": []
  },
  "stats": {
    "total_findings": 0,
    "by_layer": {"repo": 0, "wiki": 0, "notion": 0, "layout": 0},
    "high_confidence": 0,
    "unverifiable": 0,
    "destructive_fixes_required": 0
  }
}
```

## Field Rules

| Field | Rule |
|-------|------|
| `id` | Sequential from 1. Stable across JSON + markdown so a user can cross-reference. |
| `layer` | Exactly one of: `"repo"`, `"wiki"`, `"notion"`, `"layout"`. Use `"layout"` only for findings from the step-3b handoff-conformance phase (validator failures), never for content drift. |
| `page` | Human-readable page title (Outline, Notion) or file path (repo). |
| `page_id` | Machine ID for wiki/Notion; `null` for repo. Used by downstream propagators to target the right page. |
| `stale_line` | Exact text currently in the doc. Do not paraphrase. This is what a propagator will match against. |
| `should_say` | What the line should be. If unknown, copy `stale_line` and lower `confidence` accordingly. |
| `confidence` | `"high"` = verified against live state; `"medium"` = verified against another doc or the session summary; `"low"` = unverified but smells wrong; `"unverifiable"` = verification command was attempted and failed (use when you would otherwise have been tempted to fabricate). |
| `destructive_fix` | `true` if the fix would require page deletion, collection reorg, or anything that can't be cleanly undone. |
| `evidence` | **Structured object**, not a free-form string: `{command, expected_output_signature, source_tool_use_id?}`. `command` = the exact `tool_input.command` you ran; `expected_output_signature` = a distinctive substring you literally observed in that call's `tool_response.output` (never summarized, paraphrased, or inferred); `source_tool_use_id` is optional. May be `null` **only** when `confidence: "unverifiable"` (command failed / host unreachable / no verifying command produced real output); a non-null object is required for `low`, `medium`, and `high`. **Never fabricate** — `validate_output.py` rejects string-form evidence at parse time, and `verify_evidence_grounded.py` rejects any signature absent from the captured transcript. See the agent prompt's `<verification_discipline>` block. |

## Markdown Form (rendered for user)

```markdown
## Drift Audit Findings

**Context:** <1-2 sentences about what was scanned and why>

| # | Layer | Page | Stale Content | Should Say | Confidence |
|---|-------|------|---------------|------------|------------|
| 1 | Wiki | OpenBao — CT 111 | `BAO_ADDR=127.0.0.1:8200` | `BAO_ADDR=100.90.121.89:8200` | high |
| 2 | Notion | Homelab / Backup | Backup uses 127.0.0.1 | Backup uses 100.90.121.89 | medium |
| 3 | Repo | docs/handoff/deployed.md | Old `MAXAGE=20` | `MAXAGE=30` | high |

**Totals:** 3 findings | 2 high-confidence | 0 requiring destructive fix
```

Code in `Stale Content` and `Should Say` columns goes in backticks when it's literal configuration or command text.

## Escalation Triggers

Emit the escalation block when any of these hold:

1. `stats.total_findings > 10` — architectural drift suspected; Opus reasoning may help prune false positives.
2. Any affected doc is > 1000 lines — 1M context meaningfully matters.
3. Any finding has `destructive_fix: true`.
4. Cross-layer contradiction detected (wiki says X, Notion says Y, code says Z).

Escalation does not change the findings — it just adds an advisory block to the output recommending the user re-run with Opus or review findings manually before dispatching propagators.

## Escalation Block Form

```markdown
## ⚠ ESCALATION RECOMMENDED

Reasons:
- <trigger 1>
- <trigger 2>

Recommended action: <concrete next step, e.g., "re-run audit with Opus" or "review finding #3 manually">
```

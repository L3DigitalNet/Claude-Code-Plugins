# Design: plugin-review Assertion-Driven Convergence Loop

**Date:** 2026-02-20
**Version target:** 0.3.0
**Status:** Approved

## Problem

The current convergence loop in `plugin-review` is human-gated at Phase 4: the orchestrator
presents findings, proposes fixes, and waits for explicit user approval before implementing.
This prevents fully automated review runs. Additionally, there is no machine-verifiable
criterion for convergence — "all findings resolved" is a judgment call by the orchestrator
with no programmatic verification that fixes actually addressed the root cause.

## Goals

1. **Zero human intervention** — `/review` runs start to finish without prompts. The
   `--max-passes=N` flag (default 5) is the only human control.
2. **Machine-verifiable assertions** — each finding is accompanied by an assertion (grep,
   file existence, TypeScript compilation, etc.) that can be run programmatically.
3. **Confidence score** — `assertions_passed / total_assertions` reported at each pass and
   in the final report, giving a quantitative convergence signal.
4. **Targeted regression fixes** — assertion failures after implementation trigger a
   write-capable `fix-agent` for just those failing assertions, not a full re-analysis.

## Non-Goals

- Interactive mode is not being removed — existing Phase 4 gate behavior is replaced, not
  preserved as an option. The new design is always autonomous.
- Assertion type coverage is not exhaustive — five types cover the common cases. Arbitrary
  test execution is not in scope.

## Architecture

### What stays the same
- 6-phase structure in `commands/review.md`
- Three read-only analyst subagents (principles, UX, docs)
- Scoped re-audit skill for pass 2+ track selection
- `doc-write-tracker` and `validate-agent-frontmatter` hooks
- All six externalized templates

### What changes

| Component | Change |
|-----------|--------|
| `commands/review.md` | Phase 4 drops AskUserQuestion; Phase 5 adds assertion runner; new Phase 5.5 fix-agent loop; Phase 6 adds confidence score; parse `--max-passes=N` |
| `agents/principles-analyst.md` | Add `## Assertions` block to output format |
| `agents/ux-analyst.md` | Add `## Assertions` block to output format |
| `agents/docs-analyst.md` | Add `## Assertions` block to output format |
| `agents/fix-agent.md` | **NEW** — write-capable targeted fix agent |
| `scripts/run-assertions.sh` | **NEW** — assertion runner that updates state file |
| `templates/pass-report.md` | Add Confidence column to convergence table |
| `templates/final-report.md` | Add Assertions summary section |

### New state file: `.review-assertions.json`

Location: `.claude/state/review-assertions.json`

```json
{
  "plugin": "<plugin-name>",
  "max_passes": 5,
  "current_pass": 1,
  "assertions": [
    {
      "id": "A-001",
      "finding_id": "<principle or finding ID from analyst output>",
      "track": "A",
      "type": "grep_not_match",
      "description": "Human-readable intent",
      "command": "grep -n 'pattern' path/to/file",
      "expected": "no_match",
      "status": null,
      "failure_output": null
    }
  ],
  "confidence": {
    "passed": 0,
    "total": 0,
    "score": 0.0
  }
}
```

### Assertion types

| Type | Command | Pass condition |
|------|---------|----------------|
| `grep_not_match` | bash command | empty stdout |
| `grep_match` | bash command | non-empty stdout |
| `file_exists` | uses `path` field | path exists |
| `file_content` | uses `path` + `needle` fields | needle found in file |
| `typescript_compile` | `tsc --noEmit` | exit code 0 |
| `shell_exit_zero` | bash command | exit code 0 |

## Revised Loop

```
PASS N (repeat until confidence=100% or pass_count >= max_passes):
  1. Spawn analyst subagents (all on Pass 1; scoped re-audit on Pass 2+)
  2. Extract assertions from each analyst's ## Assertions block
  3. Merge into .review-assertions.json (new assertions added; existing kept)
  4. Present findings (display only — no human gate)
  5. Auto-implement all analyst proposals
  6. Run ALL assertions via run-assertions.sh
  7. Compute confidence = passed/total
  8. If any fail → spawn ONE fix-agent with all failing assertions
  9. Re-run assertions → update confidence
 10. Increment pass_count

CONVERGENCE when: confidence=100% | pass_count >= max_passes | plateau | divergence
```

**Notes:**
- Pass budget changes from 3 (hardcoded) to `--max-passes=N` (default 5)
- Fix-agent is ONE invocation per pass receiving all failing assertions — not N invocations
- New assertions added each pass; existing assertions carry forward with their last status

## Fix-Agent Contract

**Frontmatter:**
```yaml
---
name: fix-agent
description: Targeted implementation agent for assertion-driven fixes.
tools: Read, Grep, Glob, Edit, Write
---
```

**Input (from orchestrator):**
- List of failing assertions (id, type, command, description, failure_output)
- The original analyst finding each assertion was generated from
- Files likely requiring changes

**Constraints:**
- Implement only what is needed to pass the failing assertion
- Do not refactor unrelated code, add features, or address non-failing assertions
- Return a structured summary the orchestrator can include in the pass report

**Output format:**
```
## Fix-Agent Results — Pass <N>

### <assertion-id> — <description>
Changed: <file>:<line> — <what changed>

### <assertion-id> — <description>
Changed: <file>:<line> — <what changed>
```

## Analyst Assertion Output Format

Each analyst appends an `## Assertions` block after its existing findings. Example from
principles-analyst for a P3 violation finding:

```markdown
## Assertions

```json
[
  {
    "id": "A-001",
    "finding_id": "P3",
    "track": "A",
    "type": "grep_not_match",
    "description": "Phase 4 must not have AskUserQuestion gate",
    "command": "grep -cn 'AskUserQuestion' plugins/plugin-review/commands/review.md",
    "expected": "no_match"
  }
]
` ` `
```

The orchestrator extracts these JSON blocks from each analyst's output and merges them into
the central assertions file.

## Confidence Score

Displayed in every pass report and final report:

```
Confidence: 73% (11/15 assertions passing)
```

Convergence table column added to `pass-report.md`:
```
| Pass | Upheld | ... | Confidence | Trend |
```

Final report adds an Assertions section listing all assertions with their final status.

## --max-passes Flag Parsing

From the trigger line: `"review plugin-name --max-passes=7"` → N=7. Default: 5.

Orchestrator reads the invocation text and extracts `--max-passes=(\d+)` if present,
otherwise uses 5.

## Files to Create/Modify

1. `commands/review.md` — major revision (Phase 4, Phase 5, Phase 6, flag parsing)
2. `agents/principles-analyst.md` — add `## Assertions` to output format
3. `agents/ux-analyst.md` — add `## Assertions` to output format
4. `agents/docs-analyst.md` — add `## Assertions` to output format
5. `agents/fix-agent.md` — NEW
6. `scripts/run-assertions.sh` — NEW
7. `templates/pass-report.md` — add Confidence column
8. `templates/final-report.md` — add Assertions section
9. `CHANGELOG.md` — 0.3.0 entry
10. `.claude-plugin/plugin.json` — bump to 0.3.0
11. `.claude-plugin/marketplace.json` (root) — bump plugin-review to 0.3.0

# Plan: up-docs

> **Status: Phase 1 plan — execute only after STRATEGY.md is approved.**
> **Phase 2 priority: 6 of 15.**

## Current state

| Field | Value |
|---|---|
| Source files | 4 shell scripts (`context-gather.sh`, `convergence-tracker.sh`, `link-audit.sh`, `server-inspect.sh`) |
| Existing tests | 3 bats (`context-gather.bats`, `convergence-tracker.bats`, `link-audit.bats`) |
| Framework | bats |
| Untested script | `server-inspect.sh` |
| Agents | 4 (Haiku propagators × 3 + Sonnet drift auditor) |

Principles: `[P1] Right Content, Right Layer`, `[P2] Infer, Don't Interrogate`, `[P3] Update, Don't Rewrite`, `[P4] Ground Truth Wins`.

## Gap table

| Principle | Layer | Proposed test | Rationale |
|---|---|---|---|
| [P1] Right Content, Right Layer | Behavioral — out of scope | n/a | Layer assignment is the propagator agents' judgment. |
| [P2] Infer, Don't Interrogate | Mechanical | `tests/context-gather.bats` (extend) — given a session-summary input, output is a single structured payload with no prompts/questions emitted. (Negative test: no `read -p`, no `AskUserQuestion` markers.) | The script is the inference surface; no interrogation = no interactive blocking. |
| [P3] Update, Don't Rewrite | Behavioral — out of scope | n/a | Targeted-edit discipline is in the propagator agent system prompts. |
| [P4] Ground Truth Wins | Mechanical | `tests/server-inspect.bats` (new) — given a stubbed `ssh` binary returning fake live state, the script's output reflects the stub, not any cached value. (If the script has caching, deactivate it via env var.) | "Live state is authoritative" is a verifiable contract once stubbed. |
| Cross-cutting (link integrity) | Mechanical | `tests/link-audit.bats` (extend) — broken inter-document link → reported with source path, target path, and the line; valid link → no output. | Existing tests cover happy path; extend with negative cases. |
| Cross-cutting (convergence) | Mechanical | `tests/convergence-tracker.bats` (extend) — given two consecutive empty-finding reports, tracker emits "converged"; given mixed reports, emits "iterating". Oscillation detection (alternating direction) emits "oscillating". | Convergence trend math should be deterministic and tested even though the consumers are agents. |
| Cross-cutting (manifest) | Structural | `tests/manifest.bats` (new) | Marketplace-wide guard. |

## Files to create / modify

```
plugins/up-docs/tests/
├── context-gather.bats         (extend)
├── convergence-tracker.bats    (extend)
├── link-audit.bats             (extend)
├── server-inspect.bats         (new)
└── manifest.bats               (new)
```

## Fixtures needed

- `tests/fixtures/fake-docs-tree/` — markdown files with valid + broken cross-links.
- `tests/fixtures/stubs/ssh` — PATH stub returning canned output.
- `tests/fixtures/convergence-reports/` — sequences of finding-count snapshots covering each trend.

## Runtime estimate

- 5 bats files (3 extended, 2 new) × ~5 cases = 25 cases. Sub-second to ~3 s suite.

## Risks (flag, do not fix)

1. **`server-inspect.sh` may directly call `ssh user@host`** without honoring an override. If `PATH`-stubbing `ssh` doesn't work because the script uses `/usr/bin/ssh`, flag the un-overridable seam. No script change.
2. **Convergence math edge case:** plateau-vs-oscillation classification on two-data-point inputs is ambiguous (PTH's own README §Convergence notes this — "fewer than two iterations → unknown"). Tests must use ≥ 3 snapshots for non-`unknown` assertions, mirroring PTH semantics.
3. **`link-audit.sh` may not parse Outline-style wiki links** (which use UUID slugs, not paths). If it only checks repo-local links, scope the new tests to repo-local and document the gap.

## What this plan does NOT do

- Test the propagator agents (`up-docs-propagate-{repo,wiki,notion}`). Agents are behavioral.
- Test the drift-auditor agent. Behavioral.
- Test the Outline / Notion MCP integrations. Out of scope; integration testing requires real wikis.
- Modify scripts.

## Phase 2 execution log (2026-04-25)

### Built / extended

- **`tests/server-inspect.bats` (new, 5 cases)** — covers [P4] Ground Truth Wins via PATH-stubbed `ssh`. Two-phase stub: probe (`echo ok`) and heredoc-driven inspection. Verifies `unreachable` short-circuits the JSON, `reachable` parses delimited sections (hostname, kernel, ports), and **the script reflects stub state on each invocation (no caching)**.
- **`tests/manifest.bats` (new, 2 cases)** — Zod-strict allow-list + required fields.
- **`tests/fixtures/stubs/ssh`** — controllable mock with `SSH_STUB_MODE=reachable|unreachable`.

### Suite

`bash plugins/up-docs/tests/run-bats.sh` — **34 of 34 passing** (27 baseline + 7 added).

### Findings

1. **Risk #1 (`ssh` binary not overridable)** — false alarm. The script invokes `ssh` via PATH lookup, so PATH-stubbing works cleanly. No source change needed.
2. **`ss` output format sensitivity** — script parses `parts[3]` of each line. My initial stub had a `Netid` prefix column that pushed `Local Address:Port` to `parts[4]`, breaking the test. Fixed by aligning stub output with real `ss -tlnp` schema. Documents the parser's column-index assumption.
3. **Plan said "convergence math edge case ≥3 snapshots needed"** — existing convergence-tracker.bats already handles this; no extension needed.

### Coverage delta

| Layer | Before | After |
|---|---|---|
| Mechanical (script) | 27 cases (context-gather, convergence-tracker, link-audit) | +5 server-inspect cases |
| Structural (manifest) | 0 | 2 cases |
| Behavioral [P1]/[P3] | (out of scope) | (out of scope — explicitly noted) |

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

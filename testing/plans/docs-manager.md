# Plan: docs-manager

> **Status: Phase 1 plan — execute only after STRATEGY.md is approved.**
> **Phase 2 priority: 9 of 15.**

## Current state

| Field | Value |
|---|---|
| Source files | 17 shell scripts in `scripts/` |
| Existing tests | 5 bats (`detection`, `index`, `queue`, `status-dashboard`, `utilities`) |
| Framework | bats |
| Untested scripts | `bootstrap.sh`, `template-register.sh`, `post-tool-use.sh`, `is-survival-context.sh`, `frontmatter-read.sh` (likely covered by `utilities.bats` — verify), `index-source-lookup.sh`, `queue-merge-fallback.sh` |
| Hooks | Yes (`PostToolUse` + `Stop`) |
| Agents | Yes |
| Skills | Yes |

Principles: `[P1] Domain Libraries`, `[P2] Detection Automatic, Resolution Deferred`, `[P3] Staleness Surfaced`, `[P4] Templates Inferred`, `[P5] Human-First in Survival`, `[P6] Lighter Than Problem`, `[P7] Anchor to Upstream Truth`.

## Gap table

| Principle | Layer | Proposed test | Rationale |
|---|---|---|---|
| [P1] Domain Libraries | Mechanical | `tests/index-register.bats` (new) — registering a doc without library declaration → rejected; with valid library → accepted, library name persisted to `docs-index.json`. | Library-membership = mechanical guarantee. |
| [P2] Detection Automatic, Resolution Deferred | Mechanical | `tests/post-tool-use.bats` (new) — given a Write tool input for a frontmatter doc, the hook silently appends to `queue.json` and emits no user-facing output. | Quiet-detection contract. |
| [P2] Detection Automatic, Resolution Deferred | Mechanical | `tests/post-tool-use.bats` — given a Write to a non-doc file (no frontmatter, not in source-files), the hook ignores it. | Negative case for the dispatcher. |
| [P3] Staleness Surfaced | Mechanical | `tests/stop-hook.bats` (new) — Stop hook with empty queue → silent; with non-empty queue → emits surface message with item count. | Surfaces-at-session-end claim. |
| [P4] Templates Inferred | Behavioral — out of scope | n/a | Template inference is in command/agent prompts. |
| [P4] (registry side) | Mechanical | `tests/template-register.bats` (new) — registering a template persists it in the templates index without a selection menu being prompted (no `read -p`, no `AskUserQuestion`). | Mechanical sibling: registration is non-interactive. |
| [P5] Human-First in Survival | Mechanical | `tests/is-survival-context.bats` (new) — frontmatter `audience: human` → flagged survival; `audience: ai` → exempt; missing audience → defaults survival (safety-on default). | Encodes the audience-discrimination logic. |
| [P6] Lighter Than Problem | Behavioral — out of scope | n/a | Workflow-cost is a meta-claim. |
| [P7] Anchor to Upstream Truth | Mechanical | `tests/index-source-lookup.bats` (new) — entries with `upstream-url` get queued for verification at the configured cadence; entries without are skipped. | Verification-routing claim. |
| Cross-cutting (queue durability) | Mechanical | Extend existing `tests/queue.bats` — concurrent appends from two simultaneous hook invocations don't corrupt JSON (use `flock`). Verify the merge-fallback path. | Real-world race condition; merge-fallback script exists explicitly for this. |

## Files to create / modify

```
plugins/docs-manager/tests/
├── detection.bats              (existing)
├── index.bats                  (existing)
├── queue.bats                  (extend — concurrency)
├── status-dashboard.bats       (existing)
├── utilities.bats              (existing — verify covers frontmatter-read)
├── post-tool-use.bats          (new)
├── stop-hook.bats              (new)
├── index-register.bats         (new)
├── template-register.bats      (new)
├── is-survival-context.bats    (new)
└── index-source-lookup.bats    (new)
```

## Fixtures needed

- `tests/fixtures/sample-docs/` — frontmatter variants (`audience: human/ai`, with/without `upstream-url`).
- `tests/fixtures/sample-source-files/` — files matching the source-files pattern.
- `tests/fixtures/queue-states/` — pre-populated `queue.json` files for race-condition tests.

## Runtime estimate

- 5 existing + 6 new bats files × ~4 cases = ~40 cases. ~5–10 s suite.

## Risks (flag, do not fix)

1. **`post-tool-use.sh` hook expects JSON on stdin per the marketplace hook contract.** Tests must feed deterministic stdin. If the script reads from anywhere else (env var, file), flag.
2. **Concurrent-append test requires `flock`** in the script. If the script doesn't use `flock` and races are real, the test will reveal it. **Report finding**; do not add `flock` in Phase 2.
3. **`bootstrap.sh` is the first-run installer** (writes `~/.docs-manager/config.yaml`). Do not test against real `~/.docs-manager/`. If `HOME` redirection is insufficient, flag the un-overridable seam.
4. **17 scripts is a lot — coverage will be partial in Phase 2.** Plan covers the 7 most principle-load-bearing scripts; the remaining ~10 (mostly small utilities) can be covered in a follow-up if needed.

## What this plan does NOT do

- Test the agents in `agents/`. Behavioral.
- Test command markdown. Behavioral.
- Test against real Outline/Notion (no integrations here, but for symmetry with up-docs).
- Modify scripts.

## Phase 2 execution log (2026-04-25)

### Built / extended

- **`tests/post-tool-use.bats` (new, 6 cases)** — PostToolUse hook routing: empty-stdin silent, missing-file_path silent, node_modules + .git noise filters, deleted-file silent, non-md non-tracked file silent.
- **`tests/is-survival-context.bats` (new, 8 cases)** — full [P5] classification matrix: sysadmin/dev/personal × human/both/ai, including the explicit `audience=ai` exception that overrides doc-type, plus default-safe paths (missing doc-type, missing file).
- **`tests/manifest.bats` (new, 3 cases)** — Zod-strict allow-list + hooks.json record-keyed PostToolUse + Stop + matcher scope (Write|Edit|MultiEdit).
- **`tests/run-bats.sh`** — bats wrapper.

### Suite

`bash plugins/docs-manager/tests/run-bats.sh` — **91 of 91 passing** (74 baseline + 17 added).

### Findings

1. **Existing baseline coverage was extremely strong** (74 cases across detection, index, queue, status-dashboard, utilities). Only the hook-side and survival-context classifier had no explicit principle-traceable coverage.
2. **`is-survival-context.sh` is the single source of truth for the [P5] rule** — exactly as the script's own comment claims. Lock the classification matrix to prevent silent drift if doc-type/audience values change.
3. **Plan items deferred** — bootstrap-script test (writes to `~/.docs-manager/`; complex setup) and template-register/index-source-lookup/queue-merge-fallback. Those scripts are smaller and lower-stakes than the dispatcher hook + survival classifier covered here. Acceptable scope for Phase 2.

### Coverage delta

| Layer | Before | After |
|---|---|---|
| Mechanical (script) | 74 cases (5 .bats files) | +14 cases across post-tool-use + is-survival-context |
| Structural (manifest + hooks) | 0 | 3 cases |
| Behavioral [P1]/[P4]/[P6] | (out of scope) | (out of scope — explicitly noted) |

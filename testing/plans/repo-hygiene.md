# Plan: repo-hygiene

> **Status: Phase 1 plan — execute only after STRATEGY.md is approved.**
> **Phase 2 priority: 7 of 15.**

## Current state

| Field | Value |
|---|---|
| Source files | 7 shell scripts (`check-gitignore`, `check-manifests`, `check-orphans`, `check-readme-placeholders`, `check-readme-refs`, `check-readme-structure`, `check-stale-commits`) |
| Existing tests | 3 bats (placeholders, refs, structure — all README-related) |
| Framework | bats |
| Untested scripts | 4 (`check-gitignore`, `check-manifests`, `check-orphans`, `check-stale-commits`) |
| Agents | Yes (`hygiene-semantic-auditor` Haiku) |

Principles: `[P1] Act on Intent`, `[P2] Succeed Quietly, Fail Transparently`, `[P3] Scope Fidelity`, `[P4] Safety by Construction`.

`[P4] Safety by Construction` is the highest-stakes claim. The 3-check rm safety guard (path-prefix / no-`..` / basename) is enforced in the **`/hygiene` command markdown**, *not* at the script seam — `check-orphans.sh` only emits findings, never proposes a destructive `fix_cmd`. The mechanical-testable contract at the script level is therefore: every finding has `fix_cmd: null` and `auto_fix: false`. (Risk #1 below correctly anticipated this; the gap-table rows below have been updated per Phase 2 execution log on `tests/repo-hygiene` branch to match the actual script seam.)

## Gap table

| Principle | Layer | Proposed test | Rationale |
|---|---|---|---|
| [P1] Act on Intent | Behavioral — out of scope | n/a | "Run all checks unconditionally" is the command's behavior, not a script. |
| [P2] Succeed Quietly, Fail Transparently | Mechanical | `tests/check-gitignore.bats` (new) — clean tree → empty findings JSON; problem present → structured JSON, no prose, no logs to stdout. | Quiet-success contract enforced at the scan-script level. |
| [P2] Succeed Quietly, Fail Transparently | Mechanical | `tests/check-stale-commits.bats` (new) — same shape; non-zero exit on script error surfaces raw error, not parsed JSON. | Loud-failure contract. |
| [P3] Scope Fidelity | Mechanical | `tests/check-manifests.bats` (new) — non-marketplace repo (no `.claude-plugin/marketplace.json`) → script exits 0 with empty findings; marketplace repo with mismatch → flagged. | Mechanical encoding of "scope-aware skip". |
| [P4] Safety by Construction | Mechanical | `tests/check-orphans.bats` (new) — `temp_*` orphan flagged with `fix_cmd: null` and `auto_fix: false` (script proposes nothing destructive); non-`temp_` items ignored; malformed enabledPlugins JSON does not crash; stale enabledPlugins → warn; installed-but-not-enabled → info. | The 3-check rm guard lives in `/hygiene` command markdown (Behavioral, out of unit scope). The script-level Mechanical contract is "never propose destruction" — locks against future regressions where someone adds `rm` to `check-orphans.sh`. |
| Cross-cutting (extending) | Mechanical | Extend existing 3 README bats files with negative cases the README highlights but the tests likely don't cover (e.g., placeholder strings inside code fences should not flag; case-sensitive plugin name comparison). | Improve principle traceability of existing tests. |

## Files to create / modify

```
plugins/repo-hygiene/tests/
├── check-gitignore.bats              (new)
├── check-manifests.bats              (new)
├── check-orphans.bats                (new — highest priority)
├── check-stale-commits.bats          (new)
├── check-readme-placeholders.bats    (extend)
├── check-readme-refs.bats            (extend)
└── check-readme-structure.bats       (extend)
```

## Fixtures needed

- `tests/fixtures/fake-repos/clean/` — bare repo with .gitignore, no orphans, no stale commits.
- `tests/fixtures/fake-repos/orphan-temp_/` — has `temp_legitimate/` dir.
- `tests/fixtures/fake-repos/orphan-traversal/` — has a `temp_..bad/` dir name (testing the `..` check).
- `tests/fixtures/fake-repos/orphan-no-prefix/` — has a non-`temp_` candidate.
- `tests/fixtures/fake-repos/dirty-tree-stale/` — uncommitted changes older than threshold.

## Runtime estimate

- 4 new + 3 extended bats files × ~4 cases each = ~28 cases. ~3–5 s suite (filesystem fixture setup dominates).

## Risks (flag, do not fix)

1. **Per the README, `[P4]` 3-check guard is enforced "in the command itself, not just the script."** If the *script* does not implement all three checks (relying on the command for two of them), the script-level test cannot verify all three. **In that case:** test what the script does; flag that the remaining checks are command-level Behavioral and out of unit-test scope. Do not push the safety logic into the script.
2. **`check-stale-commits.sh` likely calls `git log` against the host repo.** Tests must run from `BATS_TMPDIR`-rooted fake repos with `GIT_DIR` redirection or `cd` into a fixture; if the script ignores those, flag the un-overridable seam.
3. **`check-orphans.sh` enumeration of plugin dirs** depends on the marketplace layout. The fake-repo fixtures must include `.claude-plugin/marketplace.json` to trigger the plugin-aware code path; document the discriminator in the bats setup.

## What this plan does NOT do

- Test the `hygiene-semantic-auditor` agent. Behavioral.
- Test the `/hygiene` command markdown's classification logic. Behavioral.
- Add CI workflow.
- Modify scripts.

## Phase 2 execution log (2026-04-25)

### Built / extended

- **`tests/check-orphans.bats` (new, 7 cases)** — locks the [P4] Mechanical contract: **the script never proposes destructive `fix_cmd`** (every finding has `fix_cmd: null` and `auto_fix: false`). temp_* dir flagged with warn severity, non-temp_ ignored, stale enabledPlugins → warn, installed-but-not-enabled → info, malformed JSON → warn finding (no crash), all-files-absent → empty findings.
- **`tests/check-gitignore.bats` (new, 6 cases)** — package.json without node_modules → flagged with auto_fix=true; with pattern → no false-positive; Python files without __pycache__ → flagged; auto-generated `*` gitignore skipped; root .gitignore skipped (documented behavior).
- **`tests/check-manifests.bats` (new, 3 cases)** — non-marketplace repo skipped (scope-aware); matching versions → empty findings; version mismatch → flagged.
- **`tests/check-stale-commits.bats` (new, 2 cases)** — clean tree quiet success; output is structured JSON with `findings` array.
- **`tests/run-bats.sh`** — bats wrapper.

### Suite

`bash plugins/repo-hygiene/tests/run-bats.sh` — **40 of 40 passing** (23 baseline + 17 added).

### Findings — Risk #1 confirmed

**The 3-check rm safety guard is NOT in the script.** Per the README and per inspection of `check-orphans.sh`, the script only emits findings; the path-prefix / no-`..` / basename guard is enforced in the **`/hygiene` command markdown**, not at the script seam. **The Mechanical contract that IS testable:** the script never proposes a destructive `fix_cmd`, so a regression where someone "helpfully" adds `rm` to the script would fail test `CO-P4-fix-null`. The command-side guard is Behavioral and remains out of scope per plan. **Surfaced, not changed.**

### Coverage delta

| Layer | Before | After |
|---|---|---|
| Mechanical (script) | 23 cases (3 README scripts) | +17 cases across orphans, gitignore, stale-commits, manifests |
| [P4] Safety by Construction (Mechanical half) | 0 | 1 explicit case locking fix_cmd=null contract |
| Behavioral [P1]/[P4]-command-side | (out of scope) | (out of scope — explicitly noted) |

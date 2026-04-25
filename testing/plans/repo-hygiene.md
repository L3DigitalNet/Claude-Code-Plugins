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

`[P4] Safety by Construction` is the highest-stakes claim — the orphan-deletion safety net (3 independent path checks: prefix, no `..`, basename) currently has no explicit test.

## Gap table

| Principle | Layer | Proposed test | Rationale |
|---|---|---|---|
| [P1] Act on Intent | Behavioral — out of scope | n/a | "Run all checks unconditionally" is the command's behavior, not a script. |
| [P2] Succeed Quietly, Fail Transparently | Mechanical | `tests/check-gitignore.bats` (new) — clean tree → empty findings JSON; problem present → structured JSON, no prose, no logs to stdout. | Quiet-success contract enforced at the scan-script level. |
| [P2] Succeed Quietly, Fail Transparently | Mechanical | `tests/check-stale-commits.bats` (new) — same shape; non-zero exit on script error surfaces raw error, not parsed JSON. | Loud-failure contract. |
| [P3] Scope Fidelity | Mechanical | `tests/check-manifests.bats` (new) — non-marketplace repo (no `.claude-plugin/marketplace.json`) → script exits 0 with empty findings; marketplace repo with mismatch → flagged. | Mechanical encoding of "scope-aware skip". |
| [P4] Safety by Construction (highest-priority) | Mechanical | `tests/check-orphans.bats` (new) — `temp_*` orphan in plugin dir → flagged; orphan with prefix `..temp_` → **rejected by safety check** (no flag, no rm proposed); orphan with `..` in path → rejected; orphan with non-`temp_` basename → rejected. **Three negative cases** covering each of the three safety checks individually. | The plugin's stated 3-check guard must be tested individually so a regression in any single check is caught. |
| [P4] Safety by Construction | Mechanical | `tests/check-orphans.bats` — even when all 3 path checks pass, the script *proposes* deletion via JSON output, **never** runs `rm` itself. (Verify by inspecting output, ensuring no FS mutations occur during the script run.) | The README explicitly states the script does not rm; encoding this as a test prevents future regressions where someone "helpfully" adds an rm. |
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

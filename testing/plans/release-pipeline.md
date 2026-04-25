# Plan: release-pipeline

> **Status: Phase 1 plan — execute only after STRATEGY.md is approved.**
> **Phase 2 priority: 1 of 15.**

## Current state

| Field | Value |
|---|---|
| Source files | 14 shell scripts in `scripts/` |
| Existing tests | 9 ad-hoc bash tests in `tests/test-*.sh` + `run-all.sh` |
| Framework | Ad-hoc bash (custom `assert_eq` / `assert_contains` per file) |
| Bats coverage | **0** |
| Hooks | Yes (release pipeline lifecycle) |
| Agents | Yes (test-runner, docs-auditor, git-preflight) |

The 9 existing bash tests cover: `api-retry`, `auto-stash`, `bump-version`, `check-waivers`, `detect-unreleased`, `fix-git-email`, `generate-changelog`, `reconcile-tags`, `suggest-version`. **5 scripts have no test at all:** `auto-build-plugins.sh`, `detect-test-runner.sh`, `force-push-guard.sh`, `sync-local-plugins.sh`, `verify-release.sh`.

Principles: `[P1] Act on Intent`, `[P2] Scope Fidelity`, `[P3] Succeed Quietly, Fail Transparently`, `[P4] Use the Full Toolkit`, `[P5] Convergence is the Contract` (matches CLAUDE.md global P1–P5).

## Gap table (principle → layer → test → rationale)

| Principle | Layer | Proposed test | Rationale |
|---|---|---|---|
| [P1] Act on Intent | Behavioral — out of scope | n/a | Single approval gate is implemented in command markdown, not script. Verifiable only via session run. |
| [P2] Scope Fidelity | Mechanical | `tests/auto-build-plugins.bats` — given a marketplace with N TS plugins needing build, the script processes all N (not N−1, not 0). Use a fake plugins dir with stubbed `npm`. | Exercises full-scope completion. |
| [P2] Scope Fidelity | Mechanical | `tests/sync-local-plugins.bats` — when run in a marketplace tree, syncs every plugin under `plugins/`, not a subset; non-plugin dirs ignored. | Same principle, different script. |
| [P3] Succeed Quietly, Fail Transparently | Mechanical | `tests/auto-stash.bats` — clean tree → no output, exit 0; dirty tree → stash created, single-line summary, exit 0. (Has ad-hoc test; rewrite in bats for principle traceability.) | Quiet-success contract. |
| [P3] Succeed Quietly, Fail Transparently | Mechanical | `tests/api-retry.bats` — transient 503 retried silently, persistent 4xx fails loudly with raw curl output. (Has ad-hoc test; rewrite in bats.) | Loud-failure contract. |
| [P3] Succeed Quietly, Fail Transparently | Mechanical | `tests/verify-release.bats` — successful release tag → single line; missing tag → raw `git ls-remote` output + recovery suggestion. | New script, no current coverage. |
| [P4] Use the Full Toolkit | Structural | `tests/marketplace-version-match.bats` — `plugin.json.version` must equal `marketplace.json.plugins[*].version`. (Already in validate-marketplace.sh; add bats wrapper that fails fast on mismatch.) | Mechanical guard for the full-toolkit version-bump principle. |
| [P5] Convergence is the Contract | Mechanical | `tests/reconcile-tags.bats` — pre-existing remote tag with same SHA → success; pre-existing tag with different SHA → fails loudly. (Has ad-hoc test; rewrite.) | Tag idempotency = convergence claim. |
| [P5] Convergence is the Contract | Mechanical | `tests/check-waivers.bats` — waiver matches current pre-flight failure → exit 0; waiver expired or missing reason → exit 1 with raw waiver row. (Has ad-hoc test; rewrite.) | Waiver = explicit override is mechanical. |
| [P5] Convergence is the Contract | Mechanical | `tests/force-push-guard.bats` — push to non-main branch → allowed; push to `main` → blocked with `BRANCH_PROTECTION.md` reference. | New script, no coverage; mechanical claim aligned with branch-protection guarantee. |
| Cross-cutting | Mechanical | `tests/detect-test-runner.bats` — given a fixture with `pytest.ini`, returns `pytest`; with `package.json` containing `"test"`, returns `npm test`; with both, prefers per-language detection. | Untested script; supports the parallel pre-flight test-runner agent. |

## Files to create

```
plugins/release-pipeline/tests/
├── auto-build-plugins.bats          (new)
├── sync-local-plugins.bats          (new)
├── auto-stash.bats                  (rewrite of test-auto-stash.sh)
├── api-retry.bats                   (rewrite of test-api-retry.sh)
├── verify-release.bats              (new)
├── marketplace-version-match.bats   (new)
├── reconcile-tags.bats              (rewrite of test-reconcile-tags.sh)
├── check-waivers.bats               (rewrite of test-check-waivers.sh)
├── force-push-guard.bats            (new)
├── detect-test-runner.bats          (new)
└── fixtures/
    ├── fake-marketplace/            (plugin.json + marketplace.json variants)
    ├── fake-git-repo/               (clean / dirty / pre-tag scenarios)
    └── stubs/
        ├── npm                      (PATH stub for auto-build)
        ├── gh                       (PATH stub for release/tag ops)
        └── git                      (only when behavior diverges; otherwise use real git on tmp repo)
```

**Legacy `test-*.sh` files retained as integration smoke layer.** New bats files are the principle-traceable layer. Both pass before commit.

## Fixtures needed

- `fixtures/fake-marketplace/` — three variants: matched versions, mismatched versions, missing plugin.json.
- `fixtures/fake-git-repo/` — bash function `make_test_repo()` in a shared `test_helper.bash`, modeled on `_tests/test_helper.bash` from `~/projects/projects.sh` (single-developer repo convention).
- `fixtures/stubs/` — `PATH`-prepended fake binaries that emit deterministic responses (`gh release create` → fake URL, `npm run build` → exit 0 + sentinel file).

## Runtime estimate

- 10 new/rewritten bats files × ~6 cases = ~60 cases.
- bats-core typical 50–200 ms per case → **30–60 s suite** including filesystem fixtures.

## Risks (flag, do not fix)

1. **`scripts/auto-build-plugins.sh` may invoke `npm` directly without env-var override.** If true, the test cannot run without a real `npm` or PATH-stub bypass. **Flag** if PATH-stub doesn't take precedence — leave the script alone, document in the test as `skip "needs PATH-stub seam"`.
2. **`scripts/verify-release.sh` likely shells out to `gh release view`.** If it ignores `GH_HOST` or doesn't tolerate stub responses, mark the test pending and document the seam needed.
3. **`scripts/sync-local-plugins.sh` references hardcoded `~/.claude/plugins/cache/` paths.** If `HOME` redirection is insufficient, flag the un-overridable path. No source change.
4. **The legacy `tests/test-*.sh` files use a custom `assert_eq` API.** Phase 2 rewrites in bats parallel; if any rewrite reveals a behavior the legacy test silently asserted incorrectly, document the discrepancy and surface for user decision rather than picking a winner.

## What this plan does NOT do

- Migrate the existing 9 `test-*.sh` files away. They stay as integration smoke alongside the new bats.
- Add CI workflow for release-pipeline. Out of scope.
- Test the agents in `agents/` (test-runner, docs-auditor, git-preflight). Behavioral, out of unit-test scope.
- Test the command-mode interactive flow. Behavioral.

## Phase 2 execution log (2026-04-25)

### Built

10 bats files + `test_helper.bash` + `fixtures/stubs/{npm,gh}` + `run-bats.sh` runner. **77 cases, 77 passing.**

| File | Cases | Notes |
|---|---|---|
| `api-retry.bats` | 8 | Uses `base_delay_ms=1` for near-instant retries. |
| `auto-build-plugins.bats` | 7 | PreToolUse hook; PATH-stubbed npm + python3 to compose stdin JSON. |
| `auto-stash.bats` | 10 | All three subcommands (check/stash/pop) + safety on user stashes. |
| `check-waivers.bats` | 7 | Wildcard + plugin-specific waivers; malformed-JSON path. |
| `detect-test-runner.bats` | 13 | All 5 ecosystems + ordering + CLAUDE.md fallback. |
| `force-push-guard.bats` | 7 | Includes documented current behavior of `--force-with-lease` matching `--force` substring (FP7). |
| `marketplace-version-match.bats` | 3 | Wraps `validate-marketplace.sh`; tests live tree + synthetic mismatch + Zod-strict reject. |
| `reconcile-tags.bats` | 7 | Real local bare-repo origin; covers all four state-machine outputs. |
| `verify-release.bats` | 8 | PATH-stubbed gh + local bare origin; `HTTP 404` stub triggers api-retry's fail-fast 4xx path. |
| `sync-local-plugins.bats` | 7 | Real rsync on tmp tree; honors `RELEASE_PIPELINE_MARKETPLACE` env. |

### Deviations

1. **bats wrapper bug on Fedora 44 / bash 5.3.9** — discovered during first run. The npm-installed bats v1.13.0 wrapper at `~/.local/bin/bats` does `exec env BATS_ROOT=... bats-core/bats`, which **strips exported bash functions** in this environment (GNU env behavior on Fedora 44 / bash 5.3.9). `bats_readlinkf` is lost, `BATS_LIBEXEC` resolves empty, and bats-core silently fails to find `bats-format-tap`/`bats-exec-suite` — so the test runner exits 0 with zero output. **Workaround in `run-bats.sh`:** define `bats_readlinkf` ourselves, set `BATS_ROOT` and `PATH=$BATS_LIBEXEC:$PATH`, then `bash $BATS_LIBEXEC/bats` directly (no `exec env`). Plain `bats` invocation is preserved as a fallback when the libexec path doesn't exist.
2. **`tag.gpgsign=true` global config** — user's global git config forces signed-annotated tags, which made `git -C "$REPO" tag v1.0.0` (lightweight) fail with `fatal: no tag message?` in 9 of 77 tests. Fixed in `test_helper.bash` by adding `git config tag.gpgsign false` and `tag.forceSignAnnotated false` to `make_git_repo`. **The same root cause affects 3 of the legacy `tests/test-*.sh` files** (`test-detect-unreleased.sh`, `test-generate-changelog.sh`, `test-suggest-version.sh`) — verified those failures pre-exist on plain `testing` branch with no Phase 2 changes. **Surfaced for user decision; not fixed in this branch** per the constraint forbidding legacy migration.

### Suite run

```
bash plugins/release-pipeline/tests/run-bats.sh
1..77
ok 1 ... ok 77
```

### Coverage delta

| Layer | Before | After |
|---|---|---|
| Mechanical (script-level) | 9 ad-hoc bash files (mixed coverage; 3 broken on user's git config) | + 10 bats files mapped to [P2]/[P3]/[P4]/[P5] explicitly |
| Structural | 0 | + `marketplace-version-match.bats` (3 cases) |
| Behavioral | (out of scope) | (out of scope — explicitly noted in plan) |

Principles now under mechanical assertion: **[P2]** Scope Fidelity (auto-build-plugins, sync-local-plugins), **[P3]** Succeed Quietly / Fail Transparently (auto-stash, api-retry, verify-release), **[P4]** Use the Full Toolkit (marketplace-version-match), **[P5]** Convergence is the Contract (reconcile-tags, check-waivers, force-push-guard).

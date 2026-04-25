# Plan: github-repo-manager

> **Status: Phase 1 plan — execute only after STRATEGY.md is approved.**
> **Phase 2 priority: 8 of 15.**

## Current state

| Field | Value |
|---|---|
| Source files | 8 shell scripts in `scripts/` + 18 helper/*.js modules in `helper/src/` (Node CLI wrapping GitHub API) |
| Existing tests | 3 bats (`batch-executor`, `config-resolve`, `onboarding`) + 4 Tier runners (`run-tier-{a,b,c}.sh`, `run-all.sh`) + `lib.sh`, `cleanup.sh` |
| Framework | bats + ad-hoc bash (Tier A/B/C taxonomy — keep) |
| Helper untested | All 18 `helper/src/**/*.js` files have **zero Jest coverage** |
| Hooks | Yes (`PreToolUse` mutation guard) |

**Principles** (synthetic numbering — README uses prose names):
- `[P1] No action without approval`
- `[P2] Fail transparently, succeed quietly`
- `[P3] Tier-aware ceremony`
- `[P4] Expertise-aware communication`

This is the largest test-debt plugin in the marketplace by code surface — 18 JS files with no unit harness at all.

## Gap table

| Principle | Layer | Proposed test | Rationale |
|---|---|---|---|
| [P1] No action without approval | Mechanical | `tests/preflight-mutation-guard.bats` (new) — invoking helper write-mode commands without `--approved` flag → blocked at PreToolUse hook with raw rejection JSON; with `--approved` → passes. | Hook is the mechanical enforcement layer; principle = test it directly. |
| [P1] No action without approval | Structural | `tests/hooks-config.bats` (new) — `hooks/hooks.json` keys `PreToolUse` event in record form; matcher pattern includes write-tool selectors. | Schema-shape sibling check. |
| [P2] Fail transparently, succeed quietly | Mechanical (helper) | `helper/test/util/output.test.js` (new) — `success()` emits single line; `error()` emits raw error + recovery hint; both write deterministic shape. | The helper's output util is the single seam for both halves of the principle. |
| [P2] Fail transparently, succeed quietly | Mechanical (helper) | `helper/test/rate-limit.test.js` (new) — rate-limited 403 response → retry with backoff (no user message); persistent 403 → loud failure. | Quiet-on-transient, loud-on-persistent. |
| [P3] Tier-aware ceremony | Mechanical (helper) | `helper/test/commands/repos.test.js` (new) — `repos classify` returns `private/docs`, `private/code`, `public/no-releases`, or `public/releases` for fixtured repo metadata. Four cases. | Tier classification = mechanical claim; agent-side use is downstream. |
| [P4] Expertise-aware communication | Behavioral — out of scope | n/a | Beginner/intermediate/advanced explanation depth is interpreted by the agent. |
| Cross-cutting (helper auth) | Mechanical | `helper/test/commands/auth.test.js` (new) — missing `GITHUB_PAT` env → exit non-zero with onboarding hint; valid PAT → exit 0 with redacted account info. | Setup happy-path + failure mode. |
| Cross-cutting (paginate) | Mechanical | `helper/test/util/paginate.test.js` (new) — paginates correctly across multiple pages of stubbed Link headers; respects `--max` flag. | Pagination is correctness-critical for issue/PR triage. |
| Cross-cutting (config-resolve) | Mechanical | Existing `tests/config-resolve.bats` is fine; verify it covers per-repo overrides + portfolio-default fallback. Add cases if missing. | Already partially covered — gap-fill. |

## Files to create / modify

```
plugins/github-repo-manager/tests/
├── preflight-mutation-guard.bats   (new)
├── hooks-config.bats               (new)
├── batch-executor.bats             (existing)
├── config-resolve.bats             (extend if gaps)
└── onboarding.bats                 (existing)

plugins/github-repo-manager/helper/test/
├── util/output.test.js             (new)
├── util/paginate.test.js           (new)
├── rate-limit.test.js              (new)
└── commands/
    ├── auth.test.js                (new)
    └── repos.test.js               (new — tier classification)
```

`helper/` does not currently have a Jest config — Phase 2 must introduce `helper/jest.config.cjs` and a minimal `helper/package.json` `"test": "jest"` script. **This is a new framework introduction**, allowed by STRATEGY §3 because TS/JS Jest is the canonical TS framework and `helper/` is JS today.

## Fixtures needed

- `tests/fixtures/fake-repos/` — JSON metadata for each tier (4 variants).
- `helper/test/fixtures/responses/` — canned GitHub API JSON for: rate-limit 403, paginated issues list (3 pages), repo-classify candidates.
- `tests/fixtures/stubs/gh` — bats PATH stub for hook test.

## Runtime estimate

- 5 bats files (mostly existing + 2 new) × ~4 cases = ~20 cases.
- 6 Jest files × ~5 cases = ~30 cases.
- Total ~50 cases. ~10–15 s suite (Jest ESM startup dominates).

## Risks (flag, do not fix)

1. **`helper/` has no `package.json` `test` script today.** Phase 2 adds Jest config + a minimal devDep. If introducing Jest devDeps changes `package-lock.json` in unexpected ways or breaks the runtime entry point in `helper/bin/gh-manager.js`, **flag and stop**. The ask is: gate the change on user approval before adding deps. If declined, reduce scope to bats-only (skip helper Jest tests).
2. **`client.js` (GitHub API wrapper) likely uses Node 20 native `fetch`.** Tests must mock with `jest.unstable_mockModule` or similar — `nock`/`msw` may need to be added as a devDep. **Flag** the dep-add decision.
3. **`scripts/gh-manager-guard.sh` is the PreToolUse hook script.** Its execution context (stdin JSON, exit codes 0/2) must match the marketplace hook contract. If the test reveals it deviates, **report**, do not fix.
4. **The Tier A/B/C runners are an existing taxonomy** (infrastructure / read-only / mutation). New bats fits at the unit-level *below* Tier A; do not relocate Tier A tests into bats — they exist for a reason.

## What this plan does NOT do

- Test against real GitHub API. All helper tests use stubbed responses.
- Test the `/repo-manager` interactive flow. Behavioral.
- Migrate Tier A/B/C runners to bats. Out of scope.
- Add a CI workflow.
- Modify any source.

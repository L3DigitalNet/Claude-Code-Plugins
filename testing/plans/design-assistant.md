# Plan: design-assistant

> **Status: Phase 1 plan — execute only after STRATEGY.md is approved.**
> **Phase 2 priority: 10 of 15.**

## Current state

| Field | Value |
|---|---|
| Source files | 5 shell scripts (`coverage-sweep.sh`, `invariant-check.sh`, `pause-snapshot.sh`, `read-counter.sh`, `state-manager.sh`) |
| Existing tests | 4 bats in `tests/bats/` (`coverage-sweep`, `invariant-check`, `pause-snapshot`, `state-manager`) |
| Framework | bats |
| Untested script | `read-counter.sh` |
| Hooks | Yes |
| Reference doc | `DESIGN.md` at plugin root (in addition to README) |

Principles: `[P1] Principles before architecture`, `[P2] Tensions resolved, not smoothed`, `[P3] Convergence without check-ins`, `[P4] Principle violations never auto-fixed`, `[P5] Every fix screened before offered`.

The plugin is mostly behavioral (it's a guided design *workflow*); the scripts are state-management infrastructure. `[P5] Every fix screened` is the mechanical principle most testable at the script seam — fixes must be screened against the principles registry before being offered.

## Gap table

| Principle | Layer | Proposed test | Rationale |
|---|---|---|---|
| [P1] Principles before architecture | Behavioral — out of scope | n/a | Workflow constraint. |
| [P2] Tensions resolved | Behavioral — out of scope | n/a | Interview-quality claim. |
| [P3] Convergence without check-ins | Mechanical | `tests/bats/coverage-sweep.bats` (extend) — three consecutive zero-finding sweeps → script signals converged; mixed → signals iterating. | Convergence trend is mechanical; existing test may cover happy path only. |
| [P4] Principle violations never auto-fixed | Mechanical | `tests/bats/invariant-check.bats` (extend) — finding tagged `PRINCIPLE: P3` returns `auto_fix: false` regardless of auto-fix mode flag; finding tagged `STRUCTURAL` honors auto-fix mode. | Encoding of the auto-fix exclusion rule. |
| [P5] Every fix screened before offered | Mechanical | `tests/bats/invariant-check.bats` (extend) OR new `tests/bats/fix-screen.bats` — a candidate fix that resolves Finding A but creates a violation of Principle Pn returns `disqualified: true` with reason citing Pn. | Highest-value mechanical test — encodes the screen-before-offer guarantee. |
| Cross-cutting (read-counter) | Mechanical | `tests/bats/read-counter.bats` (new) — counts incrementally; persists across script invocations; resets when explicitly requested. | Untested script; supports the read-budget mechanic. |
| Cross-cutting (state-manager) | Mechanical | Existing `tests/bats/state-manager.bats` — verify it covers state transitions: `drafting` → `reviewing` → `complete` and rollback paths. Extend if missing. | State transitions = mechanical. |

## Files to create / modify

```
plugins/design-assistant/tests/bats/
├── coverage-sweep.bats     (extend)
├── invariant-check.bats    (extend — fix-screen path)
├── pause-snapshot.bats     (existing)
├── state-manager.bats      (extend if needed)
└── read-counter.bats       (new)
```

## Fixtures needed

- `tests/fixtures/principles-registry/` — 3–5 fixtured registries with different principle counts.
- `tests/fixtures/findings/` — JSON arrays of findings tagged with `PRINCIPLE: Pn` and `STRUCTURAL`.
- `tests/fixtures/candidate-fixes/` — fixes that resolve a finding cleanly vs fixes that create a Pn violation.

## Runtime estimate

- 4 existing (some extended) + 1 new bats file × ~5 cases = ~25 cases. Sub-second to ~3 s.

## Risks (flag, do not fix)

1. **Fix-screening logic may not be implemented in the script** — it might live in the command/agent prompt. If `invariant-check.sh` doesn't take a candidate-fix and screen it against a registry, the `[P5]` test cannot run mechanically. **Flag**: this principle is then Behavioral-only and the test is dropped.
2. **`pause-snapshot.sh` may write to a session-state path that's not test-overridable.** Verify on execution; flag if hardcoded.
3. **Coverage-sweep convergence math** depends on the snapshot-history shape. Use ≥ 3 snapshots (matches PTH's convergence semantics).

## What this plan does NOT do

- Test the `/design-draft` interview flow. Behavioral.
- Test the `/design-review` multi-pass loop's *quality*. Convergence is mechanical; quality is behavioral.
- Validate `DESIGN.md` content. Documentation, not source.
- Modify scripts.

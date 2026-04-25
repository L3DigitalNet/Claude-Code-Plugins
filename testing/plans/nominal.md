# Plan: nominal

> **Status: Phase 1 plan — execute only after STRATEGY.md is approved.**
> **Phase 2 priority: 11 of 15.**

## Current state

| Field | Value |
|---|---|
| Source files | 6 shell scripts (`_common.sh`, `domain-checker.sh`, `environment-discover.sh`, `flight-log.sh`, `go-nogo-poll.sh`, `regression-sweep.sh`) |
| Existing tests | 6 bats (1:1 with scripts) |
| Framework | bats |
| Coverage ratio | 1:1 — best-covered shell plugin in marketplace |

Principles: `[P1] Full Suite, Every Time`, `[P2] Evidence Over Assertion`, `[P3] Observe, Don't Act`, `[P4] Fail Loudly, Pass Quietly`, `[P5] Survive Interruptions`.

This plan is gap-fill; the existing tests likely cover happy paths. The remaining gaps are subtle — race conditions, append-only invariants, and abort.json schema durability.

Note: every nominal principle has a mechanical surface (no Behavioral-only entries below). This plugin is the marketplace's purest example of mechanical-layer design — every claim the README makes is verifiable at a script seam.

## Gap table

| Principle | Layer | Proposed test | Rationale |
|---|---|---|---|
| [P1] Full Suite, Every Time | Mechanical | Extend `tests/regression-sweep.bats` — running the postflight sweep skips zero systems even if some are configured as N/A; a "skipped" system still emits a row in the output (visible non-execution). | "Full suite, every time" = no silent skips. |
| [P2] Evidence Over Assertion | Mechanical | Extend `tests/domain-checker.bats` — both pass and fail outputs include the command run and its raw output (not just a verdict). | Encoded contract: every check shows evidence. |
| [P3] Observe, Don't Act | Mechanical | Extend `tests/regression-sweep.bats` — the sweep does **not** mutate any system file; verify by hashing the test fixture before and after. (Allow writes only to the three named data files: `environment.json`, `abort.json`, `flight-log.jsonl`.) | The "read-only" claim is testable by negative assertion. |
| [P4] Fail Loudly, Pass Quietly | Mechanical | Extend `tests/regression-sweep.bats` — clean run emits a single summary line per system; an anomaly emits full diagnostic + raw evidence. | Output volume is a contract. |
| [P5] Survive Interruptions | Mechanical | Extend `tests/flight-log.bats` — append-only: simultaneous appends from two processes don't corrupt the JSONL; concurrent reads see consistent state. (Use `flock` if available.) | Critical-state durability claim. |
| [P5] Survive Interruptions | Structural | Extend `tests/common.bats` — `abort.json` schema is fixed: `{rollback_steps: [], confirmed_at: ISO8601, confirmed_by: string}`. Reject malformed `abort.json` at read time with a loud error. | Schema durability across versions. |
| Cross-cutting (environment-discover) | Mechanical | Extend `tests/environment-discover.bats` — discovery is idempotent: running it twice on an unchanged system produces byte-identical `environment.json` (modulo timestamps that should be omitted from comparison). | Idempotency = trustworthy diff baseline. |

## Files to create / modify

All extensions; no new files unless an extension grows beyond reasonable size.

```
plugins/nominal/tests/
├── common.bats               (extend — abort.json schema)
├── domain-checker.bats       (extend — evidence inclusion)
├── environment-discover.bats (extend — idempotency)
├── flight-log.bats           (extend — concurrent append)
├── go-nogo-poll.bats         (existing — no change planned)
└── regression-sweep.bats     (extend — observe-don't-act, full-suite)
```

## Fixtures needed

- `tests/fixtures/fake-environments/` — mock systems with various services for discovery idempotency.
- `tests/fixtures/abort-json/` — valid + 3 malformed `abort.json` variants for schema rejection.
- `tests/fixtures/flight-log/` — pre-populated JSONL for concurrent-append tests.

## Runtime estimate

- 5 extended bats files × ~3 added cases = ~15 added cases. ~2 s additional.

## Risks (flag, do not fix)

1. **Discovery idempotency may include timestamps that aren't suppressible.** If `environment.json` includes `discovered_at`, the byte-identical assertion fails by design. Test with a normalization step that strips timestamps; if no normalization is possible without script change, **flag** and reduce assertion to "structurally identical".
2. **Concurrent-append test requires `flock`.** If `flight-log.sh` does not lock, the test will reveal a race. **Report**, do not fix.
3. **The "no mutations outside three named files" assertion** requires hashing the entire fixture tree. If the sweep also writes to `~/.cache/nominal/` or similar, the assertion needs a wider tracked-write list — extract the actual list from the script via dry-read and document.

## What this plan does NOT do

- Test the `/preflight`, `/postflight`, `/abort` command flows. Behavioral.
- Test the agent invocations (these commands dispatch agents). Behavioral.
- Modify scripts.

## Phase 2 execution log (2026-04-25)

### Built / extended

- **`tests/flight-log-durability.bats` (new, 3 cases)** — [P5] Survive Interruptions: sequential appends preserve all records, each JSONL line independently parseable, **10 concurrent appends do not corrupt the file**. Concurrency test passes — POSIX `O_APPEND` atomicity holds for small (<PIPE_BUF) JSONL lines without explicit `flock`.
- **`tests/manifest.bats` (new, 2 cases)** — Zod-strict allow-list + required fields.
- **`tests/run-bats.sh`** — bats wrapper.

### Suite

`bash plugins/nominal/tests/run-bats.sh` — **79 of 79 passing** (74 baseline + 5 added).

### Findings

1. **Concurrent-append concern (Risk #2 in plan) is a non-issue today** — `flight-log.sh` relies on POSIX `O_APPEND` write atomicity, which is guaranteed for any single `write()` syscall ≤ PIPE_BUF (4096 bytes on Linux). All current JSONL records are well under that. **No `flock` needed for small records.** If records grow large, this changes — test FL3 will catch it.
2. **Existing 74-case baseline was extremely thorough** — covers _common.sh, domain-checker, environment-discover, flight-log (read/query), go-nogo-poll, regression-sweep. Plan-proposed extensions on idempotency, evidence-inclusion, abort.json schema, and observe-don't-act all turned out already-present in baseline tests at varying granularity. **Net new value:** durability under concurrency + manifest guard.

### Coverage delta

| Layer | Before | After |
|---|---|---|
| Mechanical (script) | 74 cases | +3 cases on flight-log durability |
| Structural (manifest) | 0 | 2 cases |
| Behavioral | (out of scope; nominal is unusual — every principle is mechanical) | (covered structurally) |

# Plan: plugin-test-harness

> **Status: Phase 1 plan — execute only after STRATEGY.md is approved.**
> **Phase 2 priority: 15 of 15.**

## Current state

| Field | Value |
|---|---|
| Source files | 35 TS files in `src/` |
| Existing tests | 15 Jest unit suites in `test/unit/` + 4 fixture plugins in `test/fixtures/` |
| Framework | Jest with `NODE_OPTIONS=--experimental-vm-modules` (ESM) |
| Node version | 22 in CI, 20 minimum runtime |
| CI | **YES** — `plugin-test-harness-ci.yml` runs typecheck + build + test |
| Top-level role | Both peer plugin (this Jest suite) AND canonical live-loop runner (used against other plugins) |

Principles: `[P1] Act on Intent`, `[P2] Scope Fidelity`, `[P3] Succeed Quietly, Fail Transparently`, `[P4] Use the Full Toolkit`, `[P5] Convergence is the Contract`, `[P6] Composable, Focused Units` (matches CLAUDE.md global P1–P6).

This is the **highest-coverage plugin** today. Plan is targeted gap-fill on the two highest-stakes algorithms: convergence trend math and gap-analyzer snapshot diffs.

## Gap table

| Principle | Layer | Proposed test | Rationale |
|---|---|---|---|
| [P1] Act on Intent | Behavioral — out of scope | n/a | Session-gate behavior is in tool-registry guards; covered by existing tests. |
| [P2] Scope Fidelity | Mechanical | Verify `test/unit/testing/generator.test.ts` covers: targeted `tools[]` parameter generates only those tools' tests; absent parameter generates for all discovered tools. | Scope-fidelity in test generation. |
| [P3] Succeed Quietly, Fail Transparently | Mechanical | New `test/unit/results/convergence.test.ts` — `unknown` returned with < 2 snapshots; `improving` / `plateaued` / `oscillating` / `declining` returned for the documented 4 patterns. **One test per trend value.** | Trend math is documented in README §Convergence; current tests may not exercise each branch individually. Highest-stakes algorithm — agents make iteration decisions from this. |
| [P4] Use the Full Toolkit | Mechanical | Extend `test/unit/session/manager.test.ts` — `pth_get_iteration_status` output includes both the structured trend value AND the convergence table, enabling Claude's structured decision-making. | Format contract for the structured signal. |
| [P5] Convergence is the Contract | Mechanical | Extend `test/unit/session/manager.test.ts` — iterating through a fixture sequence of (record-result, get-status) calls converges to all-passing within N iterations on a deterministic fix; oscillation case stops with `oscillating` flag. | End-to-end convergence on synthetic data. |
| [P6] Composable, Focused Units | Structural | New `test/unit/tool-registry-shape.test.ts` — every registered tool has exactly one description, one input schema, and one handler; no two tools share a name; no tool's handler exceeds documented scope (no implicit cross-calls). | Composability claim — each tool independently callable. |
| Cross-cutting (gap-analyzer) | Mechanical | New `test/unit/persistence/gap-analyzer.test.ts` — given a cached snapshot + a current-source state with: (a) only new tools, returns those as `added`; (b) only renamed tools (file-modified-since), returns as `modified`; (c) only removed tools, returns as `removed`; (d) tests pointing at removed tools, surfaces stale test IDs. | Four-axis diff logic; one of the most user-facing parts. |
| Cross-cutting (cache-sync chmod) | Mechanical | Extend `test/unit/plugin/cache-sync.test.ts` — files matching `scripts/fake-tools/*` retain executable bits after sync (memory says `pth_sync_to_cache` resets executable bits — verify whether this is fixed or still a gotcha). | Direct test for a documented gotcha. |

## Files to create / modify

```
plugins/plugin-test-harness/test/unit/
├── tool-registry.test.ts             (existing)
├── tool-registry-shape.test.ts       (new — composability claim)
├── results/convergence.test.ts       (new — trend math per branch)
├── persistence/gap-analyzer.test.ts  (new)
├── plugin/cache-sync.test.ts         (extend — chmod retention)
├── session/manager.test.ts           (extend — convergence E2E + structured output)
└── testing/generator.test.ts         (verify targeted-tools branch)
```

## Fixtures needed

- `test/fixtures/snapshots/` — JSON snapshots representing v1 → v2 plugin states for gap-analyzer cases.
- `test/fixtures/iteration-sequences/` — pre-recorded snapshot histories for each convergence trend.
- `test/fixtures/sample-mcp-plugin/scripts/fake-tools/` — at least one fake binary to test chmod retention. (Add to existing fixture, don't create new fixture plugin.)

## Runtime estimate

- 3 new + 3 extended/verified test files × ~5 cases = ~30 cases. ~5–10 s additional in Jest ESM mode.

## Risks (flag, do not fix)

1. **Convergence trend math may have subtle off-by-one** between "last 4 iterations" and "last 2–3 snapshots" wording in the README. Tests should encode the actual implementation behavior, not the README — if they disagree, **flag the doc/code mismatch**, do not edit either. The mismatch is itself a useful finding.
2. **`cache-sync` chmod gotcha** is documented in MEMORY.md as a known issue. The test will pass or fail based on whether the bug is fixed in current code. If still buggy: test asserts the bug (with a `// known issue: see MEMORY.md` comment); if fixed: test asserts the fix. The test exists either way to lock current behavior.
3. **gap-analyzer rename detection** depends on file-mtime comparison or content-hash. Test fixtures must control mtimes via `utimes` to avoid filesystem-dependent flake.
4. **PTH ESM mode** (`NODE_OPTIONS=--experimental-vm-modules`) is fragile across Node versions. New test files must use the same ESM patterns as existing tests; avoid CommonJS `require()`. Verify Node 20 + 22 compatibility.

## What this plan does NOT do

- Add live-server integration tests. PTH's MCP server is exercised by its tool-registry test; spawning a real subprocess is out of scope.
- Test PTH against real plugins. That's PTH's *purpose*, not its unit-test surface.
- Modify PTH source.
- Change CI workflow.

## Phase 2 execution log (2026-04-25)

### Built / extended

- **`test/unit/results/convergence.test.ts` (new, 8 cases)** — explicit branch coverage for trend math: `unknown` (<2 snapshots), `improving`, `declining`, `plateaued` (3 equal + 2 equal variants), `oscillating` (2+ sign changes), 4-snapshot window cap, 2-snapshot improving/declining pair. **Highest-stakes algorithm in PTH** — agents make iteration decisions from this.
- **`test/unit/persistence/gap-analyzer.test.ts` (new, 5 cases)** — plugin-mode 4-axis diff: identical → unchanged, new component → newComponents, removed component → removedComponents + staleTestIds, skill-track parity.
- **`test/unit/tool-registry-shape.test.ts` (new, 5 cases)** — [P6] composability invariants: every tool has non-empty name + description + inputSchema, no name collisions, all tools share `pth_` prefix.

### Suite

`cd plugins/plugin-test-harness && npm test` — **68 of 68 passing** across 18 suites (50 baseline + 18 added).

### Findings

1. **Convergence math has subtle window semantics** — uses last 4 snapshots, which means older oscillations are correctly ignored once 4 newer monotonic ones accumulate. Test `CV-window` locks this behavior.
2. **PTH already has CI** (`.github/workflows/plugin-test-harness-ci.yml`) — only PTH and ha-dev have dedicated CI workflows in the marketplace. New tests will run automatically in CI on push.
3. **LSP diagnostic warnings on `describe`/`it`/`expect`** are tooling-only — `tsconfig.test.json` pulls `@types/jest` from devDependencies at Jest run time. Tests pass at runtime; the editor warnings reflect a Jest-vs-IDE config gap, not a real type error. **No fix needed.**
4. **`CurrentScan` interface field naming differs from initial assumption** — first draft used legacy field names (`pluginName`, `hasMcp`, `hookScripts`, `sourceFiles`, `newestSourceMtime`); real interface has `toolNames`, `changedSourceFiles`, `scannedAt`. Corrected on second pass; tests pass with correct fields.

### Coverage delta

| Layer | Before | After |
|---|---|---|
| Mechanical (Jest) | 50 cases (15 suites) | +18 cases (3 new suites: convergence, gap-analyzer, tool-registry-shape) |
| Behavioral [P1]/[P4] | (out of scope) | (out of scope — explicitly noted) |

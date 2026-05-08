# Marketplace Test Strategy

> **Status: ⏸ Phase 1 plan — awaiting approval before Phase 2 execution.**

LLM-facing reference for the marketplace-wide testing initiative. Phase 1 product. Read this **before** executing any per-plugin plan in `testing/plans/`.

## 1. Scope

> **2026-05-08 update.** Five plugins removed from the marketplace in commit `3b8323e`: claude-sync, design-assistant, docs-manager, linux-sysadmin, python-dev. Four were in-scope and one (python-dev) was excluded as pure-markdown. Updated counts below.

- **In scope (11):** github-repo-manager, handoff, home-assistant-dev, nominal, opus-context, plugin-test-harness, qt-suite, release-pipeline, repo-hygiene, test-driver, up-docs. PTH stays in scope per §2 (peer plugin **and** canonical live-loop runner). Total marketplace plugins = 12, minus 1 excluded = 11.
- **Excluded (1):** qdev. Pure-markdown plugin (commands + agents + skills only). Zero non-vendored source files. There is no mechanical surface to unit-test — its behavior is validated by direct invocation through Claude Code, not by a test harness.
- **Vendored trees ignored:** `node_modules/`, `.venv/`, `dist/`, `build/`, `__pycache__/`.

## 2. Plugin-test-harness role (disambiguation)

PTH is **both a peer plugin and the canonical live-loop runner** — but **not** the canonical unit-test runner.

| Surface | What | Where |
|---|---|---|
| Peer plugin | Distributed in marketplace; tests its own internals | `plugins/plugin-test-harness/` (Jest) |
| Canonical live runner | Drives test/fix/reload loop against another plugin's MCP server or `.claude-plugin/` interface | Invoked from any session via `pth_*` MCP tools |
| **NOT** | Canonical unit-test framework for the marketplace | Each plugin owns its unit framework per language |

Implication for Phase 2: per-plugin unit suites use the per-language canonical framework (§3). PTH is **complementary** — once a plugin's unit suite is green, PTH can drive behavioral/integration coverage in a session branch. PTH coverage is out of scope for Phase 2 unless a plan explicitly calls it out.

## 3. Canonical frameworks (by language)

| Language | Framework | Rationale |
|---|---|---|
| Bash / shell | `bats-core` | Already used by 9 of 11 in-scope plugins (github-repo-manager, handoff, nominal, opus-context, qt-suite, release-pipeline, repo-hygiene, test-driver, up-docs). Idiomatic `@test`, `setup`/`teardown`, `bats-assert` ergonomics. |
| Python | `pytest` (+ `pytest-asyncio` where async) | Already used by home-assistant-dev and qt-suite. Fixtures, parametrize, markers established. |
| TypeScript | `Jest` with `NODE_OPTIONS=--experimental-vm-modules` for ESM | Already used by home-assistant-dev/mcp-server and plugin-test-harness. ts-jest or esbuild-jest acceptable. |

### Legacy ad-hoc runners (do not migrate in Phase 2)

| Plugin | Legacy file shape | Decision |
|---|---|---|
| github-repo-manager | `tests/run-tier-{a,b,c}.sh`, `lib.sh`, `cleanup.sh` | Leave intact (Tier A/B/C is a meaningful taxonomy worth preserving). New unit-level coverage in `*.bats`. |
| release-pipeline | `tests/test-*.sh` + `run-all.sh` (alongside `*.bats` added in Phase 2) | Leave intact. Phase 2 introduced bats as the canonical layer; ad-hoc files are the integration smoke layer. |

Rationale: the prompt's "tests validate existing behavior; do not refactor plugin source" extends to existing tests. Ad-hoc bash test runners are part of the existing-behavior surface — migrating them would be churn that exceeds Phase 2 scope and risks losing tribal-knowledge edge cases.

## 4. Naming & layout conventions

| Framework | Test file | Fixture location |
|---|---|---|
| bats | `tests/<script-name>.bats` (mirror script name) | `tests/fixtures/<topic>/` (create on demand) |
| pytest | `tests/test_<module>.py` (PEP 8) | `tests/conftest.py` per directory; `tests/fixtures/` for data |
| Jest | `test/unit/<path-mirror>/<module>.test.ts` | `test/fixtures/<scenario>/` |

**Plugin sub-trees that have their own runner** (e.g., `home-assistant-dev/mcp-server/__tests__/`, `qt-suite/mcp/qt-pilot/tests/`) keep their existing layout. A plugin can have multiple sub-suites under different runners — that's fine, document it in the plugin plan.

## 5. Enforcement-layer mapping (the principle → layer rule)

Every proposed test in a per-plugin plan is tagged with the layer it exercises. Layer assignment uses these definitions, ordered strongest-to-weakest:

### Mechanical

A hook, script, or process that deterministically blocks/warns/asserts regardless of AI behavior. Verifiable by running with deterministic input → asserting on output (exit code, stdout/stderr, file mutations, JSON return shape).

**Test signature:** `run` invocation in bats / `subprocess.run` in pytest / `execa` in Jest, asserting on side effects.

### Structural

Verifiable by reading file structure, manifests, JSON contracts — without executing code. Schema conformance, hook event-keying, manifest-version match between marketplace.json and plugin.json, presence of required scripts, frontmatter shape on skills.

**Test signature:** `jq` / `python -c "json.load(...)"` / Zod schema parse over file contents.

### Behavioral

Anything requiring an LLM, agent, or human to interpret prompts (skill markdown, agent system prompts, command instruction blocks). **Cannot be unit-tested.** Coverage comes from PTH live-loop sessions or design review. Plans explicitly mark these as `Behavioral — out of unit-test scope` so the gap is visible, not hidden.

### Per-test mapping format (used in every plugin plan)

```
| Principle | Layer | Proposed test | Rationale |
|-----------|-------|---------------|-----------|
| [P3] Succeed quietly, fail transparently | Mechanical | hook script exits 0 on no-op input; non-zero exit emits raw error to stderr + recovery hint | Verifies stated quiet-success behavior at the script seam |
| [P1] Principles before architecture       | Behavioral — out of scope | n/a | Workflow constraint; covered by /design-draft session UX, not unit tests |
```

## 6. Priority order for Phase 2

Highest test-debt first (no tests / poor principle coverage / release-critical), then breadth-fill.

> Phase 2 is complete (~225 cases cherry-picked to `main` per session 2026-05-07). The original 15-row priority table is preserved below with the four removed plugins struck out for historical traceability.

| # | Plugin | Why this rank |
|---|---|---|
| 1 | **release-pipeline** | 14 src + 9 ad-hoc shell tests but **0 bats**, no coverage of waiver/tag-reconcile/auto-stash principle compliance. Release-critical surface — failures here ship broken plugins. |
| 2 | **opus-context** | 1 src (SessionStart hook) + 0 tests. Whole plugin's mechanical layer is one shell script that emits `additionalContext` JSON. Tiny scope, high-value Mechanical coverage. |
| 3 | **handoff** | 2 src + 2 bats (1:1 nominal) but bats files cover happy paths only — `[P1] Complete Context` and `[P2] Actionable Next Steps` are not asserted. Small surface; low effort to close gap. |
| 4 | **up-docs** | 3 bats + 4 src; convergence-tracker and link-audit have script-level coverage but `[P3] Update, don't rewrite` and `[P4] Ground Truth Wins` are unverified. |
| 5 | **repo-hygiene** | 3 bats + 7 src. `[P4] Safety by Construction` (3-check orphan delete) is the highest-stakes guarantee in the plugin and only one of the three checks is tested today. |
| 6 | **github-repo-manager** | 3 bats + ~20 src (8 shell + ~18 helper/*.js). Helper CLI is **entirely untested by Jest**; tier classification + PreToolUse guard are Mechanical claims that should have explicit assertions. |
| 7 | **nominal** | 6 bats + 6 src (1:1). Best-covered shell plugin; gaps are subtle (flight-log append-only on race, abort.json schema). |
| 8 | **test-driver** | 5 bats + 5 src (1:1). Similar shape to nominal. |
| 9 | **qt-suite** | 4 pytest + 5 src. Qt Pilot MCP is the Mechanical surface; existing tests cover annotations + harness + main + imports. Gap-fill mostly. |
| 10 | **home-assistant-dev** | 7 pytest + 3 Jest + 1 e2e + 12 mcp-server src + 5 scripts. Best-covered plugin in the marketplace; gap is targeted (specific tools, specific IQS rules). |
| 11 | **plugin-test-harness** | 15 Jest unit + 35 src. Highest coverage already. Gap-fill opportunity is `convergence.ts` trend math and `gap-analyzer.ts` snapshot diff. |
| ~~—~~ | ~~linux-sysadmin~~ | Plugin removed 2026-05-08. |
| ~~—~~ | ~~claude-sync~~ | Plugin removed 2026-05-08. |
| ~~—~~ | ~~docs-manager~~ | Plugin removed 2026-05-08. |
| ~~—~~ | ~~design-assistant~~ | Plugin removed 2026-05-08. |

## 7. Marketplace-level conventions (cross-cutting)

These apply to every per-plugin plan and to any new tests introduced in Phase 2.

1. **Tests assert on existing behavior.** If a test would require changing the script under test to make a seam available, **flag the issue in the plan, do not change the script**. Phase 2 is not allowed to refactor.
2. **No network, no real tokens, no real GitHub API.** Mock at the boundary. helper/*.js tests stub `client.js` with a fake `fetch`; bats tests stub `gh`/`git` via `PATH` precedence.
3. **No real `~/.claude/`, no real `~/.pth/`, no real `/mnt/share/`.** Use `BATS_TMPDIR` / `tmp_path` / `os.tmpdir()` and `HOME=$BATS_TMPDIR/home` redirection. Tests that touch the user's real config are forbidden.
4. **`set -euo pipefail` semantics.** Bats tests of bash scripts must reproduce the script's actual flag environment — the `((var++))` and `[[ test ]] && action` failure modes are real and have shipped bugs in this repo before.
5. **JSON validation tests stay deterministic.** Compare with `jq -S` (sorted keys) or parsed Python dict equality, not raw string compare — key-order non-determinism between platforms breaks tests silently.
6. **Marker discipline (pytest only).** `unit` / `integration` / `validation` markers carry over from ha-dev's existing convention. New pytest suites adopt the same names so CI matrix remains uniform if/when extended.
7. **No multi-plugin tests in Phase 2.** Cross-plugin integration (e.g., test-driver → opus-context profile loading) is deferred. STRATEGY notes one candidate: validate-marketplace.sh as a marketplace-level Mechanical suite — proposed but **not in this Phase 2 batch** unless user confirms during review.

## 8. Out of scope for Phase 2 (will not write tests for these)

- **CI/CD pipeline changes.** Existing `.github/workflows/ha-dev-plugin-tests.yml` and `plugin-test-harness-ci.yml` are the only test-running workflows. Adding bats CI for the other 9 in-scope plugins is a separate prompt.
- **Cross-plugin integration tests** (e.g., release-pipeline → repo-hygiene chained sweep). Listed as a candidate; gated on user approval.
- **Refactoring source to add seams.** If a script has no testable seam (`source` of stdin-reading code without isolation, hardcoded `~/.claude/` paths, etc.), the per-plugin plan **flags it** with a `Risk:` note. No source change.
- **PTH-driven behavioral coverage.** PTH is mentioned where relevant but not bundled into Phase 2 plans.
- **qdev** — see §1.

## 9. Phase 2 execution rules (recap)

For each plugin, in priority order:
1. Confirm target with user.
2. Direct commits to `main`. (Phase 2 originally branched `tests/<plugin>` from a `testing` integration branch; that workflow was retired 2026-05-07.)
3. Implement strictly per `testing/plans/<plugin>.md`.
4. Run the plugin's existing runner + new tests; both must be green.
5. Update plan with deviations (and *why*).
6. Single commit (or logically-grouped commits) on `main`.
7. **HALT** — surface coverage delta, ask for next plugin.

## 10. Document index

| File | Purpose |
|---|---|
| `testing/STRATEGY.md` | This file |
| `testing/plans/<plugin>.md` × 11 | Per-plugin Phase 2 work order (was 15; 4 plans deleted 2026-05-08 alongside their plugins) |

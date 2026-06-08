# up-docs — Orchestration Efficiency & Completeness Improvements (Design)

**Date:** 2026-06-07 **Status:** Reviewed — Codex `spec-review` converged in 4 rounds (round-4 verdict: _No significant findings remain_); ready for `writing-plans` **Target version:** up-docs `0.10.1` → `0.11.0` **Topic owner:** documentation-propagation plugin (`plugins/up-docs/`)

## 1. Context & problem

The first `/up-docs:all` run after the 0.10.0 llm-wiki rewrite executed all six skill steps faithfully and produced factually accurate output (claims independently verified: state.md byte count exact, VS Code-fix host attribution correct, drift audit's zero findings legitimate). But it exposed a **cost-to-outcome** problem and one **design gap**:

- **~188k subagent tokens + 103 tool calls → 4 file edits** for a small patch session (no infrastructure changes). _These per-run figures are this session's live subagent telemetry, not committed artifacts; they motivate the work but are not acceptance criteria (see §6)._
- **Drift auditor: 39 tool calls → 0 findings.** Its multi-pass convergence loop re-scanned the full surface each pass even though narrowing-on-re-pass is specified (prose-only) in `convergence-tracking.md` and never enforced.
- **Notion propagator: 7 tool calls to conclude "no page exists"** — paid every run.
- **Step 6 leaves dirty trees** across **two** repos (project + `~/projects/llm-wiki`) and relies on a separate user prompt to land them.

## 2. Locked decisions

From brainstorming + Codex rounds 1–2 corrections (2026-06-07):

| # | Decision | Choice |
| --- | --- | --- |
| D1 | Risk posture | **Balanced.** Skip a propagator only when zero items route to its layer, logged loudly. Auditor: pass 1 full; pass N+1 narrows to prior-pass touched pages + one-hop dependents. Never silently drops a check. |
| D2 | Step 6 commit behavior | **Offer → commit on approval → no push.** Skip silently if clean. |
| D3 | Version bump | **Minor: `0.11.0`.** |
| D4 | Spec/plan location | `docs/plans/`. |
| D5 | Review gate | `writing-plans` → Codex review to convergence before implementation. |
| D6 | A1 narrowing data source _(SA-001)_ | **New per-iteration `touched_pages` path list** in the tracker. Existing numeric `pages_touched` becomes `len(touched_pages)`. |
| **D7** | A2 cross-propagator dedup _(SA-003, SA-NEW-001)_ | **Dropped.** After SA-003 forced touched pages to stay fully scanned, a signature-dedup of _reports_ required a new collision-resistant finding-key contract (`discrepancy_type` exists in no schema and is too coarse) for near-zero benefit. The existing page-level report-dedup (`audit-drift.md:99`) is **kept unchanged**. Scan reduction comes solely from A1. |
| **D8** | Commit-safety source _(SA-002, SA-NEW-002, SA-NEW-004)_ | **Git surfaces candidates; the human's per-path diff review authorizes them.** Per repo, `candidates = (porcelain now) − (pre-propagation baseline-dirty)` = paths **changed since baseline** (NOT asserted to be run-owned — a post-baseline edit by a hook/editor/other process is possible). Safety = per-path **diff disclosure + explicit approval** + a **late re-check immediately before staging** + literal-pathspec staging. No propagator schema change. |
| D9 | `Skipped` representation _(SA-004)_ | Orchestrator combined-report line only; agent action enum (`validate_output.py`) untouched. |
| D10 | Non-interactive contexts | Headless `-p` (no `AskUserQuestion`) → commit step reports dirty trees, commits nothing. |
| **D11** | Fast-path routing _(SA-NEW-003)_ | **Explicit routing matrix** in `/up-docs:all`, synchronized with the agent layer-boundaries; ambiguous items route to **all** candidate layers (fail-open); covered by routing fixtures. |

## 3. Design

Three independent changes (A/B/C), each implementable and testable on its own.

### A. Auditor narrowing (path-aware, both paths) [D6]

Add a per-iteration **path contract** to `scripts/convergence-tracker.sh`: `record-iteration` accepts a `touched_pages` array (repo-relative / wiki page paths) in its findings JSON and stores it on that iteration's history entry; the legacy numeric `pages_touched` is redefined as `len(touched_pages)` (count semantics survive). The auditor's per-phase loop becomes:

- **Pass 1**: full scan of the phase surface (unchanged).
- **Pass N+1**: scan only the union of (i) the **immediately prior pass's** `touched_pages` and (ii) pages whose frontmatter `related` references a page in that set (one-hop dependents). Other pages are presumed stable for this phase.

Keyed off the auditor's own per-pass findings, so identical in `/all` and standalone `/up-docs:drift`. `convergence-tracking.md` defers to this auditor task step (single source of truth). **A2 from earlier drafts is removed (D7);** the existing report-dedup is unchanged.

**Files:** `agents/up-docs-audit-drift.md` (per-phase loop step), `scripts/convergence-tracker.sh` (+ schema), `skills/drift/references/convergence-tracking.md`, `tests/convergence-tracker.bats`.

### B. Fast-path empty-layer skip [D1, D9, D11]

Extend `skills/all/SKILL.md` Step 2 to **tag each summary item with target layer(s)** using a new **routing matrix** added to the skill (D11) — explicit per-layer rules kept in sync with the three agents' layer-boundary sections (`propagate-repo.md`, `propagate-wiki.md`, `propagate-notion.md`), with worked examples for repo-only / wiki-only / Notion-only / multi-layer / ambiguous items. **Fail-open:** an ambiguous item routes to _all_ candidate layers; a layer is skipped only with provably zero routed items. In Step 3, dispatch only propagators with ≥1 routed item.

The auditor still audits all three layers regardless of which propagators ran — skipping a _propagation_ never skips the _audit_ of that layer. A skipped layer renders **only** as an orchestrator combined-report line, e.g. `Notion — skipped (0 items routed to this layer)`; not a table action row, not validated by `validate_output.py` (which governs agent JSON, not the combined markdown). The four-value action enum is untouched [D9].

**Files:** `skills/all/SKILL.md` (Steps 2–3 + routing matrix), `templates/summary-report.md` (document the presentation-only skipped-layer line), routing fixtures under `tests/`.

### C. Step 6 commit offer — consent-gated, baseline-safe, no push [D2, D8, D10]

Add **part (c)** to the "Handoff for Next Session" section of `templates/post-propagation-steps.md`.

**Baseline (new, captured BEFORE propagation — [D8]):** snapshot `git status --porcelain=v1 -z` (NUL-delimited, robust to spaces/special chars) for every repo the run may commit — the active project repo (both `/up-docs:all` and `/up-docs:repo` guard it clean at their Step 0, so its baseline is normally empty) and `~/projects/llm-wiki` (no Step 0 guard — the real baseline need), captured immediately before the wiki propagator is dispatched. Persist each repo's baseline-dirty path set.

**Candidate set ([D8]):** after propagation, for each repo compute `candidates = (paths dirty now) − (baseline-dirty paths)` = paths **changed since baseline**. This is the _candidate surface_, **not** a proof of run-ownership: a hook, editor, or other process could have dirtied a clean-baseline path in the window between baseline and commit (SA-NEW-004). Ownership is established by the human's diff review below, not by git. Notion writes nothing to a filesystem, so it never contributes candidates.

**Offer (per-path, diff-disclosed):** if any repo has a non-empty `candidates` set, **show the per-path diff** (the combined report lists each candidate path with its `git diff` summary) so the user can see exactly what would be staged, then present **one** `AskUserQuestion` (`multiSelect` over candidate paths/repos). On approval:

1. **Late re-check:** immediately before staging, re-run `--porcelain=v1 -z`. If any approved path's status changed since the offer, or unexpected new paths appeared, re-disclose and re-confirm rather than staging blindly.
2. Stage only the approved paths with literal pathspecs (`git add -- <path>`, NUL-safe).
3. Commit under that repo's convention (project repo: signed `docs(handoff): …`; `~/projects/llm-wiki`: its draft-contract message, page stays `status: draft`).
4. **Never push.** Report SHAs and that nothing was pushed.

**Excluded paths:** baseline-dirty paths (including a same-path collision where a baseline- dirty file is also changed this run) are **excluded** from the candidate set and **disclosed separately** as "pre-existing local changes in `<repo>` — left for you to handle manually."

**Non-interactive ([D10]):** if `AskUserQuestion` cannot be answered (headless `-p`), skip the commit and report dirty trees. No consent → no commit.

**Files:** `templates/post-propagation-steps.md` (part (c) + baseline), `skills/all/SKILL.md`

- `skills/repo/SKILL.md` (baseline capture + Step 6 reference).

## 4. Non-goals

- No change to the propagators' output schema, layer-boundary logic, or the auditor's verification discipline. (D8 explicitly avoids `written_paths`/`fixed_findings` schema work.)
- No auto-push ever [D2]; no auto-commit without consent [D10].
- No whole-touched-page scan-skipping and no cross-propagator report-dedup [D7]; the auditor audits every page, including freshly-updated ones.
- No change to standalone `/up-docs:drift` completeness: A1 narrowing affects only re-passes, never first-pass coverage.

## 5. Risks & mitigations

| Risk | Mitigation |
| --- | --- |
| A1 narrowing misses drift on a page not touched in the prior pass | Pass 1 always full; one-hop `related` dependents included; oscillation detection (existing) still applies. |
| Commit step stages unrelated work changed _after_ baseline (SA-NEW-004) | Candidates are "changed since baseline", not asserted run-owned; per-path diff disclosure + explicit approval + late re-check immediately before staging is the ownership guard; baseline-dirty (incl. same-path collisions) excluded + disclosed [D8]. |
| Fast-path wrongly skips a layer with real work | Routing matrix synced with agent boundaries; ambiguous → all layers (fail-open); audit still covers all three [D11]. |
| `Skipped` enum churn | Presentation-only; agent enum untouched [D9]. |
| Headless run mis-commits | Non-interactive → report-only [D10]. |

## 6. Test & rollout

Each change gets **prompt-conformance assertions AND ≥1 behavioral check** (SA-006):

- **A1:** `convergence-tracker.bats` asserts `touched_pages` **paths** round-trip across `record-iteration`/`status` (not a count); behavioral fixture proving a pass-2 candidate set ⊂ pass-1 surface for a given prior-pass `touched_pages`.
- **B:** routing fixtures for repo-only / wiki-only / Notion-only / multi-layer / ambiguous items (ambiguous ⇒ all candidate layers); a transcript/disposable-smoke check that a repo-only routed summary dispatches **no** wiki/Notion Agent call while the audit still covers all three layers.
- **C:** commit-safety scenarios — clean baseline; baseline-dirty _different_ path; baseline-dirty _same_ path (collision); **unrelated path dirtied _after_ baseline but before the offer** (must be excluded or require explicit per-path approval — SA-NEW-004); paths with spaces/special chars; deleted and untracked files; headless `-p` (commits nothing). Approving a commit must never silently include a non-approved or baseline-dirty change.

**Rollout:**

- Keep the `docs/handoff/specs-plans.md` row (added this round) status-current on spec convergence and plan creation (SA-005).
- After implementation: `bash plugins/up-docs/tests/run-bats.sh …`, `cd plugins/up-docs/tests && .venv/bin/python -m pytest -v`, `./scripts/validate-marketplace.sh`.
- Bump `plugin.json` + `marketplace.json` to `0.11.0`; CHANGELOG `[0.11.0]`. Release via `/release-pipeline:release` (scoped tag `up-docs/v0.11.0`). Release note: a marketplace **cache refresh** is required for the new behavior to take effect.

## 7. Resolved questions

All Codex round-1/2 ambiguities are resolved in §2: `touched_pages` is a per-iteration path list [D6]; the A2 signature-dedup is **dropped** rather than under-specified [D7]; commit safety derives from git baseline diff, not an agent `written_paths` contract [D8]; `Skipped` is presentation-only [D9]; headless never commits [D10]; fast-path routing uses an explicit matrix synced to agent boundaries [D11].

## 8. Codex review ledger

| Round | Verdict | Findings | Resolution |
| --- | --- | --- | --- |
| 1 (`…-203332-…round1.md`) | Needs major correction | SA-001/002/003 (High); SA-004/005/006 (Med) | SA-001→D6/§3A; SA-002→D8/§3C; SA-003→D7; SA-004→D9/§3B; SA-005→indexed §6; SA-006→§6 behavioral tests |
| 2 (`…-204348-…round2.md`) | Needs major correction | SA-001..006 **resolved**; new SA-NEW-001/002 (High), SA-NEW-003 (Med) | SA-NEW-001 (coarse finding-key) → **A2 dropped** [D7]; SA-NEW-002 (`written_paths` schema gap) → **commit-safety via git baseline diff** [D8], no schema change; SA-NEW-003 (under-specified routing) → **routing matrix + fixtures** [D11] |
| 3 (`…-205347-…round3.md`) | Needs major correction | SA-001..006 + SA-NEW-001..003 **resolved**; new SA-NEW-004 (High), SA-NEW-005 (Med) | SA-NEW-004 (git diff ≠ run-ownership) → **D8 downgraded: candidates are "changed since baseline"; per-path diff approval + late re-check is the ownership guard**; SA-NEW-005 (stale index row) → specs-plans.md row updated; also corrected stale `/up-docs:repo`-has-no-guard claim |
| 4 (`…-210253-…round4.md`) | **No significant findings remain** | SA-NEW-004/005 **resolved**; 0 new, 0 regressions | **Converged.** Ready for `writing-plans`. |

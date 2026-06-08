# up-docs — Orchestration Efficiency & Completeness Improvements (Design)

**Date:** 2026-06-07
**Status:** Draft — Codex `spec-review` rounds 1–2 applied (6 + 3 findings); re-audit pending
**Target version:** up-docs `0.10.1` → `0.11.0`
**Topic owner:** documentation-propagation plugin (`plugins/up-docs/`)

## 1. Context & problem

The first `/up-docs:all` run after the 0.10.0 llm-wiki rewrite executed all six skill
steps faithfully and produced factually accurate output (claims independently verified:
state.md byte count exact, VS Code-fix host attribution correct, drift audit's zero
findings legitimate). But it exposed a **cost-to-outcome** problem and one **design gap**:

- **~188k subagent tokens + 103 tool calls → 4 file edits** for a small patch session
  (no infrastructure changes). _These per-run figures are this session's live subagent
  telemetry, not committed artifacts; they motivate the work but are not acceptance
  criteria (see §6)._
- **Drift auditor: 39 tool calls → 0 findings.** Its multi-pass convergence loop re-scanned
  the full surface each pass even though narrowing-on-re-pass is specified (prose-only) in
  `convergence-tracking.md` and never enforced.
- **Notion propagator: 7 tool calls to conclude "no page exists"** — paid every run.
- **Step 6 leaves dirty trees** across **two** repos (project + `~/projects/llm-wiki`) and
  relies on a separate user prompt to land them.

## 2. Locked decisions

From brainstorming + Codex rounds 1–2 corrections (2026-06-07):

| # | Decision | Choice |
| --- | --- | --- |
| D1 | Risk posture | **Balanced.** Skip a propagator only when zero items route to its layer, logged loudly. Auditor: pass 1 full; pass N+1 narrows to prior-pass touched pages + one-hop dependents. Never silently drops a check. |
| D2 | Step 6 commit behavior | **Offer → commit on approval → no push.** Skip silently if clean. |
| D3 | Version bump | **Minor: `0.11.0`.** |
| D4 | Spec/plan location | `docs/plans/`. |
| D5 | Review gate | `writing-plans` → Codex review to convergence before implementation. |
| D6 | A1 narrowing data source *(SA-001)* | **New per-iteration `touched_pages` path list** in the tracker. Existing numeric `pages_touched` becomes `len(touched_pages)`. |
| **D7** | A2 cross-propagator dedup *(SA-003, SA-NEW-001)* | **Dropped.** After SA-003 forced touched pages to stay fully scanned, a signature-dedup of *reports* required a new collision-resistant finding-key contract (`discrepancy_type` exists in no schema and is too coarse) for near-zero benefit. The existing page-level report-dedup (`audit-drift.md:99`) is **kept unchanged**. Scan reduction comes solely from A1. |
| **D8** | Commit-safety source *(SA-002, SA-NEW-002)* | **Git ground truth, not agent self-report.** The committable set is derived per repo as `(porcelain now) − (pre-propagation baseline-dirty paths)`. No `written_paths`/`fixed_findings` schema change; propagator output schema untouched. |
| D9 | `Skipped` representation *(SA-004)* | Orchestrator combined-report line only; agent action enum (`validate_output.py`) untouched. |
| D10 | Non-interactive contexts | Headless `-p` (no `AskUserQuestion`) → commit step reports dirty trees, commits nothing. |
| **D11** | Fast-path routing *(SA-NEW-003)* | **Explicit routing matrix** in `/up-docs:all`, synchronized with the agent layer-boundaries; ambiguous items route to **all** candidate layers (fail-open); covered by routing fixtures. |

## 3. Design

Three independent changes (A/B/C), each implementable and testable on its own.

### A. Auditor narrowing (path-aware, both paths) [D6]

Add a per-iteration **path contract** to `scripts/convergence-tracker.sh`: `record-iteration`
accepts a `touched_pages` array (repo-relative / wiki page paths) in its findings JSON and
stores it on that iteration's history entry; the legacy numeric `pages_touched` is redefined
as `len(touched_pages)` (count semantics survive). The auditor's per-phase loop becomes:

- **Pass 1**: full scan of the phase surface (unchanged).
- **Pass N+1**: scan only the union of (i) the **immediately prior pass's** `touched_pages`
  and (ii) pages whose frontmatter `related` references a page in that set (one-hop
  dependents). Other pages are presumed stable for this phase.

Keyed off the auditor's own per-pass findings, so identical in `/all` and standalone
`/up-docs:drift`. `convergence-tracking.md` defers to this auditor task step (single source
of truth). **A2 from earlier drafts is removed (D7);** the existing report-dedup is unchanged.

**Files:** `agents/up-docs-audit-drift.md` (per-phase loop step), `scripts/convergence-tracker.sh`
(+ schema), `skills/drift/references/convergence-tracking.md`, `tests/convergence-tracker.bats`.

### B. Fast-path empty-layer skip [D1, D9, D11]

Extend `skills/all/SKILL.md` Step 2 to **tag each summary item with target layer(s)** using a
new **routing matrix** added to the skill (D11) — explicit per-layer rules kept in sync with
the three agents' layer-boundary sections (`propagate-repo.md`, `propagate-wiki.md`,
`propagate-notion.md`), with worked examples for repo-only / wiki-only / Notion-only /
multi-layer / ambiguous items. **Fail-open:** an ambiguous item routes to *all* candidate
layers; a layer is skipped only with provably zero routed items. In Step 3, dispatch only
propagators with ≥1 routed item.

The auditor still audits all three layers regardless of which propagators ran — skipping a
*propagation* never skips the *audit* of that layer. A skipped layer renders **only** as an
orchestrator combined-report line, e.g. `Notion — skipped (0 items routed to this layer)`;
not a table action row, not validated by `validate_output.py` (which governs agent JSON, not
the combined markdown). The four-value action enum is untouched [D9].

**Files:** `skills/all/SKILL.md` (Steps 2–3 + routing matrix), `templates/summary-report.md`
(document the presentation-only skipped-layer line), routing fixtures under `tests/`.

### C. Step 6 commit offer — consent-gated, baseline-safe, no push [D2, D8, D10]

Add **part (c)** to the "Handoff for Next Session" section of `templates/post-propagation-steps.md`.

**Baseline (new, captured BEFORE propagation — [D8]):** snapshot `git status --porcelain`
for every repo the run may commit — the active project repo (already clean at `/up-docs:all`
Step 0, but `/up-docs:repo` has no such guard) and `~/projects/llm-wiki` (if the wiki layer
is in scope), captured immediately before the wiki propagator is dispatched. Persist each
repo's baseline-dirty path set.

**Committable set (git ground truth, [D8]):** after propagation, for each repo compute
`candidates = (paths dirty now) − (baseline-dirty paths)`. These are exactly the paths
**clean at baseline and written by this run** — no dependence on agent self-report. Notion
writes nothing to a filesystem, so it never contributes candidates (no special-casing).

**Offer:** if any repo has a non-empty `candidates` set, present **one** `AskUserQuestion`
(`multiSelect` across the dirty repos). On approval, per selected repo: stage only
`candidates` by explicit name (`git add -- <path>`; safe because each was clean at baseline,
so all current hunks are this run's), commit under that repo's convention (project repo:
signed `docs(handoff): …`; `~/projects/llm-wiki`: its draft-contract message, page stays
`status: draft`), and **never push**. Report SHAs and that nothing was pushed.

**Excluded paths:** baseline-dirty paths (including a same-path collision where a baseline-
dirty file is also written this run) are **excluded** from staging and **disclosed
separately** as "pre-existing local changes in `<repo>` — left for you to handle manually."

**Non-interactive ([D10]):** if `AskUserQuestion` cannot be answered (headless `-p`), skip
the commit and report dirty trees. No consent → no commit.

**Files:** `templates/post-propagation-steps.md` (part (c) + baseline), `skills/all/SKILL.md`
+ `skills/repo/SKILL.md` (baseline capture + Step 6 reference).

## 4. Non-goals

- No change to the propagators' output schema, layer-boundary logic, or the auditor's
  verification discipline. (D8 explicitly avoids `written_paths`/`fixed_findings` schema work.)
- No auto-push ever [D2]; no auto-commit without consent [D10].
- No whole-touched-page scan-skipping and no cross-propagator report-dedup [D7]; the auditor
  audits every page, including freshly-updated ones.
- No change to standalone `/up-docs:drift` completeness: A1 narrowing affects only re-passes,
  never first-pass coverage.

## 5. Risks & mitigations

| Risk | Mitigation |
| --- | --- |
| A1 narrowing misses drift on a page not touched in the prior pass | Pass 1 always full; one-hop `related` dependents included; oscillation detection (existing) still applies. |
| Commit step stages pre-existing work | Committable set = dirty-now − baseline-dirty (git ground truth); baseline-dirty (incl. same-path collisions) excluded + disclosed [D8]. |
| Fast-path wrongly skips a layer with real work | Routing matrix synced with agent boundaries; ambiguous → all layers (fail-open); audit still covers all three [D11]. |
| `Skipped` enum churn | Presentation-only; agent enum untouched [D9]. |
| Headless run mis-commits | Non-interactive → report-only [D10]. |

## 6. Test & rollout

Each change gets **prompt-conformance assertions AND ≥1 behavioral check** (SA-006):

- **A1:** `convergence-tracker.bats` asserts `touched_pages` **paths** round-trip across
  `record-iteration`/`status` (not a count); behavioral fixture proving a pass-2 candidate
  set ⊂ pass-1 surface for a given prior-pass `touched_pages`.
- **B:** routing fixtures for repo-only / wiki-only / Notion-only / multi-layer / ambiguous
  items (ambiguous ⇒ all candidate layers); a transcript/disposable-smoke check that a
  repo-only routed summary dispatches **no** wiki/Notion Agent call while the audit still
  covers all three layers.
- **C:** dirty-baseline scenarios — clean baseline; baseline-dirty *different* path;
  baseline-dirty *same* path (collision); headless `-p` (commits nothing). Approving a commit
  must never include a baseline-dirty change.

**Rollout:**
- Keep the `docs/handoff/specs-plans.md` row (added this round) status-current on spec
  convergence and plan creation (SA-005).
- After implementation: `bash plugins/up-docs/tests/run-bats.sh …`,
  `cd plugins/up-docs/tests && .venv/bin/python -m pytest -v`, `./scripts/validate-marketplace.sh`.
- Bump `plugin.json` + `marketplace.json` to `0.11.0`; CHANGELOG `[0.11.0]`. Release via
  `/release-pipeline:release` (scoped tag `up-docs/v0.11.0`). Release note: a marketplace
  **cache refresh** is required for the new behavior to take effect.

## 7. Resolved questions

All Codex round-1/2 ambiguities are resolved in §2: `touched_pages` is a per-iteration path
list [D6]; the A2 signature-dedup is **dropped** rather than under-specified [D7]; commit
safety derives from git baseline diff, not an agent `written_paths` contract [D8]; `Skipped`
is presentation-only [D9]; headless never commits [D10]; fast-path routing uses an explicit
matrix synced to agent boundaries [D11].

## 8. Codex review ledger

| Round | Verdict | Findings | Resolution |
| --- | --- | --- | --- |
| 1 (`…-203332-…round1.md`) | Needs major correction | SA-001/002/003 (High); SA-004/005/006 (Med) | SA-001→D6/§3A; SA-002→D8/§3C; SA-003→D7; SA-004→D9/§3B; SA-005→indexed §6; SA-006→§6 behavioral tests |
| 2 (`…-204348-…round2.md`) | Needs major correction | SA-001..006 **resolved**; new SA-NEW-001/002 (High), SA-NEW-003 (Med) | SA-NEW-001 (coarse finding-key) → **A2 dropped** [D7]; SA-NEW-002 (`written_paths` schema gap) → **commit-safety via git baseline diff** [D8], no schema change; SA-NEW-003 (under-specified routing) → **routing matrix + fixtures** [D11] |

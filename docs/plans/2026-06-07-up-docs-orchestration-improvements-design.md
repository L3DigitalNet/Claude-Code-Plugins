# up-docs — Orchestration Efficiency & Completeness Improvements (Design)

**Date:** 2026-06-07
**Status:** Draft — Codex `spec-review` round 1 applied (3 High + 3 Medium addressed); re-audit pending
**Target version:** up-docs `0.10.1` → `0.11.0`
**Topic owner:** documentation-propagation plugin (`plugins/up-docs/`)

## 1. Context & problem

The first `/up-docs:all` run after the 0.10.0 llm-wiki rewrite executed all six skill
steps faithfully and produced factually accurate output (claims independently verified:
state.md byte count exact, VS Code-fix host attribution correct, drift audit's zero
findings legitimate). But it exposed a **cost-to-outcome** problem and one **design gap**:

- **~188k subagent tokens + 103 tool calls → 4 file edits** for a small patch session
  (up-docs v0.10.1 + a workstation editor-config fix; no infrastructure changes). _Note: these
  per-run figures come from this session's live subagent telemetry, not committed repo
  artifacts; they motivate the work but are not themselves acceptance criteria (see §6)._
- **Drift auditor: 39 tool calls → 0 findings.** It scanned 258 wiki pages + ran the
  validator gate + Notion searches even though (a) the session touched no infrastructure
  and (b) the propagators had already reported what they changed. Live confirmation of two
  findings from the 2026-06-07 efficiency review:
  - **narrowing-on-re-pass is prose-only** in `convergence-tracking.md` and never enforced;
  - the auditor's already-fixed **dedup runs after the expensive scan**, not before.
- **Notion propagator: 7 tool calls to conclude "no page exists"** — paid every run.
- **Step 6 leaves dirty trees.** `post-propagation-steps.md` is read-only by contract, so
  `/up-docs:all` ends with uncommitted writes across **two** repos (the project repo and
  `~/projects/llm-wiki`) and relies on a separate user prompt to land them.

## 2. Locked decisions

From brainstorming Q&A + Codex round-1 corrections (2026-06-07):

| # | Decision | Choice |
| --- | --- | --- |
| D1 | Risk posture | **Balanced.** Skip a propagator only when zero summary items route to its layer, logged loudly. Auditor: first pass always full; 2nd+ passes narrow to touched pages + one-hop dependents. Never silently drops a check. |
| D2 | Step 6 commit behavior | **Offer → commit on approval → no push.** Skip silently if clean. |
| D3 | Version bump | **Minor: `0.11.0`.** |
| D4 | Spec/plan location | `docs/plans/`. |
| D5 | Review gate | `writing-plans` → Codex adversarial review to convergence before implementation. |
| **D6** | **A1 data source** *(SA-001)* | **New machine-readable path contract.** Introduce a per-phase `touched_pages` path list in the tracker — the existing numeric `pages_touched` is a count and cannot drive narrowing. |
| **D7** | **A2 dedup granularity** *(SA-003)* | **Dedup exact finding *signatures*, never whole pages.** Touched pages remain fully eligible for validator/draft/link/contradiction checks. |
| **D8** | **Commit safety** *(SA-002)* | **Pre-propagation dirty baseline per committable repo.** Only offer to commit paths clean at baseline AND written this run; pre-existing dirty paths are excluded and disclosed separately. |
| **D9** | **`Skipped` representation** *(SA-004)* | **Not a new agent action.** Skipped layers appear only as an orchestrator-level line in the combined report; the agent-output enum (`validate_output.py`) is untouched. |
| **D10** | **Non-interactive contexts** | In `-p`/headless runs where `AskUserQuestion` cannot be answered, the commit step degrades to "report dirty trees, commit nothing." Consent is mandatory. |

## 3. Design

Three independent changes (A/B/C), each implementable and testable on its own.

### A. Auditor scoping — path-aware narrowing + signature dedup

**A1 — Convergence narrowing (BOTH paths). [D6]**
Add an explicit per-phase **path contract** to `scripts/convergence-tracker.sh`:
`record-iteration` accepts a `touched_pages` array (repo-relative paths / wiki page paths)
in its findings JSON and stores the per-phase **deduplicated union** as
`state.phases[N].touched_pages`. The legacy numeric `pages_touched` is retained but
redefined as `len(touched_pages)` (so existing count semantics survive). The auditor's
per-phase loop then becomes:

- **Pass 1**: full scan of the phase surface (unchanged).
- **Pass N+1**: scan only the union of (i) `touched_pages` from the prior pass and (ii)
  pages whose frontmatter `related` references a page in that set (one-hop dependents).

Keyed off the auditor's **own** per-pass findings, so it works identically in `/all` and
standalone `/up-docs:drift`. `convergence-tracking.md` stops being the rule's authority and
points to the auditor task step (single source of truth).

**A2 — Pre-emptive signature dedup (`/all` path only). [D7]**
Replace the current post-scan dedup with a **finding-signature** dedup that still audits
touched pages. New task step: *"If propagator reports were provided, build the set of
already-fixed finding signatures `(page, discrepancy_type)` from their `Updated`/`Created`
rows. Continue to scan and run all validator / draft-status / link / cross-page
contradiction checks on every page — including touched pages — but suppress emitting a
finding whose signature exactly matches an already-fixed one. If no reports were provided
(standalone `/up-docs:drift`), report normally."*

This deliberately does **not** skip touched pages — their independent validation is the
auditor's core value (a page a propagator just `Updated` is the most likely to carry a
fresh frontmatter/link/contradiction error). The token win here is modest (suppressed
duplicate findings, not skipped scans); the real scan reduction is A1.

**Files:** `agents/up-docs-audit-drift.md` (task steps + dedup guardrail), `scripts/convergence-tracker.sh`
(+ schema), `skills/drift/references/convergence-tracking.md` (defer to the task step),
`tests/convergence-tracker.bats` (path round-trip).

### B. Fast-path empty-layer skip [D1, D9]

In `skills/all/SKILL.md` Step 2 the orchestrator already enumerates summary items. Extend
Step 2 to **tag each item with its target layer(s)** (`repo`/`wiki`/`notion`) via the
existing Layer Boundaries table. In Step 3, **dispatch only propagators with ≥1 routed
item**. **Fail-open:** an item whose layer is ambiguous routes to *all* candidate layers; a
layer is skipped only when it provably has zero routed items. The auditor still audits all
three layers regardless of which propagators ran — skipping a *propagation* never skips the
*audit* of that layer.

A skipped layer is rendered **only** in the orchestrator's combined report as a
layer-status line, e.g. `Notion — skipped (0 items routed to this layer)`. This is **not** a
table action row and does **not** pass through `validate_output.py` (which governs each
agent's JSON output, not the orchestrator's combined markdown). The four-value action enum
is untouched. [D9]

**Files:** `skills/all/SKILL.md` (Steps 2–3), `templates/summary-report.md` (document the
orchestrator-level skipped-layer line; note it is presentation-only).

### C. Step 6 commit offer — consent-gated, baseline-safe, no push [D2, D8, D10]

Add **part (c)** to the "Handoff for Next Session" section of `templates/post-propagation-steps.md`.

**Baseline (new, runs early — [D8]):** before propagation, snapshot `git status --porcelain`
for every repo the run may commit: the active project repo (already guarded clean at Step 0
of `/up-docs:all`, but `/up-docs:repo` has no such guard) and `~/projects/llm-wiki` (if the
wiki layer is in scope). Persist the baseline dirty-path set per repo.

**Written-paths contract ([D8], resolves "propagation-written paths"):** each propagator
emits, alongside its table, a machine-readable `written_paths` list (the paths it
`Created`/`Updated`). The commit offer's candidate set = `written_paths` **minus** any path
dirty at baseline.

**Offer:** if the candidate set is non-empty, present **one** `AskUserQuestion`
(`multiSelect` across the dirty repos). On approval, per selected repo: stage only candidate
paths by explicit name (`git add -- <path>`; safe because each was clean at baseline, so all
current hunks are this run's), commit under that repo's convention (project repo: signed
`docs(handoff): …`; `~/projects/llm-wiki`: its draft-contract message, page stays
`status: draft`), and **never push**. Report SHAs and that nothing was pushed.

**Excluded paths:** any path dirty at baseline (including a baseline-dirty path the
propagator later also wrote — a same-path collision) is **excluded** from auto-staging and
**disclosed separately** as "pre-existing local changes in `<repo>` — left for you to handle
manually." Never silently fold them into the up-docs commit.

**Non-interactive ([D10]):** if `AskUserQuestion` cannot be answered (headless `-p`), skip
the commit entirely and report the dirty trees. No consent → no commit.

**Files:** `templates/post-propagation-steps.md` (part (c) + baseline), `skills/all/SKILL.md`
+ `skills/repo/SKILL.md` (Step 6 references + baseline capture), the three propagator agents
(emit `written_paths`).

## 4. Non-goals

- No change to the propagators' layer-boundary logic or the auditor's verification
  discipline (`evidence` grounding, unverifiable handling).
- No auto-push, ever [D2]. No auto-commit without consent [D10].
- No "Aggressive" auditor mode that skips the adjacent-infrastructure sweep or skips whole
  touched pages — explicitly rejected [D1, D7].
- No change to standalone `/up-docs:drift` completeness: A2 is gated to the `/all` path; A1
  narrowing affects only re-passes, never first-pass coverage.

## 5. Risks & mitigations

| Risk | Mitigation |
| --- | --- |
| A1 narrowing misses drift on a page not touched in the prior pass | First pass always full; one-hop `related` dependents included; oscillation detection (existing) still applies. |
| A2 suppresses a *real* new finding because its signature collides with a fixed one | Signature is `(page, discrepancy_type)`; validators/link/contradiction checks still run on every page, so a *different* defect on a touched page is still reported. Only exact-signature duplicates are suppressed. |
| Commit step stages pre-existing local work (SA-002) | Pre-propagation baseline per repo; candidate set excludes baseline-dirty paths; same-path collisions excluded + disclosed [D8]. |
| Fast-path wrongly skips a layer with real work | Fail-open on ambiguity; skip only on provably-zero routed items; audit still covers all three layers. |
| `Skipped` enum churn breaks `validate_output.py` | Skipped is orchestrator-presentation only, not an agent action; enum untouched [D9]. |
| Commit offer in headless run blocks or mis-fires | Non-interactive degrades to report-only, no commit [D10]. |

## 6. Test & rollout

Each change gets **prompt-conformance assertions AND at least one behavioral check** (SA-006
— grep-level conformance alone cannot prove the cost/safety outcome):

- **A1:** `convergence-tracker.bats` asserts `touched_pages` **paths** round-trip across
  `record-iteration`/`status` (not a count); an auditor assertion that pass-N+1 reads those
  paths + one-hop `related` dependents. Behavioral: a tracker-state fixture proving pass-2
  candidate set ⊂ pass-1 surface.
- **A2:** false-green regression — a propagator reports `Updated` for a wiki page that still
  has a broken `related` link or contradiction; the auditor must still report it.
- **B:** transcript/disposable-smoke check proving a repo-only routed summary dispatches
  **no** wiki/Notion Agent call while the audit still covers all three layers; a
  conformance assertion that Step 3 dispatch is conditioned on routed items + fail-open.
- **C:** negative dirty-baseline scenario — `~/projects/llm-wiki` dirty before `/up-docs:all`
  (including a same-path pre-existing edit); approving the commit must **not** include the
  pre-existing change; headless `-p` commits nothing.

**Rollout:**
- Index this design (and the future plan) in `docs/handoff/specs-plans.md` now, with status
  updates on spec convergence and plan creation (SA-005; repo convention per
  `agents/up-docs-propagate-repo.md`).
- Run after implementation: `bash plugins/up-docs/tests/run-bats.sh …`,
  `cd plugins/up-docs/tests && .venv/bin/python -m pytest -v`, `./scripts/validate-marketplace.sh`.
- Bump `plugin.json` + `marketplace.json` to `0.11.0`; CHANGELOG `[0.11.0]`. Release via
  `/release-pipeline:release` (scoped tag `up-docs/v0.11.0`). Release note: a marketplace
  **cache refresh** is required for the new behavior to take effect.

## 7. Resolved questions

All Codex round-1 ambiguities are resolved in §2 (D6–D10): `touched_pages` is a per-phase
path list [D6]; A2 dedups signatures not pages [D7]; pre-existing llm-wiki dirt is
baseline-excluded [D8]; `Skipped` is presentation-only [D9]; headless runs never commit
[D10]. `propagation-written paths` is the propagator-emitted `written_paths` artifact [§3C].

## 8. Codex review ledger

| Round | Verdict | Blocking | Resolution |
| --- | --- | --- | --- |
| 1 (`…-203332-…round1.md`) | Needs major correction | SA-001, SA-002, SA-003 (High); SA-004, SA-005, SA-006 (Med) | SA-001→D6/§3A1; SA-002→D8/§3C; SA-003→D7/§3A2; SA-004→D9/§3B; SA-005→§6 rollout; SA-006→§6 behavioral tests |

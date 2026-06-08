# up-docs — Orchestration Efficiency & Completeness Improvements (Design)

**Date:** 2026-06-07
**Status:** Draft — awaiting user review, then `writing-plans` + Codex `$spec-review` gate
**Target version:** up-docs `0.10.1` → `0.11.0`
**Topic owner:** documentation-propagation plugin (`plugins/up-docs/`)

## 1. Context & problem

The first `/up-docs:all` run after the 0.10.0 llm-wiki rewrite executed all six skill
steps faithfully and produced factually accurate output (claims independently verified:
state.md byte count exact, VS Code-fix host attribution correct, drift audit's zero
findings legitimate). But it exposed a **cost-to-outcome** problem and one **design gap**:

- **~188k subagent tokens + 103 tool calls → 4 file edits** for a small patch session
  (up-docs v0.10.1 + a workstation editor-config fix; no infrastructure changes).
- **Drift auditor: 39 tool calls → 0 findings.** It scanned 258 wiki pages + ran the
  validator gate + Notion searches even though (a) the session touched no infrastructure
  and (b) the propagators had already reported exactly what they changed. This is live
  confirmation of two findings from the 2026-06-07 efficiency review:
  - **narrowing-on-re-pass is prose-only** in `convergence-tracking.md` and never enforced;
  - the auditor's already-fixed **dedup runs after the expensive scan**, not before.
- **Notion propagator: 7 tool calls to conclude "no page exists"** — paid every run.
- **Step 6 leaves dirty trees.** `post-propagation-steps.md` is read-only by contract, so
  `/up-docs:all` ends with uncommitted writes across **two** repos (the project repo and
  `~/projects/llm-wiki`) and relies on a separate user prompt to land them. The run's
  output is not self-contained.

The framework pays near-full orchestration freight regardless of session size: a 4-file
patch session and a 40-file infra session cost roughly the same.

## 2. Locked decisions (from brainstorming Q&A, 2026-06-07)

| # | Decision | Choice |
| --- | --- | --- |
| D1 | Risk posture for cost-cutting | **Balanced.** Skip a propagator only when zero summary items route to its layer, and log the skip loudly. Auditor: first pass always full; 2nd+ convergence passes narrow to touched pages + dependents. Never silently drops a check. |
| D2 | Step 6 commit behavior | **Offer → commit on approval → no push.** One `AskUserQuestion`; on approval commit each dirty repo under its own convention. Never auto-pushes. Skip silently if clean. |
| D3 | Version bump | **Minor: `0.11.0`** (adds orchestration behavior). |
| D4 | Spec/plan location | `docs/plans/` (this repo's convention), not the superpowers default. |
| D5 | Review gate | `writing-plans` → Codex adversarial `$spec-review`/`$plan-review` to convergence **before** implementation. |

## 3. Design

Three independent changes (A/B/C), each implementable and testable on its own.

### A. Auditor scoping — path-aware narrowing + pre-filter

The auditor (`agents/up-docs-audit-drift.md`) runs two cost sinks. Both are fixed by
promoting existing-but-unused state into **explicit numbered task steps**, made
**path-aware** so standalone `/up-docs:drift` (which has no propagator reports) stays
self-sufficient.

**A1 — Convergence narrowing (applies in BOTH paths).**
`scripts/convergence-tracker.sh` already persists `pages_touched` per phase; the value is
computed and never consumed. Change the auditor's per-phase loop (current task step 4 +
`convergence-tracking.md` "Narrowing on Re-pass") so that:

- **Pass 1** of each phase: full scan of the phase's surface (unchanged).
- **Pass N+1**: scan only the union of (i) the pages in the prior pass's `pages_touched`
  set and (ii) pages whose frontmatter `related` references a page in that set
  (one-hop dependents). Other pages are presumed stable for this phase.

This is keyed off the auditor's **own** per-pass findings (not propagator reports), so it
works identically in `/all` and standalone. `convergence-tracking.md` stops being the
authority for the rule and instead points to the auditor task step (single source of truth).

**A2 — Propagator-report pre-filter (applies in the `/all` path ONLY).**
Add an explicit early task step: *"If propagator reports were provided in your prompt,
build the set of pages they marked `Updated`/`Created` this run and exclude those pages
from your scan-candidate set **before** scanning — not merely before reporting. If no
reports were provided (standalone `/up-docs:drift`), scan normally."* This moves the
existing dedup (current guardrail at task lines ~99–100) from post-scan to pre-scan in the
`/all` path while preserving full standalone behavior.

**Files:** `agents/up-docs-audit-drift.md` (task steps 2/4 + the dedup guardrail),
`skills/drift/references/convergence-tracking.md` (defer to the task step).

**Verifiable against:** a bats/prompt-conformance assertion that the auditor prompt
contains a pass-1-full / pass-N-narrow instruction referencing `pages_touched`, and a
path-aware pre-filter instruction gated on "reports provided".

### B. Fast-path empty-layer skip

In `skills/all/SKILL.md` Step 2 the orchestrator already enumerates summary items. Extend
Step 2 to **tag each item with its target layer(s)** (`repo` / `wiki` / `notion`) using the
existing Layer Boundaries table. In Step 3, **dispatch only propagators with ≥1 routed
item**. For each skipped layer, emit an explicit combined-report row, e.g.
`| Notion | Skipped | 0 items routed to this layer |`.

**Fail-open rule (preserves the Balanced posture):** if an item's target layer is
ambiguous, it routes to **all** candidate layers rather than being dropped. A layer is
skipped only when it provably has zero routed items. The auditor still audits all three
layers regardless of which propagators were dispatched — skipping a *propagation* never
skips the *audit* of that layer.

**Files:** `skills/all/SKILL.md` (Steps 2–3), `templates/summary-report.md` (a `Skipped`
row variant + totals note).

**Verifiable against:** a prompt-conformance assertion that Step 3 is conditioned on routed
items and that the skip path is fail-open + logged; a manual scenario (repo-only change ⇒
notion + wiki skipped, audit still covers all three).

### C. Step 6 commit offer (consent gate, two repos, no push)

Add **part (c)** to the "Handoff for Next Session" section of
`templates/post-propagation-steps.md`, after the handoff brief:

1. Detect dirty trees in (i) the active project repo and (ii) `~/projects/llm-wiki` — the
   latter only if the wiki propagator reported a write there.
2. If neither is dirty, skip silently.
3. If either is dirty, present **one** `AskUserQuestion` (`multiSelect` across the dirty
   repos) offering to commit. On approval, for each selected repo:
   - stage **only** the propagation-written paths, by explicit name (never `git add -A`);
   - commit under that repo's convention — project repo: signed, scoped
     `docs(handoff): …` message summarizing the session close; `~/projects/llm-wiki`: its
     draft-contract message (`docs(<area>): …`, the page stays `status: draft`);
   - **never push.**
4. Report the resulting commit SHAs (and that nothing was pushed).

This keeps `post-propagation-steps.md` honest about its now-expanded role: it remains
read-only over the *handoff brief* state files, and only ever commits the
**propagation-written** paths after explicit consent.

**Files:** `templates/post-propagation-steps.md` (new part (c)), `skills/all/SKILL.md` +
`skills/repo/SKILL.md` (Step 6 references, since the template is shared by both).

**Verifiable against:** a scenario test — after a propagation that writes both repos, the
step surfaces a consent question; declining commits nothing; approving commits only the
written paths under each convention and pushes nothing.

## 4. Non-goals

- No change to the three propagators' layer-boundary logic or the auditor's verification
  discipline (`evidence` grounding, unverifiable handling).
- No auto-push, ever (D2).
- No "Aggressive" auditor mode that skips the adjacent-infrastructure sweep on small
  sessions — explicitly rejected in favor of Balanced (D1).
- No change to standalone `/up-docs:drift` scan completeness (A2 is gated to the `/all`
  path; A1 narrowing applies but only affects re-passes, not first-pass coverage).

## 5. Risks & mitigations

| Risk | Mitigation |
| --- | --- |
| Narrowing (A1) misses drift introduced on a page not touched in the prior pass | First pass is always full; one-hop `related` dependents are included; oscillation detection (already in `convergence-tracking.md`) still applies. |
| Pre-filter (A2) skips a page that a propagator only *partially* fixed | Pre-filter excludes only pages the propagator marked `Updated`/`Created`; the auditor's mandate is cross-page drift, and any *remaining* drift on a touched page would have been a propagator FAILED row (still scanned). Accept residual risk; document it. |
| Fast-path (B) wrongly skips a layer with real work | Fail-open on ambiguity; skip only on provably-zero routed items; the audit layer still covers all three regardless. |
| Commit step (C) stages unintended paths | Stage only propagation-written paths by explicit name; never `-A`; consent-gated. |
| Cache lag: running skill is one version behind HEAD | Out of scope for this change; note in release notes that a cache refresh is needed post-release. |

## 6. Test & rollout

- Extend `tests/prompt-conformance.bats` with assertions for A1/A2 task-step presence and
  B's conditional dispatch + fail-open language.
- Add a `post-propagation-steps` template assertion for part (c) (consent-gated, no-push,
  explicit-path staging).
- Bump `plugin.json` + `marketplace.json` to `0.11.0`; CHANGELOG `[0.11.0]`.
- Release via `/release-pipeline:release` (plugin release, scoped tag `up-docs/v0.11.0`).

## 7. Open questions

None — all design forks resolved in §2.

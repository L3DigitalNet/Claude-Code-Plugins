# Session State Models

State persists in the conversation context and is never discarded between exchanges. The Pause State Snapshot serialises all variables for cross-session resumption.

---

## design-draft State Model

── IDENTITY ──────────────────────────────────────────────────────────

project_name
  Init: Phase 0 Q1  |  Read: all phases, document header
  Value: string or UNANSWERED

problem_statement
  Init: Phase 0 Q2  |  Read: Phase 2A, Phase 5
  Value: string or UNANSWERED

document_trigger
  Init: Phase 0 Q3  |  Read: Phase 3 (section structure)
  Value: [new / existing / change / audit / other] or UNANSWERED

── CONTEXT (Phase 1) ─────────────────────────────────────────────────

answers[]
  Init: Phase 1 Rounds 1–3  |  Read: Phase 1 synthesis,
        Phase 2A, Phase 5 (constraints/risks coverage check)
  Value: map of Q1–Q9 → [answer string | SKIPPED: reason | UNANSWERED]
  Note: UNANSWERED is not a valid final state for Phase 1 answers.
  Every UNANSWERED entry must become SKIPPED: [reason] before the
  Phase 1 completion check passes.

governance_requirements[]
  Init: Phase 1 Q9  |  Read: Phase 4 coverage sweep, Phase 5
  Value: list of {
    description: string,
    source: "Q9" or named standard/body,
    coverage_status: [Covered-in: section | OQ[N] | UNCOVERED]
  }
  Note: feeds into the pre-Phase-5 coverage sweep alongside
  constraints and risks. Any UNCOVERED entry blocks Phase 5
  generation until assigned or logged as an OQ.

phase1_tensions[]
  Init: Phase 1 Round 1 & 2 tension scans
  Read: Phase 2C (pre-populates tension flag list)
  Update: Phase 2C-0 (reconciliation)
  Value: list of {answer_a, answer_b, hardness_assessment,
          status: [Active | Carried-to-2C | Retired]}

── PRINCIPLES (Phase 2) ──────────────────────────────────────────────

candidates[]
  Init: Phase 2A  |  Read: Phase 2B, 2C, 2D, Phase 5
  Update: Phase 2B (verdict + cost), Phase 2C (tension resolution),
          Phase 2D (lock)
  Value: list of {
    id: PC[N],
    name: string,
    statement: string,
    inferred_from: quote,
    in_practice: [example, example, ...],
    cost_of_violation: string,
    tension_flags: [PC[M], ...] or [],
    status: [Pending | Stress-tested | SPLIT→[N+1,N+2] | DROPPED],
    verdict: [null | STRONG | NEEDS_REFINEMENT | TOO_VAGUE | SPLIT | DROPPED],
    cost_of_following: string or null,   ← required if STRONG
    dissent: string or null,             ← set if user selects (D) Keep as-is
    locked: bool                         ← true after Phase 2D confirmation
  }

tension_flags[]
  Init: Phase 2A (Tension flag fields) + phase1_tensions[] carried forward
  Read: Phase 2C-0 (reconciliation), Phase 2C (scenarios)
  Update: Phase 2C-0 (reconcile), Phase 2C (resolve)
  Value: list of {
    id: T[N],
    pc_a: PC[N],
    pc_b: PC[M],
    status: [Active | Reconciled | Retired],
    reconciliation_note: string or null,
    scenario_presented: bool,
    resolution: [null | A | B | C | D | E],
    tiebreaker_rule: string or null
  }

registry_locked: bool
  Init: false  |  Set true: Phase 2D on human (A) confirm
  Read: all subsequent phases — no principle changes after this is
  true without explicit `revise [Pn]` command

── STRUCTURE (Phase 3) ───────────────────────────────────────────────

sections[]
  Init: Phase 3  |  Read: Phase 4, Phase 5
  Update: Phase 3 confirmation (human modifications)
  Value: list of {
    name: string,
    priority: [Required | Recommended | Optional],
    status: [Pending | Has-content | Stubbed | Complete],
    stub_description: string or null
  }

── CONTENT (Phase 4) ─────────────────────────────────────────────────

section_answers{}
  Init: Phase 4 rounds  |  Read: Phase 5 (draft generation)
  Value: map of section_name → {
    answers: [string, ...],
    status: [Pending | Answered | Stub-accepted],
    stub_description: string or null
  }

── DRAFT (Phase 5) ───────────────────────────────────────────────────

open_questions[]
  Init: any phase (collected throughout, see OQ Collection Rule below)
  Read: Phase 5 (OQ log), Pause Snapshot
  Value: list of {
    id: OQ[N],
    question: string,
    why_it_matters: string,
    owner: string or TBD,
    status: [Open | Resolved | Deferred]
  }

OQ Collection Rule:
  Whenever a user answer reveals an unresolved design decision, a
  dependency on an unknown external factor, or a constraint whose
  resolution requires information not yet available, Claude immediately
  creates an OQ entry and acknowledges it inline without interrupting
  the interview flow: "Noted as OQ[N]: [one-sentence question]."
  OQ entries are collected silently throughout all phases — the user
  does not need to explicitly flag them.

constraints_coverage{}
  Init: Phase 4 pre-Phase-5 coverage sweep
  Value: map of constraint → {
    addressed_in: section_name or null,
    logged_as: OQ[N] or null,
    status: [Covered | Open-Question | UNCOVERED]
  }
  Any UNCOVERED entry blocks Phase 5 generation until resolved.

risks_coverage{}
  Init: Phase 4 pre-Phase-5 coverage sweep
  Value: same structure as constraints_coverage{}
  Any UNCOVERED entry blocks Phase 5 generation until resolved.

project_folder
  Init: First write operation of the session (whichever comes first:
        `save draft`, `export principles`, `export log`, Phase 5 option A)
  Read: all subsequent write operations
  Value: absolute or relative path string, or UNSET
  Note: Established via the first-write flow below. Once set, never
  overridden without explicit user instruction. Persisted in Pause
  Snapshot so a resumed session knows where to write without asking again.

  First-write establishment flow (triggers on first write operation only):
  ```
  📁 PROJECT FOLDER
  ──────────────────────────────────────────────────────────────────────
  Where is your project folder? All documentation will be saved to
  [project-folder]/docs/

  Provide an absolute or relative path, or press enter to use the
  current working directory.
  ──────────────────────────────────────────────────────────────────────
  ```
  After the user responds:
  1. Confirm the folder exists or create it.
  2. Create `docs/` inside it if not already present.
  3. Store the resolved path as `project_folder`.
  4. Proceed with the write operation — all artifacts go to
     `[project_folder]/docs/[filename]`.
  5. Do not ask for the project folder again this session.

  Standard filenames under `[project_folder]/docs/`:
    design-draft.md          ← draft (Phase 5 option A, `save draft`)
    principles-registry.md   ← `export principles`
    review-session-log.md    ← `export log` (/design-review)
    [original]-reviewed.md   ← /design-review save

draft_sections{}
  Init: Phase 5  |  Read: `show draft`, Pause Snapshot
  Value: map of section_name → {
    content: string or null,
    status: [Not-started | Complete | Stubbed]
  }

── STATE INVARIANTS ──────────────────────────────────────────────────

These must be true at all times. If Claude detects a violation
mid-session, it flags it before continuing:

1. No candidate in candidates[] with status Pending may advance past
   the Phase 2B completion check.
2. No tension_flag with status Active may advance past the Phase 2C
   completion check.
3. registry_locked may not be set true while any candidate has
   verdict null or status Pending.
4. No section in sections[] with priority Required may have status
   Pending at Phase 5 entry.
5. Every entry in answers[] that is UNANSWERED at the Phase 1
   completion check must be recorded as SKIPPED: [reason] before
   the gate passes — UNANSWERED is not a valid final state.


---

## design-review State Model

document_path
  Init: Entry point  |  Read: all phases, pause snapshot, session log
  Value: absolute or relative file path string

document_title
  Init: Initialization (extracted from file)  |  Read: all phases
  Value: string or UNKNOWN

project_folder
  Init: First write operation (export log, save reviewed document)
  Read: all subsequent write operations
  Value: absolute or relative path string, or UNSET
  Note: Same first-write establishment flow as /design-draft.
  Once set, never overridden without explicit user instruction.

── PRINCIPLES ───────────────────────────────────────────────────────

principles_source
  Init: Initialization Step 1  |  Read: all passes, pause snapshot
  Value: [cold-start-extracted | cold-start-manual | warm-handoff |
          none (Track B disabled)]

principles_registry[]
  Init: Initialization Step 1 (extracted, imported, or provided)
  Read: Step 2 (health check), all passes (Track B), session log
  Update: `update principle [Pn]`, health check resolutions
  Value: list of {
    id: P[N],
    name: string,
    statement: string,
    intent: string,
    enforcement_heuristic: string,
    auto_fix_heuristic: string,   ← internal tooling only — never shown in output
    risk_areas: [string, ...],
    auto_fix_eligible: bool,
    source: [Extracted | Imported | Manual]
  }

track_b_enabled: bool
  Init: Initialization Step 1
  Set false: when principles_source is none (user chose Tracks A and C only)
  Read: all passes — Track B skipped when false

── HEALTH CHECK ─────────────────────────────────────────────────────

health_check_passed: bool
  Init: Initialization Step 2  |  Read: pause snapshot
  Value: true after all SYSTEMIC: Health findings have been resolved

── GAP BASELINE ─────────────────────────────────────────────────────

gap_baseline[]
  Init: Initialization Step 4  |  Read: all passes (Track C), session log
  Update: Gap Baseline Impact Check (Step 3), `gap check [Gn]`
  Value: list of {
    id: G[N],
    name: string,
    status: [Active | Covered | Skipped]
  }

── LOOP STATE ───────────────────────────────────────────────────────

auto_fix_mode
  Init: Initialization Step 5  |  Read: all passes
  Update: `set mode [A/B/C/D]`, end-of-pass mode change (option G)
  Value: [A | B | C | D]

pass_number
  Init: 0  |  Increments: at start of each pass  |  Read: all phases
  Value: integer ≥ 1 once loop begins

global_finding_counter
  Init: 0  |  Increments: each new finding created (never decreases)
  Read: all findings, deferred log, session log
  Value: integer

finding_queue[]
  Init: each pass (reset at pass start)  |  Read: resolution modes
  Update: as findings are resolved, deferred, or rejected
  Value: list of {
    id: #[N] (global),
    type: [STRUCTURAL | PRINCIPLE: P[N] | GAP: G[N] |
           SYSTEMIC | SYSTEMIC: Health],
    severity: [Critical | High | Medium | Low],
    scope: [cross-section | single-section],
    section: string,
    auto_fix_eligible: bool,
    auto_fix_confidence: [HIGH | MEDIUM | LOW | N/A],
    status: [Queued | Resolved | Auto-Fixed | Deferred | Rejected]
  }

section_status_table[]
  Init: Initialization (from document inventory)
  Update: each pass as sections are reviewed or modified
  Value: list of {
    section: string,
    status: [Clean | Flagged | Modified | Deferred | Pending Review],
    last_changed: pass number or null,
    p_flags: [P[N], ...] or [],
    g_flags: [G[N], ...] or [],
    modification_count: integer   ← for churn detection (3+ consecutive → High Churn)
  }

deferred_log[]
  Init: empty  |  Updated: when a finding is deferred or retired
  Read: `revisit deferred`, End of Pass Summary, session log
  Value: list of {
    id: #[N],
    type: string,
    section: string,
    severity: [Critical | High | Medium | Low],
    description: string,
    deferred_at_pass: integer,
    status: [Active | RETIRED (→ see #N)]
  }

── COMPLIANCE & COVERAGE ────────────────────────────────────────────

principle_compliance{}
  Init: Pass 1  |  Updated: each pass after resolution
  Read: End of Pass Summary, `show violations`, session log
  Value: map of P[N] → {
    status: [✓ Clean | ⚠ Violations],
    violation_streak: integer,   ← consecutive passes with violations; 3+ → Systemic Issue
    open_violations: [#N, ...]
  }

gap_coverage{}
  Init: Pass 1  |  Updated: each pass after resolution
  Read: End of Pass Summary, `show violations`, session log
  Value: map of G[N] → {
    status: [✓ Adequate | ⚠ Partial | ✗ Not covered],
    violation_streak: integer,   ← consecutive passes with findings; 3+ → Systemic Issue
    open_gaps: [#N, ...]
  }

── CONTEXT HEALTH ───────────────────────────────────────────────────

context_growth_lines
  Init: 0  |  Updated: after each pass (estimated lines added to session context)
  Read: End of Pass Summary, `context status`
  Value: integer (cumulative net lines added)

context_health
  Init: GREEN  |  Evaluated: at End of Pass Summary
  Value: [GREEN | YELLOW | RED]
  Thresholds:
    GREEN  — context_growth_lines < 4,000; no Heavy or Critical passes
    YELLOW — context_growth_lines 4,000–8,000; or 3+ consecutive Heavy passes
    RED    — context_growth_lines > 8,000; or any Critical-volume pass
  On YELLOW: warn at end-of-pass ("Context pressure building — consider pausing
    and resuming in a fresh session with the current document state.")
  On RED: strong warning before next pass ("Context pressure is high — pause
    recommended. Use `pause` to snapshot state, save the reviewed document,
    and continue in a new session.")

── WARM HANDOFF CONTEXT (when applicable) ───────────────────────────

handoff_imported: bool
  Init: Entry point detection  |  Read: Initialization Step 1
  Value: true if a `/design-draft → /design-review HANDOFF` block is
  detected in the session context

imported_tensions[]
  Init: warm handoff import  |  Read: Initialization Step 2 (health check)
  Value: list of {
    id: T[N],
    pc_a: P[N],
    pc_b: P[M],
    resolution: [A | B | C | D | E],
    tiebreaker_rule: string or None
  }
  Note: Tensions in this list are closed. Do NOT re-surface as
  SYSTEMIC: Health findings. Surface only tensions introduced by the draft
  that do NOT appear in this list.

imported_oq_log[]
  Init: warm handoff import  |  Read: all passes (Track C)
  Value: list of {
    id: OQ[N],
    question: string,
    associated_stub_section: string or null
  }
  Note: Stub sections with a matching entry here are expected gaps. Do not
  queue as GAP findings unless the OQ's "why it matters" reveals an
  unaddressed gap category. Stubs with NO matching entry are legitimate
  GAP findings.

── STATE INVARIANTS ─────────────────────────────────────────────────

These must be true at all times. If Claude detects a violation
mid-session, it flags it before continuing:

1. No finding may be Auto-Fixed if the relevant principle has
   auto_fix_eligible: false — regardless of auto_fix_mode.
   No `PRINCIPLE: Pn` type finding may EVER be Auto-Fixed — regardless
   of auto_fix_mode or the principle's auto_fix_eligible setting.
   Principle violations represent design decisions that must be
   consciously resolved by the author, not silently applied.
2. No finding with severity Critical may ever be Auto-Fixed.
3. global_finding_counter never decreases within a session. Retiring
   a deferred finding (RETIRED → see #N) does not decrement the counter.
4. A section in section_status_table[] may not have status Clean while
   it has any unresolved entries in p_flags[] or g_flags[].
5. track_b_enabled may not be true if principles_registry[] is empty.
6. SYSTEMIC: Health findings must be fully resolved before SYSTEMIC
   findings at any pass boundary where both types are present.
7. Convergence (DESIGN REVIEW COMPLETE) may not be declared while any
   finding has status Queued. Deferred findings do not block convergence
   but must be listed in the Completion Declaration.
8. auto_fix_heuristic values from principles_registry[] must never
   appear in user-facing output — they are internal tooling only.
9. Before any proposed resolution is presented to the human (whether
   for manual review or auto-fix), the proposed fix must be screened
   against all principles in principles_registry[]. If the fix would
   violate any established principle, the conflict must be surfaced
   explicitly before the fix is offered. A resolution that closes one
   finding while introducing a principle violation is not a valid
   resolution — it must be modified, rejected, or explicitly
   acknowledged as a deliberate exception by the author.


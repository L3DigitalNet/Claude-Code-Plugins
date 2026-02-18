---
argument-hint: [path/to/design-doc.md]
description: >
  Iterative design document review loop with principle enforcement,
  gap analysis, and optional auto-fix. Accepts a file path as argument.
  Runs multi-pass Q&A refinement until the document converges. Use when
  reviewing, auditing, or improving any design document, architecture
  spec, or technical plan.
allowed-tools: Read, Write, Glob, Grep
---

# DESIGN DOCUMENT REVIEW & ITERATIVE REFINEMENT PROTOCOL
*Large Document Edition | Principle-Enforced | Gap-Analyzed | Interactive Q&A Resolution | Auto-Fix Capable*

## ENTRY POINT

$ARGUMENTS has been provided. Handle entry as follows:

**If $ARGUMENTS is a file path:**
Read the file at that path using the Read tool. If the file does not
exist, tell the user and stop. If it exists, proceed with its contents
as the design document.

**If $ARGUMENTS is empty:**
Ask the user to provide a file path. Do not begin initialization until
a valid file has been read.

Once document content is in hand, begin the INITIALIZATION sequence below.

For large documents, Claude reads the full file via the Read tool.
No chunking or manual content submission is required.

---

You are entering an iterative design document refinement loop. You will
work through this document collaboratively with the human, resolving one
issue at a time through structured multiple-choice dialogue — or, when
authorized, automatically resolving findings that have clear
principle-aligned solutions without requiring individual approval.

---

## SESSION STATE MODEL

Claude maintains the following state variables throughout the session.
State persists in the conversation context — it is never discarded between
exchanges. The Pause State Snapshot serialises all of these variables for
cross-session resumption.

── DOCUMENT ─────────────────────────────────────────────────────────

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

---

## INITIALIZATION

Begin with a structural inventory:

```
DOCUMENT INVENTORY
══════════════════
Title:
Estimated Size:
Top-Level Sections Detected:
Domain Hints Detected:
Cross-Reference Map:
```

---

## DESIGN PRINCIPLES EXTRACTION

Extract and codify all stated design principles:

```
DESIGN PRINCIPLES REGISTRY
═══════════════════════════
Extracted from: [section]

[P1] [Principle Name]
     Statement: [from document]
     Intent: [your interpretation]
     Enforcement Heuristic: [what a violation looks like in practice]
     Auto-Fix Heuristic: [what a compliant resolution looks like —
                          used when auto-fix is authorized]
     Risk Areas: [sections most likely to violate this]
```

**No-principles cold start:**

If the document has no principles section AND no warm handoff context
was provided, do not infer candidates silently. Instead emit:

```
⚠ NO PRINCIPLES FOUND
──────────────────────────────────────────────────────────────────────
This document does not contain a principles section, and no warm
handoff context was provided.

Design principles are what make the review valuable — without them,
Track B (Principle Compliance) cannot run.

Options:
  (A) Run /design-draft first — discover and lock principles before
      reviewing this document (recommended)
  (B) Provide principles manually — paste or describe them now
  (C) Proceed without principles — run Tracks A and C only
      (structural + gap analysis, no principle enforcement)
──────────────────────────────────────────────────────────────────────
```

If (A): emit "Run `/design-draft [filename]` to begin." and stop.
If (B): collect principles via Q&A, treat as manually provided registry,
        proceed normally.
If (C): skip Track B for all passes. Pass summaries note
        "Track B: Skipped — no principles registry."
        Convergence is assessed across Tracks A and C only.
        Stubs with no OQ log context are treated as GAP findings.

**Inferred principles (document has content but no explicit section):**

If the document has design decisions but no explicit principles section,
infer candidates from the decisions already made and confirm:

```
❓ PRINCIPLES CONFIRMATION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  (A) Accept all inferred principles as stated
  (B) Accept with modifications — tell me which to change
  (C) Reject — I will provide them manually
  (D) Proceed without principles (gap and structural analysis only)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

If (D): same behaviour as no-principles cold start option (C) above.

---

## SHARED PROCEDURE — PRINCIPLE HEALTH CHECK

Called at initialization (Step 2) and after any mid-loop principle update.
Checks the registry across four dimensions:

1. **Inter-Principle Tension** — do any two principles conflict?
2. **Enforcement Vagueness** — can a concrete violation heuristic be derived?
3. **Auto-Fix Reliability** — can a reliable auto-fix heuristic be derived?
   If not, flag principle as **Auto-Fix Ineligible**.
4. **Goal Conflict** — does any principle contradict the document's goals?

Output format:
```
✓ PRINCIPLE HEALTH CHECK PASSED
Auto-Fix Eligible: [P1, P2, ...]
Auto-Fix Ineligible (always reviewed): [Pn, ...]
```

Or, if issues found — one Q&A per issue [SYSTEMIC: Health]:
```
⚠ PRINCIPLE HEALTH ISSUE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Finding #[N] | SYSTEMIC: Health
Type: [Tension / Vagueness / Auto-Fix Ineligible / Goal Conflict]
  (A) Accept proposed resolution
  (B) Accept with modifications
  (C) I'll resolve it myself
  (D) Acknowledge as accepted tradeoff
  (E) Remove one of the conflicting principles
  (F) Mark principle as Auto-Fix Ineligible
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## GAP ANALYSIS FRAMEWORK

Establish baseline before Pass 1:

```
GAP ANALYSIS BASELINE
══════════════════════
  [G1]  Functional Requirements Coverage
  [G2]  Non-Functional Requirements
  [G3]  Security & Authentication Model
  [G4]  Error Handling & Failure Modes
  [G5]  Data Model & Persistence Strategy
  [G6]  Integration Points & External Dependencies
  [G7]  Observability (logging, tracing, alerting)
  [G8]  Deployment & Environment Configuration
  [G9]  Testing Strategy
  [G10] Migration / Upgrade Path (if applicable)
  [G11+] [domain-specific categories inferred from document]
```

---

## INITIALIZATION SEQUENCE (mandatory order)

**Warm handoff detection (check before Step 1):**

If the session context contains a block beginning with
`/design-draft → /design-review HANDOFF`, treat it as a warm handoff
and follow the modified sequence below. Otherwise proceed with the
standard cold start sequence.

---

### WARM HANDOFF SEQUENCE

When a handoff block is detected, the following substitutions apply
to the standard initialization steps:

**Step 1 — SKIP principle extraction.**
Import the Principles Registry from the handoff block as authoritative.
Do not re-extract from document text. Do not ask the user to confirm
the registry — it is pre-confirmed.

Announce import:
```
▶ WARM HANDOFF DETECTED
──────────────────────────────────────────────────────────────────────
Principles registry pre-loaded ([N] principles, locked — not re-extracted).
Tension Resolution Log imported ([N] tensions — will not be re-surfaced).
Open Questions Log imported ([N] entries — associated stubs are expected).
Context summary loaded for gap baseline calibration.
Proceeding to Principle Health Check (document-verification scope).
──────────────────────────────────────────────────────────────────────
```

**Step 2 — Run Principle Health Check in document-verification scope only.**
Check that the document text is consistent with each imported principle.
Flag any new tensions introduced by the draft that do NOT appear in the
imported Tension Resolution Log. Do not re-check logged tensions — those
are resolved and closed.

**Step 3 — Gap Baseline Impact Check** — runs only if Step 2 health check
resolutions resulted in any principle modifications (additions, rewrites, or
removals). Finding a tension that is acknowledged without modifying a principle
does not trigger Step 3.

**Step 4 — Build & confirm Gap Baseline**, using the Phase 1 Context Summary
from the handoff block to calibrate domain and gap categories. Present for
confirmation as normal — the summary is a calibration input, not a bypass.

**Stub handling:** Stub sections with a corresponding OQ entry in the imported
OQ log are expected gaps — do not queue them as GAP findings. Stub sections
with NO corresponding OQ entry are legitimate GAP findings — queue normally.

**Tension handling:** Tensions listed in the imported Tension Resolution Log
are closed. If the document text introduces a new tension not in that log,
surface it as a SYSTEMIC: Health finding in Step 2.

**Step 5** — Set Auto-Fix Mode (same as cold start).
**Step 6** — Begin Pass 1.

---

### COLD START SEQUENCE

**Step 1** — Build & confirm Principles Registry (with Auto-Fix Heuristics)
**Step 2** — Run Principle Health Check; establish Auto-Fix Eligible list
**Step 3** — Gap Baseline Impact Check — runs only if Step 2 health check
resolutions resulted in any principle modifications (additions, rewrites, or
removals).

```
⚠ PRINCIPLE CHANGE MAY AFFECT GAP BASELINE
  (A) Accept suggested gap adjustments
  (B) Accept with modifications
  (C) Proceed with original gap baseline
```

**Step 4** — Build & confirm Gap Baseline
**Step 5** — Set Auto-Fix Mode:

```
AUTO-FIX MODE SELECTION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  (A) Interactive — review and authorize each finding individually
      [Default — maximum control]

  (B) Auto-Fix eligible findings, review the rest —
      Summarize all findings at end of pass, auto-fix those
      with clear principle-aligned solutions, bring ambiguous
      or high-risk findings to you individually.

  (C) Auto-Fix bulk confirmation —
      Present full findings plan, ask for bulk approval,
      implement all authorized fixes at once.

  (D) Ask me each pass — choose mode per-pass.

Auto-Fix Eligible principles: [list]
Auto-Fix Ineligible principles (always reviewed): [list]

Note: Regardless of mode, these ALWAYS require individual review:
  - Critical severity findings
  - SYSTEMIC and SYSTEMIC: Health findings
  - Cross-section findings affecting 3+ sections
  - Confidence below HIGH
  - Violations against Auto-Fix Ineligible principles
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Step 6** — Begin Pass 1

---

## SECTION STATUS TABLE

```
SECTION STATUS TABLE (Pass N)
──────────────────────────────────────────────────────────────────────
Section  | Status   | Last Changed | P-Flags | G-Flags
──────────────────────────────────────────────────────────────────────
```
Status: `Clean` | `Flagged` | `Modified` | `Deferred` | `Pending Review`
A section is not `Clean` with unresolved P-Flags or G-Flags.

---

## LOOP STRUCTURE

Pass header:
```
═══════════════════════════════════════════════════════════════════════
PASS [N] | Change Volume: [Prior] | Auto-Fix Mode: [A/B/C/D]
Sections Full Review: [list]
Sections Consistency Check Only: [list]
Active Violations & Systemic Issues: Principle:[list] Gap:[list] Systemic:[desc]
═══════════════════════════════════════════════════════════════════════
```

---

## REVIEW TRACKS

### Track A — Structural & Technical
Internal Consistency · Completeness · Logic & Correctness · Ambiguity ·
Redundancy · Scalability & Maintainability · Security & Error Handling ·
Clarity & Structure

### Track B — Design Principle Compliance
For every section under full review, check each principle for:
Direct violations · Soft violations · Principle tension ·
Principle drift · Missing principle application

**Violation Consolidation:** Multiple violation types against the SAME
principle in the SAME section → consolidate into ONE finding.
Different principles or different sections → keep separate.

**Cross-Pass Consolidation:** If a deferred PRINCIPLE finding exists for
section [X] against [Pn] AND the current pass finds a new violation of
[Pn] in [X] → retire the deferred finding, create a consolidated
REOPENED finding at the next global number.

### Track C — Gap Analysis
- Pass 1: full cross-document sweep; establish Gap Coverage Table baseline
- Subsequent passes: full analysis for sections under full review;
  lightweight re-check for consistency-check-only sections
- Full sweep on demand via `gap check [Gn]` or after Heavy/Critical pass

---

## FINDING TYPE TAXONOMY

**Pass Queue Types** (ordered, resolved in Q&A loop):
- `[STRUCTURAL]` — Track A
- `[PRINCIPLE: Pn]` — Track B
- `[GAP: Gn]` — Track C

**Out-of-Queue Types** (resolved at pass boundaries, always reviewed individually):
- `[SYSTEMIC]` — pattern across 3+ consecutive passes
- `[SYSTEMIC: Health]` — from Principle Health Check

All types enter the global finding number sequence.
SYSTEMIC: Health resolved before SYSTEMIC at any pass boundary.

---

## AUTO-FIX ELIGIBILITY

A finding is **Auto-Fix Eligible** when ALL are true:
1. Principle-aligned resolution clearly prescribed by Auto-Fix Heuristic
2. Single-section scope
3. Claude confidence is HIGH
4. Severity is not Critical
5. Principle is Auto-Fix Eligible
6. No new design decision required

**Auto-Fix Confidence:**
- HIGH — heuristic directly and unambiguously prescribes the resolution
- MEDIUM — heuristic points the way but requires interpretation
- LOW — context-dependent or involves unresolved tradeoffs

Only HIGH confidence findings are auto-fixed.

---

## FINDING QUEUE ORDERING

Level 1: Severity — Critical → High → Medium → Low
Level 2: Type — Principle → Gap → Structural
Level 3: Scope — Cross-section before single-section

Display queue with eligibility before resolution begins:
```
FINDINGS QUEUE — PASS [N]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  | Type          | Sev  | Scope         | Section  | Auto-Fix
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## RESOLUTION MODES

### Mode A — Interactive
Present each finding individually:
```
──────────────────────────────────────────────────────────────────────
FINDING #[N] of [Total] | Pass [N] | [TYPE] | [Auto-Fix: ✓/✗]
Section: [section] | Severity: [level]
──────────────────────────────────────────────────────────────────────
[Issue description and risk]

PROPOSED RESOLUTION: [specific fix]

  (A) Accept — implement it
  (B) Accept with modifications
  (C) Propose alternative
  (D) Defer
  (E) Reject
  (F) Escalate — deeper design problem
  (G) Acknowledge gap — address externally [GAP only]
  (H) Switch to auto-fix for remaining eligible findings this pass
──────────────────────────────────────────────────────────────────────
```

### Mode B — Auto-Fix Eligible + Review Rest
At end of internal review phase, present Auto-Fix Summary:
```
AUTO-FIX SUMMARY — PASS [N]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
AUTO-FIX ELIGIBLE — Claude proposes to fix these automatically:
  #[N] | [TYPE] | [Sev] | [Section]
       Violation: [plain-language description]
       Auto-fix: [what will be changed and why it's principle-aligned]
       Confidence: HIGH

REQUIRES YOUR REVIEW — will surface individually after:
  #[N] | [TYPE] | [Sev] | [Section] | Reason: [why review required]

  (A) Approve auto-fixes — implement all, then surface review findings
  (B) Approve with exclusions — exclude #[list]
  (C) Review all individually — switch to Interactive this pass
  (D) Reject all auto-fixes
  (E) Show full diff preview before deciding
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Mode C — Auto-Fix Bulk Confirmation
Present Full Pass Auto-Fix Plan (all findings) and ask for bulk approval.
Review-required findings still surface individually after bulk approval.

### Mode D — Per-Pass
Present mode options at start of each pass.

---

## AMBIGUOUS AUTHORIZATION RULE
If the human's response is ambiguous, ask exactly ONE clarifying question
before taking any action. Never assume intent. Never implement under ambiguity.

---

## ESCALATION SUB-PROTOCOL
```
⚡ ESCALATION — Finding #[N]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[Deeper design problem description]

  (A) Adopt [design direction A]
  (B) Adopt [design direction B]
  (C) I have a different direction
  (D) Defer deeper issue; apply minimal surface fix
  (E) Update a design principle
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```
Upon closure: `↩ RETURNING TO FINDING QUEUE — [summary of decision]`

---

## SEVERITY DEFINITIONS

| Severity | Definition | Auto-Fix? |
|---|---|---|
| Critical | Implementation failure, data loss, security breach | Never |
| High | Significant confusion, architectural debt | If eligible |
| Medium | Ambiguity, minor inconsistency, shallow gap | If eligible |
| Low | Clarity, readability improvement | If eligible |

---

## DIFF FORMAT
Never reprint the full document. Use structured diffs:
```
IMPLEMENTING FINDING #[N]  [AUTO-FIX per Pn / MANUAL]
──────────────────────────────────────────────────────────────────────
Section [X.X] — [Change Description]
  BEFORE: ┌─── [original text] ───┐
  AFTER:  ┌─── [revised text]  ───┐
  Finding #[N] closed ✓
  [Principle Restored: Pn ✓] [Gap Closed: Gn ✓] [Auto-Fixed per Pn ✓]
──────────────────────────────────────────────────────────────────────
```

---

## END OF PASS SUMMARY

```
══════════════════════════════════════════════════════════════════════
PASS [N] COMPLETE
══════════════════════════════════════════════════════════════════════
Findings: [n] total ([s]S [p]P [g]G [sy]Sy [sh]SH)
  Auto-Fixed: [n] | Manually Resolved: [n] | Deferred: [n] | Rejected: [n]
Change Volume: [level]
Principle Compliance: [P1 ✓/⚠] [P2 ✓/⚠] ...
Gap Coverage: [G1 ✓/⚠/✗] [G2 ✓/⚠/✗] ...
Context Health: [GREEN/YELLOW/RED] | Growth: ~[+N] lines | Cumulative: ~[+N]
══════════════════════════════════════════════════════════════════════
```

Followed by Systemic Issue Resolution (if detected), then End of Pass Options:
```
  (A) Begin Pass [N+1]
  (B) Focused section review
  (C) Principle sweep [Pn]
  (D) Gap sweep [Gn]
  (E) Review Deferred Log
  (F) Update a design principle
  (G) Change auto-fix mode
```

**Systemic Issue Protocol:** When a principle or gap category produces
findings in 3+ consecutive passes → mandatory resolution before next pass:
```
🔁 SYSTEMIC ISSUE — Finding #[N] | SYSTEMIC
  (A) Address root cause via targeted design change
  (B) Reframe as deliberate tradeoff — update principle/gap definition
  (C) Escalate — focused design discussion
  (D) Override — accept as systemic risk (re-flags at 5+ passes)
```

---

## CHANGE VOLUME + TREND TRACKING

Labels: None · Light · Moderate · Heavy · Critical

**Churn Indicator:** Section Modified in 3+ consecutive passes → `High Churn`
**Principle Violation Trend:** Violations in 3+ consecutive passes across
sections → `Systemic Principle Breach` → triggers Systemic Issue Protocol
**Auto-Fix Reliability:** MEDIUM/LOW confidence for a principle in 2+
consecutive passes → flag and offer to refine heuristic or mark ineligible

---

## DEFERRED LOG

```
DEFERRED FINDINGS LOG
──────────────────────────────────────────────────────────────────────────────
#  | Type     | Section | Sev  | Description              | Pass | Status
──────────────────────────────────────────────────────────────────────────────
                                          Status: Active | RETIRED (→ see #N)
⚠ High-severity deferred items: [n] — resolve before implementation
```

---

## PAUSE STATE SNAPSHOT

On `pause`:
```
⏸ PAUSE STATE SNAPSHOT — /design-review
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Document: [title]
File: [document_path]
Project folder: [absolute path or "UNSET"]
Pass: [pass_number] | Auto-Fix Mode: [auto_fix_mode]
Global finding counter: #[global_finding_counter]
Context health: [GREEN/YELLOW/RED] | Context growth: ~[n] lines

── PRINCIPLES ────────────────────────────────────────
Source: [cold-start-extracted | cold-start-manual | warm-handoff | none]
Track B: [Enabled | Disabled]
Registry:
  [P1] [name] | Auto-Fix: [eligible/ineligible] | Health: [✓/⚠]
  [P2] ...

── GAP BASELINE ──────────────────────────────────────
[G1] [name] | [Active/Covered/Skipped]
[G2] ...

── LOOP STATE ────────────────────────────────────────
Last Finding: #[N] ([status]) | Remaining Queue: #[list]
Auto-Fix Eligible Remaining: #[list]
Findings This Pass: [n] | Auto-Fixed: [n] | Deferred: [n]

── COMPLIANCE & COVERAGE ─────────────────────────────
Principle compliance:
  [P1] [✓ Clean | ⚠ Violations (streak: [n])] — open: [#list or none]
  [P2] ...
Gap coverage:
  [G1] [✓ Adequate | ⚠ Partial | ✗ Not covered (streak: [n])] — open: [#list or none]
  [G2] ...

── SECTION STATUS ────────────────────────────────────
[section | status | p_flags | g_flags | mod_count]

── DEFERRED LOG ──────────────────────────────────────
[#N | Type | Section | Sev | Description | Pass | Active/RETIRED]
[None] if empty

── WARM HANDOFF (if applicable) ──────────────────────
Handoff imported: [true/false]
Imported tensions: [T1: P[A]×P[B] resolved-(A/B/C/D/E), ... | None]
Imported OQ stubs: [OQ1→[section], ... | None]

TO RESUME: paste this snapshot and type `continue`. The document is
read from the file system — no need to re-paste content.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

On `continue` with snapshot:

1. Read the first line of the snapshot.
2. If label is `/design-draft` (not `/design-review`), emit:
   ```
   ✗ SNAPSHOT MISMATCH
   ──────────────────────────────────────────────────────────────────
   This snapshot is from /design-draft but you're running /design-review.
     (A) I meant to run /design-draft — start that session instead
     (B) I have the correct /design-review snapshot — let me paste it
     (C) Start fresh with no snapshot
   ──────────────────────────────────────────────────────────────────
   ```
   Do not restore any state until resolved.
3. If label is `/design-review` or matches: reconstruct all state
   variables from the snapshot fields, re-read the document from
   the file system, then confirm reconstructed state before resuming:
   ```
   ▶ RESUMING /design-review
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   Document: [title] (re-read from [path])
   Resuming at: Pass [N] | Finding #[N] | Mode [A/B/C/D]
   Principles restored: [N] ([N] eligible, [N] ineligible)
   Gap baseline restored: [N] categories
   Deferred findings: [N] active
   Context health: [GREEN/YELLOW/RED]
   Handoff context: [imported / not applicable]
   Continuing now...
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   ```
4. If no label found: ask user to confirm which command the snapshot
   belongs to before proceeding.

---

## EARLY EXIT PROTOCOL

On `finalize`:
```
⚠ EARLY EXIT REQUESTED
  (A) Finalize now — emit Partial Completion Declaration
  (B) Auto-fix all eligible findings first, then finalize
  (C) Finalize after resolving remaining Critical/High only
  (D) Finalize after current pass completes
  (E) Cancel — continue the loop
```

Partial Completion Declaration includes: open findings by severity,
open principle violations, open gap categories, and a Readiness Assessment:
- IMPLEMENTATION READY WITH CAUTION
- NOT RECOMMENDED FOR IMPLEMENTATION
- INCOMPLETE — DESIGN DECISIONS OUTSTANDING

---

## COMPLETION DECLARATION

Complete when a full pass produces zero findings across all three tracks
AND Principle Compliance and Gap Coverage are both fully clean.

```
╔════════════════════════════════════════════════════════════════╗
║                   DESIGN REVIEW COMPLETE                       ║
╚════════════════════════════════════════════════════════════════╝
Passes: [N] | Findings: [X] | Auto-Fixed: [n] | Manual: [n]
Deferred: [n] | Rejected: [n]
Final Principles: [P1 ✓] [P2 ✓] ...
Final Gap Coverage: [G1 ✓ Adequate] [G2 ✓ Adequate] ...
```

---

## SESSION LOG EXPORT

On `export log` — emit structured Session Log including:
Pass Summary · Findings Register (with Auto-Fix Y/N per finding) ·
Systemic Issues Log · Principles Registry (final state with heuristics) ·
Gap Coverage Table (final state) · Deferred Log (final state) ·
Chronological Diff Summary · Auto-Fix Effectiveness Report

After emitting, offer to save: trigger first-write establishment flow
if `project_folder` is UNSET (same flow as in /design-draft — ask for
project folder path, create `docs/` subfolder if needed), then write to
`[project_folder]/docs/review-session-log.md`.

Auto-Fix Effectiveness Report format:
```
── AUTO-FIX EFFECTIVENESS REPORT ─────────────────────────────────
Total eligible: [n] | Auto-fixed: [n] | Escalated to manual: [n]
Confidence: HIGH [n] / MEDIUM [n] / LOW [n]
Per-principle: [Pn] [n] eligible, [n] auto-fixed, [n] escalated
```

---

## OPERATIONAL COMMANDS

### Session Control
| Command | Effect |
|---|---|
| `pause` | Suspend loop; emit Pause State Snapshot |
| `continue` | Resume from snapshot or current state |
| `finalize` | Early Exit Protocol |
| `set mode [A/B/C/D]` | Change auto-fix mode immediately |

### Navigation & State
| Command | Effect |
|---|---|
| `where are we` | Current pass, finding, queue, mode, context health |
| `reprint inventory` | Document Inventory + Principles + Gap Baseline + Status Table |
| `reorder queue` | Reorder remaining findings queue |
| `context status` | Current context health assessment |

### Targeted Review
| Command | Effect |
|---|---|
| `review section [name]` | Focused three-track review via Q&A or auto-fix |
| `cross-check [A] vs [B]` | Consistency + principle check between two sections |
| `principle check [Pn]` | Compliance sweep for one principle |
| `gap check [Gn]` | Full coverage sweep for one gap category |
| `revisit deferred` | Pull deferred findings into active queue |
| `show violations` | All open principle/gap/systemic findings |

### Document Output
| Command | Effect |
|---|---|
| `show section [name]` | Current state of section with all diffs applied |
| `export log` | Full structured Session Log with auto-fix report |

### Principle & Gap Management
| Command | Effect |
|---|---|
| `reprint principles` | Registry with Auto-Fix Heuristics and eligibility |
| `reprint gaps` | Gap Baseline and current coverage status |
| `update principle [Pn]` | ⚠ Triggers cascade: registry update → Health Check → Gap Impact Check → Q&A for any resulting findings. Best at End of Pass Summary. If mid-pass: warns and offers to defer. |
| `set autofixable [Pn]` | Mark principle as Auto-Fix Eligible |
| `set not-autofixable [Pn]` | Mark principle as Auto-Fix Ineligible |
| `show autofix status` | Eligibility list + confidence distribution from current/last pass |

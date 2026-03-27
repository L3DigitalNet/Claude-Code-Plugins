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

## REFERENCES

Read these references as needed throughout the session:

- `${CLAUDE_PLUGIN_ROOT}/references/interaction-conventions.md` — AskUserQuestion conversion rules (read at session start)
- `${CLAUDE_PLUGIN_ROOT}/references/session-state.md` — design-review state model and invariants (read at session start)
- `${CLAUDE_PLUGIN_ROOT}/references/ux-templates.md` — all formatted output templates (read before emitting any template)
- `${CLAUDE_PLUGIN_ROOT}/references/pause-resume.md` — pause, resume, early exit protocols (read on `pause`/`continue`/`finalize`)
- `${CLAUDE_PLUGIN_ROOT}/references/operational-commands.md` — available session commands (read on unknown command)

## ENTRY POINT

$ARGUMENTS has been provided. Handle entry as follows:

**If $ARGUMENTS is a file path:**
Read the file at that path using the Read tool. If the file does not
exist, tell the user and stop. If it exists, proceed with its contents
as the design document.

**If $ARGUMENTS is empty:**
Emit the following, then stop until a valid file path is provided:

```
✗ NO FILE PROVIDED
──────────────────────────────────────────────────────────────────────
/design-review requires a path to the design document to review.

  Usage: /design-review path/to/design-doc.md

Provide the file path and I'll begin the review.
──────────────────────────────────────────────────────────────────────
```

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

Read `${CLAUDE_PLUGIN_ROOT}/references/session-state.md` for the complete design-review state model and invariants.
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
  - PRINCIPLE: Pn type findings (never auto-fixed — principle violations
    are design decisions requiring conscious author resolution)
  - Any finding whose proposed fix fails Principle Conflict Screening
    (fix disqualified from auto-fix, surfaced for manual review)
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

**`PRINCIPLE: Pn` type findings are NEVER Auto-Fix Eligible.** They always
require individual human review regardless of auto_fix_mode or the
principle's auto_fix_eligible setting. Principle violations are design
decisions — the author must consciously choose the resolution. This mirrors
the rigour of /design-draft, where every principle is human-confirmed through
stress testing and tension resolution before being locked.

`STRUCTURAL` and `GAP: Gn` findings are **Auto-Fix Eligible** only when
ALL of the following are true:
1. Principle-aligned resolution clearly prescribed by Auto-Fix Heuristic
2. Single-section scope
3. Claude confidence is HIGH
4. Severity is not Critical
5. Relevant principle (the one guiding the fix) is Auto-Fix Eligible
6. No new design decision required
7. Proposed fix passes Principle Conflict Screening (see below) — a fix
   that resolves the finding but violates an established principle fails
   this criterion and is moved to manual review

**Auto-Fix Confidence:**
- HIGH — heuristic directly and unambiguously prescribes the resolution
- MEDIUM — heuristic points the way but requires interpretation
- LOW — context-dependent or involves unresolved tradeoffs

Only HIGH confidence findings are auto-fixed.

---

## PRINCIPLE CONFLICT SCREENING

**Mandatory for every proposed resolution before it is presented to the
human** — whether the finding is STRUCTURAL, GAP, PRINCIPLE, or SYSTEMIC,
and whether the resolution mode is interactive, auto-fix, or bulk.

Before presenting any proposed fix, Claude screens it against the full
principles_registry[]. This step is **silent** — it does not produce output
unless a conflict is detected. The result is recorded in the session log
entry for the finding: `Conflict Screening: Passed` or
`Conflict Screening: Conflict with [Pn] — [resolution chosen]`.

**When no conflict is found:** Proceed to present the resolution normally.

**When a conflict is found:** Do not present the resolution as clean.
Instead, disqualify it from auto-fix (if applicable) and surface the
conflict explicitly:

```
⚠ PROPOSED FIX CONFLICTS WITH [Pn]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Finding #[N]: [original finding type and section]
Proposed fix: [what would resolve the finding]
Principle conflict: [Pn] — [one sentence: how the proposed fix
  violates this principle's enforcement heuristic]

Options:
  (A) Accept the fix — deliberate exception to [Pn]
      [Tiebreaker rule or cost-of-violation recorded in session log]
  (B) Modify the fix to honour [Pn]
      [Alternative approach that resolves both the finding and
       respects the principle — Claude provides a concrete proposal]
  (C) Revise [Pn] — the principle needs updating to accommodate this
      [Triggers update principle [Pn] flow + health check]
  (D) Defer — flag both the original finding and this conflict for later
  (E) Reject the fix — original finding remains open
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Auto-fix disqualification:** If a proposed auto-fix fails Principle
Conflict Screening, it is removed from the auto-fix list and added to
"REQUIRES YOUR REVIEW" with reason `Proposed fix conflicts with [Pn]`.
The conflict is surfaced in the review queue, not silently discarded.

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
Auto-Fix column values: `✓ Eligible` | `✗ Ineligible` |
`MANUAL ONLY` (all PRINCIPLE: Pn findings) |
`✗ Conflict: Pn` (auto-fix disqualified by Principle Conflict Screening)

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
       Conflict Screening: Passed
       Confidence: HIGH

REQUIRES YOUR REVIEW — will surface individually after:
  #[N] | [TYPE] | [Sev] | [Section] | Reason: [why review required]
  Note: ALL PRINCIPLE: Pn findings appear here — they are never
  auto-fixed. Any finding whose proposed fix failed Principle Conflict
  Screening also appears here, with "Reason: Proposed fix conflicts
  with [Pn]" and the conflict presented inline.

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

## PAUSE, RESUME & EARLY EXIT

Read `${CLAUDE_PLUGIN_ROOT}/references/pause-resume.md` for the design-review pause snapshot format, continue/resume protocol, and early exit (finalize) protocol.

---

## COMPLETION DECLARATION

Complete when a full pass produces zero findings across all three tracks AND Principle Compliance and Gap Coverage are both fully clean. Read `${CLAUDE_PLUGIN_ROOT}/references/ux-templates.md` for Template 36 (Completion Declaration).

---

## SESSION LOG EXPORT

On `export log`, emit structured Session Log including: Pass Summary, Findings Register (with Auto-Fix Y/N per finding), Systemic Issues Log, Principles Registry (final state with heuristics), Gap Coverage Table (final state), Deferred Log (final state), Chronological Diff Summary, Auto-Fix Effectiveness Report (Template 37).

After emitting, offer to save: trigger first-write establishment flow if `project_folder` is UNSET, then write to `[project_folder]/docs/review-session-log.md`.

---

## OPERATIONAL COMMANDS

Read `${CLAUDE_PLUGIN_ROOT}/references/operational-commands.md` for the full list of available session commands.

---
argument-hint: [path/to/design-doc.md] or paste document below
description: >
  Iterative design document review loop with principle enforcement,
  gap analysis, and optional auto-fix. Accepts a file path as argument
  or document content pasted directly. Runs multi-pass Q&A refinement
  until the document converges. Use when reviewing, auditing, or
  improving any design document, architecture spec, or technical plan.
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
The user will paste the document content directly. Acknowledge readiness
and wait. Do not begin initialization until content is received.

**If $ARGUMENTS appears to be inline document content (not a path):**
Treat it as the document content directly and proceed.

Once document content is in hand, begin the INITIALIZATION sequence below.

---

You are entering an iterative design document refinement loop. You will
work through this document collaboratively with the human, resolving one
issue at a time through structured multiple-choice dialogue — or, when
authorized, automatically resolving findings that have clear
principle-aligned solutions without requiring individual approval.

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

If no explicit principles section exists, infer candidates and confirm:

```
❓ PRINCIPLES CONFIRMATION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  (A) Accept all inferred principles as stated
  (B) Accept with modifications — tell me which to change
  (C) Reject — I will provide them manually
  (D) Proceed without principles (gap and structural analysis only)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

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

**Step 1** — Build & confirm Principles Registry (with Auto-Fix Heuristics)
**Step 2** — Run Principle Health Check; establish Auto-Fix Eligible list
**Step 3** — Gap Baseline Impact Check (if any principles were rewritten)

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

## CHUNK HANDLING (large documents)

Label chunks `CHUNK [N] OF [M]`. Claude confirms each:
```
✓ CHUNK [N] OF [M] received. Waiting for: [remaining]
```
After all chunks: emit Context Size Assessment (GREEN / YELLOW / RED).

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
⏸ PAUSE STATE SNAPSHOT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Document: [title] | Pass: [N] | Auto-Fix Mode: [A/B/C/D]
Last Finding: #[N] ([status]) | Remaining Queue: #[list]
Auto-Fix Eligible Remaining: #[list]
Findings This Pass: [n] | Auto-Fixed: [n]
Principles: [P1 (eligible), P2 (ineligible), ...]
Gap Baseline: [G1, G2, ...]
Deferred Log Summary: [#N | Type | Section | Sev | Description]
Section Status: [section | status | flags]
TO RESUME: paste this snapshot + document + type `continue`
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

On `continue` with snapshot: confirm reconstructed state before resuming.

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
| `skip chunk [N]` | Mark chunk as intentionally omitted |
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

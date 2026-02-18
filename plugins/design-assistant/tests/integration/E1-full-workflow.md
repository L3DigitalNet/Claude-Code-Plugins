# Test E1 — Full Workflow: /design-draft → Warm Handoff → /design-review → Convergence

Command: End-to-end
Milestone: M13
Scenario ID: E1

## What it validates

Complete workflow from /design-draft through /design-review convergence.
No context loss at the command boundary. Principles registry, tensions,
and OQ log transferred without re-derivation.

## Setup

Clean working directory. No pre-existing documents.

## Session Script

**Phase A — /design-draft**

**Step 1:** `/design-draft "Payments API"`
Run through all phases (abbreviated here — see D1 for full detail).
At Phase 2C, ensure at least one tension exists and is resolved with
a tiebreaker rule.

**Step 2:** Complete through Phase 5 draft generation.

**Step 3:** At NEXT STEPS, select `(B) Begin /design-review immediately`
Expected:
- Handoff block emitted containing:
  - Header: `/design-draft → /design-review HANDOFF`
  - Principles registry in /design-review Appendix format (includes
    Auto-Fix Heuristics)
  - Tension Resolution Log with all T[N] entries
  - OQ log with annotation ("do not flag stubs with corresponding OQ")
  - Phase 1 Context Summary (domain, non-negotiable, constraints,
    governance, risks)
  - HANDOFF INSTRUCTIONS FOR /design-review (6 numbered points)
- Transition announcement emitted:
  "Handing off to /design-review with warm context.
   Principles registry pre-loaded ([N] principles, locked).
   [N] resolved tensions imported — will not be re-surfaced.
   [N] open questions imported — associated stubs are expected."

**Phase B — /design-review (warm handoff)**

**Step 4:** /design-review initialization from handoff
Expected:
- Principle extraction step SKIPPED (handoff note visible)
- Principle Health Check runs in document-verification scope only:
  checks draft consistency against imported principles; flags new
  tensions not in tension log
- Resolved tensions from handoff NOT re-surfaced as findings
- Gap baseline presented using Phase 1 Context Summary for calibration

**Step 5:** `(A) Accept gap baseline`
Expected:
- Mode selection presented
- Pass 1 begins

**Step 6:** Pass 1 findings
Expected:
- OQ-associated stub sections NOT in findings queue (they are expected)
- Stub sections with no corresponding OQ ARE in findings queue as GAP findings
- Principles from handoff correctly referenced in Track B findings

**Step 7:** Continue through convergence
Expected:
- Each pass reduces findings
- Convergence reached (zero findings)
- DESIGN REVIEW COMPLETE emitted

## Pass Criteria

- [ ] Handoff block emitted before /design-review begins
- [ ] Handoff block contains all 4 required sections (registry, tensions,
      OQ log, context summary)
- [ ] Handoff block contains HANDOFF INSTRUCTIONS FOR /design-review
- [ ] Transition announcement emitted with correct counts
- [ ] Principle extraction step skipped in /design-review initialization
- [ ] Resolved tensions not re-surfaced as findings
- [ ] OQ-associated stubs not in findings queue
- [ ] Stubs without OQ entries ARE in findings queue
- [ ] Convergence declared correctly

## Fail Indicators

- [ ] Handoff block missing any of the 4 required sections
- [ ] /design-review re-extracts principles from document text
- [ ] Resolved tension appears as a new SYSTEMIC: Health finding
- [ ] OQ stub appears as a GAP finding
- [ ] Principles registry re-confirmed by user (should be imported silently)

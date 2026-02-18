# Test D1 — Happy Path: Greenfield Project

Command: /design-draft
Milestone: M5
Scenario ID: D1

## What it validates

Full Phase 0–5 flow with a greenfield project, 4 principles, no tensions.
Registry lock, draft generation, project folder establishment, save to file.

## Setup

No pre-existing files required. Run in a clean working directory.

## Session Script

**Step 1:** `/design-draft "Notification Service"`
Expected:
- ENTRY POINT RESOLVED emitted (Mode: No content — starting blank)
- Phase 0 orientation questions presented (Q1, Q2, Q3)

**Step 2:** Answer Q1–Q3
```
Q1: Notification Service
Q2: Developers can't reliably deliver transactional notifications across
    email, SMS, and push without building bespoke integrations per channel.
Q3: Starting a new project from scratch
```
Expected:
- Phase 0 Completion Check runs and passes all three criteria
- Orientation Summary presented with (A)/(B) options

**Step 3:** `(A) Yes, proceed to Phase 1`
Expected:
- Phase 1 Round 1 questions presented (Q1, Q2, Q3, Q3b)

**Step 4:** Answer Round 1
```
Q1: 6mo success = single team sending 1M notifications/day reliably.
    2yr = platform supporting 20 internal teams. Failure = messages
    silently dropped with no alerting.
Q2: Must use existing AWS infrastructure. Team of 3 engineers.
    No new vendor contracts without VP approval.
Q3: Prior attempt used SQS + Lambda directly — collapsed under fan-out load.
Q3b: Ship half the channels but remove zero constraints.
     Would cut push notifications, keep email and SMS.
```
Expected:
- Tension scan runs after Round 1 (no tension found acceptable)
- Round 2 questions presented (Q4, Q5, Q6, Q6b)

**Step 5:** Answer Round 2
```
Q4: Product wants delivery guarantees. Engineering wants simple ops.
    Finance wants cost visibility. They conflict on retry strategy cost.
Q5: Same 3-engineer team builds and operates. Pain point: on-call alerts
    for flaky third-party providers at 3am.
Q6: Third-party provider reliability. No SLA from SMS vendor.
Q6b: Engineering needs protected first — they're on-call.
     Finance has the most leverage if costs blow up.
```
Expected:
- Tension scan runs after Round 2 (no tension found acceptable)
- Round 3 questions presented (Q7, Q8, Q9)

**Step 6:** Answer Round 3
```
Q7: Reliability #1, Observability #2, Maintainability #3
Q8: Would sacrifice Maintainability first. Reliability is non-negotiable —
    a dropped notification is worse than ugly code.
Q9: Must conform to internal AWS tagging standards. No governance body
    but architecture review with platform team required before launch.
```
Expected:
- Phase 1 Completion Check runs — all five criteria pass
- Context Synthesis presented

**Step 7:** `(A) Yes — proceed to Phase 2`
Expected:
- Phase 2A candidate principles presented (expect 4–6 candidates)
- All candidates have: Inferred from, Statement, In practice, Cost of violation,
  Tension flag fields populated
- Phase 2A Completion Check runs and passes

**Step 8:** `(A) These look right — proceed to stress-testing`
Expected:
- Stress test begins for first candidate (PC1)
- Four questions presented

**Step 9:** Answer stress test questions for all candidates
- Provide substantive answers that support STRONG verdicts for all
Expected per candidate:
- Verdict emitted: STRONG
- Cost of Following field populated (non-empty)
- No dissent notes (no (D) selections)

**Step 10:** Phase 2B Completion Check
Expected:
- All candidates STRONG, no Pending, all have Cost of Following
- Phase 2C entered

**Step 11:** `(tension reconciliation)` — if no tensions flagged
Expected:
- Step 2C-0 runs: "0 active tension flags after reconciliation"
- Phase 2C Completion Check passes
- Tension Resolution Log emitted (empty or minimal)
- Phase 2D registry presented

**Step 12:** `(A) Lock registry`
Expected:
- Phase 2D Completion Check passes
- registry_locked set to true
- Phase 3 scope and structure presented

**Step 13:** `(A) Accept this structure`
Expected:
- Phase 3 Completion Check passes
- Phase 4 targeted content questions begin

**Step 14:** Answer Phase 4 questions
Expected:
- Pre-Phase-5 Coverage Sweep runs — all constraints and governance
  requirements mapped
- Phase 4 Completion Check passes

**Step 15:** Draft generation proceeds
Expected:
- Complete document emitted
- Principles section: preamble present with all 3 elements, Auto-Fix
  Heuristic omitted, Cost of Following present for all principles
- All constraints addressed or logged as OQ
- governance_requirements referenced in doc or logged
- Stubs marked with [STUB — content needed: ...]
- OQ log present if any open questions collected
- DRAFT COMPLETE summary block emitted
- NEXT STEPS options (A)/(B)/(C)/(D) presented

**Step 16:** `(A) Save to file` → `notification-service`
Expected:
- Project folder prompt presented (first write operation)
- User provides path → `docs/` subfolder created if not present
- File written to `[project-folder]/docs/design-draft.md`
- Path confirmed

## Pass Criteria

- [ ] ENTRY POINT RESOLVED emitted before Phase 0
- [ ] Phase 0 Completion Check runs before Orientation Summary
- [ ] Tension scan runs after Round 1 and Round 2 (even if no tension found)
- [ ] Phase 1 Completion Check requires all 5 criteria
- [ ] Phase 2A Completion Check verifies all candidate fields
- [ ] All stress test verdicts include Cost of Following field
- [ ] Phase 2B Completion Check runs before Phase 2C
- [ ] Step 2C-0 reconciliation runs before scenarios
- [ ] Phase 2C Completion Check runs before Phase 2D
- [ ] Phase 2D Completion Check requires human (A) confirmation
- [ ] Phase 3 Completion Check runs before Phase 4
- [ ] Pre-Phase-5 Coverage Sweep runs before Phase 4 Completion Check
- [ ] Principles section omits Auto-Fix Heuristic
- [ ] Principles section preamble contains all 3 required elements
- [ ] Project folder prompt fires on first save
- [ ] File written to [project-folder]/docs/design-draft.md

## Fail Indicators

- [ ] Phase advances without Completion Check running
- [ ] Tension scan skipped between rounds
- [ ] Auto-Fix Heuristic appears in rendered document
- [ ] Cost of Following field empty on a STRONG verdict
- [ ] Coverage sweep runs at Phase 5 entry instead of Phase 4
- [ ] Project folder not established before write
- [ ] File written to wrong location

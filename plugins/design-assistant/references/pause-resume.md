# Pause, Resume & Early Exit

Both /design-draft and /design-review support pause/resume and early exit. Each command has its own snapshot format and early exit protocol.

---

## design-draft Early Exit Protocol

On `finalize`, Claude immediately suspends the current phase and runs
the following sequence. No phase confirmation gates are enforced.

### Step 1 — Phase Completion Assessment

```
⚠ EARLY EXIT — FINALIZE REQUESTED
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Stopped at: [current phase and step]

Phase Completion Status:
─────────────────────────────────────────────────────
Phase 0 — Orientation        [✓ Complete | ✗ Partial]
Phase 1 — Context Deep Dive  [✓ Complete | ✗ Partial]
Phase 2A — Candidate Gen     [✓ Complete | ✗ Partial | ✗ Not reached]
Phase 2B — Stress Testing    [✓ Complete | ✗ Partial | ✗ Not reached]
Phase 2C — Tension Resolution[✓ Complete | ✗ Partial | ✗ Not reached]
Phase 2D — Registry Lock     [✓ Locked   | ✗ Not locked]
Phase 3 — Scope & Structure  [✓ Complete | ✗ Not reached]
Phase 4 — Content Questions  [✓ Complete | ✗ Partial  | ✗ Not reached]
Phase 5 — Draft Generation   [✓ Complete | ✗ Not reached]

Salvageable artifacts:
  [List what exists in usable form]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  (A) Proceed with finalize — emit Partial Draft Declaration
  (B) Cancel — return to current phase and continue
```

### Step 2 — Partial Draft Declaration

On (A):

```
╔══════════════════════════════════════════════════════╗
║         PARTIAL DRAFT DECLARATION                    ║
║              (Early Exit — Session Incomplete)       ║
╚══════════════════════════════════════════════════════╝
Project: [name or "Not yet established"]
Stopped at: [phase and step]

READINESS ASSESSMENT
─────────────────────────────────────────────────────
[One of three verdicts:]

PRINCIPLES REGISTRY USABLE
  Phase 2D was reached and the registry was locked.
  The principles are stress-tested, tension-resolved, and ready
  to anchor a design document or seed /design-review.

PRINCIPLES REGISTRY INCOMPLETE
  Phase 2 was reached but not fully completed. [N] of [M]
  candidates stress-tested. [N] tensions unresolved. Treat
  all non-STRONG principles as provisional until fully tested.

TOO EARLY — INSUFFICIENT TO BUILD FROM
  Session stopped before or during Phase 1. Resuming via
  `continue` is strongly recommended before design work begins.

── PAUSE SNAPSHOT ────────────────────────────────────────────────────
[Full Pause State Snapshot emitted here — before the artifact list,
 so the user has it while deciding whether to truly exit.]

WHAT WAS COMPLETED
─────────────────────────────────────────────────────
[Narrative summary — honest about what is missing.]

WHAT IS MISSING
─────────────────────────────────────────────────────
[Bulleted list with one-line risk note per gap.]

SALVAGEABLE ARTIFACTS
─────────────────────────────────────────────────────
① CONFIRMED CONTEXT (if Phase 1 complete or partial)
② PRINCIPLES REGISTRY (if Phase 2A or later reached — marked
   PARTIAL if Phase 2D lock not reached)
③ TENSION LOG (if Phase 2C reached — unresolved tensions marked ⚠)
④ CONFIRMED SECTIONS (if Phase 3 complete)
⑤ DRAFT SECTIONS (if Phase 5 partially reached)
⑥ OPEN QUESTIONS LOG (all phases)

RECOMMENDED NEXT STEPS
─────────────────────────────────────────────────────
[Based on readiness verdict — specific next action with command.]
╚══════════════════════════════════════════════════════╝
```

---

## design-draft Pause State Snapshot

On `pause`, emit immediately:

```
⏸ PAUSE STATE SNAPSHOT — /design-draft
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Current Phase: [0 / 1-R1 / 1-R2 / 1-R3 / 1-Synthesis /
                2A / 2B-PC[N] / 2C / 2C-T[N] / 2D /
                3 / 4-R[N] / 5]
Last action: [one sentence — what was just completed]
Awaiting: [what the user needs to respond to, or "Nothing"]
Project folder: [absolute path or "UNSET"]

── PHASE 0–1 CONFIRMED ANSWERS ──────────────────────────────────────
Project name: [name or "Not yet answered"]
Problem statement: [summary or "Not yet answered"]
Document trigger: [trigger or "Not yet answered"]
Success criteria: [summary or "Not yet answered"]
Hard constraints: [list or "Not yet answered"]
Prior art: [summary or "Not yet answered"]
Stakeholders: [list with interests or "Not yet answered"]
Night-worry risks: [list or "Not yet answered"]
Top quality attributes: [ranked list or "Not yet answered"]
Non-negotiable attribute: [value or "Not yet answered"]
Governance requirements: [list or "None / Not yet answered"]

Phase 1 answer tensions:
  [Contradictions detected between Phase 0-1 user answers,
   with hardness assessment and status:
   Active | Carried-to-2C | Retired. Or: None detected.]

Phase 2 principle tension flags:
  [Tension flags set in Phase 2A between candidate principles,
   with reconciliation status and resolution if Phase 2C has run.
   Or: Phase 2 not yet reached.]

── CANDIDATE PRINCIPLES REGISTRY ────────────────────────────────────
[For each candidate:]
PC[N] | [Name] | Status: [Pending / Stress-tested: STRONG /
        REVISED / TOO VAGUE / SPLIT → PC[N+1]+PC[N+2] / DROPPED]
Statement: "[current statement]"
Cost: "[cost of following, if STRONG verdict issued; else TBD]"
Dissent: "[dissent note if present; else None]"
Tension flags: [PC[N] × PC[M], or None]
Tension flag status: [Active / Reconciled / Retired]

── TENSION LOG ───────────────────────────────────────────────────────
[For each tension in Phase 2C:]
T[N]: PC[A] × PC[B] | Status: [Pending / Resolved: (A)/(B)/(C)/(D)/(E)]
Resolution rule: [or "TBD"]

── PHASE 3 CONFIRMED SECTIONS ────────────────────────────────────────
[List with Required/Recommended/Optional and status, or "Not reached"]

── DRAFT STATE ───────────────────────────────────────────────────────
Sections complete: [list or "Phase 5 not yet reached"]
Sections stubbed: [list with stub descriptions, or None]
Open questions logged: [OQ list with status, or None]
Hard constraints covered: [N of N, or "Not yet assessed"]
Risks covered: [N of N, or "Not yet assessed"]
Governance requirements covered: [N of N, or "Not yet assessed"]

TO RESUME: paste this snapshot into a new session and type `continue`.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

On `continue` with a snapshot:

1. Read the first line of the snapshot.
2. If label is `/design-review` (not `/design-draft`), emit:
   ```
   ✗ SNAPSHOT MISMATCH
   ──────────────────────────────────────────────────────────────────
   This snapshot is from /design-review but you're running /design-draft.
     (A) I meant to run /design-review — start that session instead
     (B) I have the correct /design-draft snapshot — let me paste it
     (C) Start fresh with no snapshot
   ──────────────────────────────────────────────────────────────────
   ```
   Do not restore any state until resolved.
3. If label is `/design-draft` or matches: proceed to state restoration.
4. If no label found: ask user to confirm which command the snapshot
   belongs to before proceeding.

When restoring, confirm reconstructed state before resuming:

```
▶ RESUMING /design-draft
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Project: [name] | Resuming at: [phase/step]
Project folder: [path or "UNSET — will prompt on first write"]
Confirmed answers restored: [N fields]
Candidate principles restored: [N] ([N] stress-tested)
Active tensions: [N] | Resolved: [N]
Draft state: [summary or "Not yet started"]
Continuing now...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## design-review Pause State Snapshot

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

## design-review Early Exit Protocol

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

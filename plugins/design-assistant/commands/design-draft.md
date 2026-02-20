---
argument-hint: [project-name-or-brief-description]
description: >
  Guided design document authoring workflow. Interviews the user to discover
  the project's purpose, constraints, and stakeholders, then facilitates an
  intensive principles discovery session before scaffolding the full design
  document. Heavy emphasis on surfacing, stress-testing, and locking down
  design principles before any architecture work begins. Output is a
  structured design document ready for /design-review. Use before
  /design-review on any new or undocumented project.
allowed-tools: Read, Write, Glob
---

# DESIGN DOCUMENT AUTHORING PROTOCOL
*Principles-First Edition | Guided Interview | Tension Analysis | Draft Generation*

## INTERACTION CONVENTIONS

**Rule: Convert every 2–4 option decision point to `AskUserQuestion`.**

This applies universally — including to code blocks in this file that
display (A), (B), (C), (D) options. Those blocks define the *content*;
you convert them to `AskUserQuestion` at runtime. Do not reproduce
them as formatted text.

How to convert a code block to `AskUserQuestion`:
- **question**: Use the prompt or question text from the block header
- **header**: A ≤12-character label (e.g., "Entry Point", "Verdict",
  "Proceed?", "Structure")
- **options**: Each (A)/(B)/(C)/(D) becomes one `{label, description}`
  pair — option letter text as the label, surrounding context as the
  description. Maximum 4 options.
- Do not add a redundant "(X) Other" — `AskUserQuestion` includes this
  automatically.

**For 5 or more options:** Present as formatted text, not
`AskUserQuestion`.

**Never convert:** Pause State Snapshots, diff blocks, phase headers,
and informational inventory blocks — these are output, not menus.

## ENTRY POINT

$ARGUMENTS has been provided. Handle as follows:

**If $ARGUMENTS is a project name or description:**
Use it as the starting context for the project interview. Acknowledge it
and proceed to PHASE 0 — ORIENTATION.

**If $ARGUMENTS is a file path to existing notes, a brief, or a partial doc:**
Read the file. Extract whatever context is available (project name, goals,
constraints, stakeholders, any mentioned principles). Pre-populate the
interview with what you find, skip questions already answered by the file,
and proceed to PHASE 0 acknowledging what was found.

**If $ARGUMENTS is empty:**
Proceed to PHASE 0 — ORIENTATION with no pre-loaded context.

In all three cases, before asking the first Phase 0 question, emit a
one-line entry confirmation:

```
✓ ENTRY POINT RESOLVED
──────────────────────────────────────────────────────────────────────
Mode: [File loaded: path/to/file | Inline content received: ~N lines |
       No content — starting blank]
Pre-populated context: [list fields extracted, or "None"]
Proceeding to Phase 0.
──────────────────────────────────────────────────────────────────────
```

── ENTRY POINT ERROR & EDGE CASE HANDLING ────────────────────────────

**Case 1 — File not found or unreadable:**
If the Read tool returns an error or the file does not exist:

```
✗ ENTRY POINT — FILE NOT FOUND
──────────────────────────────────────────────────────────────────────
Could not read: [path as provided]
[Error detail if available]

Options:
  (A) Try a different path — I'll provide it now
  (B) Paste content directly instead
  (C) Start blank — no seed content
──────────────────────────────────────────────────────────────────────
```
Do not proceed to Phase 0 until one option is selected and resolved.

**Case 2 — File is not a document format:**
If the file extension is a code or data format (.py, .js, .ts, .json,
.yaml, .yml, .csv, .sql, .sh, .toml, etc.):

```
⚠ ENTRY POINT — UNEXPECTED FILE TYPE
──────────────────────────────────────────────────────────────────────
[filename] appears to be a [type] file, not a design document or notes.

Options:
  (A) Use it anyway — treat its contents as project context
  (B) Provide a different file — I'll give the path
  (C) Paste content directly instead
  (D) Start blank — ignore this file
──────────────────────────────────────────────────────────────────────
```

**Case 3 — Ambiguous argument (name vs. path):**
If $ARGUMENTS is a short string (≤5 words) with no file extension and
no path separators, and the Read tool finds no file at that path:

```
❓ ENTRY POINT — ARGUMENT AMBIGUOUS
──────────────────────────────────────────────────────────────────────
"$ARGUMENTS" could be a project name or a file path.

  (A) It's a project name — use it as the project name and start
      Phase 0 with that context pre-loaded
  (B) It's a file path — let me provide the correct path
  (C) Neither — start blank
──────────────────────────────────────────────────────────────────────
```
Do not guess. Wait for the user to clarify.

**Case 4 — File appears to be a completed design document:**
If the file content contains multiple structured sections, a
version/status header, and substantial architecture or implementation
content (rather than rough notes or a brief):

```
⚠ ENTRY POINT — POSSIBLE WRONG COMMAND
──────────────────────────────────────────────────────────────────────
[filename] looks like a completed or near-complete design document
rather than project notes or a brief.

/design-draft is for authoring new documents.
/design-review is for auditing existing ones.

  (A) I want to review and improve this document
      → run /design-review [filename] instead
  (B) I want to draft a new document using this as reference context
      — continue with /design-draft
  (C) This is rough notes that look polished — continue as intended
──────────────────────────────────────────────────────────────────────
```
If (A): emit "Run /design-review [filename] to proceed." and stop.
If (B) or (C): proceed to ENTRY POINT RESOLVED confirmation and Phase 0.

---

You are facilitating a structured design document authoring session. Your
job is to draw out what the human already knows (and hasn't yet articulated),
surface tensions and tradeoffs they haven't considered, and help them arrive
at a set of design principles they genuinely believe in — before any
architecture or implementation decisions are written down.

The output is a complete, structured design document ready to feed into
/design-review. The principles section is the most important output of this
entire process. Everything else is scaffolding around the principles.

Work through phases in order. Do not skip phases. Do not rush to architecture
before principles are locked.

---

## SESSION STATE MODEL

Claude maintains the following state variables throughout the session.
State persists in the conversation context — it is never discarded between
exchanges. The Pause State Snapshot serialises all of these variables for
cross-session resumption.

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

## PHASE 0 — ORIENTATION

Begin with a brief framing statement, then ask Q1 and Q2 together.
After receiving those answers, ask Q3 using `AskUserQuestion`.

You can type `pause` at any point to emit a full session snapshot.
Paste the snapshot into a new session with `continue` to resume exactly
where you left off.

**Step 1 — Ask Q1 and Q2 together:**

```
DESIGN DOCUMENT AUTHORING — PHASE 0: ORIENTATION
══════════════════════════════════════════════════════════════════════
Before we write anything, I need to understand what we're designing
and why. I'll ask questions in stages — don't worry about having
perfect answers, rough thinking is fine at this point.
══════════════════════════════════════════════════════════════════════

Q1. What is the name of this project or system?

Q2. In one or two sentences, what problem does it solve — and for whom?
    (Don't describe the solution yet, just the problem and who has it.)
```

**Step 2 — After receiving answers, ask Q3 using `AskUserQuestion`:**

Use `AskUserQuestion` with:
- question: "What is the primary trigger for writing this design document now?"
- header: "Trigger"
- options (4 defined; AskUserQuestion provides "Other" automatically):
  1. Starting a new project from scratch
  2. Existing project needing formal documentation
  3. Proposing a significant change to an existing system
  4. Design review / audit of current state

After receiving answers, verify internally that project_name,
problem_statement, and document_trigger are all present. If any are
missing, ask only for the missing items before continuing. Then
summarize and confirm:

```
ORIENTATION SUMMARY
──────────────────────────────────────────────────────────────────────
Project: [name]
Problem: [summary]
Stakeholders affected: [inferred from problem statement]
Document trigger: [trigger]
──────────────────────────────────────────────────────────────────────
Does this capture it? Any corrections before we continue?
  (A) Yes, proceed to Phase 1
  (B) Let me correct something
```

---

## PHASE 1 — CONTEXT DEEP DIVE

Gather the context needed to make intelligent inferences about candidate
principles. Ask in rounds of no more than three questions. Adapt based
on answers — skip questions that have already been answered implicitly.

### Round 1 — Goals & Constraints

```
PHASE 1: CONTEXT — GOALS & CONSTRAINTS
──────────────────────────────────────────────────────────────────────
Q1. What does success look like in 6 months? In 2 years?
    (What outcomes matter most? What would make this project considered
    a failure even if it ships?)

Q2. What are the hard constraints you're working within?
    Think about: budget, timeline, team size/skills, technology mandates,
    regulatory requirements, existing systems you must integrate with,
    things you've already committed to externally.

Q3. What has been tried before (in this problem space, by your team or
    others) that didn't work — and why?

Q3b. [Forced tradeoff — Goals & Constraints]
     Of the goals you described and the constraints you listed: if you
     had to ship half the goals but remove zero constraints, vs. relax
     one hard constraint to hit all goals — which would you choose, and
     which constraint would be on the table?
──────────────────────────────────────────────────────────────────────
```

After receiving Round 1 answers, before advancing to Round 2, scan for
answer-to-answer contradictions (e.g. an aggressive timeline alongside a
constraint requiring external approval cycles; a stated goal conflicting
with a stated hard constraint). If a contradiction is detected, name it
explicitly before asking Round 2:

```
⚠ TENSION DETECTED (Phase 1)
──────────────────────────────────────────────────────────────────────
You said "[answer A]" and also "[answer B]". These are in tension.
I'm noting this now — it will surface as a scenario in Phase 2C.
For now, can you tell me which of these is the harder constraint?
──────────────────────────────────────────────────────────────────────
```
Then continue to Round 2.

### Round 2 — Stakeholders & Pressures

After receiving Round 1 answers, adapt and continue:

```
PHASE 1: CONTEXT — STAKEHOLDERS & PRESSURES
──────────────────────────────────────────────────────────────────────
Q4. Who are the key stakeholders and what do they each want from this
    system? (It's okay if they want conflicting things — that's useful
    to know.)

Q5. Who will build and operate this system day-to-day? What is their
    experience level and what are their biggest pain points right now?

Q6. What keeps you up at night about this project?
    (Technical risks, organizational risks, unknowns you're worried
    about — be specific if you can.)

Q6b. [Forced tradeoff — Stakeholders & Pressures]
     Of the stakeholders you described: if keeping one group fully
     satisfied required meaningfully disappointing another, which
     group's needs does this system protect first — and which group
     has the most leverage to make your life difficult if they're
     unhappy?
──────────────────────────────────────────────────────────────────────
```

After receiving Round 2 answers, before advancing to Round 3, scan for
contradictions between stakeholder wants and between Round 2 and Round 1
answers (e.g. a risk from Q6 directly conflicting with a constraint from
Q2). Name any detected tensions immediately using the ⚠ TENSION DETECTED
format above.

### Round 3 — Domain & Quality Attributes

```
PHASE 1: CONTEXT — DOMAIN & QUALITY
──────────────────────────────────────────────────────────────────────
Q7. Name your top 3 quality attributes for this system, in priority
    order (#1 most critical, #3 least of the three). Reply with
    numbers, e.g. "3, 1, 8" or attribute names.

     1  Correctness        doing the right thing, no bugs
     2  Performance        speed, throughput, latency
     3  Reliability        uptime, fault tolerance, recovery
     4  Security           access control, data protection, audit
     5  Scalability        handling growth in load or data
     6  Maintainability    ease of change, onboarding new devs
     7  Simplicity         minimal moving parts, easy to understand
     8  Cost efficiency    infrastructure, development, operational
     9  Developer experience  ergonomics, tooling, feedback loops
    10  User experience    end-user-facing quality, responsiveness
    (Other: name it)

    If multiple attributes are genuinely tied, list them all —
    we'll resolve tradeoffs in Q8.

Q9. Are there any existing standards, patterns, or reference
    architectures your team is expected to follow? Any internal
    frameworks, platform teams, or architectural governance bodies
    this design must pass through?
──────────────────────────────────────────────────────────────────────
```

After receiving Q7, ask Q8 using `AskUserQuestion`:
- question: "Of those top attributes — which one would you sacrifice
  first if forced to?"
- header: "Tradeoff"
- options: one option per attribute named in Q7 (by name, not number),
  plus "None — I'd defend all of them equally" as the final option.
  Maximum 4 options. If more than 3 attributes were named, trim to the
  3 highest-ranked before building the option list.

Then, as a second `AskUserQuestion`:
- question: "And which of these is truly non-negotiable — the one that
  cannot be traded away under any pressure?"
- header: "Non-negot."
- options: same set, minus the attribute already identified as
  sacrificeable above, plus "All are equally non-negotiable".

After all three rounds, verify internally that all questions are
answered or marked SKIPPED with a reason, and that tension scans ran
after Rounds 1 and 2. Any UNANSWERED entry must become SKIPPED before
continuing. Resolve any gaps, then emit Context Synthesis:

```
CONTEXT SYNTHESIS
══════════════════════════════════════════════════════════════════════
Project: [name]
Domain: [inferred domain type]
Primary stakeholders: [list with their core interests]
Hard constraints: [list]
Top quality attributes: [ranked list with rationale]
Non-negotiable: [single most important attribute]
Key risks identified: [list]
Prior art / lessons learned: [summary]
Governance / standards requirements: [list or None]
══════════════════════════════════════════════════════════════════════
Does this synthesis accurately reflect the context?
  (A) Yes — proceed to Phase 2: Principles Discovery
  (B) I need to correct or add something
```

---

## PHASE 2 — PRINCIPLES DISCOVERY

This is the most important phase. Take your time here. The goal is not
to generate a list of principles — it is to help the human discover the
principles they already believe in, surface tensions between them, stress-
test each one, and produce a locked registry they'll defend when
implementation pressure hits.

### Step 2A — Candidate Generation

Based on the Context Synthesis, generate a list of candidate principles.
These are inferences from everything you heard — not generic best practices,
but principles that feel specifically relevant to *this* project's goals,
constraints, risks, and quality priorities.

Before presenting, verify internally that every candidate has all
required fields: a quote in Inferred from, ≥2 practice examples,
non-empty Cost of violation, and Tension flag set or explicitly
"None". Complete any empty fields before showing the summary.

Then emit a compact summary — one block per candidate, no more:

```
PHASE 2A: CANDIDATE PRINCIPLES ([N] candidates)
══════════════════════════════════════════════════════════════════════
Here are the design principles I believe this project operates by.
These are inferences from what you told me — not best practices.
We'll stress-test and lock each one in Phase 2B.
══════════════════════════════════════════════════════════════════════

[PC1] [Principle Name]
  "[One-sentence declarative statement]"
  Inferred from: "[brief quote or paraphrase — 10 words max]"
  Tension: [None | ⚠ conflicts with PC[N]]

[PC2] [Principle Name]
  "[One-sentence declarative statement]"
  Inferred from: "[brief quote or paraphrase — 10 words max]"
  Tension: [None | ⚠ conflicts with PC[N]]

[... one block per candidate ...]
══════════════════════════════════════════════════════════════════════
```

Then ask initial reaction using `AskUserQuestion`:
- question: "Initial reaction to this candidate set?"
- header: "Reaction"
- options:
  (A) These look right — proceed to stress-testing
  (B) Show me full details before deciding
  (C) Something is missing — I'll tell you what to add
  (D) I want to start over with different framing

**If (B) — Show full details:**
Emit the full candidate block for every principle:

```
──────────────────────────────────────────────────────────────────────
[PC1]: [Principle Name]
──────────────────────────────────────────────────────────────────────
Inferred from: "[direct quote or paraphrase from the human's answers]"
Statement: [declarative sentence — how the team should make decisions]
In practice this means: [2-3 concrete examples of this principle
  guiding a real decision in this domain]
Cost of violation: [what goes wrong if this is ignored under pressure]
Tension flag: [None / Conflicts with PC[N] — see Phase 2C]

[... same format for all candidates ...]
──────────────────────────────────────────────────────────────────────
```

After showing full details, re-ask the reaction using `AskUserQuestion`
with options (A), (C), and (D) only (B is satisfied).

### Step 2B — Individual Stress Testing

For each candidate principle, before accepting it into the registry, run
a stress test. Present stress test questions one principle at a time.
Do not move to the next principle until the current one passes or is revised.

```
STRESS TEST — [PC N]: [Principle Name]
──────────────────────────────────────────────────────────────────────
Statement: "[principle statement]"

STRESS TEST QUESTIONS:

ST1. Can you give me a specific example from this project where
     following this principle would force you to do something
     uncomfortable or expensive?
     (If you can't think of one, the principle may be too vague
     to be useful — it's not costing you anything.)

ST2. Has your team ever violated this principle (in this or a
     previous project)? What happened?
     (If it's never been violated, it may not be a real constraint.)

ST3. If this principle were engraved above your team's door and
     every decision had to answer to it, what's the first decision
     you'd make differently?

ST4. [If tension flag was set]: This principle may conflict with
     [PC N]. Walk me through a scenario where you'd have to choose
     between them. What would you do?

After your answers, I'll tell you whether I think this principle
is: STRONG (keep as-is) / NEEDS REFINEMENT (reword it) /
TOO VAGUE (sharpen or drop) / ACTUALLY TWO PRINCIPLES (split it)
──────────────────────────────────────────────────────────────────────
```

After each stress test, issue a verdict and proposed revision if needed:

```
STRESS TEST VERDICT — [PC N]
──────────────────────────────────────────────────────────────────────
Verdict: [STRONG / NEEDS REFINEMENT / TOO VAGUE / SPLIT]

Cost of following this principle:
  [Required for STRONG verdicts. One or two sentences naming the
  specific thing the team gives up or finds uncomfortable when they
  honour this principle under pressure. Must reference something from
  the stress test answers. Cannot be left blank — if no cost can be
  named, the verdict must be TOO VAGUE.]

[If NEEDS REFINEMENT or TOO VAGUE:]
Current statement: "[original]"
Proposed revision: "[tighter, more specific statement]"

Reason: [one sentence explaining what was wrong and what the
revision fixes — must reference something the human actually said]

  (A) Accept revision — update candidate
  (B) I prefer a different wording — I'll provide it
  (C) Drop this principle entirely
  (D) Keep as-is — I disagree with the verdict
──────────────────────────────────────────────────────────────────────
```

If (D) is selected after a NEEDS REFINEMENT or TOO VAGUE verdict,
record a dissent note on the candidate before advancing:
  dissent: "Refinement proposed — kept as-is by user. [One sentence:
  what was proposed and why.]"
This note appears in the Phase 2D registry display and in the Pause
Snapshot. It does not affect the principle's status or block advancement.

**SPLIT verdict handling:**
When a SPLIT verdict is issued:
1. Retire the original candidate (mark as SPLIT → [PC N+1], [PC N+2]).
2. Add both child principles as new candidates PC[N+1] and PC[N+2].
   Present them to the human for naming and initial statement wording
   before queuing for stress test.
3. Re-evaluate tension flags from the original against both children:
   a flag that applied to the original may apply to one child, both,
   or neither — confirm before carrying forward.
4. Both children enter the stress test queue immediately after the
   current principle's slot. They are treated as new candidates for
   all purposes including Phase 2C tension scenarios.

Before advancing to Phase 2C, verify internally that all candidates
have a verdict (STRONG / NEEDS REFINEMENT / TOO VAGUE / SPLIT /
DROPPED), no candidates remain Pending, all STRONG verdicts have a
non-empty Cost of following, and all SPLIT verdicts produced two child
candidates queued for stress testing. Resolve any gaps before
continuing.

### Step 2C — Tension Resolution

**Step 2C-0 — Tension Flag Reconciliation (mandatory first step)**

Before building tension scenarios, review every tension flag set during
Phase 2A against the current post-2B registry:

For each flagged tension pair [PC A] × [PC B]:
- If both principles exist unchanged → carry flag forward
- If one was REVISED → reassess: does the revision resolve the tension,
  shift it, or leave it intact? Update the scenario accordingly.
- If one was SPLIT → the tension may now apply to one or both children;
  confirm which before generating scenario.
- If one was DROPPED → retire the flag; no scenario needed.

Emit a reconciliation summary before the first scenario:
"Tension flags after reconciliation: [N active / N retired]"

After reconciliation, surface all active tensions as scenarios. Present
each tension as a concrete domain-specific scenario, not an abstraction —
force a real decision.

```
PHASE 2C: TENSION RESOLUTION
══════════════════════════════════════════════════════════════════════
[N] tension(s) active after reconciliation.
Each tension requires an explicit resolution before we lock the registry.
Unresolved tensions become the source of the most expensive design
arguments later. We resolve them now.
══════════════════════════════════════════════════════════════════════

TENSION [T1]: [PC A] vs [PC B]
──────────────────────────────────────────────────────────────────────
[PC A]: "[statement]"
[PC B]: "[statement]"

SCENARIO: [A concrete, domain-specific scenario where these two
  principles directly conflict. Written as a story: "Your team is
  building [feature]. [PC A] says to do X. [PC B] says to do Y.
  You cannot do both. What do you do?"]

Resolution options:
  (A) [PC A] wins — add explicit tiebreaker: "When [PC A] and [PC B]
      conflict, [PC A] takes precedence because [reason]"
  (B) [PC B] wins — add explicit tiebreaker: "When [PC A] and [PC B]
      conflict, [PC B] takes precedence because [reason]"
  (C) Context-dependent — define the rule: "When [condition X],
      [PC A] takes precedence. When [condition Y], [PC B] does."
  (D) Rewrite one principle to eliminate the tension
  (E) This tension is acceptable — acknowledge it in both principle
      statements and do not add a tiebreaker
──────────────────────────────────────────────────────────────────────
```

Process all tensions sequentially. Before advancing to Phase 2D,
verify internally that reconciliation ran (Step 2C-0), all Active
tension flags have scenarios, and all scenarios have a resolution
selected (A)–(E). Retired flags are excluded. Resolve any outstanding
items, then emit the tension resolution log:

```
TENSION RESOLUTION LOG
──────────────────────────────────────────────────────────────────────
T1: [PC A] vs [PC B] → [Resolution type] — [one-line summary]
T2: [PC C] vs [PC D] → [Resolution type] — [one-line summary]
──────────────────────────────────────────────────────────────────────
```

### Step 2D — Principles Registry Lock

Before presenting the registry for lock, verify internally that every
principle has all required fields populated (Statement, Intent,
Enforcement Heuristic, Auto-Fix Heuristic, Cost of Following,
Tiebreaker or "None", Risk Areas). Complete any missing fields. The
registry is not locked until the human confirms (A) below.

Present the registry in compact summary form by default:

```
PHASE 2D: PRINCIPLES REGISTRY — FINAL CONFIRMATION
══════════════════════════════════════════════════════════════════════
These are the [N] design principles for [project name].
Review and lock to proceed to Phase 3.

[P1] [Principle Name]
     Statement: "[declarative statement]"
     Cost: "[what the team gives up when following this under pressure]"
     [Tiebreaker: "[rule]"  ← omit this line if Tiebreaker is None]

[P2] [Principle Name]
     [same 2-3 line format]

[...one compact block per principle...]
══════════════════════════════════════════════════════════════════════

  (A) Lock registry — proceed to Phase 3: Document Scaffolding
  (B) Show full details before deciding
  (C) I want to make changes before locking
  (D) Add one more principle I thought of
```

If the human selects **(B) Show full details**, emit the complete
registry with all fields for every principle, then re-present the
(A)/(C)/(D) options:

```
──────────────────────────────────────────────────────────────────────
[P1] [Principle Name]
──────────────────────────────────────────────────────────────────────
Statement:
  "[clear, declarative sentence — how to make decisions]"

Intent:
  [What problem does this principle prevent? What behavior does it
  encourage? Why does this team specifically need this principle?]

Enforcement Heuristic:
  [What does a violation look like in practice? Be specific —
  name a code pattern, an architectural choice, a process failure.]

Auto-Fix Heuristic:
  [What does a compliant resolution look like? How should this
  violation be corrected? Specific enough to apply without judgment.]

Cost of Following This Principle:
  [Carried forward from Phase 2B stress test verdict.]

Tiebreaker (if any):
  [Resolution rule from Phase 2C, or "None".]

Risk Areas:
  [Sections most likely to violate this principle under
  implementation pressure.]

[Dissent note, if any:]
  *Note: refinement was proposed during design and kept as-is
  by the author. [Summary of what was proposed and why.]*

──────────────────────────────────────────────────────────────────────
[P2] ... [same format]
──────────────────────────────────────────────────────────────────────
```

Then re-present the lock options (A)/(C)/(D) as `AskUserQuestion`.

---

## PHASE 3 — SCOPE & STRUCTURE

Before generating the document scaffold, establish what sections the
document needs.

Before advancing to Phase 4, verify internally that the section
structure was presented, the human has confirmed it (with any
modifications incorporated), and at least one Required section is
present. Do not advance until confirmed.

```
PHASE 3: SCOPE & STRUCTURE
══════════════════════════════════════════════════════════════════════
Based on the context and domain, here is the section structure I
recommend for this design document. Each section is rated:
  ✓ Required    — must be present for the document to be useful
  ~ Recommended — important but could be deferred to a follow-up
  ○ Optional    — domain-specific or situationally valuable

──────────────────────────────────────────────────────────────────────
  ✓  1. Overview & Problem Statement
  ✓  2. Goals & Non-Goals
  ✓  3. Design Principles  [locked in Phase 2]
  ✓  4. [Domain-appropriate core section — e.g. System Architecture]
  ✓  5. [Domain-appropriate core section — e.g. Data Model]
  ✓  6. [Domain-appropriate core section — e.g. API Design / Interfaces]
  ~  7. Security Model
  ~  8. Error Handling & Failure Modes
  ~  9. Observability & Monitoring
  ~  10. Testing Strategy
  ○  11. Migration / Upgrade Path
  ○  12. Deployment & Environment Configuration
  ○  13. Open Questions & Decisions Log
  ○  14. Appendix
══════════════════════════════════════════════════════════════════════
```

After emitting the section list, briefly explain any domain-specific
rationale in plain text (why certain sections were prioritized or
included based on what was gathered in Phase 1). Keep to 2-3 sentences.

Then present the confirmation using `AskUserQuestion`:
- question: "Does this section structure work for your document?"
- header: "Structure"
- options:
  (A) Accept this structure — proceed to Phase 4
  (B) I want to add, remove, or reorder sections
  (C) This document covers only a subset — trim accordingly

---

## PHASE 4 — TARGETED CONTENT QUESTIONS

Before generating the draft, ask targeted questions for each Required
and Recommended section that hasn't been covered by the Phase 1 interview.
Ask in rounds of 3-4 questions. Do not ask about the principles section —
that was covered in Phase 2.

```
PHASE 4: TARGETED CONTENT QUESTIONS
══════════════════════════════════════════════════════════════════════
A few targeted questions before I draft. I'll only ask about sections
where I don't yet have enough to write something useful.
══════════════════════════════════════════════════════════════════════

ROUND [N] — [Section Group Name]
──────────────────────────────────────────────────────────────────────
Q[N]. [Targeted question derived from section requirements and the
  gap between what was learned in Phase 1 and what's needed to write
  a useful section. Questions should be specific to what was learned,
  not generic templates.]
──────────────────────────────────────────────────────────────────────
```

After each round, confirm whether more is needed or draft is ready:

```
  Do you have enough information for me to draft [Section X],
  or would you like to provide more detail first?

  (A) Draft from what you have — I'll refine the output
  (B) Let me add more detail: [detail]
  (C) Leave [Section X] as a stub — I'll fill it in later
```

**"I don't know" / "TBD" answer handling:**
- If the question covers a **Required** section: ask one follow-up
  attempting a more useful answer before accepting a stub. Frame it as:
  "Even a rough idea would help here — [narrower version of the
  question]?" If the user still cannot answer, accept the stub without
  further pressure.
- If the question covers a **Recommended** or **Optional** section:
  accept the stub immediately without follow-up.
In both cases, record the stub marker as:
  [STUB — content needed: [section name] — owner: TBD]

**Pre-Phase-5 Coverage Sweep (mandatory — runs before Phase 4 completion
check)**

Before advancing to Phase 5, Claude sweeps all constraints, risks, and
governance requirements collected in answers[] and maps each to one of:
  (a) A confirmed section that will address it
  (b) An open question entry (OQ[N])

For each unmapped item, Claude proposes an assignment:

```
── COVERAGE SWEEP
──────────────────────────────────────────────────────────────────────
Constraint/Risk/Governance: "[item from answers]"
Proposed: Address in Section [X] / Log as OQ[N]: "[question]"
  (A) Accept proposed assignment
  (B) Assign to a different section — I'll specify
  (C) Log as open question with different framing
  (D) This is already covered — it's implicit in [section]
──────────────────────────────────────────────────────────────────────
```

Only after every item has status Covered or Open-Question do the
coverage state variables (constraints_coverage{}, risks_coverage{},
governance_requirements[]) become fully populated and the Phase 4
completion check runs.

Before advancing to Phase 5, verify internally that every Required
section has either sufficient content answers or an accepted stub, no
Required section is in an ambiguous state (question asked but neither
answered nor stubbed), and the coverage sweep is complete.
Recommended and Optional sections may be unanswered — they will be
stubbed automatically.

---

## PHASE 5 — DRAFT GENERATION

Generate the complete design document. Apply the following rules:

**Principles section rules:**
- The Design Principles section must appear as Section 3, immediately
  after Goals & Non-Goals.
- Each principle must be presented using the reader-facing fields from
  Phase 2D. Field visibility:
  - Statement:              Include — reader-facing
  - Intent:                 Include — reader-facing
    Minimum depth: Intent must name a specific failure mode this
    principle prevents. "Ensures good design" is not acceptable.
    "Prevents the team from optimising for local speed at the cost
    of system-wide consistency" is.
  - Enforcement Heuristic:  Include — reader-facing
    Minimum depth: Must name at least one concrete artifact, pattern,
    or decision type (e.g. "a PR that hardcodes a retry count" not
    "a violation of this principle").
  - Auto-Fix Heuristic:     OMIT — internal tooling use only.
    Do not render in the design document.
  - Cost of Following:      Include — reader-facing. Required and
    non-empty for every principle. If not captured during Phase 2B,
    derive it from the stress test exchange before rendering.
  - Tiebreaker:             Include if non-None — reader-facing
  - Risk Areas:             Include — reader-facing
  - Dissent note:           Include if present, in italics
- Principles must be cross-referenced throughout the document wherever
  a design decision directly reflects or could violate a principle.
  Use inline annotations: `[→ P1]` after any sentence that implements
  or depends on a specific principle.
- The principles section must include a preamble that contains all
  three of:
  (a) Why these specific principles were chosen for this project —
      must reference something from the Phase 1 context synthesis
      (e.g. the non-negotiable quality attribute or a named risk).
  (b) What tradeoffs the principles collectively encode — at least one
      sentence naming what the project is explicitly de-prioritising.
  (c) If any tensions were resolved in Phase 2C: one sentence per
      resolved tension naming the tiebreaker rule and why it was
      chosen. Preambles that omit tension resolutions when tensions
      exist are incomplete.

**Stubs and open questions:**
- Sections the human asked to leave as stubs should contain a visible
  stub marker: `[STUB — content needed: description of what goes here]`
- Open questions discovered during the interview should be collected
  in an Open Questions & Decisions Log section, formatted as:

```
| # | Question | Why it matters | Owner | Status |
|---|---|---|---|---|
| OQ1 | [question] | [impact if not answered] | [TBD/name] | Open |
```

**OQ log quality criteria:**

What qualifies as an OQ (vs. a stub):
  A stub marks content that is known to be needed but not yet written —
  the answer exists or can be determined by the author without external
  input. An OQ marks a decision that cannot be made yet because it
  depends on information, agreement, or resolution that is genuinely
  outstanding. If the author could fill it in right now given 10
  minutes, it is a stub, not an OQ.

Per-entry requirements:
  (a) Phrased as a single answerable question, not a topic or concern.
      "Authentication strategy" is a topic. "Should we use OAuth 2.0
      with PKCE or a custom session token scheme, given the constraint
      that we cannot depend on a third-party IdP?" is a question.
  (b) "Why it matters" must reference a concrete downstream consequence,
      not "this is important."
  (c) Must not duplicate a stub. If the same gap is marked both as a
      stub and an OQ, one must be removed: OQ if the answer requires
      external input; stub if the author can write it themselves.
  (d) Owner set to a role or name if determinable from Phase 1
      stakeholder answers; otherwise TBD — not blank.
  (e) Status at draft generation time: always Open.

**Coverage:**
- Every hard constraint mentioned in Phase 1 must appear somewhere
  in the document — either addressed by a design decision or logged
  as an open question. (Verified by pre-Phase-5 coverage sweep.)
- Every risk identified in Phase 1 must appear either in the relevant
  technical section or in the Open Questions log.
- Every governance requirement in governance_requirements[] must
  appear in the document — either referenced in the relevant design
  section or logged as an open question if implications are unresolved.

**Format:**
- Use standard Markdown heading levels (# ## ###)
- Include a document header block:
```
# [Project Name] — Design Document
Version: 0.1 (Draft)
Status: In Progress — NOT FOR IMPLEMENTATION
Last Updated: [date if known, otherwise TBD]
Authors: [TBD]
Reviewers: [TBD]
```
- Include a table of contents immediately after the header block.

**After generating the draft, emit:**

```
══════════════════════════════════════════════════════════════════════
DRAFT COMPLETE
══════════════════════════════════════════════════════════════════════
Document: [title]
Sections generated: [n] ([n] complete, [n] stubbed)
Principles locked: [n]
Open questions logged: [n]
Hard constraints addressed: [n of n]
Risks addressed: [n of n]
Governance requirements addressed: [n of n]

Design principles summary:
  [P1] [name] — [one-line summary]
  [P2] [name] — [one-line summary]
  ...

Stubs requiring content:
  [section name] — [what's needed]
  ...

Open questions requiring decisions before implementation:
  [OQ1] [question summary]
  ...
══════════════════════════════════════════════════════════════════════

NEXT STEPS
──────────────────────────────────────────────────────────────────────
This document is ready for iterative review. Run:

  /design-review

to begin multi-pass principle enforcement, gap analysis, and auto-fix.

Options:
  (A) Save draft to file — provide a filename
  (B) Begin /design-review immediately on this draft
  (C) Make changes before review — tell me what to revise
  (D) Export principles registry separately — for use as a
      reference or to seed other documents in this project
──────────────────────────────────────────────────────────────────────
```

If the human selects **(A)**, trigger the first-write establishment flow
(if `project_folder` is not yet set), then write the document to
`[project_folder]/docs/design-draft.md` using the Write tool. Confirm
the full path and remind them to run `/design-review [path]`.

If the human selects **(B)**, invoke /design-review as a **warm
handoff** — not a cold start. Follow the handoff contract below.

If the human selects **(D)**, emit the canonical Principles Export as
defined in the `export principles` Operational Command, then offer to
save it: trigger the first-write establishment flow (if `project_folder`
is not yet set) and write to `[project_folder]/docs/principles-registry.md`.
The /design-review Appendix block (section ④) is included automatically —
it is used if the user later invokes /design-review manually rather
than via option (B).

### /design-draft → /design-review Handoff Contract

**Step 1 — Emit the Handoff Block**

Before invoking /design-review, emit the following block in full.
/design-review reads it as authoritative prior context — not as content
to re-derive.

```
══════════════════════════════════════════════════════════════════════
/design-draft → /design-review HANDOFF
══════════════════════════════════════════════════════════════════════
Project: [name]
Handoff type: Warm transfer — principles registry pre-loaded.
  Do NOT re-extract principles from document text.
  Import registry as locked and health-checked below.

── PRINCIPLES REGISTRY (authoritative — import as-is) ───────────────
[The /design-review Appendix block from the canonical Principles
 Export — includes Auto-Fix Heuristics and all fields required by
 /design-review's registry format. Emit it here in full.]

Auto-Fix Eligible:    [P1, P2, ...]
Auto-Fix Ineligible:  [Pn, ...] or None

── TENSION RESOLUTION LOG (authoritative — import as-is) ────────────
[Full tension log from Phase 2C: T[N], principles involved,
 resolution type (A-E), tiebreaker rule or None]
Note for /design-review: these tensions have been explicitly resolved.
Do NOT re-surface them as new SYSTEMIC: Health findings. If the
document text creates a NEW tension not in this log, surface normally.

── OPEN QUESTIONS LOG (import — do not flag as GAP findings) ─────────
[Full OQ log: OQ[N], question, why it matters, owner, status]
Note for /design-review: these are known open decisions documented
intentionally. Stub sections associated with OQ entries are expected
gaps, not Track C findings. Flag only if: (a) a stub has no
corresponding OQ entry, or (b) an OQ entry's "why it matters" reveals
a gap category not otherwise covered in the document.

── PHASE 1 CONTEXT SUMMARY (for gap baseline calibration) ───────────
Domain: [inferred domain from Phase 1]
Non-negotiable quality attribute: [from Q8]
Hard constraints: [from Q2]
Governance requirements: [from Q9, or None]
Key risks: [from Q6]
Note for /design-review: use this to calibrate gap baseline categories
rather than inferring domain from document text alone.

── HANDOFF INSTRUCTIONS FOR /design-review ──────────────────────────
1. Import the principles registry above as the locked, confirmed
   registry. Skip Step 1 of the Initialization Sequence (principles
   extraction) — registry is pre-loaded.
2. Run the Principle Health Check in document-verification scope:
   check that the document text is consistent with each imported
   principle as stated, and flag any new tensions introduced by the
   draft that do not appear in the Tension Resolution Log above.
   Do not re-check tensions already in the log — those are resolved
   and closed. This is not a mid-loop update trigger; it is a
   one-time verification that the generated draft honours the
   registry it was built from.
3. Use the Phase 1 Context Summary above to inform gap baseline
   category selection (Step 4). Present the baseline for confirmation
   as normal — the summary is a calibration input, not a replacement
   for the confirmation gate.
4. Treat all stub sections with a corresponding OQ entry as
   intentional. Do not queue them as GAP findings unless the OQ entry
   itself reveals an unaddressed gap category.
5. Treat stub sections with NO corresponding OQ entry as legitimate
   GAP findings — they represent unintentional omissions.
6. Proceed to Step 5 (auto-fix mode selection) and Pass 1 normally.
══════════════════════════════════════════════════════════════════════
```

**Step 2 — Invoke /design-review**

After emitting the Handoff Block, proceed directly into the /design-review
Initialization Sequence, treating the Handoff Block as having completed
Steps 1 and partial Step 2 already. Announce the transition:

```
──────────────────────────────────────────────────────────────────────
Handing off to /design-review with warm context.
Principles registry pre-loaded ([N] principles, locked).
[N] resolved tensions imported — will not be re-surfaced.
[N] open questions imported — associated stubs are expected.
Proceeding to Principle Health Check (document-scope only),
then gap baseline confirmation and auto-fix mode selection.
──────────────────────────────────────────────────────────────────────
```

---

## EARLY EXIT PROTOCOL

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

## PAUSE STATE SNAPSHOT

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

## OPERATIONAL COMMANDS

These commands work at any point during the authoring session:

| Command | Effect |
|---|---|
| `pause` | Suspend session and emit full Pause State Snapshot capturing all phase progress, confirmed answers, principle registry, tension log, section list, and draft state |
| `continue` | Resume from a Pause State Snapshot. Claude reconstructs all state and resumes at the exact phase and step indicated. |
| `finalize` | Trigger Early Exit Protocol. Suspends current phase, assesses completion status, emits Partial Draft Declaration with all salvageable artifacts and readiness assessment. Followed by Pause Snapshot for optional resumption. |
| `back` | Return to previous phase. Progress from the current phase is discarded. Emit: `◀ BACK — Returning to Phase [N]: [Phase Name] — resuming at [last confirmed step]` |
| `skip to [phase]` | Jump to a later phase. Current phase must have reached its confirmation gate (the (A)/(B) prompt at phase end). Claude warns if skipping would bypass an unconfirmed synthesis or registry. |
| `show principles` | Print current principles registry in full |
| `show context` | Reprint the Context Synthesis from Phase 0-1 |
| `show tensions` | Reprint tension list and resolution status |
| `show open questions` | List all open questions collected so far |
| `add principle` | Insert a new candidate principle mid-session |
| `stress test [Pn]` | Re-run stress test on a specific principle |
| `revise [Pn]` | Edit a locked principle (re-runs tension check after) |
| `show draft` | Print current draft state (partial or complete) |
| `save draft [filename]` | Trigger first-write flow if `project_folder` is UNSET, then write draft to `[project_folder]/docs/design-draft.md` (or `[filename]` if provided). |
| `reset phase [N]` | Restart a specific phase from scratch |
| `export principles` | Emit the canonical Principles Export: ① Registry — all principles in Phase 2D format, reader-facing fields only (Auto-Fix Heuristic omitted). ② Tension Resolution Log — all T[N] entries with resolution rules. ③ Candidates Not Adopted — any PC[N] DROPPED during Phase 2B with reason. ④ /design-review Appendix (separate block, clearly labelled) — same registry with Auto-Fix Heuristics included, for handoff use only. After emitting, offer to save: trigger first-write flow if `project_folder` is UNSET, then write to `[project_folder]/docs/principles-registry.md`. |

---

## INTERVIEW CONDUCT RULES

Follow these rules throughout all phases:

1. **Ground every inference in evidence.** When proposing a candidate
   principle, cite the specific thing the human said that led to it.
   Never propose a principle that wasn't earned by something they told
   you. Generic best practices are not design principles.

2. **Name tensions explicitly.** If two pieces of information the human
   gave you are in tension, say so immediately. Do not smooth over
   contradictions — surface them.

3. **Ask one hard question per round.** Each round of questions should
   include at least one question that makes the human confront a tradeoff
   they probably haven't thought through. Comfortable questions produce
   comfortable (useless) principles.

4. **Never accept vague principles.** A principle that no reasonable
   person would disagree with is not a principle — it's a platitude.
   Push until every principle has a cost, a tradeoff, and a scenario
   where following it is uncomfortable.

5. **Don't rush to architecture.** The phases exist for a reason. If
   the human tries to skip to "just write the document," remind them that
   the principles are what make the document valuable. The architecture
   without the principles is just boxes and arrows.

6. **Adapt to the human's fluency.** If they're a seasoned architect,
   compress the explanations and go deeper on stress testing. If they're
   less experienced, spend more time on the "in practice this means"
   sections and scenario-building.

7. **Be specific to the domain.** Infer the domain from what you hear
   and tailor every example, every tension scenario, and every stress
   test question to that specific domain. No generic examples.

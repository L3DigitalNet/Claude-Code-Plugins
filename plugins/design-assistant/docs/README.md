# Design Assistant — Claude Code Plugin

Full design document lifecycle in two commands:

| Command | When to use |
|---|---|
| `/design-draft` | Starting from scratch — no document yet |
| `/design-review` | Document exists — audit, refine, converge |

Both commands share a common design principles registry format. The output
of `/design-draft` feeds directly into `/design-review` via a warm handoff —
no re-paste, no re-derivation of principles.

---

## Install

```
/plugin install design-assistant@claude-code-plugins
```

---

## `/design-draft` — Guided Document Authoring

A structured interview that discovers your design principles before
writing any architecture. Heavy emphasis on surfacing and resolving
tensions between principles before a single box-and-arrow diagram
gets committed to paper.

### Usage

```
/design-draft                             # start blank
/design-draft "Payment Processing API"    # start with project name
/design-draft path/to/existing-notes.md  # seed from existing notes
```

### Phases

**Phase 0 — Orientation**
Project name, problem statement, and document trigger.

**Phase 1 — Context Deep Dive**
Goals, constraints, stakeholders, quality attribute priorities, risks,
governance requirements. Three interview rounds, each with a forced-tradeoff
question and a tension scan before advancing.

**Phase 2 — Principles Discovery** *(the core of this command)*

- **2A Candidate Generation** — infers candidate principles from your
  answers, grounded in specific things you said.
- **2B Individual Stress Testing** — four questions per candidate to find
  vague, toothless, or contradictory principles. Verdicts: STRONG /
  NEEDS REFINEMENT / TOO VAGUE / SPLIT.
- **2C Tension Resolution** — all inter-principle tensions surfaced as
  concrete domain-specific scenarios. Each tension gets an explicit
  tiebreaker rule or acknowledgment.
- **2D Registry Lock** — final principles registry confirmed before any
  document scaffolding begins.

**Phase 3 — Scope & Structure**
Recommended section structure based on domain and trigger. Sections rated
Required / Recommended / Optional. Confirmed before drafting.

**Phase 4 — Targeted Content Questions**
Fills gaps between Phase 1 and what each section needs. Includes a
mandatory coverage sweep mapping all constraints, risks, and governance
requirements to sections or open questions before advancing.

**Phase 5 — Draft Generation**
Complete document with principles cross-referenced throughout. All
constraints and risks accounted for. Stubs clearly marked. Open questions
logged. Immediately ready for `/design-review`.

### After the draft

```
  (A) Save to file
  (B) Begin /design-review now — automatic warm handoff
  (C) Revise before review
  (D) Export principles registry separately
```

All saved artifacts go to `[project-folder]/docs/` — the project folder
is established on the first write of any session.

### Key commands

```
pause / continue         Snapshot full session state for resumption
finalize                 Early exit with readiness assessment
show principles          Current registry in full
show tensions            Tension list and resolution status
show open questions      All OQs collected so far
export principles        Emit canonical principles export (4 sections)
stress test [Pn]         Re-run stress test on a specific principle
revise [Pn]              Edit a locked principle
skip to [phase]          Jump forward (only from a confirmed gate)
```

---

## `/design-review` — Iterative Document Review

Multi-pass principle enforcement, gap analysis, and optional auto-fix.
Runs until the document converges to zero findings across all review tracks.

### Usage

```
/design-review path/to/design-doc.md
```

For large documents Claude reads the full file via the Read tool.
No manual chunking required.

### Review tracks (per pass)

| Track | What's checked |
|---|---|
| A — Structural | Consistency, completeness, logic, ambiguity, security, clarity |
| B — Principle Compliance | Violations against the document's own design principles |
| C — Gap Analysis | Coverage of domain-appropriate categories |

### Auto-Fix Modes

| Mode | Behaviour |
|---|---|
| A | Interactive — review every finding individually |
| B | Auto-fix eligible findings, surface the rest for review |
| C | Full plan, bulk approval, implement all at once |
| D | Choose per-pass |

### No-principles cold start

If the document has no principles section and no warm handoff context:

```
  (A) Run /design-draft first (recommended)
  (B) Provide principles manually
  (C) Proceed with Tracks A and C only (no principle enforcement)
```

### Key commands

```
pause / continue             Snapshot state for cross-session resumption
finalize                     Early exit with readiness assessment
set mode [A/B/C/D]           Change auto-fix mode
where are we                 Lightweight status check
revisit deferred             Pull deferred findings back into queue
show violations              All open principle/gap/systemic findings
update principle [Pn]        Modify a principle (triggers health check)
set autofixable [Pn]         Mark principle as auto-fix eligible
set not-autofixable [Pn]     Mark principle as always requiring review
gap check [Gn]               Full gap sweep for one category on demand
principle check [Pn]         Compliance sweep for one principle on demand
export log                   Full session log with auto-fix effectiveness report
```

---

## Recommended workflow

```
1. /design-draft "Project Name"
   → Interview → Principles → Draft

2. (B) Begin /design-review immediately
   → Warm handoff — principles and tensions transferred automatically

   or: /design-review path/to/draft.md

3. Iterate until convergence (typically 3–5 passes)

4. export log → archive alongside document
```

---

## Plugin structure

```
plugins/design-assistant/
├── .claude-plugin/
│   └── plugin.json
├── commands/
│   ├── design-draft.md     ← /design-draft
│   └── design-review.md    ← /design-review
├── skills/
│   ├── design-draft/
│   │   └── SKILL.md
│   └── design-review/
│       └── SKILL.md
├── tests/
│   ├── draft/
│   ├── review/
│   └── integration/
└── docs/
    ├── README.md
    └── spec/               ← archived spec versions
```

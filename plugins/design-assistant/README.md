# Design Assistant

Full design document lifecycle in two commands.

## Summary

Design Assistant provides a structured approach to technical design — from blank page to reviewed document. `/design-draft` conducts a guided interview that discovers and stress-tests your design principles before writing a single line of architecture. `/design-review` then enforces those principles across multiple passes, surfacing violations, gaps, and ambiguities until the document converges. Both commands share a common principles registry format, enabling automatic warm handoff from draft to review.

## Installation

```
/plugin marketplace add L3DigitalNet/Claude-Code-Plugins
/plugin install design-assistant@l3digitalnet-plugins
```

## Usage

Typical workflow:

```
1. /design-draft "Project Name"
   → Interview → Principles → Draft

2. (B) Begin /design-review immediately  ← automatic warm handoff
   or: /design-review path/to/draft.md

3. Iterate until convergence (typically 3–5 passes)

4. export log → archive alongside document
```

Both commands accept mid-session commands: `pause / continue`, `show principles`, `show open questions`, `finalize`.

All saved artifacts go to `[project-folder]/docs/` — the project folder is established on the first write of each session.

## Commands

| Command | Description |
|---------|-------------|
| `/design-draft` | Guided document authoring — interview, principles discovery, and draft generation |
| `/design-review` | Iterative review — principle enforcement, gap analysis, and optional auto-fix |

## Skills

| Skill | Description |
|-------|-------------|
| `design-draft` | Loaded by `/design-draft` — phases, interview patterns, principles stress-testing |
| `design-review` | Loaded by `/design-review` — review tracks, auto-fix modes, gap categories |

## `/design-draft` — Guided Document Authoring

A structured interview that discovers your design principles before writing any architecture. Heavy emphasis on surfacing and resolving principle tensions before any diagram is committed.

### Phases

| Phase | What happens |
|-------|-------------|
| **0 — Orientation** | Project name, problem statement, document trigger |
| **1 — Context Deep Dive** | Goals, constraints, stakeholders, quality attributes, risks — three interview rounds with forced-tradeoff questions |
| **2 — Principles Discovery** | Candidate generation → stress testing → tension resolution → registry lock |
| **3 — Scope & Structure** | Recommended section structure, confirmed before drafting |
| **4 — Targeted Content Questions** | Gap-filling between Phase 1 and what each section needs |
| **5 — Draft Generation** | Complete document with principles cross-referenced; ready for `/design-review` |

### After the draft

```
  (A) Save to file
  (B) Begin /design-review now — automatic warm handoff
  (C) Revise before review
  (D) Export principles registry separately
```

### Key commands

```
pause / continue         Snapshot full session state for resumption
finalize                 Early exit with readiness assessment
show principles          Current registry in full
show tensions            Tension list and resolution status
show open questions      All open questions collected so far
export principles        Emit canonical principles export (4 sections)
stress test [Pn]         Re-run stress test on a specific principle
revise [Pn]              Edit a locked principle
skip to [phase]          Jump forward (only from a confirmed gate)
```

## `/design-review` — Iterative Document Review

Multi-pass principle enforcement, gap analysis, and optional auto-fix. Runs until the document converges to zero findings across all review tracks.

### Usage

```
/design-review path/to/design-doc.md
```

### Review tracks

| Track | What's checked |
|-------|---------------|
| **A — Structural** | Consistency, completeness, logic, ambiguity, security, clarity |
| **B — Principle Compliance** | Violations against the document's own design principles |
| **C — Gap Analysis** | Coverage of domain-appropriate categories |

### Auto-Fix Modes

| Mode | Behaviour |
|------|-----------|
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
gap check [Gn]               Full gap sweep for one category on demand
principle check [Pn]         Compliance sweep for one principle on demand
export log                   Full session log with auto-fix effectiveness report
```

## Plugin Structure

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

## Planned Features

- **Domain-specific principle templates** — starter principle registries for common domains (SaaS APIs, IoT firmware, data pipelines) to accelerate Phase 2 of `/design-draft`
- **Cross-document consistency checks** — reference a second design doc during review to detect contradictions or scope overlaps
- **Principles library** — persist and reuse a personal principles registry across documents, building up a house style over time
- **Export adapters** — structured export to Confluence wiki format and Notion page API

## Known Issues

- **Large documents cause context pressure** — documents over ~500 lines may push review context near limits during Track B; use `pause/continue` to checkpoint and resume across sessions
- **Cold-start review has limited analysis** — without a principles section and without a warm handoff from `/design-draft`, Track B (principle enforcement) is skipped entirely
- **`pause/continue` state is session-local** — session snapshots are held in the active conversation context; starting a new Claude Code session requires a fresh run of `/design-draft` or `/design-review`

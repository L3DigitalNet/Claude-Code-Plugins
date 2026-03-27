# Operational Commands

## Shared Commands

These commands work in both `/design-draft` and `/design-review` sessions:

| Command | Effect |
|---|---|
| `pause` | Suspend session and emit full Pause State Snapshot |
| `continue` | Resume from a Pause State Snapshot. Reconstructs all state and resumes at the exact phase/step indicated. |
| `finalize` | Trigger Early Exit Protocol. Suspends current phase, assesses completion status, emits salvageable artifacts and readiness assessment. |

## /design-draft Commands

| Command | Effect |
|---|---|
| `back` | Return to previous phase. Progress from the current phase is discarded. |
| `skip to [phase]` | Jump to a later phase. Current phase must have reached its confirmation gate. Warns if skipping would bypass an unconfirmed synthesis or registry. |
| `show principles` | Print current principles registry in full |
| `show context` | Reprint the Context Synthesis from Phase 0-1 |
| `show tensions` | Reprint tension list and resolution status |
| `show open questions` | List all open questions collected so far |
| `add principle` | Insert a new candidate principle mid-session |
| `stress test [Pn]` | Re-run stress test on a specific principle |
| `revise [Pn]` | Edit a locked principle (re-runs tension check after) |
| `show draft` | Print current draft state (partial or complete) |
| `save draft [filename]` | Write draft to `[project_folder]/docs/design-draft.md` (or specified filename). Triggers first-write flow if `project_folder` is UNSET. |
| `reset phase [N]` | Restart a specific phase from scratch |
| `export principles` | Emit the canonical Principles Export: registry (reader-facing fields only), tension resolution log, candidates not adopted, and /design-review appendix (with Auto-Fix Heuristics). Offer to save to `[project_folder]/docs/principles-registry.md`. |

## /design-review Commands

### Session Control
| Command | Effect |
|---|---|
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
| `update principle [Pn]` | Triggers cascade: registry update, Health Check, Gap Impact Check, Q&A for resulting findings. Best at End of Pass Summary. If mid-pass: warns and offers to defer. |
| `set autofixable [Pn]` | Mark principle as Auto-Fix Eligible |
| `set not-autofixable [Pn]` | Mark principle as Auto-Fix Ineligible |
| `show autofix status` | Eligibility list + confidence distribution from current/last pass |

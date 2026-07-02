# Spec Construction Standard — Phase Delta

Read `spec-construction.md` first. This addendum adds the obligations specific to a **phase spec** — a full-depth spec for ONE phase that inherits system context from the master rather than re-deriving it.

## Inheritance rule (the core of the phase delta)

A phase spec is full-depth **on its own slice** but inherits everything system-level from the master and predecessor phases. Concretely:

- **Reference, do not re-derive.** Cite the master's cross-cutting decisions by their stable id; cite predecessor-phase contracts by name. Do NOT restate the system architecture — a restatement is unchecked, so it can silently contradict the master, and nothing in the phase review gate would catch the drift.
- **Restate only load-bearing inherited invariants**, flagged `(inherited from <source>)`. If this phase's correctness turns on an upstream invariant, restate it here with attribution so the implementer and reviewer have it in front of them; reference (don't copy) everything else.
- **Dated supersession is allowed but must be explicit.** If this phase records an implementation decision that supersedes the master, flag it inline with the date and reasoning. Absent such a flag, the phase defers to the master on conflict; the repo policy file (AGENTS.md) governs where they overlap.

## Required additional sections (beyond the core structure)

- **Status / Revision provenance** — status, date, and a revision history that records the review applied: the panel review (lenses, raw → confirmed counts) and the Codex convergence rounds. This is where the executor skill's review-gate output lands; it is the audit trail that the depth bar was met.
- **Provenance & governance** — what this phase sits under and defers to: the master design, the predecessor phase specs whose contracts it consumes, the authoritative planning artifacts, and AGENTS.md. State the conflict order explicitly (defer to master except dated inline supersession; AGENTS.md governs overlaps).
- **Inherited contracts (honored + extended)** — the contracts from the master / prior phases this phase consumes, and precisely how this phase extends them (new types, interfaces, keys, or invariants pinned for later phases). Restate load-bearing inherited invariants here with attribution.
- **Scope & decomposition decision** — what this phase covers and the deliberate cuts: what re-homes to which sibling phase, and why. Name it so the boundary is unambiguous.
- **Out of scope** — the named boundary: each excluded item and the sibling phase (or later) that owns it.
- **Sizing flag** — assess this phase against the single-plan / single-session upper bound defined for the project (the master spec sets the task-count ceiling; absent one, use what a single session can complete and review). If the implementation plan would exceed that bound, instruct splitting into a micro-batch rather than overpacking. Isolate independently-reviewable units as their own plan checkpoints.
- **Rejected alternatives** and **contract touch-points** (exit codes / interface deltas this phase touches), per the core structure.

## Phase self-review (in addition to the core checklist)

1. **Citations resolve** — every cited decision id and predecessor contract resolves to a real master / prior-phase statement. No dangling reference.
2. **No silent re-derivation** — system architecture is referenced, not restated; the only restatements are load-bearing invariants, each flagged inherited.
3. **Boundary completeness** — every out-of-scope item names the sibling phase that owns it; nothing falls through the seam.
4. **Sizing honest** — the phase fits one plan/session, or the spec says where to split.
5. **Supersession flagged** — any departure from the master is dated and reasoned inline, not silent.

## Red flags (phase-specific)

- System architecture restated inline (drift risk) instead of cited by id.
- A cited decision id or predecessor contract that does not resolve.
- An out-of-scope item with no owning sibling phase named.
- A phase that silently contradicts the master with no dated supersession flag.
- A phase sized past the single-plan bound with no split instruction.

## Next step

On completion the spec hands off to plan authoring (the executor skill's plan step, governed by `plan-construction.md`).

# Spec Construction Standard — Core

Purpose: the shared structure and quality bar for every spec in this project — master and per-phase alike. Read this for any spec, then read the altitude-specific addendum:

- Authoring or reviewing a **master spec** → also read `spec-construction-master.md`.
- Authoring or reviewing a **phase spec** → also read `spec-construction-phase.md`.

This document is the rubric the review gates check against: the author writes to it; the panel and Codex review against it. "Is this spec good" is defined here, not invented per run.

## Required structure

Scale each section to its complexity (a few sentences if straightforward; longer where nuanced). Omit a section only with an explicit `"N/A — <reason>"`. The altitude addendums add required sections on top of these.

- Overview — problem statement; goals; explicit non-goals.
- Architecture — components, boundaries, key technical decisions with rationale.
- Data model — domain types and their relationships.
- Interfaces — CLI / API / contracts the unit exposes or consumes.
- Behavior & rules — what each component does, per case.
- Error handling — failure modes and how each is handled.
- Testing strategy — see "Testing strategy" below.
- Acceptance criteria — each one testable.
- Rejected alternatives — approaches considered and why they were not taken (prevents re-litigation downstream).
- Out of scope — what is deliberately excluded.

## Design for isolation (core principle)

Decompose into units that each have one clear purpose, communicate through well-defined interfaces, and can be understood and tested independently.

- For each unit, you must be able to answer: what does it do, how is it used, what does it depend on.
- Two tests of a good boundary: (a) can someone understand what the unit does without reading its internals? (b) can the internals change without breaking consumers? If either fails, the boundary needs work.
- Prefer small, well-bounded units. A unit you cannot describe in a single clear purpose is doing too much — split it.

## Working in existing code

- Explore the current structure before proposing changes; follow existing patterns.
- Include targeted improvements where existing problems directly affect the work. Do not propose unrelated refactoring.

## Scope discipline

- YAGNI: cut features not needed for the stated goals.
- If the spec covers multiple independent subsystems, it is too large for one spec. (For a master spec this is the phase decomposition; for a phase spec it is a signal to split into a micro-batch.)
- Every acceptance criterion must be expressible as a failing test. If it cannot, it is not yet a criterion — sharpen it.

## Testing strategy (mutation mindset)

Coverage proves a line ran, not that it is correct. For load-bearing behavior, pick the adversarial input that makes a _wrong answer observable_ and assert the behavior, not mere membership or coverage. State, per load-bearing unit, the adversarial cases that would distinguish a correct implementation from a plausible-but-wrong one (degradation arms, both sides of each branch, boundary values). A spec that only promises "test X" without naming the discriminating cases is under-specified.

## Self-review checklist

Run before the spec leaves your hands; fix issues inline.

1. Placeholder scan — no "TBD", "TODO", incomplete sections, or vague requirements.
2. Internal consistency — no section contradicts another; the architecture matches the behavior described.
3. Scope check — focused enough for its altitude (one implementation cycle for a phase; cleanly decomposable for a master).
4. Ambiguity check — no requirement readable two ways. Pick one and make it explicit.
5. Testability — every acceptance criterion maps to a test you could write, and load-bearing behavior names its discriminating adversarial case.

## Red flags (defects, not style)

- "Should", "probably", "handle appropriately" where a concrete rule belongs.
- A requirement with no corresponding acceptance criterion.
- An acceptance criterion that cannot be written as a test.
- A unit that cannot be described in one clear purpose.
- A load-bearing behavior whose test asserts coverage/membership rather than a wrong-answer-observable outcome.

---

Attribution: section structure, design-for-isolation tests, and self-review checklist adapted from the Superpowers `brainstorming` skill (obra/superpowers, MIT). Question-driven elicitation and user-approval gates are intentionally omitted — process lives in the skills; this is the quality standard only.

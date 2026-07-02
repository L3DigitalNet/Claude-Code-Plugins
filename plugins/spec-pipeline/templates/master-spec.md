# {{PROJECT}} — Master Spec

- **Date:** {{DATE}}
- **Status:** Draft

## Overview

{{Problem statement; goals; explicit non-goals.}}

## Architecture

{{Components, boundaries, key technical decisions with rationale. State each cross-cutting decision once in the register below and cite it here by id (D1, D2, …).}}

## Data model

{{Domain types and their relationships. Shared types phases consume are defined here, once.}}

## Interfaces

{{CLI / API / contracts the system exposes or consumes.}}

## Behavior & rules

{{What each component does, per case. Concrete rules, not "handled appropriately".}}

## Error handling

{{Failure modes and how each is handled.}}

## Testing strategy

{{Mutation mindset: per load-bearing unit, name the adversarial cases that make a wrong answer observable — both sides of each branch, boundary values, degradation arms.}}

## Acceptance criteria

- {{Each criterion expressible as a failing test.}}

## Rejected alternatives

- {{Approach considered}} — {{why not taken}}.

## Out of scope

- {{Deliberate exclusion.}}

## Build plan

Per-phase task-count ceiling: 12 tasks.

{{Ordered phase list — mirror each entry into docs/handoff/phase-plan.md (the status-tracking projection; definitions stay here, and on conflict this master governs). Each phase: id (stable — never renumber), objective, scope in/out, depends-on (earlier ids only, acyclic), the master-spec slice it implements, phase-level acceptance criteria, size note. Phase 1 establishes the toolchain + test harness. Prefer vertical slices over horizontal layers.}}

## Cross-cutting decision register

- **D1** — {{Decision statement, once, in citable form}} — {{rationale}}.

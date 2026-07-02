# Spec Construction Standard — Master Delta

Read `spec-construction.md` first. This addendum adds the obligations specific to a **master spec** — the authoritative, multi-phase design that phase specs sit under, cite, and defer to. The master is the single source of truth for everything that spans phases.

## What the master spec owns (and phase specs do NOT re-decide)

- **Full system scope** — every requirement of the system, even those implemented many phases later.
- **Cross-cutting / architectural decisions** that span phases. Assign each a **stable id** (e.g. `D1`, `D2`) so phase specs cite the decision by id rather than restating it. The id is the contract; phases reference it.
- **Shared data model and contracts** that phases consume — base types, registries, the envelope/record shape, and any shared interfaces. These are defined once here.
- **Authoritative planning artifacts** — where exhaustive per-item enumeration belongs (e.g. a complete data dictionary, a full API/CLI surface, an exhaustive requirements list). The master designates these as authoritative for exhaustive detail and references them rather than inlining the enumeration.

## Required additional sections

- **Build plan / phase decomposition** — the ordered phase list. Each phase: id, objective, scope in/out, depends-on (earlier phases only; the graph must be acyclic), the master-spec slice it implements, phase-level acceptance criteria, and a size note. Phase 1 establishes the toolchain + test harness so every later phase has a working RED→GREEN environment. Prefer vertical slices that deliver testable behavior over horizontal layers. Set the **per-project task-count ceiling** (the working upper bound of TDD tasks for a single phase plan) here, so the phase delta's sizing flag has a concrete bound to check against.
- **Cross-cutting decision register** — the id'd decisions above, each stated once with rationale, in a form a phase spec can cite.
- **Corrections log** (if the master is revised) — dated, numbered corrections folded into the design, so phases citing a decision id get the corrected version.

## Master self-review (in addition to the core checklist)

1. **Scope coverage** — every system requirement maps to exactly **one** phase. No orphaned requirement (implemented by no phase); no duplicated requirement (claimed by two).
2. **Decomposition soundness** — dependency graph acyclic; each phase independently executable and testable in a single session/plan; phase 1 establishes the harness.
3. **Citable decisions** — every cross-cutting decision a phase will depend on has a stable id and a single authoritative statement.
4. **Seams named** — the decomposition seams (where one phase ends and the next begins) are explicit, so phase specs can state what re-homes to which sibling.

## Red flags (master-specific)

- A cross-cutting decision stated in prose with no stable id (phases will restate and drift).
- A requirement no phase implements, or one two phases both claim.
- Exhaustive enumeration inlined into the master instead of delegated to a named planning artifact.
- A phase in the build plan that is not independently testable, or that depends on a later phase.

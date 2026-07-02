# Phase Plan — {{PROJECT}}

Master spec: `{{master-spec path}}`

<!-- Statuses live HERE; phase definitions live in the master spec's build
     plan — on conflict the master governs. Phase ids are STABLE: never
     renumber once execution begins; append or split instead. `complete` is
     terminal: reopening a finished phase is a deliberate manual edit of this
     file (set-status refuses it) — prefer appending a follow-up phase. -->

## Phase 1 — {{TITLE}}

- **status:** pending
- **objective:** {{One line.}}
- **scope-in:** {{What this phase covers.}}
- **scope-out:** {{What it deliberately excludes.}}
- **depends_on:** []
- **spec-slice:** {{Master-spec sections this phase implements.}}
- **acceptance:**
  - {{Phase-level testable criterion.}}
- **size:** {{Size note vs the master's task-count ceiling.}}

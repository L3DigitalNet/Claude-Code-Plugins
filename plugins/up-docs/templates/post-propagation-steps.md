# Post-Propagation Steps

Shared orchestrator procedures that run AFTER the repo propagator returns. Single source of truth for
both `/up-docs:repo` (single-layer) and `/up-docs:all` (combined run). "Propagator output" below means
the repo propagator's returned table in either case.

## Stale File Candidate Review (conditional)

If the repo propagator's output includes a `## Stale File Candidates` section, present the listed paths
to the user via `AskUserQuestion` and execute deletions only on explicit approval:

1. Parse the candidate rows from the propagator output. Each row has a path, reason, and confidence.
2. Build an `AskUserQuestion` with `multiSelect: true`, one option per candidate (up to 4 — if more,
   batch in subsequent questions, or label the 4th "Delete these; rerun to review remaining").
3. Each option label is the filename basename (for readability); the description carries the reason +
   confidence verbatim from the agent.
4. For every path the user selects, run `git rm <path>` (never plain `rm` — staying inside git keeps
   history recoverable). Report what was deleted.
5. Paths the user does not select are left alone — no follow-up, no retry.
6. If the user cancels the question entirely, skip deletions and continue.

If the propagator emitted zero stale candidates (or omitted the section), skip this step silently.
Deletion is the orchestrator's job, after consent — the propagator agent only surfaces candidates and
never runs a destructive command, even for `high`-confidence rows.

## Handoff for Next Session

**(a) Update confirmation.** One or two lines summarizing the propagator table(s): files changed vs.
audited-but-unchanged vs. deleted (if any). For `/up-docs:all`, one line per layer.

**(b) Handoff brief.** Detect the repo's handoff layout (probe-based, not flag-based) and source from
the matching files:

- **V2 (handoff-system-v2):** `docs/state.md` exists. Read it + `docs/deployed.md` + `docs/bugs/INDEX.md`.
- **V1 (legacy):** `docs/handoff.md` exists (and no `docs/state.md`). Read it.
- **NONE:** neither file exists. Skip this subsection silently.

Emit using this structure (fields sourced per layout):

```markdown
## 📋 Handoff for Next Session

**Last work:** <V2: top row of docs/sessions/<current-month>.md | V1: top Last Updated line>

**Currently deployed:**
- <V2: docs/deployed.md rows, one per row, name + version + state>
- <V1: docs/handoff.md What Is Deployed bullets>

**Open items — what remains:**
- <V2: docs/deployed.md ## What Remains bullets | V1: docs/handoff.md What Remains bullets>

**Active incidents:** <V2: docs/state.md Session Instructions 🔴/🟡/🟢 block | V1: skip>

**Open bugs:** <V2: docs/bugs/INDEX.md rows with status != fixed | V1: docs/handoff.md Bugs table with unresolved items. "None" if all are fixed.>
```

Keep it scannable — no narrative prose, no full-file dump. The brief is a READ-only excerpt of the
already-updated state files; do not re-edit them.

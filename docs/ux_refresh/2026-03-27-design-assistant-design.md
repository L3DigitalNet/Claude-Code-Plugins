# design-assistant: References Architecture Conversion

## Problem

Two commands totaling 2,636 lines embed all domain knowledge inline: state models, output templates, shared protocols (pause/resume, handoff, interaction conventions), and interview rules. Content is duplicated across both commands. Two stub skills (39 lines combined) pollute the skill menu.

## Pattern

Extract shared infrastructure and output templates into `references/`, keeping the sequential phase procedures in the commands. This differs from the github-repo-manager conversion (where skills mapped 1:1 to references) because the design-assistant's phases are deeply sequential and state-dependent: decomposing into per-phase files would add file count without meaningful "load only what you need" benefit.

## New Directory Structure

```
design-assistant/
  .claude-plugin/plugin.json
  commands/
    design-draft.md              # Phase procedures only (~500 lines)
    design-review.md             # Review loop only (~500 lines)
  references/
    interaction-conventions.md   # AskUserQuestion rules (shared by both commands)
    session-state.md             # State model + invariants (shared structure)
    pause-resume.md              # Pause snapshot, continue, early exit protocol
    operational-commands.md      # Command tables (shared, per-command differences noted)
    handoff-contract.md          # /design-draft → /design-review warm handoff
    interview-rules.md           # 7 interview conduct rules
    ux-templates.md              # All formatted output blocks from both commands
  README.md
  CHANGELOG.md
```

The `skills/` directory is deleted (2 stub skills removed).

## Reference Content

### interaction-conventions.md (~25 lines)
The AskUserQuestion conversion rules shared by both commands. Currently duplicated in lines 17-41 of each command.

### session-state.md (~400 lines)
Combined state model from both commands, organized as two clearly separated sections (not merged). design-draft section has identity, context, principles, structure, content, and draft state variables. design-review section has its own state model (principles registry, finding queue, section status, pass tracking). Shared invariant patterns appear once at the top. Each command's Read pointer targets its own section within the file.

### pause-resume.md (~300 lines)
Pause state snapshot format (both variants), continue/resume protocol, snapshot mismatch handling, and early exit protocol (finalize, partial draft declaration, phase completion assessment). Both commands share the same structural approach with command-specific fields.

### operational-commands.md (~65 lines)
Command tables from both commands. Organized as shared commands (pause, continue, finalize, back, skip) then per-command additions (design-draft: show principles, add principle, stress test, revise, export principles; design-review: focus section, skip section, show findings, accept all, show deferred, export log).

### handoff-contract.md (~75 lines)
The /design-draft to /design-review warm handoff: the handoff block format, what gets transferred (principles registry, tension resolution log, open questions, phase 1 context summary), and the instructions for /design-review on how to import.

### interview-rules.md (~37 lines)
The 7 interview conduct rules from design-draft. Referenced by the command but useful as a standalone reference.

### ux-templates.md (~600 lines)
All formatted output blocks from both commands, numbered as templates. Includes:

**From design-draft:** entry point confirmation/error, orientation summary, context synthesis, candidate principles (compact + full), stress test + verdict, tension resolution scenario + log, registry lock (compact + full), phase 3 section structure, phase 4 coverage sweep, draft complete summary, partial draft declaration, resume confirmation.

**From design-review:** section status table, end of pass summary, finding format (per track), diff format, change volume + trend tracking, deferred log, completion declaration, session log export.

## Command Rewrite Approach

Both commands keep their phase/loop procedures but replace inline content with Read pointers:

```markdown
# At the top of each command:
Read ${CLAUDE_PLUGIN_ROOT}/references/interaction-conventions.md for AskUserQuestion rules.
Read ${CLAUDE_PLUGIN_ROOT}/references/session-state.md for the state model and invariants.

# Before formatted output:
Read ${CLAUDE_PLUGIN_ROOT}/references/ux-templates.md for Template N.

# On pause/continue/finalize:
Read ${CLAUDE_PLUGIN_ROOT}/references/pause-resume.md.

# On handoff (design-draft only):
Read ${CLAUDE_PLUGIN_ROOT}/references/handoff-contract.md.
```

## User-Facing Changes

- `/design-draft` and `/design-review` work identically
- 2 fewer skill menu entries
- Shared content is deduplicated
- Output formatting centralized in ux-templates.md

## Migration Checklist

1. Create `references/`
2. Extract shared content into 6 reference files
3. Create `ux-templates.md` with all formatted output blocks
4. Rewrite design-draft.md with Read pointers (~500 lines)
5. Rewrite design-review.md with Read pointers (~500 lines)
6. Delete `skills/` directory
7. Update README.md
8. Update CHANGELOG.md
9. Bump version in plugin.json and marketplace.json
10. Run `./scripts/validate-marketplace.sh`

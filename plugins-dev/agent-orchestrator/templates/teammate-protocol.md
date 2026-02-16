# Teammate Operating Protocol

You are a teammate in a coordinated agent team. Follow these rules exactly.

## Context Discipline — THIS IS YOUR TOP PRIORITY

1. **NEVER read a file "just to check."** Use a grep/glob subagent first.
2. **NEVER dump entire file contents.** Read specific line ranges, function signatures, type definitions.
3. **When a subagent returns results, extract ONLY the actionable findings.** Reduce to: what files are involved, what the answer is, what to do next. If verbose, compress to 3 bullet points max.
4. **Proactively manage your context** using these heuristics:
   - After completing every 3 tasks, write a handoff note regardless.
   - After reading more than 10 files (even partial), write a handoff and compact. The read-counter hook will warn you at 10 reads.
   - If responses feel sluggish or repetitive, compact immediately.
   - If `/context` is available, run it. If usage exceeds 50%, compact.

   When compacting:
   a. FIRST write handoff to `.claude/state/<your-name>-handoff.md`:
      - What you completed (files created/modified, brief descriptions)
      - What remains (numbered task list)
      - Key decisions and why
      - Blockers or dependencies
   b. Update `.claude/state/<your-name>-status.md`
   c. Run: `/compact Preserve: my tasks, file ownership, decisions from my handoff note at .claude/state/<your-name>-handoff.md`

5. **After any compaction**, immediately read your handoff note to restore continuity.

## Subagent Usage

**Delegate TO subagents:**
- Searching/grepping the codebase (Explore subagent)
- Running tests (test-runner subagent)
- Validating work against conventions (reviewer subagent)

**Keep IN your own context:**
- Active editing and decision-making
- Cross-file reasoning within your ownership boundary
- Communication with other teammates

## File Ownership

- You own ONLY the files listed in your spawn prompt.
- If working in a worktree, ALL file operations stay inside your worktree directory.
- NEVER read or modify outside your ownership without messaging the lead first.
- If you discover something another teammate needs, message them directly (agent teams) or write it in your status file's Notes field (subagent fallback mode).

## Status Updates

After each significant milestone, write your status to `.claude/state/<your-name>-status.md`:

```
## Status: working | blocked | done
## Context Pressure: low | mid | high
## Files Modified:
- path/to/file.ext (brief description)
## Current Task: <what you are working on now>
## Notes: <anything the lead or other teammates should know>
```

**NEVER write directly to `.claude/state/ledger.md`.** The ledger is maintained exclusively by the lead to avoid concurrent write corruption. The lead reads your status file and aggregates it.

## Completion

When all your tasks are done:
1. Write a final summary to `.claude/state/<your-name>-handoff.md` (overwrite previous)
2. Update `.claude/state/<your-name>-status.md` with `Status: done`
3. Message the lead with a brief completion summary

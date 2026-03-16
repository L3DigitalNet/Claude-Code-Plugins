---
name: deep-context
description: >
  1M context window behavioral rules. MUST consult before any file reading, code editing,
  or subagent delegation decision. Applies to every task in Opus 4.6 sessions. Governs:
  whole-file reading (never use offset/limit for files under 4000 lines), direct reading
  over subagent delegation, pre-loading dependencies before edits, avoiding redundant
  re-reads, parallel file reads, and deep-context planning for complex multi-file tasks.
  Triggers on: read, edit, explore, debug, refactor, implement, investigate, fix, build,
  create, modify, change, update, add, review, analyze, understand.
---

# Deep Context: 1M Token Context Rules

You have a 1M token context window. A 500-line file costs ~0.1% of your context. The cost of *not* reading is almost always higher than the cost of reading. These rules override conservative behaviors optimized for smaller-context models.

## Baseline Rules (Always Active)

### Rule 1: Whole-File Reading

Read entire files by default. Only use `offset`/`limit` when:
- The file exceeds 4000 lines, OR
- You have already identified the exact section you need and have previously read the full file

For files between 2000-4000 lines, use two parallel Read calls (first half + second half) to load the complete file.

A 500-line file is ~0.1% of your context. Partial reads cost more in missed connections than they save in tokens.

### Rule 2: Direct Read Over Delegation

Use Glob/Grep to find files, then Read them directly into your own context. Only delegate to subagents when:
- The search space is genuinely unknown and broad
- You need to explore 10+ files to find the right ones
- The task is truly independent and parallelizable

**The test:** "Would I lose important nuance by reading a summary instead of the source?" If yes, read it yourself.

### Rule 3: Read Before Edit

Before editing any file, read its immediate dependency graph:
1. The target file itself (full read)
2. Its imports and dependencies
3. Files that import or reference it (callers/consumers)
4. Its test files
5. Config files that reference it

Never start an edit without understanding what your change touches.

### Rule 4: No Redundant Reads

Trust your context. If you read a file earlier in this conversation, reference what you already know. Only re-read if:
- The file was modified since you last read it (by you or a tool)
- You explicitly need to verify current state after an edit

Do not re-read files "just to be sure."

### Rule 5: Parallel Reads

When you need multiple files, read them all in a single parallel tool call. Never issue sequential Read calls for independent files.

**Wrong:**
```
Read(file_a.py)
# wait
Read(file_b.py)
# wait
Read(file_c.py)
```

**Right:**
```
Read(file_a.py) | Read(file_b.py) | Read(file_c.py)  # single parallel call
```

## Deep-Context Mode (Complex Tasks)

Activate this planning phase when ANY of these apply:
- Task touches 3+ files
- Task involves debugging or investigating unexpected behavior
- Task is a new feature or significant refactoring
- Task crosses module/package boundaries
- User explicitly requests deep analysis

### Step 1: Scope the File Graph

Use Glob and Grep to identify all files relevant to the task. Map what imports what, what tests what, what configs reference what. This is a *search* phase -- use lightweight tools, don't read files yet.

### Step 2: Load Strategically

Read files in priority order, using parallel batches:

1. **Primary targets** -- files being modified
2. **Direct dependencies** -- imports, base classes, interfaces
3. **Callers/consumers** -- files that reference the targets
4. **Tests** -- existing test files
5. **Config/docs** -- manifests, READMEs, config files

For a typical task: 5-15 files in 2-3 parallel batches.

### Step 3: Execute with Full Context

Implement the change with the full picture loaded. No mid-task "let me check..." reads -- you should already have what you need.

Briefly tell the user what you loaded: "Loaded X, Y, Z to understand the full picture."

## Anti-Patterns

### "Let me check that with a subagent"
**Wrong:** Spawning an Explore agent to find and summarize code you could read directly.
**Right:** Glob for the pattern, Read the matches yourself.
**Exception:** Genuinely broad research across 10+ unknown files.

### "Let me read lines 1-50 first"
**Wrong:** `Read(file, offset=0, limit=50)` to "peek" at a file.
**Right:** `Read(file)` for files under 4000 lines.

### "Let me read this file again"
**Wrong:** Re-reading a file already in your context.
**Right:** Reference your existing knowledge. Re-read only if the file was modified.

### "I'll start coding and figure out imports later"
**Wrong:** Editing before reading dependencies.
**Right:** Read target + imports + tests + callers, then edit.

### "I'll read these files one at a time"
**Wrong:** Sequential Read calls for independent files.
**Right:** Batch all independent reads into one parallel tool call.

## Context Budget Awareness

Use these heuristics to gauge context pressure and shift strategy:

| Signal | Strategy | Behavior |
|--------|----------|----------|
| **Early session** (few files, short conversation) | Aggressive | Load everything potentially relevant. Read whole files freely. |
| **Mid session** (10-20 files loaded, several tasks done) | Selective | Focus on files directly touched by the current task. |
| **Heavy session** (30+ files, long conversation, compaction warnings) | Deliberate | Only read what's strictly needed. Prefer Grep for quick lookups. |
| **Approaching limit** (compaction occurred, system pressure signals) | Conserve | Stop loading new content. Work with what you have. Suggest new session. |

## Guardrails

- **Don't read blindly.** "Read aggressively" does not mean "read the whole repo." Have a reason for each file.
- **Match scope to task.** "Fix this one line" doesn't need the entire module graph loaded.
- **Communicate loading.** When entering deep-context mode, tell the user what you're loading and why.

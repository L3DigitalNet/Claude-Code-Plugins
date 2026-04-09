---
name: save
description: "Save a task handoff file to the shared network drive. This skill should be used when the user runs /handoff:save."
argument-hint: "[optional description]"
allowed-tools: Read, Glob, Grep, Bash, Write
---

# /handoff:save [description]

Write a handoff file to `/mnt/share/instructions/` so work can be resumed on a different machine.

## Procedure

### 1. Gather Context

Run the context gathering script:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/gather-context.sh [--description "<user-provided-slug>"]
```

Parse the JSON output. Use the git state and working directory as the machine context. The `filename` field provides the generated filename. Also use the conversation context: what task was being worked on, what has been completed, what remains.

### 3. Write the Handoff File

Write to `/mnt/share/instructions/<filename>` using this structure:

```markdown
# Handoff: [brief task title]

**Saved:** [YYYY-MM-DD HH:MM]
**Machine:** [hostname]
**Working directory:** [full path]
**Branch:** [git branch, if applicable]

## Task Summary

[2-3 sentences: what is the overall goal of this work]

## Work Completed

[Bullet list of what was accomplished in this session]

## Current State

[Where things stand right now: what's running, what's changed, what's been committed vs uncommitted]

## Next Steps

[Numbered list of what needs to happen next, in order. Be specific about which machine, which commands, which files. This is the handoff — the person reading this should be able to pick up exactly where you left off.]

## Context

[Any additional context that would be lost between sessions: error messages encountered, decisions made and why, things that were tried and didn't work, credentials or paths referenced]
```

Write the content concisely but completely. The reader is Claude Code on a different machine with no conversation history.

### 4. Confirm

Report the full path of the saved file:

```
Saved: /mnt/share/instructions/<filename>
```

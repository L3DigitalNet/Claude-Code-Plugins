---
name: load
description: "Load the most recent task handoff file from the shared network drive. This skill should be used when the user runs /handoff:load."
argument-hint: "[filename]"
allowed-tools: Read, Bash, Glob
---

# /handoff:load [filename]

Read a handoff file from `/mnt/share/instructions/` to resume work started on another machine.

## Procedure

### 1. Find the File

If a filename argument was provided, read that file directly from `/mnt/share/instructions/`.

If no argument was provided, find the most recent handoff file:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/find-latest-handoff.sh
```

If `found` is false, report that no handoff files were found and stop. If `found` is true, use the `path` field to read the full file.

### 2. Read and Present

Read the full handoff file. Then present a compact summary:

```
Loaded: /mnt/share/instructions/<filename>
Task: [task title from the file]
From: [machine] at [timestamp]
Next steps: [count] items
```

Then display the **Next Steps** section in full — that's the actionable part.

### 3. Offer to Continue

After presenting, ask if the user wants to proceed with the next steps. The handoff file contains enough context to begin work immediately.

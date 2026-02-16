#!/bin/bash
# PreToolUse hook: blocks Write/Edit/MultiEdit/NotebookEdit and MCP write operations
# on files outside .claude/state/
# Only active when ORCHESTRATOR_LEAD=1 env var is set (lead session only).
# Teammates are NOT affected.

# Skip enforcement for non-lead sessions
if [ "$ORCHESTRATOR_LEAD" != "1" ]; then
  exit 0
fi

# Extract file path from hook input (JSON on stdin)
# Different tools use different field names: file_path, path, notebook_path
FILE_PATH=$(cat | python3 -c "
import sys, json
d = json.load(sys.stdin)
tool_input = d.get('tool_input', {})
# Try multiple field names in priority order
path = tool_input.get('file_path') or tool_input.get('path') or tool_input.get('notebook_path') or ''
print(path)
" 2>/dev/null)

# Fail open if we can't determine the path
if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Normalize to absolute canonical path for comparison
PROJECT_ROOT="$(pwd)"

# Convert FILE_PATH to absolute if it's relative
if [[ "$FILE_PATH" != /* ]]; then
  FULL_PATH="$PROJECT_ROOT/$FILE_PATH"
else
  FULL_PATH="$FILE_PATH"
fi

# Canonicalize paths to resolve .. and . components
# Use -m flag to allow non-existent files (we're checking write intent, not existence)
ABS_PATH=$(realpath -m "$FULL_PATH" 2>/dev/null)

# Fail open if realpath fails
if [ -z "$ABS_PATH" ]; then
  exit 0
fi

# Allow writes to orchestration state, settings, and gitignore in project root only
# Block writes to worktree coordination directories (.worktrees/*/.claude/state/)
if [[ "$ABS_PATH" == "$PROJECT_ROOT/.claude/state/"* ]] || \
   [[ "$ABS_PATH" == "$PROJECT_ROOT/.claude/settings"* ]] || \
   [[ "$ABS_PATH" == "$PROJECT_ROOT/.gitignore" ]]; then
  exit 0
fi

# Block: lead cannot write source files
echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","decision":"block","reason":"DELEGATE MODE: Lead cannot write source files. Delegate this edit to a teammate or subagent."}}'
exit 2

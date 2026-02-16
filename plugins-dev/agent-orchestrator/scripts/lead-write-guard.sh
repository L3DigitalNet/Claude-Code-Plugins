#!/bin/bash
# PreToolUse hook: blocks Write/Edit/MultiEdit on files outside .claude/state/
# Only active when ORCHESTRATOR_LEAD=1 env var is set (lead session only).
# Teammates are NOT affected.

# Skip enforcement for non-lead sessions
if [ "$ORCHESTRATOR_LEAD" != "1" ]; then
  exit 0
fi

# Extract file path from hook input (JSON on stdin)
FILE_PATH=$(cat | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('file_path',''))" 2>/dev/null)

# Fail open if we can't determine the path
if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Allow writes to orchestration state, settings, and gitignore
case "$FILE_PATH" in
  .claude/state/*|.claude/settings*|.gitignore)
    exit 0
    ;;
  *)
    # Block: lead cannot write source files
    echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","decision":"block","reason":"DELEGATE MODE: Lead cannot write source files. Delegate this edit to a teammate or subagent."}}'
    exit 2
    ;;
esac

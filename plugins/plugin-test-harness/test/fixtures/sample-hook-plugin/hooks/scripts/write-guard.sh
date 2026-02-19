#!/bin/bash
# Reads tool_input from stdin JSON, blocks Write to /etc/ paths
set -e
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('file_path',''))" 2>/dev/null || echo "")

if echo "$FILE_PATH" | grep -q "^/etc/"; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","decision":"block","reason":"Writes to /etc/ are blocked by sample-hook-plugin"}}'
  exit 2
fi
exit 0

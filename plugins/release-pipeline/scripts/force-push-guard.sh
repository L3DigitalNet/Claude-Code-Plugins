#!/bin/bash
# PreToolUse hook: block force-push commands in the release pipeline.
# CRITICAL RULE: never use git push --force or -f. (commands/release.md rule 3)

set -uo pipefail

# Extract the bash command from hook input (JSON on stdin)
COMMAND=$(cat | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('tool_input', {}).get('command', ''))
" 2>/dev/null)

# Fail open if we can't parse the command
if [ -z "$COMMAND" ]; then
  exit 0
fi

# Block force-push: 'git push' with '--force' or '-f' flag
if echo "$COMMAND" | grep -q 'git push' && echo "$COMMAND" | grep -qE '(--force|\s-f(\s|$))'; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","decision":"block","reason":"CRITICAL RULE: Force-push is prohibited in the release pipeline. Never use git push --force or -f. Fix the underlying issue and use a normal push."}}'
  exit 2
fi

exit 0

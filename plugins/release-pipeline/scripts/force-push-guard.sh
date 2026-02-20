#!/bin/bash
# PreToolUse hook: block force-push commands in the release pipeline.
# CRITICAL RULE: never use git push --force or -f. (commands/release.md rule 3)
#
# Called by: hooks.json → PreToolUse/Bash (first command in sequential pair with auto-build-plugins.sh)
# If this hook blocks (exit 2), auto-build-plugins.sh does not run for that command.

set -euo pipefail

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

# Block force-push: 'git push' with '--force' or '-f' flag.
# The \s-f pattern requires surrounding whitespace/end-of-string to avoid matching flags like -fd.
if echo "$COMMAND" | grep -q 'git push' && echo "$COMMAND" | grep -qE '(--force|\s-f(\s|$))'; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","decision":"block","reason":"Force-push is not allowed. If the branch has diverged, check rollback-suggestions or rebase from origin before retrying."}}'
  exit 2
fi

exit 0

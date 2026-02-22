#!/usr/bin/env bash
# gh-manager-guard.sh — PreToolUse hook for mutation detection
#
# Intercepts Bash tool calls before execution and records a PENDING audit entry for
# any gh-manager mutation subcommand that is about to run.
#
# What this does:
#   - Detects gh-manager mutation commands via shared mutation-patterns.sh
#   - Logs a PENDING entry to the audit trail before the command executes
#   - The monitor (PostToolUse) logs the confirmed entry after execution
#
# What this deliberately does NOT do:
#   - Emit warnings to the agent context window — behavioral enforcement lives in the
#     skill file (require owner approval before any mutation). Injecting a warning on
#     every approved mutation would add noise without adding safety. The hook cannot
#     read conversation history to distinguish an approved mutation from an unapproved
#     one, so any context-window warning would fire on all mutations equally.
#   - Block executions — exit 0 always (exit 2 is reserved for future hard blocks)
#
# Receives PreToolUse hook JSON on stdin.
# Stdout is injected into the agent context window — kept empty for normal operation.
# Exit 0 to allow the tool call.

set -uo pipefail

# shellcheck source=mutation-patterns.sh
source "${BASH_SOURCE%/*}/mutation-patterns.sh"

# Read full stdin once
INPUT=$(cat)

# Only process Bash tool calls
TOOL_NAME=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_name', ''))
except:
    print('')
" 2>/dev/null)

[ "$TOOL_NAME" = "Bash" ] || exit 0

# Extract the command about to run
COMMAND=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('command', ''))
except:
    print('')
" 2>/dev/null)

# Only process gh-manager invocations
echo "$COMMAND" | grep -q "gh-manager" || exit 0

# Log PENDING if this is a mutation command
if is_mutation_command "$COMMAND"; then
    AUDIT_LOG="$HOME/.github-repo-manager-audit.log"
    TIMESTAMP=$(date -Iseconds 2>/dev/null || date +"%Y-%m-%d %H:%M:%S")
    GH_CMD=$(echo "$COMMAND" | grep -oE 'gh-manager\.js[^|;&]*' | head -1 || echo "$COMMAND")
    echo "[$TIMESTAMP] [PENDING] $GH_CMD" >> "$AUDIT_LOG" 2>/dev/null || true
fi

exit 0

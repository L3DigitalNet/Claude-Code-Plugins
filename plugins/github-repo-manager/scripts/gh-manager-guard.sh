#!/usr/bin/env bash
# gh-manager-guard.sh — PreToolUse hook for mutation detection
#
# Intercepts Bash tool calls before execution and warns when a gh-manager mutation
# subcommand is about to run. This provides a mechanical enforcement layer that
# complements the behavioral approval requirement (owner approval in conversation).
#
# What this does:
#   - Detects gh-manager mutation commands (merge, close, push, publish, etc.)
#   - Emits a warning to the agent context so the AI can abort if no approval preceded it
#   - Logs the pending mutation to the audit trail
#
# What this cannot do:
#   - Read conversation history to verify that approval actually happened
#   - Block executions programmatically (this is a warning hook, not a blocking gate)
#
# Practical effect: The warning appears in the agent's context window. If the AI is
# following the behavioral approval principle, it already has the approval — the warning
# is a no-op. If the AI skipped approval, the warning gives it a chance to abort before
# the mutation completes.
#
# Receives PreToolUse hook JSON on stdin.
# Stdout is injected into the agent context window.
# Exit 0 to allow the tool call. Exit 2 to block it (reserved for future enforcement).

set -uo pipefail

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

# Skip dry-run calls — they don't mutate
if echo "$COMMAND" | grep -q -- "--dry-run"; then
    exit 0
fi

# Mutation command patterns — MUST be kept in sync with gh-manager-monitor.sh (lines 93-99).
# Both scripts match the same write operations so the guard and audit trail stay aligned.
# If you add a new gh-manager write command, update the pattern in BOTH scripts.
MUTATION_PATTERN="prs merge|prs close|prs label|prs comment|prs create|prs request-review"
MUTATION_PATTERN2="issues close|issues label|issues comment|issues assign"
MUTATION_PATTERN3="files put|files delete|branches create|branches delete"
MUTATION_PATTERN4="releases draft|releases publish"
MUTATION_PATTERN5="discussions comment|discussions close"
MUTATION_PATTERN6="notifications mark-read|wiki push|wiki init"
MUTATION_PATTERN7="repo labels create|repo labels update|config repo-write|config portfolio-write"

IS_MUTATION=0
for PATTERN in "$MUTATION_PATTERN" "$MUTATION_PATTERN2" "$MUTATION_PATTERN3" "$MUTATION_PATTERN4" "$MUTATION_PATTERN5" "$MUTATION_PATTERN6" "$MUTATION_PATTERN7"; do
    if echo "$COMMAND" | grep -qE "$PATTERN"; then
        IS_MUTATION=1
        break
    fi
done

[ "$IS_MUTATION" -eq 1 ] || exit 0

# Extract the mutation subcommand for a more specific warning
MUTATION_CMD=$(echo "$COMMAND" | grep -oE 'gh-manager\.js [a-z-]+ [a-z-]+' | head -1 || echo "gh-manager mutation")

# Warn in context — gives the AI a chance to abort if no prior approval existed
echo "⚙️ GUARD: About to execute mutation: ${MUTATION_CMD}. Verify owner approval was given in this conversation before proceeding."

# Also log as a pending entry (separate from the post-execution audit trail)
AUDIT_LOG="$HOME/.github-repo-manager-audit.log"
TIMESTAMP=$(date -Iseconds 2>/dev/null || date +"%Y-%m-%d %H:%M:%S")
GH_CMD=$(echo "$COMMAND" | grep -oE 'gh-manager\.js[^|;&]*' | head -1 || echo "$COMMAND")
echo "[$TIMESTAMP] [PENDING] $GH_CMD" >> "$AUDIT_LOG" 2>/dev/null || true

exit 0

#!/usr/bin/env bash
# gh-manager-monitor.sh — PostToolUse hook for gh-manager monitoring
#
# Handles two concerns:
#   1. Rate limit watchdog — warns when API budget is running low
#   2. Mutation audit trail — logs non-dry-run mutations to ~/.github-repo-manager-audit.log
#
# Receives PostToolUse hook JSON on stdin.
# Stdout is injected into the agent context window.

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

# Extract the command that ran
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

# ─── Rate Limit Watchdog ──────────────────────────────────────────────────────
#
# gh-manager always returns _rate_limit in its JSON output.
# Try to extract it from the tool response output.

TOOL_OUTPUT=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    # try both 'output' and 'stdout' field names
    r = d.get('tool_response', {})
    print(r.get('output') or r.get('stdout') or '')
except:
    print('')
" 2>/dev/null)

if [ -n "$TOOL_OUTPUT" ]; then
    RATE_REMAINING=$(echo "$TOOL_OUTPUT" | python3 -c "
import sys, json
try:
    # The output might be a JSON object or the whole gh-manager JSON response
    text = sys.stdin.read()
    # Try to find _rate_limit in any JSON structure in the output
    d = json.loads(text)
    r = d.get('_rate_limit', {})
    remaining = r.get('remaining')
    if remaining is not None:
        print(remaining)
except Exception as e:
    import sys
    print(f'[gh-manager-monitor] rate-limit parse error: {e}', file=sys.stderr)
" 2>/dev/null)

    if [ -n "$RATE_REMAINING" ]; then
        if [ "$RATE_REMAINING" -lt 100 ] 2>/dev/null; then
            echo "🔴 Rate limit critical: ${RATE_REMAINING} REST calls remaining. Limit resets in ~1 hour — consider pausing."
        elif [ "$RATE_REMAINING" -lt 300 ] 2>/dev/null; then
            echo "⚠️ Rate limit low: ${RATE_REMAINING} REST calls remaining. Large cross-repo scans may fail."
        fi
    fi
fi

# ─── Mutation Audit Trail ─────────────────────────────────────────────────────
#
# Log every non-dry-run mutation to an audit log.
# This creates a recovery trail for the session.

# Skip dry-run calls — they don't mutate
if echo "$COMMAND" | grep -q -- "--dry-run"; then
    exit 0
fi

# Mutation command patterns (any write operation) — MUST be kept in sync with gh-manager-guard.sh (lines 62-68).
# Both scripts match the same write operations so the guard warning and audit trail stay aligned.
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

if [ "$IS_MUTATION" -eq 1 ]; then
    AUDIT_LOG="$HOME/.github-repo-manager-audit.log"
    TIMESTAMP=$(date -Iseconds 2>/dev/null || date +"%Y-%m-%d %H:%M:%S")
    # Extract just the gh-manager portion of the command
    GH_CMD=$(echo "$COMMAND" | grep -oE 'gh-manager\.js[^|;&]*' | head -1 || echo "$COMMAND")
    echo "[$TIMESTAMP] $GH_CMD" >> "$AUDIT_LOG" 2>/dev/null || true
fi

exit 0

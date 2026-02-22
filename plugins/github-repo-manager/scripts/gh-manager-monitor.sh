#!/usr/bin/env bash
# gh-manager-monitor.sh — PostToolUse hook for gh-manager monitoring
#
# Handles two concerns:
#   1. Rate limit watchdog — warns when API budget is running low
#   2. Mutation audit trail — logs confirmed mutations to ~/.github-repo-manager-audit.log
#
# Mutation patterns are sourced from mutation-patterns.sh (shared with gh-manager-guard.sh).
# To add a new mutation command, update mutation-patterns.sh — no changes needed here.
#
# Receives PostToolUse hook JSON on stdin.
# Stdout is injected into the agent context window.

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
# Log every confirmed (non-dry-run) mutation to the audit log.

if is_mutation_command "$COMMAND"; then
    AUDIT_LOG="$HOME/.github-repo-manager-audit.log"
    TIMESTAMP=$(date -Iseconds 2>/dev/null || date +"%Y-%m-%d %H:%M:%S")
    # Extract just the gh-manager portion of the command
    GH_CMD=$(echo "$COMMAND" | grep -oE 'gh-manager\.js[^|;&]*' | head -1 || echo "$COMMAND")
    echo "[$TIMESTAMP] $GH_CMD" >> "$AUDIT_LOG" 2>/dev/null || true
fi

exit 0

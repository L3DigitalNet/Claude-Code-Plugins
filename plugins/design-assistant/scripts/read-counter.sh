#!/usr/bin/env bash
# read-counter.sh — warns about context pressure when file reads accumulate
# Runs as a PostToolUse hook after every Read tool call.
# Uses $PPID (Claude Code process PID) as a stable session identifier.
# Mirrors the read-counter pattern from agent-orchestrator.

COUNT_FILE="/tmp/da-reads-$PPID"

# Read current count (0 if first run this session)
if [[ -f "$COUNT_FILE" ]]; then
    COUNT=$(cat "$COUNT_FILE")
else
    COUNT=0
fi

# Increment (safe with set -e — avoids ((var++)) pitfall when var=0)
COUNT=$((COUNT + 1))
echo "$COUNT" > "$COUNT_FILE"

# Emit threshold warnings — stdout is injected into the agent's context
if [[ "$COUNT" -eq 10 ]]; then
    echo "⚠ CONTEXT NOTICE — design-assistant: $COUNT files read this session. Context is growing. For long /design-review sessions, consider using \`pause\` to snapshot state before the next pass."
elif [[ "$COUNT" -eq 20 ]]; then
    echo "⚠⚠ CONTEXT PRESSURE — design-assistant: $COUNT files read this session. High context load. Strongly recommended: use \`pause\` before continuing and resume in a fresh session with the saved document."
fi

exit 0

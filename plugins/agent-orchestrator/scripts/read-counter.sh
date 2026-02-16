#!/bin/bash
# PostToolUse hook: counts file reads per session (keyed by parent PID).
# Warns at 10+ reads, critical alert at 15+ to enforce context discipline.
# Applies to all agents (lead + teammates).

COUNTER_FILE=".claude/state/.read-count-$PPID"

# Ensure state directory exists
mkdir -p "$(dirname "$COUNTER_FILE")"

# Read current count (default 0)
COUNT=$(cat "$COUNTER_FILE" 2>/dev/null || echo 0)
COUNT=$((COUNT + 1))
echo "$COUNT" > "$COUNTER_FILE"

if [ "$COUNT" -eq 10 ]; then
  echo "WARNING: You have read 10 files in this session. Write your handoff note NOW and consider compacting. Context discipline is critical."
elif [ "$COUNT" -eq 15 ]; then
  echo "CRITICAL: 15 file reads. You MUST write a handoff note and compact immediately. Run: /compact"
fi

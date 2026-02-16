#!/bin/bash
# PreCompact hook: logs compaction event to its own file (NOT the ledger)
# and injects a reminder into the agent's context via stdout.

TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Log to compaction events file (append-only, read by lead between waves)
if [ -d ".claude/state" ]; then
  echo "$TIMESTAMP auto-compaction triggered" >> ".claude/state/compaction-events.log"
fi

# stdout becomes context — remind the agent
echo "COMPACTION IMMINENT. Write your handoff note to .claude/state/<your-name>-handoff.md NOW. After compaction, read it to restore continuity."

#!/usr/bin/env bash
# pause-snapshot.sh — Serialize session state to markdown snapshot.
#
# Usage: pause-snapshot.sh <command-type> <session-id>
#   command-type: "review" reads from state file, "draft" reads from stdin
#
# Output: Formatted markdown snapshot to stdout.
# Exit:   0 on success, 1 if session not found.

set -euo pipefail
PYTHON=$(command -v python3 2>/dev/null || command -v python 2>/dev/null) \
  || { echo '{"error":"python3 not found"}' >&2; exit 1; }

CMD_TYPE="${1:?Usage: pause-snapshot.sh <draft|review> <session-id>}"
SESSION_ID="${2:--}"

if [[ "$CMD_TYPE" == "review" ]]; then
  STATE_FILE="/tmp/design-assistant-${SESSION_ID}.json"
  if [[ ! -f "$STATE_FILE" ]]; then
    echo "{\"error\":\"session not found\",\"session_id\":\"$SESSION_ID\"}" >&2
    exit 1
  fi
  STATE_JSON=$(cat "$STATE_FILE")
elif [[ "$CMD_TYPE" == "draft" ]]; then
  STATE_JSON=$(cat)
else
  echo '{"error":"command-type must be draft or review"}' >&2
  exit 1
fi

echo "$STATE_JSON" | $PYTHON -c "
import json, sys
from datetime import datetime, timezone

state = json.load(sys.stdin)
cmd_type = sys.argv[1]
now = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')

lines = []

if cmd_type == 'review':
    lines.append('## DESIGN REVIEW — PAUSE SNAPSHOT')
    lines.append(f'Saved: {now}')
    lines.append(f'Document: {state.get(\"document_path\", \"unknown\")}')
    lines.append(f'Session: {state.get(\"session_id\", \"unknown\")}')
    lines.append(f'Pass: {state.get(\"pass_number\", 0)}')
    lines.append(f'Auto-Fix Mode: {state.get(\"auto_fix_mode\", \"not set\")}')
    lines.append(f'Finding Counter: {state.get(\"global_finding_counter\", 0)}')
    lines.append('')

    # Pending findings
    pending = [f for f in state.get('finding_queue', []) if f.get('status') == 'pending']
    lines.append(f'### Pending Findings ({len(pending)})')
    if pending:
        lines.append('| # | Track | Severity | Section | Description |')
        lines.append('|---|-------|----------|---------|-------------|')
        for f in pending:
            lines.append(f'| {f.get(\"id\",\"?\")} | {f.get(\"track\",\"?\")} | {f.get(\"severity\",\"?\")} | {f.get(\"section\",\"?\")} | {f.get(\"description\",\"\")[:60]} |')
    else:
        lines.append('None')
    lines.append('')

    # Section status
    sections = state.get('section_status', {})
    if sections:
        lines.append('### Section Status')
        lines.append('| Section | Status | Modifications |')
        lines.append('|---------|--------|---------------|')
        for name, info in sections.items():
            lines.append(f'| {name} | {info.get(\"status\",\"?\")} | {info.get(\"modification_count\",0)} |')
        lines.append('')

    # Deferred log
    deferred = state.get('deferred_log', [])
    active_deferred = [d for d in deferred if d.get('retired_status') == 'Active']
    if active_deferred:
        lines.append(f'### Active Deferred ({len(active_deferred)})')
        for d in active_deferred:
            lines.append(f'- #{d[\"id\"]} [{d.get(\"severity\",\"?\")}] {d.get(\"description\",\"\")[:80]}')
        lines.append('')

    # Systemic triggers
    triggers = state.get('systemic_triggers', [])
    if triggers:
        lines.append('### Systemic Triggers')
        for t in triggers:
            lines.append(f'- {t}')
        lines.append('')

elif cmd_type == 'draft':
    lines.append('## DESIGN DRAFT — PAUSE SNAPSHOT')
    lines.append(f'Saved: {now}')
    lines.append(f'Phase: {state.get(\"phase\", \"unknown\")}')
    lines.append(f'Step: {state.get(\"step\", \"unknown\")}')
    lines.append('')

    # Candidates
    candidates = state.get('candidates', [])
    if candidates:
        lines.append(f'### Candidate Principles ({len(candidates)})')
        lines.append('| Name | Status | Stress-Test |')
        lines.append('|------|--------|-------------|')
        for c in candidates:
            lines.append(f'| {c.get(\"name\",\"?\")} | {c.get(\"status\",\"?\")} | {c.get(\"stress_test_verdict\",\"pending\")} |')
        lines.append('')

    # Tensions
    tensions = state.get('tension_log', [])
    if tensions:
        lines.append(f'### Tensions ({len(tensions)})')
        for t in tensions:
            lines.append(f'- [{t.get(\"status\",\"?\")}] {t.get(\"description\",\"\")[:80]}')
        lines.append('')

    # Open questions
    oqs = state.get('open_questions', [])
    if oqs:
        lines.append(f'### Open Questions ({len(oqs)})')
        for oq in oqs:
            lines.append(f'- {oq.get(\"id\",\"?\")}: {oq.get(\"text\",\"\")[:80]}')
        lines.append('')

print('\n'.join(lines))
" "$CMD_TYPE"

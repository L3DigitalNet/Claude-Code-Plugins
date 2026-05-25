#!/usr/bin/env bash
# deny-guard.sh — PreToolUse hook for up-docs plugin.
#
# Scoped: only enforces denies when invoked from inside an up-docs subagent
# (up-docs:up-docs-audit-drift and its siblings). In the main session, or
# when invoked from a non-up-docs subagent, exits 0 immediately.
#
# Scoping is determined by reading transcript_path from the hook JSON input
# and walking the JSONL to find the innermost still-open Agent tool_use.
# If that Agent's subagent_type starts with "up-docs:", enforcement runs.
#
# Blocks Bash commands matching the auditor's <forbidden_commands> categories:
#   - Filesystem destruction: rm, rmdir, shred, truncate, mv, cp -f overwriting
#   - Output redirection writes that overwrite system files
#   - Container lifecycle: pct stop/destroy/restore/migrate, qm stop/destroy
#   - Service control: systemctl stop/restart/disable/mask, service X stop, kill, killall, pkill
#   - Network/permissions: iptables, nft, ip route add/del, chmod, chown, chgrp, chattr, setfacl
#   - Package edits: apt install/remove, dnf install/remove, pip install, npm install --save
#   - Git destructive: git rm, git push --force, git reset --hard
#   - SQL writes: INSERT/UPDATE/DELETE/DROP/ALTER/TRUNCATE
#
# Failure mode: fail open. If JSON parse, transcript scan, or pattern match
# fails, exit 0. The deny-guard is defense-in-depth, not a security
# boundary — see README "Recommended consumer-side permissions.deny" for
# the actually-enforced layer.

set -uo pipefail

# Read PreToolUse JSON
INPUT=$(cat)

# Extract command + transcript path (fail open if extraction fails)
COMMAND=$(printf '%s' "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('command', ''))
except Exception:
    print('')
" 2>/dev/null)

[ -z "$COMMAND" ] && exit 0

TRANSCRIPT_PATH=$(printf '%s' "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('transcript_path', ''))
except Exception:
    print('')
" 2>/dev/null)

# --- Scope check: are we inside an up-docs subagent? -------------------------
# Walk the transcript JSONL and track a stack of (tool_use_id, subagent_type)
# entries for Agent tool_use blocks. Pop when a matching tool_result appears.
# If the innermost still-open Agent at end-of-transcript is an up-docs agent,
# enforcement applies. Otherwise exit 0.

IN_UP_DOCS_SUBAGENT=$(TRANSCRIPT="$TRANSCRIPT_PATH" python3 <<'PY' 2>/dev/null || echo 0
import json, os, sys

path = os.environ.get("TRANSCRIPT", "")
if not path or not os.path.exists(path):
    print(0)
    sys.exit(0)

UP_DOCS_PREFIX = "up-docs:"
active = []  # stack of (tool_use_id, subagent_type)

try:
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                entry = json.loads(line)
            except Exception:
                continue
            msg = entry.get("message")
            if not isinstance(msg, dict):
                continue
            content = msg.get("content", [])
            if not isinstance(content, list):
                continue
            for block in content:
                if not isinstance(block, dict):
                    continue
                bt = block.get("type")
                if bt == "tool_use" and block.get("name") == "Agent":
                    tid = block.get("id") or ""
                    sub = ((block.get("input") or {}).get("subagent_type")) or ""
                    active.append((tid, sub))
                elif bt == "tool_result":
                    target = block.get("tool_use_id") or ""
                    active = [a for a in active if a[0] != target]
except Exception:
    print(0)
    sys.exit(0)

if active and active[-1][1].startswith(UP_DOCS_PREFIX):
    print(1)
else:
    print(0)
PY
)

if [ "$IN_UP_DOCS_SUBAGENT" != "1" ]; then
    exit 0
fi

# --- Enforcement (only reached when inside an up-docs subagent) -------------
# Tokenize on shell operators: |, &&, ||, ;, $(, `
SEGMENTS=$(printf '%s\n' "$COMMAND" | python3 -c "
import sys, re
text = sys.stdin.read()
parts = [text]
parts.extend(re.findall(r'\\\$\\(([^)]*)\\)', text))
parts.extend(re.findall(r'\`([^\`]*)\`', text))
splitter = re.compile(r'\\|\\||&&|\\||;')
out = []
for p in parts:
    out.extend(splitter.split(p))
for line in out:
    line = line.strip()
    if line:
        print(line)
")

DENY_PATTERNS=$(cat <<'PATTERNS'
^\s*rm(\s+-[a-zA-Z]+)*\s+
^\s*rmdir(\s+-[a-zA-Z]+)*\s+
^\s*shred(\s|$)
^\s*truncate(\s|$)
^\s*mv\s+\S+\s+\S+
^\s*cp\s+(-[a-zA-Z]*f[a-zA-Z]*\s+|-f\s+|--force\s+)
^\s*git\s+rm(\s|$)
^\s*git\s+push\s+(--force|-f(\s|$))
^\s*git\s+reset\s+--hard
^\s*pct\s+(stop|shutdown|destroy|restore|migrate)(\s|$)
^\s*qm\s+(stop|destroy)(\s|$)
^\s*docker\s+(stop|rm)(\s|$)
^\s*docker-compose\s+down(\s|$)
^\s*systemctl\s+(stop|restart|disable|mask)(\s|$)
^\s*service\s+\S+\s+(stop|restart)(\s|$)
^\s*kill(\s|$)
^\s*killall(\s|$)
^\s*pkill(\s|$)
^\s*iptables(\s|$)
^\s*nft(\s|$)
^\s*ip\s+route\s+(add|del)(\s|$)
^\s*chmod(\s|$)
^\s*chown(\s|$)
^\s*chgrp(\s|$)
^\s*chattr(\s|$)
^\s*setfacl(\s|$)
^\s*apt(-get)?\s+(install|remove|purge)(\s|$)
^\s*dnf\s+(install|remove)(\s|$)
^\s*yum\s+(install|remove)(\s|$)
^\s*pip3?\s+install(\s|$)
^\s*npm\s+install\s+(--save|-S\b)
^\s*sed\s+-i(\s|$)
^\s*tee(\s+-a)?\s+(/etc|/usr|/var|/opt|/boot)
.*>\s*(/etc|/usr|/var|/opt|/boot)
.*\b(INSERT|UPDATE|DELETE|DROP|ALTER|TRUNCATE)\s+(INTO|FROM|TABLE|DATABASE|VIEW|INDEX)\b
PATTERNS
)

MATCHED_SEG=""
MATCHED_PAT=""
while IFS= read -r SEG; do
    [ -z "$SEG" ] && continue
    while IFS= read -r PAT; do
        [ -z "$PAT" ] && continue
        if echo "$SEG" | grep -qE "$PAT"; then
            MATCHED_SEG="$SEG"
            MATCHED_PAT="$PAT"
            break 2
        fi
    done <<< "$DENY_PATTERNS"
done <<< "$SEGMENTS"

if [ -n "$MATCHED_PAT" ]; then
    REASON="up-docs deny-guard blocked: command segment $(printf '%q' "$MATCHED_SEG") matches forbidden pattern $(printf '%q' "$MATCHED_PAT"). See plugins/up-docs/agents/up-docs-audit-drift.md <forbidden_commands>. Override only with explicit owner approval and re-run as a separate command without the up-docs plugin loaded."
    REASON_JSON=$(printf '%s' "$REASON" | python3 -c "import sys, json; print(json.dumps(sys.stdin.read()))")
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":%s}}\n' "$REASON_JSON"
    exit 2
fi

exit 0

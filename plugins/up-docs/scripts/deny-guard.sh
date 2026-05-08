#!/usr/bin/env bash
# deny-guard.sh — PreToolUse hook for up-docs plugin.
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
# The hook parses the full command line — including pipes, redirects, `&&` /
# `;` chains, and inline subshell substitution — by tokenizing on shell
# operators and checking each segment.
#
# Patterned on plugins/release-pipeline/scripts/force-push-guard.sh:
#   - Reads PreToolUse JSON on stdin
#   - exit 0 to allow, exit 2 to block
#   - On block: emits hookSpecificOutput.permissionDecision="deny" JSON
#
# Failure mode: fail open. If the JSON parse fails or the command can't be
# extracted, exit 0. The deny-guard is defense-in-depth, not a security
# boundary — see README "Recommended consumer-side permissions.deny" for
# the actually-enforced layer.

set -uo pipefail

# Read PreToolUse JSON
INPUT=$(cat)

# Extract command (fail open if extraction fails)
COMMAND=$(printf '%s' "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('command', ''))
except Exception:
    print('')
" 2>/dev/null)

[ -z "$COMMAND" ] && exit 0

# Tokenize on shell operators: |, &&, ||, ;, $(, `
# Anything inside one of those segments is a candidate command-line.
# We also keep the whole command as one segment for catch-all matchers.
SEGMENTS=$(printf '%s\n' "$COMMAND" | python3 -c "
import sys, re
text = sys.stdin.read()
# Split on |, &&, ||, ;, and the body of \$(...) and \`...\`
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

# Patterns to deny. Each pattern is matched against each segment with grep -E.
# Format: one anchored regex per line.
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

# Iterate every segment against every pattern; first match blocks.
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

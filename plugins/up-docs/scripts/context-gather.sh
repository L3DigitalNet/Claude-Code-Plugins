#!/usr/bin/env bash
# context-gather.sh — Consolidate git context for up-docs skills.
#
# Usage: context-gather.sh [--depth N]
# Output: JSON with branch, commits, diff stats.
# Exit:   0 always.

set -euo pipefail
PYTHON=$(command -v python3 2>/dev/null || command -v python 2>/dev/null) \
  || { echo '{"error":"python3 not found"}' >&2; exit 1; }

DEPTH=5
while [[ $# -gt 0 ]]; do
  case "$1" in
    --depth) DEPTH="$2"; shift 2 ;;
    *) shift ;;
  esac
done

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo '{"is_git_repo":false}'
  exit 0
fi

BRANCH=$(git branch --show-current 2>/dev/null || git describe --always 2>/dev/null || echo "detached")
LOG_OUTPUT=$(git log --oneline --numstat -"$DEPTH" 2>/dev/null || echo "")

# Get diff stat: compare HEAD against N commits back
BASE=$(git rev-list --max-count="$DEPTH" HEAD 2>/dev/null | tail -1)
if [[ -n "$BASE" ]]; then
  DIFF_STAT=$(git diff --numstat "$BASE" HEAD 2>/dev/null || git diff --numstat 2>/dev/null || echo "")
else
  DIFF_STAT=$(git diff --numstat 2>/dev/null || echo "")
fi

export BRANCH LOG_OUTPUT DIFF_STAT DEPTH

$PYTHON << 'PYEOF'
import json, os, re, sys

branch = os.environ.get("BRANCH", "unknown")
log_output = os.environ.get("LOG_OUTPUT", "")
diff_stat = os.environ.get("DIFF_STAT", "")

# Parse git log --oneline --numstat
commits = []
current = None
for line in log_output.splitlines():
    line = line.rstrip()
    if not line:
        continue
    # Commit line: hash subject
    if re.match(r'^[0-9a-f]{7,}', line):
        if current:
            commits.append(current)
        parts = line.split(None, 1)
        current = {"hash": parts[0], "subject": parts[1] if len(parts) > 1 else "", "files_changed": 0}
    elif current and '\t' in line:
        current["files_changed"] += 1

if current:
    commits.append(current)

# Parse diff stat
files = []
total_ins = 0
total_del = 0
for line in diff_stat.splitlines():
    parts = line.split('\t')
    if len(parts) >= 3:
        ins = int(parts[0]) if parts[0] != '-' else 0
        dels = int(parts[1]) if parts[1] != '-' else 0
        path = parts[2]
        files.append({"path": path, "insertions": ins, "deletions": dels})
        total_ins += ins
        total_del += dels

result = {
    "branch": branch,
    "last_n_commits": commits,
    "diff_stat": {
        "files_changed": len(files),
        "insertions": total_ins,
        "deletions": total_del,
        "files": files,
    },
    "is_git_repo": True,
}

print(json.dumps(result, indent=2))
PYEOF

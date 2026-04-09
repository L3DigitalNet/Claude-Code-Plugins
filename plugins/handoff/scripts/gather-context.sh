#!/usr/bin/env bash
# gather-context.sh — Collect machine and git context for handoff save.
#
# Usage: gather-context.sh [--description <slug>]
# Output: JSON with working_directory, hostname, timestamp, git state.
# Exit:   0 always.

set -euo pipefail
PYTHON=$(command -v python3 2>/dev/null || command -v python 2>/dev/null) \
  || { echo '{"error":"python3 not found"}' >&2; exit 1; }

DESCRIPTION=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --description) DESCRIPTION="$2"; shift 2 ;;
    *) shift ;;
  esac
done

WORK_DIR=$(pwd)
HOST=$(hostname 2>/dev/null || cat /etc/hostname 2>/dev/null || echo "unknown")
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S")
DATE_SLUG=$(date +"%Y-%m-%d-%H%M%S")

# Generate filename
if [[ -n "$DESCRIPTION" ]]; then
  SLUG=$(echo "$DESCRIPTION" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g; s/--*/-/g; s/^-//; s/-$//')
  FILENAME="${SLUG}-handoff-${DATE_SLUG}.md"
else
  FILENAME="handoff-${DATE_SLUG}.md"
fi

# Git context
GIT_JSON="{\"is_repo\":false}"
if git rev-parse --git-dir >/dev/null 2>&1; then
  BRANCH=$(git branch --show-current 2>/dev/null)
  [[ -z "$BRANCH" ]] && BRANCH=$(git describe --always 2>/dev/null || echo "detached")

  STATUS_RAW=$(git status --porcelain 2>/dev/null || echo "")
  if [[ -z "$STATUS_RAW" ]]; then
    GIT_STATUS="clean"
    UNCOMMITTED="[]"
  else
    GIT_STATUS="dirty"
    UNCOMMITTED=$(echo "$STATUS_RAW" | $PYTHON -c "import json,sys; print(json.dumps([l.strip() for l in sys.stdin if l.strip()]))")
  fi

  COMMITS=$(git log --oneline -5 2>/dev/null | $PYTHON -c "
import json,sys
commits = []
for line in sys.stdin:
    parts = line.strip().split(' ', 1)
    if len(parts) >= 2:
        commits.append({'hash': parts[0], 'subject': parts[1]})
    elif parts:
        commits.append({'hash': parts[0], 'subject': ''})
print(json.dumps(commits))
")

  REMOTE=$(git remote 2>/dev/null | head -1 || echo "")

  AHEAD_BEHIND=$(git rev-list --left-right --count HEAD...@{upstream} 2>/dev/null || echo "")
  if [[ -n "$AHEAD_BEHIND" ]]; then
    AHEAD=$(echo "$AHEAD_BEHIND" | awk '{print $1}')
    BEHIND=$(echo "$AHEAD_BEHIND" | awk '{print $2}')
  else
    AHEAD="null"
    BEHIND="null"
  fi

  export BRANCH GIT_STATUS UNCOMMITTED COMMITS REMOTE AHEAD BEHIND
fi

export WORK_DIR HOST TIMESTAMP FILENAME

$PYTHON << 'PYEOF'
import json, os

work_dir = os.environ.get("WORK_DIR", "")
hostname = os.environ.get("HOST", "unknown")
timestamp = os.environ.get("TIMESTAMP", "")
filename = os.environ.get("FILENAME", "")

branch = os.environ.get("BRANCH", "")
if branch:
    git_status = os.environ.get("GIT_STATUS", "clean")
    uncommitted = json.loads(os.environ.get("UNCOMMITTED", "[]"))
    commits = json.loads(os.environ.get("COMMITS", "[]"))
    remote = os.environ.get("REMOTE", "") or None
    ahead_str = os.environ.get("AHEAD", "null")
    behind_str = os.environ.get("BEHIND", "null")
    ahead = None if ahead_str == "null" else int(ahead_str)
    behind = None if behind_str == "null" else int(behind_str)

    git = {
        "is_repo": True,
        "branch": branch,
        "status": git_status,
        "uncommitted_files": uncommitted,
        "recent_commits": commits,
        "remote": remote,
        "ahead": ahead,
        "behind": behind,
    }
else:
    git = {"is_repo": False}

result = {
    "working_directory": work_dir,
    "hostname": hostname,
    "timestamp": timestamp,
    "filename": filename,
    "git": git,
}
print(json.dumps(result, indent=2))
PYEOF

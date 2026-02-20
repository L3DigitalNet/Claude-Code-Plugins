#!/usr/bin/env bash
set -euo pipefail

# Check 5 of 5: finds uncommitted files (modified or untracked, excluding ignored)
# that were last modified more than 24 hours ago.
# All findings are needs-approval — staging/committing requires user intent.
# Output: JSON {check, findings[]} to stdout. No auto_fix, fix_cmd is always null.

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

python3 - "$REPO_ROOT" << 'PYTHON_EOF'
import json, os, sys, subprocess, time

repo_root = sys.argv[1]
cutoff = time.time() - 86400  # 24 hours ago

result = subprocess.run(
    ["git", "-C", repo_root, "status", "--porcelain"],
    capture_output=True, text=True, check=True
)

findings = []
for line in result.stdout.splitlines():
    if not line.strip():
        continue
    xy = line[:2]      # two-char status code
    filepath = line[3:].strip()

    # Handle renamed files: "old -> new"
    if " -> " in filepath:
        filepath = filepath.split(" -> ")[-1]

    # Prefer worktree status char (xy[1]); fall back to index char (xy[0])
    status_char = xy[1].strip() or xy[0].strip() or "?"

    abs_path = os.path.join(repo_root, filepath)
    if not os.path.exists(abs_path):
        continue  # deleted file — skip

    mtime = os.stat(abs_path).st_mtime
    if mtime < cutoff:
        age_secs = int(time.time() - mtime)
        age_h = age_secs // 3600
        age_d = age_h // 24
        age_str = f"{age_d}d {age_h % 24}h" if age_d > 0 else f"{age_h}h"

        findings.append({
            "severity": "warn",
            "path": filepath,
            "detail": f"Uncommitted '{status_char}' file last modified {age_str} ago",
            "auto_fix": False,
            "fix_cmd": None
        })

print(json.dumps({"check": "stale-commits", "findings": findings}))
PYTHON_EOF

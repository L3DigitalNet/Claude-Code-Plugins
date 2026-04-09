#!/usr/bin/env bash
# git-function-changes.sh — Extract function signatures changed since a date.
#
# Usage: git-function-changes.sh <since-date> [scope-directory] [--extensions .py,.ts,.swift]
# Output: JSON with changed_functions array and file list.
# Exit:   0 always.

set -euo pipefail
PYTHON=$(command -v python3 2>/dev/null || command -v python 2>/dev/null) \
  || { echo '{"error":"python3 not found"}' >&2; exit 1; }

SINCE_DATE="${1:?Usage: git-function-changes.sh <since-date> [scope-dir] [--extensions .py,.ts]}"
shift
SCOPE="."
EXTENSIONS=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --extensions) EXTENSIONS="$2"; shift 2 ;;
    *) SCOPE="$1"; shift ;;
  esac
done

# Check for git repo
if ! git rev-parse HEAD >/dev/null 2>&1; then
  echo '{"error":"no git repository or no commits","changed_functions":[],"changed_files":[],"total_functions_changed":0,"total_files_changed":0}'
  exit 0
fi

# Get git diff output
GIT_OUTPUT=$(git log --since="$SINCE_DATE" -p -- "$SCOPE" 2>&1) || {
  echo "{\"error\":\"git error\",\"changed_functions\":[],\"changed_files\":[],\"total_functions_changed\":0,\"total_files_changed\":0}"
  exit 0
}

export SINCE_DATE EXTENSIONS GIT_OUTPUT

$PYTHON << 'PYEOF'
import json, os, re, sys

extensions = os.environ.get("EXTENSIONS", "")
since = os.environ.get("SINCE_DATE", "")

# Parse extension filter
ext_filter = set()
if extensions:
    ext_filter = {e.strip() if e.startswith(".") else f".{e.strip()}" for e in extensions.split(",")}

# Function patterns per language
FUNC_PATTERNS = {
    ".py": re.compile(r"(?:async\s+)?def\s+(\w+)"),
    ".swift": re.compile(r"(?:public|private|internal|open|fileprivate)?\s*(?:static\s+)?func\s+(\w+)"),
    ".ts": re.compile(r"(?:export\s+)?(?:async\s+)?function\s+(\w+)|(?:export\s+)?(?:const|let|var)\s+(\w+)\s*=\s*(?:async\s+)?\("),
    ".tsx": re.compile(r"(?:export\s+)?(?:async\s+)?function\s+(\w+)|(?:export\s+)?(?:const|let|var)\s+(\w+)\s*=\s*(?:async\s+)?\("),
    ".js": re.compile(r"(?:export\s+)?(?:async\s+)?function\s+(\w+)|(?:export\s+)?(?:const|let|var)\s+(\w+)\s*=\s*(?:async\s+)?\("),
    ".jsx": re.compile(r"(?:export\s+)?(?:async\s+)?function\s+(\w+)|(?:export\s+)?(?:const|let|var)\s+(\w+)\s*=\s*(?:async\s+)?\("),
    ".rs": re.compile(r"(?:pub(?:\(.*\))?\s+)?(?:async\s+)?fn\s+(\w+)"),
    ".go": re.compile(r"^func\s+(?:\(.*\)\s+)?(\w+)"),
    ".java": re.compile(r"(?:public|private|protected)\s+(?:static\s+)?(?:\w+\s+)+(\w+)\s*\("),
}

diff_text = os.environ.get("GIT_OUTPUT", "")
current_file = None
added_funcs = {}   # file -> set of func names in + lines
removed_funcs = {} # file -> set of func names in - lines
changed_files = set()

for line in diff_text.splitlines():
    if line.startswith("+++ b/"):
        current_file = line[6:]
        ext = os.path.splitext(current_file)[1]
        if ext_filter and ext not in ext_filter:
            current_file = None
            continue
        changed_files.add(current_file)
    elif line.startswith("--- a/"):
        pass
    elif current_file:
        ext = os.path.splitext(current_file)[1]
        pattern = FUNC_PATTERNS.get(ext)
        if not pattern:
            continue

        if line.startswith("+") and not line.startswith("+++"):
            m = pattern.search(line[1:])
            if m:
                func_name = m.group(1) or (m.group(2) if m.lastindex and m.lastindex >= 2 else None)
                if func_name:
                    added_funcs.setdefault(current_file, set()).add(func_name)
        elif line.startswith("-") and not line.startswith("---"):
            m = pattern.search(line[1:])
            if m:
                func_name = m.group(1) or (m.group(2) if m.lastindex and m.lastindex >= 2 else None)
                if func_name:
                    removed_funcs.setdefault(current_file, set()).add(func_name)

# Classify: added (only in +) vs modified (in both + and -)
changed_functions = []
seen = set()

for f in sorted(added_funcs.keys()):
    for func in sorted(added_funcs[f]):
        key = (f, func)
        if key in seen:
            continue
        seen.add(key)
        removed_in_file = removed_funcs.get(f, set())
        change_type = "modified" if func in removed_in_file else "added"
        changed_functions.append({
            "file": f,
            "function": func,
            "change_type": change_type,
        })

result = {
    "since": since,
    "changed_functions": changed_functions,
    "changed_files": sorted(changed_files),
    "total_functions_changed": len(changed_functions),
    "total_files_changed": len(changed_files),
}

print(json.dumps(result, indent=2))
PYEOF

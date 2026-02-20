#!/usr/bin/env bash
# auto-build-plugins.sh — PreToolUse hook on Bash.
#
# When a git commit is about to run, checks if any staged TypeScript source
# files belong to a plugin with a "build" npm script. If so, runs npm run build
# in each affected plugin directory, stages the resulting dist/ files, then
# exits 0 to let the commit proceed (now including fresh built artifacts).
#
# Blocks with exit 2 if any build fails — better to stop the commit than
# release a plugin with a stale or broken dist/.
#
# Called by: release-pipeline hooks.json → PreToolUse → Bash
# Receives:  JSON on stdin with tool_input.command and cwd

set -euo pipefail

input=$(cat)

# Extract the bash command being run. Fail open if parsing fails.
cmd=$(printf '%s' "$input" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('tool_input', {}).get('command', ''))
" 2>/dev/null) || cmd=""

# Only act on git commit commands — skip everything else
printf '%s' "$cmd" | grep -qE 'git\s+commit' || exit 0

# Find the git repo root from the session's cwd
cwd=$(printf '%s' "$input" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('cwd', ''))
" 2>/dev/null) || cwd=""

[ -z "$cwd" ] && exit 0

repo_root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null) || exit 0

# Get staged files; bail early if nothing staged
staged=$(git -C "$repo_root" diff --cached --name-only 2>/dev/null) || staged=""
[ -z "$staged" ] && exit 0

# Find unique plugin dirs that have staged TypeScript source files
declare -A seen
built=()
failed=()

while IFS= read -r file; do
  # Match: plugins/<name>/src/**/*.ts
  if [[ "$file" =~ ^plugins/([^/]+)/src/.*\.ts$ ]]; then
    plugin="${BASH_REMATCH[1]}"

    # Deduplicate — only process each plugin once
    [ "${seen[$plugin]:-}" = "1" ] && continue
    seen[$plugin]="1"

    plugin_dir="$repo_root/plugins/$plugin"
    pkg_json="$plugin_dir/package.json"

    [ -f "$pkg_json" ] || continue

    # Check for a "build" script in package.json
    has_build=$(python3 -c "
import json, sys
try:
    d = json.load(open('$pkg_json'))
    print('yes' if 'build' in d.get('scripts', {}) else 'no')
except Exception:
    print('no')
") || has_build="no"

    [ "$has_build" = "yes" ] || continue

    echo "Building $plugin before commit..."
    if (cd "$plugin_dir" && npm run build 2>&1); then
      built+=("$plugin")
      # Stage dist/ so the built files land in this commit
      git -C "$repo_root" add "plugins/$plugin/dist/" 2>/dev/null || true
    else
      failed+=("$plugin")
    fi
  fi
done <<< "$staged"

if [ ${#failed[@]} -gt 0 ]; then
  printf 'Build failed for: %s\nFix build errors before releasing.\n' "${failed[*]}" >&2
  exit 2
fi

if [ ${#built[@]} -gt 0 ]; then
  printf 'Auto-built and staged dist/ for: %s\n' "${built[*]}"
fi

exit 0

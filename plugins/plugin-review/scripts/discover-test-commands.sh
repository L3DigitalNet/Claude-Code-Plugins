#!/usr/bin/env bash
# Probes a plugin directory for build and test commands.
# Called by run-build-test.sh and directly by commands/review.md Phase 4.5.
# Output: JSON array to stdout — [{"type":"build|test","command":"...","cwd":"..."}]
# Exit 0 always — absence of tests is not an error.
# Arg: $1 = plugin directory path (relative or absolute)

set -uo pipefail

PLUGIN_DIR="${1:-}"

if [ -z "$PLUGIN_DIR" ]; then
  echo "Usage: discover-test-commands.sh <plugin-dir>" >&2
  exit 1
fi

if [ ! -d "$PLUGIN_DIR" ]; then
  echo "Error: directory not found: $PLUGIN_DIR" >&2
  exit 1
fi

# Resolve to absolute path so cwd fields are unambiguous
PLUGIN_DIR_ABS="$(cd "$PLUGIN_DIR" && pwd)"

# Collect commands as bash arrays, then serialize with Python to avoid JSON quoting issues
TYPES=()
COMMANDS=()
CWDS=()

# --- package.json (npm/node plugin) ---
if [ -f "$PLUGIN_DIR_ABS/package.json" ]; then
  has_build=$(python3 -c "
import json, sys
try:
    d = json.load(open('$PLUGIN_DIR_ABS/package.json'))
    s = d.get('scripts', {})
    print('yes' if 'build' in s else 'no')
except Exception:
    print('no')
")
  has_test=$(python3 -c "
import json, sys
try:
    d = json.load(open('$PLUGIN_DIR_ABS/package.json'))
    s = d.get('scripts', {})
    print('yes' if 'test' in s else 'no')
except Exception:
    print('no')
")
  if [ "$has_build" = "yes" ]; then
    TYPES+=("build"); COMMANDS+=("npm run build"); CWDS+=("$PLUGIN_DIR_ABS")
  fi
  if [ "$has_test" = "yes" ]; then
    TYPES+=("test"); COMMANDS+=("npm test"); CWDS+=("$PLUGIN_DIR_ABS")
  fi
fi

# --- Makefile ---
if [ -f "$PLUGIN_DIR_ABS/Makefile" ]; then
  if grep -q "^build:" "$PLUGIN_DIR_ABS/Makefile" 2>/dev/null; then
    TYPES+=("build"); COMMANDS+=("make build"); CWDS+=("$PLUGIN_DIR_ABS")
  fi
  if grep -q "^test:" "$PLUGIN_DIR_ABS/Makefile" 2>/dev/null; then
    TYPES+=("test"); COMMANDS+=("make test"); CWDS+=("$PLUGIN_DIR_ABS")
  fi
fi

# --- pytest (pyproject.toml or pytest.ini or setup.cfg) ---
has_pytest=0
if [ -f "$PLUGIN_DIR_ABS/pytest.ini" ]; then
  has_pytest=1
fi
if [ -f "$PLUGIN_DIR_ABS/pyproject.toml" ] && grep -q '\[tool\.pytest' "$PLUGIN_DIR_ABS/pyproject.toml" 2>/dev/null; then
  has_pytest=1
fi
if [ -f "$PLUGIN_DIR_ABS/setup.cfg" ] && grep -q '\[tool:pytest\]' "$PLUGIN_DIR_ABS/setup.cfg" 2>/dev/null; then
  has_pytest=1
fi
if [ "$has_pytest" = "1" ]; then
  TYPES+=("test"); COMMANDS+=("pytest"); CWDS+=("$PLUGIN_DIR_ABS")
fi

# --- shell test scripts (scripts/test*.sh) ---
if [ -d "$PLUGIN_DIR_ABS/scripts" ]; then
  for f in "$PLUGIN_DIR_ABS/scripts"/test*.sh; do
    [ -f "$f" ] || continue
    TYPES+=("test"); COMMANDS+=("bash $f"); CWDS+=("$PLUGIN_DIR_ABS")
  done
fi

# Serialize to JSON with Python — avoids manual quoting of paths/commands
python3 - <<PYEOF
import json
types = ${TYPES[@]+"$(IFS=$'\n'; printf '%s\n' "${TYPES[@]}" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read().splitlines()))")"}
commands = ${COMMANDS[@]+"$(IFS=$'\n'; printf '%s\n' "${COMMANDS[@]}" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read().splitlines()))")"}
cwds = ${CWDS[@]+"$(IFS=$'\n'; printf '%s\n' "${CWDS[@]}" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read().splitlines()))")"}

result = [
    {"type": t, "command": c, "cwd": d}
    for t, c, d in zip(types, commands, cwds)
]
print(json.dumps(result, indent=2))
PYEOF

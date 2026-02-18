#!/usr/bin/env bash
set -euo pipefail

# detect-test-runner.sh — Auto-detect the test runner for a project.
#
# Usage: detect-test-runner.sh [repo-path]
# Output: the test command to run (stdout)
# Exit:   0 = found, 1 = not detected
#
# Detection order:
#   1. Python pytest  (pyproject.toml, pytest.ini, setup.cfg)
#   2. Node.js        (package.json scripts.test)
#   3. Rust           (Cargo.toml)
#   4. Make           (Makefile with test: target)
#   5. Go             (go.mod)
#   6. Fallback       (CLAUDE.md for common test commands)

REPO="${1:-.}"

# Verify directory exists, then resolve to absolute path.
if [[ ! -d "$REPO" ]]; then
  echo "Error: directory '$REPO' does not exist" >&2
  exit 1
fi
REPO="$(cd "$REPO" && pwd)"

# ---------- 1. Python pytest ----------
if [[ -f "$REPO/pyproject.toml" ]]; then
  if grep -q '^\[tool\.pytest' "$REPO/pyproject.toml" 2>/dev/null; then
    echo "pytest --tb=short -q"
    exit 0
  fi
fi

if [[ -f "$REPO/pytest.ini" ]]; then
  echo "pytest --tb=short -q"
  exit 0
fi

if [[ -f "$REPO/setup.cfg" ]]; then
  if grep -q '^\[tool:pytest\]' "$REPO/setup.cfg" 2>/dev/null; then
    echo "pytest --tb=short -q"
    exit 0
  fi
fi

# ---------- 2. Node.js ----------
if [[ -f "$REPO/package.json" ]]; then
  # Use python or node to parse JSON; fall back to grep.
  has_test=false
  if command -v python3 &>/dev/null; then
    has_test=$(PACKAGE_JSON="$REPO/package.json" python3 -c "
import json, sys, os
try:
    d = json.load(open(os.environ['PACKAGE_JSON']))
    print('true' if d.get('scripts',{}).get('test') else 'false')
except Exception:
    print('false')
")
  elif command -v node &>/dev/null; then
    has_test=$(PACKAGE_JSON="$REPO/package.json" node -e "
try {
  const p = require(process.env.PACKAGE_JSON);
  console.log(p.scripts && p.scripts.test ? 'true' : 'false');
} catch { console.log('false'); }
")
  else
    # Rough grep fallback — look for "test": inside "scripts" block.
    if grep -q '"test"' "$REPO/package.json" 2>/dev/null; then
      has_test=true
    fi
  fi

  if [[ "$has_test" == "true" ]]; then
    echo "npm test"
    exit 0
  fi
fi

# ---------- 3. Rust ----------
if [[ -f "$REPO/Cargo.toml" ]]; then
  echo "cargo test"
  exit 0
fi

# ---------- 4. Make ----------
if [[ -f "$REPO/Makefile" ]]; then
  if grep -qE '^test:' "$REPO/Makefile" 2>/dev/null; then
    echo "make test"
    exit 0
  fi
fi

# ---------- 5. Go ----------
if [[ -f "$REPO/go.mod" ]]; then
  echo "go test ./..."
  exit 0
fi

# ---------- 6. Fallback: CLAUDE.md ----------
# Extract the actual test command the user documented (preserving flags/args).
if [[ -f "$REPO/CLAUDE.md" ]]; then
  cmd=$(grep -oP '(?:pytest|npm test|cargo test|make test|go test|bun test)[^\n`]*' "$REPO/CLAUDE.md" | head -1)
  if [[ -n "$cmd" ]]; then
    echo "$cmd"
    exit 0
  fi
fi

# ---------- 7. Not detected ----------
echo "Error: could not detect test runner in '$REPO'" >&2
exit 1

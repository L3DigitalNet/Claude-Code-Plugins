#!/usr/bin/env bash
# run-tests.sh — language-aware test runner for autonomous-refactor Phase 1 and Phase 3.
# Consumed by commands/refactor.md to verify baseline and each worktree change.
# Accepts --worktree <path> to run tests inside a git worktree rather than cwd.
# Exit codes: 0=all pass, 1=test failure, 2=test runner not found.

set -euo pipefail

WORKTREE=""
TEST_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --worktree) WORKTREE="$2"; shift 2 ;;
    --test-file) TEST_FILE="$2"; shift 2 ;;
    --help|-h)
      echo "Usage: run-tests.sh [--worktree <path>] [--test-file <file>]"
      echo "  Detects language and runs the appropriate test suite."
      echo "  Exit 0: all pass. Exit 1: test failure. Exit 2: runner not found."
      exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

# Run from worktree root if specified; otherwise use cwd
RUN_DIR="${WORKTREE:-$(pwd)}"

if [[ ! -d "$RUN_DIR" ]]; then
  echo "ERROR: directory does not exist: $RUN_DIR" >&2
  exit 1
fi

# Determine language: TypeScript takes priority, then Python
LANGUAGE=""
if [[ -f "$RUN_DIR/package.json" ]]; then
  LANGUAGE="typescript"
elif [[ -f "$RUN_DIR/pyproject.toml" || -f "$RUN_DIR/pytest.ini" || -f "$RUN_DIR/setup.py" ]]; then
  LANGUAGE="python"
elif [[ -n "$TEST_FILE" ]]; then
  # Infer from test file extension
  case "$TEST_FILE" in
    *.ts|*.tsx) LANGUAGE="typescript" ;;
    *.py)       LANGUAGE="python" ;;
  esac
fi

if [[ -z "$LANGUAGE" ]]; then
  echo "ERROR: Cannot detect language. Provide a package.json or pyproject.toml." >&2
  echo "Install hint: Add a package.json (TypeScript) or pyproject.toml (Python) to your project root." >&2
  exit 2
fi

echo "Language detected: $LANGUAGE"
echo "Run directory: $RUN_DIR"

run_typescript_tests() {
  local dir="$1"
  local test_file="${TEST_FILE:-}"

  # Read test script from package.json
  TEST_SCRIPT=$(python3 -c "
import json, sys
try:
    pkg = json.load(open('$dir/package.json'))
    print(pkg.get('scripts', {}).get('test', ''))
except Exception:
    print('')
")

  # Build optional test-file args array to avoid word-splitting on empty string
  local extra_args=()
  [[ -n "$test_file" ]] && extra_args+=("$test_file")

  if [[ -n "$TEST_SCRIPT" && "$TEST_SCRIPT" != "null" && "$TEST_SCRIPT" != "" ]]; then
    echo "Running: npm test (from package.json scripts.test)"
    (cd "$dir" && npm test -- "${extra_args[@]}" 2>&1)
    return $?
  fi

  # Fallback order: vitest, then jest
  if (cd "$dir" && npx --yes vitest --version >/dev/null 2>&1); then
    echo "Running: npx vitest run"
    (cd "$dir" && npx vitest run "${extra_args[@]}" 2>&1)
    return $?
  fi

  if (cd "$dir" && npx --yes jest --version >/dev/null 2>&1); then
    echo "Running: npx jest"
    (cd "$dir" && npx jest --passWithNoTests "${extra_args[@]}" 2>&1)
    return $?
  fi

  echo "ERROR: No TypeScript test runner found (checked package.json scripts.test, vitest, jest)." >&2
  echo "Install hint: npm install --save-dev vitest   OR   npm install --save-dev jest @types/jest ts-jest" >&2
  exit 2
}

run_python_tests() {
  local dir="$1"
  local test_file="${TEST_FILE:-}"

  if ! command -v pytest >/dev/null 2>&1; then
    echo "ERROR: pytest not found in PATH." >&2
    echo "Install hint: pip install pytest   OR   uv add --dev pytest" >&2
    exit 2
  fi

  echo "Running: pytest"
  if [[ -n "$test_file" ]]; then
    (cd "$dir" && pytest "$test_file" -v 2>&1)
  else
    (cd "$dir" && pytest -v 2>&1)
  fi
}

case "$LANGUAGE" in
  typescript) run_typescript_tests "$RUN_DIR" ;;
  python)     run_python_tests "$RUN_DIR" ;;
esac

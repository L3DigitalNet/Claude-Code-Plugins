#!/usr/bin/env bash
# Smoke-tests run-assertions.sh with synthetic assertions.
# Run from repo root: bash plugins/plugin-review/scripts/test-run-assertions.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNNER="$SCRIPT_DIR/run-assertions.sh"
FIXTURE=$(mktemp)
trap 'rm -f "$FIXTURE"' EXIT

cat > "$FIXTURE" << 'EOF'
{
  "plugin": "test",
  "max_passes": 5,
  "current_pass": 1,
  "assertions": [
    {
      "id": "T-001",
      "finding_id": "test",
      "track": "A",
      "type": "grep_not_match",
      "description": "empty echo has no output",
      "command": "echo ''",
      "expected": "no_match",
      "status": null,
      "failure_output": null
    },
    {
      "id": "T-002",
      "finding_id": "test",
      "track": "A",
      "type": "grep_match",
      "description": "ls output is non-empty",
      "command": "ls /",
      "expected": "match",
      "status": null,
      "failure_output": null
    },
    {
      "id": "T-003",
      "finding_id": "test",
      "track": "C",
      "type": "file_exists",
      "description": "fixture file must exist",
      "path": "",
      "status": null,
      "failure_output": null
    },
    {
      "id": "T-004",
      "finding_id": "test",
      "track": "C",
      "type": "file_content",
      "description": "fixture contains plugin key",
      "path": "",
      "needle": "\"plugin\": \"test\"",
      "status": null,
      "failure_output": null
    },
    {
      "id": "T-005",
      "finding_id": "test",
      "track": "A",
      "type": "shell_exit_zero",
      "description": "true exits zero",
      "command": "true",
      "expected": "exit_zero",
      "status": null,
      "failure_output": null
    },
    {
      "id": "T-006",
      "finding_id": "test",
      "track": "A",
      "type": "typescript_compile",
      "description": "exit 0 simulates a passing tsc run",
      "command": "exit 0",
      "status": null,
      "failure_output": null
    }
  ],
  "confidence": { "passed": 0, "total": 0, "score": 0.0 }
}
EOF

# Patch path-dependent assertions to use the fixture path
python3 -c "
import json, sys
data = json.load(open('$FIXTURE'))
for a in data['assertions']:
    if a['type'] in ('file_exists', 'file_content'):
        a['path'] = '$FIXTURE'
with open('$FIXTURE', 'w') as f:
    json.dump(data, f, indent=2)
"

echo "Running run-assertions.sh..."
RUNNER_EXIT=0
ASSERTIONS_FILE="$FIXTURE" bash "$RUNNER" || RUNNER_EXIT=$?
if [ "$RUNNER_EXIT" -ne 0 ]; then
  echo "FAIL: run-assertions.sh exited with code $RUNNER_EXIT (expected 0)"
  exit 1
fi

echo ""
echo "Checking results..."
python3 -c "
import json, sys
data = json.load(open('$FIXTURE'))
errors = []
for a in data['assertions']:
    if a['status'] != 'pass':
        errors.append(f\"  {a['id']}: expected pass, got {a['status']} — {a.get('failure_output','')}\")
if errors:
    print('FAILURES:')
    print('\n'.join(errors))
    sys.exit(1)
if data['confidence']['score'] != 1.0:
    print(f\"Score wrong: {data['confidence']}\")
    sys.exit(1)
print(f\"All {len(data['assertions'])} assertions pass. Confidence: {int(data['confidence']['score']*100)}%\")
"

# --- Fail-case test: verify exit code 1 on failing assertions ---
FAIL_FIXTURE=$(mktemp)
trap 'rm -f "$FIXTURE" "$FAIL_FIXTURE"' EXIT

cat > "$FAIL_FIXTURE" << 'EOF'
{
  "plugin": "test",
  "max_passes": 5,
  "current_pass": 1,
  "assertions": [
    {
      "id": "F-001",
      "finding_id": "test",
      "track": "A",
      "type": "grep_match",
      "description": "grep for a string that does not exist",
      "command": "echo '' | grep 'DOES_NOT_EXIST_XYZ'",
      "expected": "match",
      "status": null,
      "failure_output": null
    },
    {
      "id": "F-002",
      "finding_id": "test",
      "track": "A",
      "type": "typescript_compile",
      "description": "exit 1 simulates a failing tsc run",
      "command": "exit 1",
      "status": null,
      "failure_output": null
    }
  ],
  "confidence": { "passed": 0, "total": 0, "score": 0.0 }
}
EOF

echo ""
echo "Running fail-case test (expect exit code 1)..."
FAIL_EXIT=0
ASSERTIONS_FILE="$FAIL_FIXTURE" bash "$RUNNER" || FAIL_EXIT=$?
if [ "$FAIL_EXIT" -ne 1 ]; then
  echo "FAIL: run-assertions.sh exited with code $FAIL_EXIT (expected 1 on failing assertions)"
  exit 1
fi
python3 -c "
import json, sys
data = json.load(open('$FAIL_FIXTURE'))
fails = [a for a in data['assertions'] if a['status'] == 'fail']
if len(fails) != 2:
    print(f'Expected 2 failures, got {len(fails)}: {[a[\"id\"] for a in fails]}')
    sys.exit(1)
if data['confidence']['score'] != 0.0:
    print(f'Expected score 0.0, got {data[\"confidence\"][\"score\"]}')
    sys.exit(1)
print(f'Fail-case OK: {len(fails)} failures, confidence 0%')
"

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
ASSERTIONS_FILE="$FIXTURE" bash "$RUNNER"

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

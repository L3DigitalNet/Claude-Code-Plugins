#!/usr/bin/env bash
# Runs all assertions in ASSERTIONS_FILE. Consumed by commands/review.md Phase 5.5.
# Writes pass/fail status and confidence back to the same file.
# Exit code: 0 = all pass, 1 = some fail, 2 = script/file error.
# Environment: ASSERTIONS_FILE — path override (default: .claude/state/review-assertions.json).

set -uo pipefail

ASSERTIONS_FILE="${ASSERTIONS_FILE:-.claude/state/review-assertions.json}"

if [ ! -f "$ASSERTIONS_FILE" ]; then
  echo "Error: assertions file not found: $ASSERTIONS_FILE" >&2
  exit 2
fi

python3 << PYEOF
import json, subprocess, os, sys

assertions_file = os.environ.get('ASSERTIONS_FILE', '.claude/state/review-assertions.json')

with open(assertions_file) as f:
    data = json.load(f)

passed = 0
failed = 0

for a in data['assertions']:
    a_type = a['type']
    a_id = a['id']

    try:
        if a_type == 'grep_not_match':
            r = subprocess.run(a['command'], shell=True, capture_output=True, text=True)
            if r.stdout.strip() == '':
                a['status'] = 'pass'; a['failure_output'] = None; passed += 1
            else:
                a['status'] = 'fail'; a['failure_output'] = r.stdout.strip()[:500]; failed += 1

        elif a_type == 'grep_match':
            r = subprocess.run(a['command'], shell=True, capture_output=True, text=True)
            if r.stdout.strip() != '':
                a['status'] = 'pass'; a['failure_output'] = None; passed += 1
            else:
                a['status'] = 'fail'; a['failure_output'] = 'No output — pattern not found'; failed += 1

        elif a_type == 'file_exists':
            path = a.get('path', '')
            if os.path.exists(path):
                a['status'] = 'pass'; a['failure_output'] = None; passed += 1
            else:
                a['status'] = 'fail'; a['failure_output'] = f'Not found: {path}'; failed += 1

        elif a_type == 'file_content':
            path = a.get('path', '')
            needle = a.get('needle', '')
            if not os.path.exists(path):
                a['status'] = 'fail'; a['failure_output'] = f'File not found: {path}'; failed += 1
            elif needle in open(path).read():
                a['status'] = 'pass'; a['failure_output'] = None; passed += 1
            else:
                a['status'] = 'fail'; a['failure_output'] = f'Needle not found: {needle!r}'; failed += 1

        elif a_type == 'typescript_compile':
            r = subprocess.run(a['command'], shell=True, capture_output=True, text=True)
            out = (r.stdout + r.stderr).strip()
            if r.returncode == 0 and out == '':
                a['status'] = 'pass'; a['failure_output'] = None; passed += 1
            else:
                a['status'] = 'fail'; a['failure_output'] = out[:500]; failed += 1

        elif a_type == 'shell_exit_zero':
            r = subprocess.run(a['command'], shell=True, capture_output=True, text=True)
            if r.returncode == 0:
                a['status'] = 'pass'; a['failure_output'] = None; passed += 1
            else:
                out = (r.stdout + r.stderr).strip()
                a['status'] = 'fail'; a['failure_output'] = out[:500]; failed += 1

        else:
            a['status'] = 'fail'; a['failure_output'] = f'Unknown type: {a_type}'; failed += 1

    except Exception as e:
        a['status'] = 'fail'; a['failure_output'] = f'Runner error: {e}'; failed += 1

    icon = '✅' if a['status'] == 'pass' else '❌'
    print(f"  {icon} {a_id}: {a_type} — {a['description'][:60]}")
    if a['status'] == 'fail':
        print(f"     Failure: {(a.get('failure_output') or '')[:80]}")

total = len(data['assertions'])
data['confidence']['passed'] = passed
data['confidence']['total'] = total
data['confidence']['score'] = round(passed / total, 4) if total > 0 else 0.0

pct = int(data['confidence']['score'] * 100)
print(f"\nConfidence: {pct}% ({passed}/{total} assertions passing)")

with open(assertions_file, 'w') as f:
    json.dump(data, f, indent=2)

sys.exit(0 if failed == 0 else 1)
PYEOF

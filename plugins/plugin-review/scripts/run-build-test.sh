#!/usr/bin/env bash
# Runs build and test commands discovered for a plugin directory.
# Called by commands/review.md Phase 4.5 [AUTONOMOUS MODE].
# Output: JSON to stdout — {"pass":bool,"results":[{"type":...,"command":...,"exit_code":...,"output":"..."}]}
# Human-readable summary written to stderr.
# Exit codes: 0 = all pass, 1 = some fail, 2 = script/discovery error.
# Arg: $1 = plugin directory path

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="${1:-}"

if [ -z "$PLUGIN_DIR" ]; then
  echo "Usage: run-build-test.sh <plugin-dir>" >&2
  exit 2
fi

if [ ! -d "$PLUGIN_DIR" ]; then
  echo "Error: directory not found: $PLUGIN_DIR" >&2
  exit 2
fi

# Discover commands — exit 2 if discovery script fails
COMMANDS_JSON=$("$SCRIPT_DIR/discover-test-commands.sh" "$PLUGIN_DIR") || {
  echo "Error: discover-test-commands.sh failed" >&2
  exit 2
}

# Validate JSON
echo "$COMMANDS_JSON" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null || {
  echo "Error: discover-test-commands.sh returned invalid JSON" >&2
  exit 2
}

command_count=$(echo "$COMMANDS_JSON" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))")

if [ "$command_count" = "0" ]; then
  echo '{"pass":true,"results":[],"note":"No build/test commands discovered"}'
  echo "Build/test: no commands discovered — skipping" >&2
  exit 0
fi

echo "Running $command_count command(s) for $PLUGIN_DIR..." >&2

# Run each command, capture results, build JSON output
python3 - "$PLUGIN_DIR" "$COMMANDS_JSON" << 'PYEOF'
import json, os, subprocess, sys, time

plugin_dir = sys.argv[1]
commands = json.loads(sys.argv[2])

OUTPUT_LIMIT = 2000
results = []
overall_pass = True

for entry in commands:
    cmd_type = entry['type']
    cmd = entry['command']
    cwd = entry['cwd']

    print(f"  [{cmd_type}] {cmd}", file=sys.stderr)

    start = time.time()
    try:
        r = subprocess.run(
            cmd, shell=True, capture_output=True, text=True,
            cwd=cwd, timeout=300
        )
        elapsed = time.time() - start
        combined = (r.stdout + r.stderr).strip()
        truncated = combined[:OUTPUT_LIMIT] + ('...(truncated)' if len(combined) > OUTPUT_LIMIT else '')

        passed = r.returncode == 0
        if not passed:
            overall_pass = False

        icon = '✅' if passed else '❌'
        print(f"  {icon} exit={r.returncode} ({elapsed:.1f}s)", file=sys.stderr)

        results.append({
            'type': cmd_type,
            'command': cmd,
            'cwd': cwd,
            'exit_code': r.returncode,
            'passed': passed,
            'output': truncated,
        })
    except subprocess.TimeoutExpired:
        overall_pass = False
        print(f"  ❌ timeout after 300s", file=sys.stderr)
        results.append({
            'type': cmd_type,
            'command': cmd,
            'cwd': cwd,
            'exit_code': -1,
            'passed': False,
            'output': 'Command timed out after 300s',
        })
    except Exception as e:
        overall_pass = False
        results.append({
            'type': cmd_type,
            'command': cmd,
            'cwd': cwd,
            'exit_code': -1,
            'passed': False,
            'output': f'Runner error: {e}',
        })

passed_count = sum(1 for r in results if r['passed'])
total = len(results)
status = 'all pass' if overall_pass else f'{total - passed_count}/{total} failed'
print(f"\nBuild/test: {status}", file=sys.stderr)

print(json.dumps({'pass': overall_pass, 'results': results}, indent=2))
sys.exit(0 if overall_pass else 1)
PYEOF

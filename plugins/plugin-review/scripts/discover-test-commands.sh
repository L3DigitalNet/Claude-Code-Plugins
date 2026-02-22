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

PLUGIN_DIR_ABS="$(cd "$PLUGIN_DIR" && pwd)"

# Delegate all discovery to Python — avoids JSON quoting issues with bash arrays.
# Each discovery block appends to the 'commands' list in Python.
python3 - "$PLUGIN_DIR_ABS" << 'PYEOF'
import json, os, sys

plugin_dir = sys.argv[1]
commands = []

# --- package.json (npm/node plugins) ---
pkg = os.path.join(plugin_dir, 'package.json')
if os.path.exists(pkg):
    try:
        scripts = json.load(open(pkg)).get('scripts', {})
        if 'build' in scripts:
            commands.append({'type': 'build', 'command': 'npm run build', 'cwd': plugin_dir})
        if 'test' in scripts:
            commands.append({'type': 'test', 'command': 'npm test', 'cwd': plugin_dir})
    except (json.JSONDecodeError, OSError):
        pass

# --- Makefile ---
makefile = os.path.join(plugin_dir, 'Makefile')
if os.path.exists(makefile):
    try:
        content = open(makefile).read()
        if '\nbuild:' in content or content.startswith('build:'):
            commands.append({'type': 'build', 'command': 'make build', 'cwd': plugin_dir})
        if '\ntest:' in content or content.startswith('test:'):
            commands.append({'type': 'test', 'command': 'make test', 'cwd': plugin_dir})
    except OSError:
        pass

# --- pytest (pytest.ini / pyproject.toml / setup.cfg) ---
has_pytest = (
    os.path.exists(os.path.join(plugin_dir, 'pytest.ini'))
    or (
        os.path.exists(os.path.join(plugin_dir, 'pyproject.toml'))
        and '[tool.pytest' in open(os.path.join(plugin_dir, 'pyproject.toml')).read()
    )
    or (
        os.path.exists(os.path.join(plugin_dir, 'setup.cfg'))
        and '[tool:pytest]' in open(os.path.join(plugin_dir, 'setup.cfg')).read()
    )
)
if has_pytest:
    commands.append({'type': 'test', 'command': 'pytest', 'cwd': plugin_dir})

# --- shell test scripts in scripts/ ---
scripts_dir = os.path.join(plugin_dir, 'scripts')
if os.path.isdir(scripts_dir):
    for fname in sorted(os.listdir(scripts_dir)):
        if fname.startswith('test') and fname.endswith('.sh'):
            fpath = os.path.join(scripts_dir, fname)
            commands.append({'type': 'test', 'command': f'bash {fpath}', 'cwd': plugin_dir})

print(json.dumps(commands, indent=2))
PYEOF

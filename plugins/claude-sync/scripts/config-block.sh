#!/usr/bin/env bash
# config-block.sh — Read, write, and update the claude-sync config block in ~/.claude/CLAUDE.md.
#
# Subcommands:
#   read                     Extract config block as JSON
#   write                    Read JSON from stdin, replace config block
#   update <key> <value>     Update a single key
#   add-exclude <pattern>    Append to exclude list
#   remove-exclude <pattern> Remove from exclude list
#   validate                 Check config block syntax and paths
#
# Output: JSON to stdout.
# Exit:   0 on success, 1 on failure.

set -euo pipefail
PYTHON=$(command -v python3 2>/dev/null || command -v python 2>/dev/null) \
  || { echo '{"error":"python3 not found"}' >&2; exit 1; }

CLAUDE_MD="$HOME/.claude/CLAUDE.md"
LOCK_FILE="$HOME/.claude/sync.lock"

read_config() {
  $PYTHON -c "
import json, os, re, sys

path = os.path.expanduser('$CLAUDE_MD')

if not os.path.exists(path):
    print(json.dumps({'block_found': False, 'source_file': '~/.claude/CLAUDE.md'}))
    sys.exit(0)

with open(path, encoding='utf-8') as f:
    content = f.read()

# Extract config block
m = re.search(r'<!--\s*claude-sync-config\s*\n(.*?)-->', content, re.DOTALL)
if not m:
    print(json.dumps({'block_found': False, 'source_file': '~/.claude/CLAUDE.md'}))
    sys.exit(0)

block = m.group(1)
config = {}
current_list_key = None

for line in block.splitlines():
    line = line.rstrip()
    if not line or line.startswith('#'):
        continue
    if line.startswith('  - '):
        if current_list_key:
            config.setdefault(current_list_key, []).append(line[4:].strip())
        continue
    if ': ' in line:
        key, val = line.split(': ', 1)
        key = key.strip()
        val = val.strip()
        if not val:
            current_list_key = key
            config[key] = []
        else:
            config[key] = val
            current_list_key = None
    elif line.endswith(':'):
        current_list_key = line[:-1].strip()
        config[current_list_key] = []

config['source_file'] = '~/.claude/CLAUDE.md'
config['block_found'] = True
print(json.dumps(config, indent=2))
"
}

write_config() {
  local json_input
  json_input=$(cat)

  (
    flock -w 5 200 || { echo '{"error":"could not acquire lock"}' >&2; exit 1; }

    $PYTHON -c "
import json, os, re, sys

path = os.path.expanduser('$CLAUDE_MD')
config = json.loads(sys.argv[1])

# Remove metadata keys
config.pop('source_file', None)
config.pop('block_found', None)

# Build config block text
lines = ['<!-- claude-sync-config']
for key, val in config.items():
    if isinstance(val, list):
        lines.append(f'{key}:')
        for item in val:
            lines.append(f'  - {item}')
    else:
        lines.append(f'{key}: {val}')
lines.append('-->')
block_text = '\n'.join(lines)

if os.path.exists(path):
    with open(path, encoding='utf-8') as f:
        content = f.read()
    # Replace existing block or append
    new_content, count = re.subn(
        r'<!--\s*claude-sync-config\s*\n.*?-->',
        block_text,
        content,
        count=1,
        flags=re.DOTALL
    )
    if count == 0:
        new_content = content.rstrip() + '\n\n' + block_text + '\n'
else:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    new_content = block_text + '\n'

tmp = path + '.tmp'
with open(tmp, 'w', encoding='utf-8') as f:
    f.write(new_content)
os.rename(tmp, path)

config['source_file'] = '~/.claude/CLAUDE.md'
config['block_found'] = True
print(json.dumps(config, indent=2))
" "$json_input"

  ) 200>"$LOCK_FILE"
}

cmd_read() { read_config; }

cmd_write() { write_config; }

cmd_update() {
  local key="${1:?Usage: update <key> <value>}" value="${2:?}"
  local current
  current=$(read_config)
  echo "$current" | $PYTHON -c "
import json, sys
config = json.load(sys.stdin)
key, val = sys.argv[1], sys.argv[2]
try:
    config[key] = json.loads(val)
except (json.JSONDecodeError, ValueError):
    config[key] = val
print(json.dumps(config))
" "$key" "$value" | write_config
}

cmd_add_exclude() {
  local pattern="${1:?Usage: add-exclude <pattern>}"
  local current
  current=$(read_config)
  echo "$current" | $PYTHON -c "
import json, sys
config = json.load(sys.stdin)
exclude = config.get('exclude', [])
if sys.argv[1] not in exclude:
    exclude.append(sys.argv[1])
config['exclude'] = exclude
print(json.dumps(config))
" "$pattern" | write_config
}

cmd_remove_exclude() {
  local pattern="${1:?Usage: remove-exclude <pattern>}"
  local current
  current=$(read_config)
  echo "$current" | $PYTHON -c "
import json, sys
config = json.load(sys.stdin)
exclude = config.get('exclude', [])
exclude = [e for e in exclude if e != sys.argv[1]]
config['exclude'] = exclude
print(json.dumps(config))
" "$pattern" | write_config
}

cmd_validate() {
  local config
  config=$(read_config)
  echo "$config" | $PYTHON -c "
import json, os, sys

config = json.load(sys.stdin)
issues = []

if not config.get('block_found'):
    issues.append('No claude-sync-config block found in ~/.claude/CLAUDE.md')
    print(json.dumps({'valid': False, 'issues': issues}))
    sys.exit(0)

for field in ('sync_path', 'repos_root', 'machine_id'):
    if not config.get(field):
        issues.append(f'Missing required field: {field}')

sp = config.get('sync_path', '')
if sp and not os.path.isdir(os.path.expanduser(sp)):
    issues.append(f'sync_path is not an accessible directory: {sp}')

rr = config.get('repos_root', '')
if rr and not os.path.isdir(os.path.expanduser(rr)):
    issues.append(f'repos_root does not exist: {rr}')

print(json.dumps({'valid': len(issues) == 0, 'issues': issues}, indent=2))
"
}

# --- Dispatch ---
subcmd="${1:-}"
shift || true

case "$subcmd" in
  read)           cmd_read ;;
  write)          cmd_write ;;
  update)         cmd_update "$@" ;;
  add-exclude)    cmd_add_exclude "$@" ;;
  remove-exclude) cmd_remove_exclude "$@" ;;
  validate)       cmd_validate ;;
  *)
    echo '{"error":"Usage: config-block.sh {read|write|update|add-exclude|remove-exclude|validate}"}' >&2
    exit 1
    ;;
esac

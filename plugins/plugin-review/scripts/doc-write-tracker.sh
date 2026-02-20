#!/bin/bash
# PostToolUse hook: tracks impl-vs-doc file writes during plugin review sessions.
# Provides mechanical enforcement for [P6] Documentation Co-mutation.
#
# Only active when PLUGIN_REVIEW_ACTIVE=1 (set by the review command).
# Categorizes each written file as "implementation" or "documentation" and
# warns when impl files are modified without any doc files in the session.
#
# State is tracked in .claude/state/plugin-review-writes.json

# Skip enforcement outside review sessions
if [ "$PLUGIN_REVIEW_ACTIVE" != "1" ]; then
  exit 0
fi

# Extract file path from hook input (JSON on stdin)
# Different tools use different field names: file_path, path, notebook_path
FILE_PATH=$(cat | python3 -c "
import sys, json
d = json.load(sys.stdin)
tool_input = d.get('tool_input', {})
path = tool_input.get('file_path') or tool_input.get('path') or tool_input.get('notebook_path') or ''
print(path)
" 2>/dev/null)

# Fail open if we can't determine the path
if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Ensure state directory exists
STATE_DIR=".claude/state"
STATE_FILE="$STATE_DIR/plugin-review-writes.json"
mkdir -p "$STATE_DIR"

# Initialize state file if missing
if [ ! -f "$STATE_FILE" ]; then
  echo '{"impl_files":[],"doc_files":[]}' > "$STATE_FILE"
fi

# Categorize the file and update state
FILE_PATH="$FILE_PATH" STATE_FILE="$STATE_FILE" python3 -c "
import json, os

file_path = os.environ['FILE_PATH']
state_file = os.environ['STATE_FILE']

# Load current state
try:
    with open(state_file, 'r') as f:
        state = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    state = {'impl_files': [], 'doc_files': []}

# Categorize file
basename = os.path.basename(file_path)
doc_patterns = ('README.md', 'DESIGN.md', 'CHANGELOG.md')
impl_dirs = ('commands/', 'agents/', 'skills/', 'scripts/', 'hooks/scripts/', 'src/', 'templates/')

is_doc = basename in doc_patterns
is_impl = any(d in file_path for d in impl_dirs)

# Update state (deduplicate)
if is_doc and file_path not in state['doc_files']:
    state['doc_files'].append(file_path)
elif is_impl and file_path not in state['impl_files']:
    state['impl_files'].append(file_path)

# Save state
with open(state_file, 'w') as f:
    json.dump(state, f)

# Warn if impl files exist but no doc files yet
if state['impl_files'] and not state['doc_files']:
    count = len(state['impl_files'])
    recent = ', '.join(state['impl_files'][-3:])
    print(f'\u26a0\ufe0f [P6] Doc co-mutation: {count} implementation file(s) modified with no documentation updates yet.')
    print(f'  Modified: {recent}')
    print(f'  Remember to update README.md, DESIGN.md, or CHANGELOG.md before completing this pass.')
" 2>/dev/null

exit 0

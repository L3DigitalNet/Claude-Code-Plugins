#!/bin/bash
# PostToolUse hook: validates analyst agent YAML frontmatter tool lists after writes.
# Provides secondary enforcement for [P9] Subagents Analyze, Orchestrator Acts.
#
# Primary enforcement is the agent tool restriction in frontmatter — Claude Code's platform
# enforces it. This hook is a secondary warning layer that fires when an agent file is
# modified, alerting the orchestrator if disallowed tools (Write, Edit, MultiEdit, Bash,
# Task, etc.) were added to the tools: line.
#
# Active at all times (not gated by PLUGIN_REVIEW_ACTIVE) because agent frontmatter
# correctness is a permanent invariant, not session-scoped.
#
# Cross-file dependency: hooks/hooks.json registers this hook on Write|Edit|MultiEdit.
# Allowed tool list below must stay in sync with the design intent in docs/DESIGN.md's
# "Subagents don't implement" row of the Enforcement Layer Mapping table.

# Extract file path from hook input (JSON on stdin)
FILE_PATH=$(cat | python3 -c "
import sys, json
d = json.load(sys.stdin)
tool_input = d.get('tool_input', {})
path = tool_input.get('file_path') or tool_input.get('path') or tool_input.get('notebook_path') or ''
print(path)
" 2>/dev/null)

# Only check files in the agents/ directory
if [[ ! "$FILE_PATH" =~ /agents/[^/]+\.md$ ]]; then
  exit 0
fi

# Ensure the file exists (it should, since this is PostToolUse)
if [ ! -f "$FILE_PATH" ]; then
  exit 0
fi

# Extract the tools: line from YAML frontmatter (between --- delimiters)
# Use env var to pass FILE_PATH — avoids single-quote injection in Python string literals
TOOLS_LINE=$(FILE_PATH="$FILE_PATH" python3 -c "
import sys, re, os
try:
    with open(os.environ['FILE_PATH'], 'r') as f:
        content = f.read()
    # Match YAML frontmatter between --- delimiters
    match = re.search(r'^---\s*\n(.*?)\n---', content, re.DOTALL)
    if match:
        frontmatter = match.group(1)
        for line in frontmatter.split('\n'):
            if line.strip().startswith('tools:'):
                print(line.strip())
                break
except Exception:
    pass
" 2>/dev/null)

if [ -z "$TOOLS_LINE" ]; then
  exit 0
fi

# Check for disallowed tools in the tools: line
# Analyst agents are permitted: Read, Grep, Glob, NotebookRead, WebFetch, TodoWrite, WebSearch
# Use env var to pass TOOLS_LINE — avoids single-quote injection in Python string literals
DISALLOWED=$(TOOLS_LINE="$TOOLS_LINE" python3 -c "
import re, sys, os

tools_line = os.environ['TOOLS_LINE']
# Extract tool names from 'tools: Read, Grep, Glob' or 'tools: [Read, Grep]'
tools_str = re.sub(r'^tools:\s*', '', tools_line)
tools_str = tools_str.strip('[]')
tools = [t.strip() for t in tools_str.split(',')]

# Tools that should never appear in analyst agent frontmatter
disallowed = {'Write', 'Edit', 'MultiEdit', 'Bash', 'Task', 'NotebookEdit', 'EnterPlanMode', 'ExitPlanMode'}

found_disallowed = [t for t in tools if t in disallowed]
if found_disallowed:
    print(', '.join(found_disallowed))
" 2>/dev/null)

if [ -n "$DISALLOWED" ]; then
  echo ""
  echo "🚫 [P9] Blocked: disallowed tool(s) in analyst agent frontmatter: $FILE_PATH"
  echo "  Disallowed: $DISALLOWED"
  echo "  Analyst agents must only have read-only tools: Read, Grep, Glob"
  echo "  (optionally: WebFetch, WebSearch, TodoWrite, NotebookRead)."
  echo "  Remove disallowed tools from the 'tools:' line before proceeding."
  echo ""
  exit 2
fi

exit 0

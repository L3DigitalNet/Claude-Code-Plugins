---
title: Hooks Reference
category: automation
target_platform: linux
audience: ai_agent
keywords: [hooks, lifecycle, events, automation, triggers]
---

# Hooks Reference

## Overview

**Purpose:** Run shell commands at lifecycle events — before or after tool calls, at session start, or before context compaction. **Location:** `hooks/hooks.json` at plugin root **Format:** JSON record keyed by event name

Hooks provide _mechanical_ enforcement — they run regardless of AI behavior and cannot be bypassed by prompts. This makes them stronger than behavioral instructions.

## hooks.json Format

```json
{
	"hooks": {
		"EventName": [
			{
				"matcher": "ToolName|OtherTool",
				"hooks": [
					{
						"type": "command",
						"command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/my-hook.sh",
						"timeout": 30
					}
				]
			}
		]
	}
}
```

**Structure:**

- `hooks`: Record (object) keyed by event name — **not** an array
- Each event value: array of hook groups, each with a `matcher` and a `hooks` array
- `type`: always `"command"` — runs an external shell process
- `command`: shell command string; only `${CLAUDE_PLUGIN_ROOT}` is available as a variable
- `timeout`: optional — max execution time in seconds

## Event Types

| Event          | Timing                    | Stdin                                 |
| -------------- | ------------------------- | ------------------------------------- |
| `SessionStart` | Session begins            | None                                  |
| `SessionEnd`   | Session ends              | None                                  |
| `PreToolUse`   | Before tool call          | Tool name + arguments (JSON)          |
| `PostToolUse`  | After tool call           | Tool name + arguments + result (JSON) |
| `PreCompact`   | Before context compaction | None                                  |

## Matcher Pattern

The `matcher` field is a regex matched against the tool name for `PreToolUse` and `PostToolUse`. For `SessionStart`, `SessionEnd`, and `PreCompact`, use `"*"` or `"auto"`.

```json
"matcher": "Write|Edit|MultiEdit|NotebookEdit"     // exact tool names, pipe-separated
"matcher": "Bash"                                   // single tool
"matcher": "Read|View"                              // any of these tools
"matcher": "mcp__.*__(write|edit|create|update).*"  // regex for MCP write tools
"matcher": "*"                                      // all (for SessionStart/SessionEnd)
"matcher": "auto"                                   // system-managed (for PreCompact)
```

Multiple hook groups for the same event run in the order listed.

## Hook Input (stdin)

For `PreToolUse` and `PostToolUse`, the hook script receives a JSON object on stdin:

```json
{
	"tool_name": "Write",
	"tool_input": { "file_path": "/path/to/file.py", "content": "..." }
}
```

`tool_response` is additionally available in `PostToolUse`. `SessionStart` and `PreCompact` hooks receive no stdin data.

Extract fields in bash:

```bash
FILE_PATH=$(cat | python3 -c "
import sys, json
d = json.load(sys.stdin)
tool_input = d.get('tool_input', {})
# Try multiple field names — different tools use different keys
path = tool_input.get('file_path') or tool_input.get('path') or tool_input.get('notebook_path') or ''
print(path)
" 2>/dev/null)
```

## Hook Output

### PostToolUse — inject a warning into agent context

Write plain text to stdout — it is injected as a system message the agent will see on its next turn:

```bash
echo "WARNING: This file is in the protected zone. Review carefully before proceeding."
```

### PreToolUse — block the tool call

Exit with code `2` and write the block decision JSON to stdout:

```bash
echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","decision":"block","reason":"Writes to this path are not permitted."}}'
exit 2
```

Exit code `0` (or any code other than `2`) allows the tool call to proceed normally.

### SessionStart — write to terminal

Stdout from `SessionStart` hooks is displayed in the terminal when the session begins. Useful for status messages, sync confirmations, or warnings.

## Variable Reference

Only one variable substitution is available in hook `command` strings:

| Variable                | Value                                           |
| ----------------------- | ----------------------------------------------- |
| `${CLAUDE_PLUGIN_ROOT}` | Absolute path to the installed plugin directory |

There is no `${file}` or other automatic variable substitution. Pass data to scripts via stdin JSON (for PreToolUse/PostToolUse) or by using `${CLAUDE_PLUGIN_ROOT}` to reference scripts and state bundled with the plugin.

## Multiple Hooks per Event

One event can have multiple hook groups, and each group can have multiple hooks. Groups run in order; within a group, hooks run sequentially.

```json
{
	"hooks": {
		"PreToolUse": [
			{
				"matcher": "Bash",
				"hooks": [
					{
						"type": "command",
						"command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/force-push-guard.sh"
					},
					{
						"type": "command",
						"command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/auto-build.sh"
					}
				]
			}
		]
	}
}
```

## Dispatcher Pattern (Recommended)

When multiple files or patterns need different handling, use a single hook that routes internally — one hook registration per event type. This keeps `hooks.json` simple and puts routing logic in a shell script where it can be tested independently.

**hooks.json:**

```json
{
	"hooks": {
		"PostToolUse": [
			{
				"matcher": "Write|Edit|MultiEdit",
				"hooks": [
					{
						"type": "command",
						"command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/post-write-hook.sh"
					}
				]
			}
		]
	}
}
```

**scripts/post-write-hook.sh:**

```bash
#!/bin/bash
# Dispatcher: routes by file path to the appropriate validator
FILE_PATH=$(cat | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('tool_input', {}).get('file_path', ''))
")

case "$FILE_PATH" in
  */.claude-plugin/plugin.json) bash "${CLAUDE_PLUGIN_ROOT}/scripts/validate-manifest.sh" "$FILE_PATH" ;;
  */agents/*.md)                bash "${CLAUDE_PLUGIN_ROOT}/scripts/validate-agent-frontmatter.sh" "$FILE_PATH" ;;
esac
```

## Examples

### SessionStart: sync plugins on session open

```json
{
	"hooks": {
		"SessionStart": [
			{
				"matcher": "*",
				"hooks": [
					{
						"type": "command",
						"command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/sync-local-plugins.sh",
						"timeout": 30
					}
				]
			}
		]
	}
}
```

### PreToolUse: block force-push

```bash
#!/bin/bash
# force-push-guard.sh
ARGS=$(cat | python3 -c "import sys, json; d=json.load(sys.stdin); print(d.get('tool_input', {}).get('command', ''))")

if echo "$ARGS" | grep -qE -- '--force|-f '; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","decision":"block","reason":"Force push is prohibited. Use a non-destructive push strategy."}}'
  exit 2
fi
```

### PostToolUse: read-count warning

```bash
#!/bin/bash
# read-counter.sh — warns when session is consuming excessive context via file reads
COUNTER_FILE=".claude/state/.read-count-$PPID"
mkdir -p "$(dirname "$COUNTER_FILE")"
COUNT=$(cat "$COUNTER_FILE" 2>/dev/null || echo 0)
COUNT=$((COUNT + 1))
echo "$COUNT" > "$COUNTER_FILE"

if [ "$COUNT" -eq 10 ]; then
  echo "WARNING: 10 file reads in this session. Consider compacting context."
elif [ "$COUNT" -eq 15 ]; then
  echo "CRITICAL: 15 reads. Compact immediately to preserve working context."
fi
```

### PreCompact: save state before compaction

```json
{
	"hooks": {
		"PreCompact": [
			{
				"matcher": "auto",
				"hooks": [
					{
						"type": "command",
						"command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/on-pre-compact.sh"
					}
				]
			}
		]
	}
}
```

## Debugging Hooks

Hooks are silent on success. To debug:

**1. Run the script manually** with a sample payload:

```bash
echo '{"tool_name":"Write","tool_input":{"file_path":"test.py","content":""}}' \
  | bash ./scripts/my-hook.sh
echo "Exit code: $?"
```

**2. Validate hooks.json syntax:**

```bash
python3 -m json.tool hooks/hooks.json
```

**3. Add stderr logging temporarily** (stderr is discarded in production but visible when run directly):

```bash
echo "[DEBUG] FILE_PATH=$FILE_PATH" >&2
```

## Common Mistakes

| Mistake | Effect | Fix |
| --- | --- | --- |
| `"hooks"` field is an array, not a record | Schema error on load | Use `{"hooks": {"EventName": [...]}}`, not `{"hooks": [...]}` |
| Using `${file}` in command string | Literal string — no substitution happens | Read file path from stdin JSON in the script |
| Exit 1 in PreToolUse | Tool proceeds (exit 1 is not a block) | Only exit code `2` blocks tool execution |
| Script path without `${CLAUDE_PLUGIN_ROOT}` | Wrong path at install time | Always prefix: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/...` |
| Forgetting `cat \|` before python3 | stdin is not consumed; JSON parse fails | Always pipe stdin: `FILE_PATH=$(cat \| python3 -c "...")` |

## Next Steps

- [Plugins development guide](./plugins.md) — plugin structure and workflow
- [Sub-agents](./sub-agents.md) — isolated agent execution
- [Skills](./skills.md) — context-triggered knowledge injection
- [Plugins reference](./plugins-reference.md) — full manifest schema

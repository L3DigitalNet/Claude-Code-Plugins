---
schema_version: '1.0'
id: '2026-05-08-up-docs-plugin-security-eval-infrastructure'
title: 'Plugin-Shipped Security/Eval Infrastructure for Claude Code Plugins'
description: 'Research backing the up-docs hardening plan v2: plugin-shipped security and eval infrastructure primitives.'
doc_type: 'research'
status: 'active'
created: '2026-05-08'
updated: '2026-06-03'
reviewed: null
owner: ''
tags:
  - claude-code
  - plugins
  - security
  - eval
aliases:
  - up-docs-security-eval
related: []
source: []
confidence: 'high'
visibility: 'internal'
license: null
---

# Plugin-Shipped Security/Eval Infrastructure for Claude Code Plugins

**Topic:** Plugin-shipped security/eval infrastructure for Claude Code plugins — concrete patterns for up-docs v2 plan. **Date:** 2026-05-08 **Queries:** 14 · Results parsed: 80+ · Deep reads: 7 (official docs) · Follow-up pass: no

---

## Summary

| Angle | Sources | Strongest finding |
| --- | --- | --- |
| Plugin Hook Packaging | 5 (official + local) | `hooks/hooks.json` supports all 29 events; `${CLAUDE_PLUGIN_ROOT}` works; PreToolUse/PostToolUse command hooks confirmed working |
| Plugin Security Mechanisms | 4 (official + community) | `plugins/<name>/settings.json` supports ONLY `agent` + `subagentStatusLine`; deny rules live in consuming project's `.claude/settings.json` |
| Headless Mode / CLI Contract | 3 (official) | `--plugin-dir <path> -p --agent <name>` loads plugin from local FS; tool results NOT in stream-json; PostToolUse hook is the only result capture path |
| MCP Stub Wiring | 3 (official + community) | FastMCP `Client(server)` in-memory transport only works within Python process; external `claude -p` subprocess requires stdio wrapper + `--mcp-config` |
| PostToolUse Safety Patterns | 3 (official + community) | `tool_response` IS available in PostToolUse; opt-in via env var + `umask 077` + regex redaction are the canonical pattern |
| Pydantic v2 Discriminated Unions | 3 (official) | `Field(discriminator="layer")` with `Literal["repo"]` field on each model; validation error names the bad tag explicitly |
| DeepEval Current API | 4 (official) | `LLMTestCaseParams` renamed to `SingleTurnParams` in 2025 — audit CR-012 is confirmed correct; `AnthropicModel` works without OpenAI key |

**Queries:** 14 · **Results parsed:** 80+ · **Deep reads:** 7 · **Follow-up pass:** no

---

## Angle 1: Plugin Hook Packaging — Authoritative `hooks/hooks.json` Schema

### Event Names (complete list as of May 2026)

From `code.claude.com/docs/en/hooks` [official]:

```text
SessionStart, Setup, UserPromptSubmit, UserPromptExpansion,
PreToolUse, PermissionRequest, PermissionDenied,
PostToolUse, PostToolUseFailure, PostToolBatch,
Notification, SubagentStart, SubagentStop,
TaskCreated, TaskCompleted, Stop, StopFailure, TeammateIdle,
InstructionsLoaded, ConfigChange, CwdChanged, FileChanged,
WorktreeCreate, WorktreeRemove, PreCompact, PostCompact,
Elicitation, ElicitationResult, SessionEnd
```

29 total events. Plugins support the same full set as user hooks (confirmed in `code.claude.com/docs/en/plugins-reference` table).

### Matcher Field Exact Syntax

Three modes, determined by characters in the string [official]:

| Pattern type    | Characters             | Behavior                      |
| --------------- | ---------------------- | ----------------------------- | --------------------- | ------------------- |
| Match all       | `"*"`, `""`, or absent | Fires on every occurrence     |
| Exact/pipe-list | Only `[A-Za-z0-9\_     | ]`                            | Exact tool name, or ` | `-separated OR list |
| Regex           | Any other character    | Evaluated as JavaScript regex |

Matcher targets for PreToolUse/PostToolUse: **the tool name** (`Bash`, `Edit`, `Write`, `Read`, `mcp__server__tool`, etc.). MCP tools match as regular tool names.

The `if` field on individual hook handlers uses permission-rule syntax: `"Bash(git *)"`, `"Edit(*.ts)"`. It runs if ANY subcommand matches and fires even for complex pipelines. Available only on tool events. The `matcher` and `if` fields are independent filters — both must match for the hook to fire.

### Sub-agent Tool Call Firing

Yes: hooks fire for sub-agent tool calls. The stdin JSON includes `agent_id` and `agent_type` fields when the hook fires inside a sub-agent context. A plugin-scoped agent dispatched via the `Agent` tool fires the parent session's hooks (not a separate hook context). [official] (<https://code.claude.com/docs/en/hooks>)

### `${CLAUDE_PLUGIN_ROOT}` in Command Field

Confirmed working. `${CLAUDE_PLUGIN_ROOT}` is substituted in hook command strings and exported as an environment variable to hook subprocesses. Same for `${CLAUDE_PLUGIN_DATA}`. [official] (<https://code.claude.com/docs/en/plugins-reference>)

Evidence from five sibling plugins in this repo: all use `bash ${CLAUDE_PLUGIN_ROOT}/scripts/...` pattern successfully.

### Hook Script stdin/stdout JSON Contract

**PreToolUse stdin:**

```json
{
	"session_id": "...",
	"transcript_path": "/path/to/transcript.jsonl",
	"cwd": "/current/dir",
	"permission_mode": "default|plan|acceptEdits|auto|dontAsk|bypassPermissions",
	"hook_event_name": "PreToolUse",
	"effort": { "level": "low|medium|high|xhigh|max" },
	"tool_name": "Bash",
	"tool_input": { "command": "npm test" },
	"tool_use_id": "toolu_01abc...",
	"agent_id": "optional-subagent-id",
	"agent_type": "optional-agent-name"
}
```

**PostToolUse stdin:** Same plus `tool_response: { output: "...", isError: false }`. The `output` field contains full tool stdout/stderr. `tool_response` is the only way to capture Bash output from a plugin hook.

**Exit code contract:**

- `exit 0` — allow; parse stdout for JSON output
- `exit 2` — **block** tool call; stderr passed to Claude as context
- `exit 1` or other — non-blocking error (counterintuitive: NOT a block)

**Block payload (PreToolUse):**

```json
{
	"hookSpecificOutput": {
		"hookEventName": "PreToolUse",
		"permissionDecision": "deny",
		"permissionDecisionReason": "reason shown to Claude"
	}
}
```

Alternatively, exit 2 alone blocks without JSON output.

**Context injection (any event):** stdout text is injected into Claude's context window (for PreToolUse/PostToolUse).

Working example from this repo (`force-push-guard.sh`):

```bash
COMMAND=$(cat | python3 -c "import sys, json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))")
if echo "$COMMAND" | grep -q 'git push' && echo "$COMMAND" | grep -qE '(--force|\s-f(\s|$))'; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","reason":"Force-push not allowed"}}'
  exit 2
fi
exit 0
```

### Footgun: GH Issue 34573 — Plugin PreToolUse/PostToolUse Command Hooks Silently Dropped

**This is a confirmed, closed-as-not-planned bug.** Prompt hooks fire; command hooks are silently dropped for PreToolUse/PostToolUse in plugins. However: the five sibling plugins in this repo (`release-pipeline`, `github-repo-manager`, `home-assistant-dev`, `plugin-test-harness`, `opus-context`) all use command hooks for PreToolUse/PostToolUse and appear to work based on their production use. The issue may be version-specific or partially resolved. **Verify with `/hooks` menu before relying on plugin PreToolUse/PostToolUse command hooks.** [community] (<https://github.com/anthropics/claude-code/issues/34573>)

**Recommended for up-docs v2 plan:** Ship `hooks/hooks.json` with `PreToolUse` and `PostToolUse` command hooks using `bash ${CLAUDE_PLUGIN_ROOT}/scripts/capture-transcript.sh`; verify the hooks appear in `/hooks` menu after `claude plugin install --scope local` before trusting the security gate.

---

## Angle 2: Plugin-Level Permission/Security Mechanisms

### What `plugins/<name>/settings.json` Actually Supports

The official plugins-reference (File Locations Reference table, line 707) states:

> **Settings** `settings.json` — Default configuration applied when the plugin is enabled. **Only the `agent` and `subagentStatusLine` keys are currently supported.**

This definitively invalidates the v1 plan's `plugins/up-docs/.claude/settings.json` approach. Two distinct problems:

1. `.claude/settings.json` (subdirectory) is not a supported plugin component location at all.
2. Even `settings.json` (at plugin root) only supports `agent` and `subagentStatusLine`, not `permissions.deny`.

### Option (a): PreToolUse Validator Hook (confirmed working)

Exit-code-2 blocking works from plugin hooks. The `permissionDecision: "deny"` JSON output is the preferred form (gives Claude a reason). The `if` field narrows further:

```json
{
	"hooks": {
		"PreToolUse": [
			{
				"matcher": "Bash",
				"hooks": [
					{
						"type": "command",
						"command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/deny-guard.sh"
					}
				]
			}
		]
	}
}
```

```bash
#!/usr/bin/env bash
# deny-guard.sh — PreToolUse hook, fails open on parse error
set -uo pipefail
INPUT=$(cat)
COMMAND=$(printf '%s' "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('command', ''))
except Exception:
    print('')
" 2>/dev/null)
[ -z "$COMMAND" ] && exit 0  # fail open

# Deny-list patterns (handles pipes, semicolons, subshell substitution)
# Note: this catches the pattern anywhere in the command string
if echo "$COMMAND" | grep -qE '(curl|wget)\s+.*\|\s*(bash|sh)|eval\s+\$\(|rm\s+-rf\s+/'; then
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Command matches deny list"}}\n'
  exit 2
fi
exit 0
```

**Shell metacharacter caveat:** grep-based deny matching on shell command strings is inherently incomplete. A sufficiently crafted command (`VAR=$(curl ...); bash <<<"$VAR"`) evades naive pattern matching. The hook is defense-in-depth, not a security boundary. For genuine security boundaries, use project-level `permissions.deny`. [official]

### Option (b): Project-Level `permissions.deny` (the only enforced layer)

The consuming project adds to its `.claude/settings.json`:

```json
{ "permissions": { "deny": ["Bash(curl *)", "Bash(wget *)", "WebFetch", "WebSearch"] } }
```

This is enforced by Claude Code's permission engine regardless of agent frontmatter. Known caveat: GH issue #27040 reports `permissions.deny` not enforced in some versions for file paths — the rule syntax using `//` for absolute paths differs from Linux convention. Tool-name-based deny patterns (`Bash(curl *)`) are more reliable than path-based ones. [official] (<https://code.claude.com/docs/en/settings>), [community] (<https://github.com/anthropics/claude-code/issues/27040>)

### Agent Frontmatter `disallowedTools`

`disallowedTools:` in agent `.md` frontmatter removes tools from the model's available set for that agent. This is the `--disallowedTools` CLI flag equivalent, applied per-agent. It is best-effort (model-context removal, not engine enforcement). [official] (<https://code.claude.com/docs/en/plugins-reference>)

Important: the plugins-reference explicitly states: "For security reasons, `hooks`, `mcpServers`, and `permissionMode` are not supported for plugin-shipped agents." Agent frontmatter cannot set `permissionMode`.

**Recommended for up-docs v2 plan:** Ship a PreToolUse `deny-guard.sh` as defense-in-depth, document that consuming projects should add `permissions.deny` to their `.claude/settings.json`, and add `disallowedTools:` to agent frontmatter. Three layers, none of them individually complete.

---

## Angle 3: Headless-Mode Integration Testing — CLI Contract

### `--plugin-dir <path>` Confirmed

`--plugin-dir ./plugins/up-docs` loads a plugin from the local filesystem path for the duration of that `--print` session. Each `--plugin-dir` flag takes one path; repeat for multiple. [official] (<https://code.claude.com/docs/en/cli-reference>)

Works with `--bare` for faster startup (skips other auto-discovery). The `--bare` flag still honors explicit `--plugin-dir`.

Failure mode surfaced in `system/init` stream event: `plugin_errors` array lists plugins that failed to load.

### `--agent <name>` Flag

`--agent my-custom-agent` specifies which agent definition to use for the session. For plugin-shipped agents, the name is `<plugin-name>:<agent-name>` based on UI namespacing docs. No explicit `--agent plugin:agent` syntax documented; the `--agent` flag takes the agent name as it appears in `claude agents`. [official]

### `--mcp-config <file>` Flag

`--mcp-config ./test-mcp.json` loads additional MCP servers. The `--strict-mcp-config` flag restricts to ONLY those servers, ignoring all other MCP configs including the plugin's `.mcp.json`. Use `--strict-mcp-config --mcp-config` to replace plugin MCP servers with test stubs. [official] (<https://code.claude.com/docs/en/cli-reference>)

### `--output-format stream-json` Event Schema

Events are newline-delimited JSON objects. Key events for testing:

| Event type | Subtype | Key fields |
| --- | --- | --- |
| `system` | `init` | `session_id`, `plugins`, `plugin_errors`, `model`, `tools`, `mcp_servers` |
| `assistant` | (message) | `message.content[].type` = `text` or `tool_use`; tool_use has `name`, `input`, `id` |
| `result` | — | `result` (final text), `session_id`, `total_cost_usd` |
| `system` | `api_retry` | `attempt`, `error`, `retry_delay_ms` |

**Tool RESULTS:** Tool results (Bash stdout, file contents) are **NOT** emitted in the stream. Only tool inputs (`tool_use` content blocks) appear. Tool outputs are consumed internally. The PostToolUse hook's `tool_response.output` field is the only programmatic access path to tool results. [official] (<https://code.claude.com/docs/en/headless>)

**`parent_tool_use_id`:** Present in the Agent SDK Python/TypeScript library's message objects for sub-agent context. Not documented as a raw stream-json field in the CLI output format. The Agent SDK (`claude-agent-sdk`) is the preferred path if `parent_tool_use_id` tracking is needed. [official] (<https://code.claude.com/docs/en/agent-sdk/overview>)

### Working Headless Test Pattern (bats-style)

```bash
@test "up-docs propagate-repo produces valid JSON" {
  # Load plugin from local path, use acceptEdits to avoid permission prompts
  OUTPUT=$(claude --plugin-dir "$PLUGIN_DIR" \
    --bare \
    --agent up-docs-propagate-repo \
    --permission-mode acceptEdits \
    --dangerously-skip-permissions \
    --output-format json \
    -p "$(cat "$BATS_TEST_DIRNAME/fixtures/session-summary-config-rebind.md")" \
    --allowedTools "Read,Glob,Grep,Bash" \
    --max-turns 10)

  # Check plugin loaded
  PLUGIN_ERRORS=$(echo "$OUTPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('plugin_errors',''))" 2>/dev/null || echo "")
  [ -z "$PLUGIN_ERRORS" ]

  # Validate result is non-empty
  RESULT=$(echo "$OUTPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('result',''))")
  [ -n "$RESULT" ]

  # Schema validation against Pydantic model
  echo "$RESULT" | python3 "$BATS_TEST_DIRNAME/../validate_output.py" repo
}
```

Note: `--output-format json` (not stream-json) returns a single JSON object at exit; easier to `jq`/parse for assertions. Use `stream-json` only when you need per-event interception.

**Recommended for up-docs v2 plan:** Use `claude --plugin-dir ./plugins/up-docs --bare --agent up-docs-propagate-repo --output-format json -p "$(cat fixture.md)"` as the test driver; pipe final `result` field through `validate_output.py`; check `plugin_errors` is absent.

---

## Angle 4: MCP Stub Wiring for Headless Agent Tests

### FastMCP `Client(server)` In-Memory Transport — What It Does NOT Solve

FastMCP's `Client(server_instance)` runs server and client in the same Python process. There is no network or subprocess. This is excellent for unit-testing the stub server itself. [official] (<https://gofastmcp.com/development/tests>), [community] (<https://smithery.ai/skills/ghosttypes/mcp-test-harness>)

**The fundamental mismatch:** When `claude --plugin-dir` runs as an external subprocess, it launches its own MCP client via stdio transport. The `Client(server)` in-memory pattern is inaccessible to Claude Code's subprocess. You cannot wire an in-memory FastMCP server to an external `claude -p` call.

### The Correct Pattern: stdio stub + `--mcp-config`

For headless test stubs that `claude -p` can use:

```python
# tests/stubs/mcp_outline_stub.py
from fastmcp import FastMCP

app = FastMCP("outline-stub")

@app.tool()
def search_documents(query: str) -> list[dict]:
    """Return canned search results for testing."""
    return [{"id": "doc-123", "title": "Test Doc", "url": "/doc/test-doc"}]

@app.tool()
def read_document(document_id: str) -> dict:
    return {"id": document_id, "content": "# Test content\n\nStub content."}

if __name__ == "__main__":
    app.run()  # stdio transport by default
```

```json
// tests/stubs/test-mcp.json
{
	"mcpServers": {
		"mcp-outline": {
			"command": "python3",
			"args": ["/abs/path/to/tests/stubs/mcp_outline_stub.py"]
		}
	}
}
```

```bash
claude --plugin-dir ./plugins/up-docs \
  --bare \
  --strict-mcp-config \
  --mcp-config ./tests/stubs/test-mcp.json \
  --agent up-docs-propagate-wiki \
  --output-format json \
  -p "$(cat fixture.md)"
```

`--strict-mcp-config` replaces the plugin's `.mcp.json` with the stub config entirely.

### MCP Tool Name Mangling Convention

From inspection of existing up-docs agent tool lists in this repo:

- `mcp__plugin_mcp-outline_mcp-outline__search_documents` — plugin name `up-docs`, server key in `.mcp.json` is `mcp-outline`
- `mcp__plugin_Notion_notion__notion-search` — server key `Notion` (note: case-sensitive from key)

The pattern is `mcp__plugin_<server-key>_<server-key>__<tool-name>`. The plugin name itself is NOT in the prefix — only the server key from `.mcp.json` appears (doubled). **The stub server's key in `test-mcp.json` must exactly match the key in the plugin's `.mcp.json`** or the agent won't find the tool.

When using `--strict-mcp-config`, the stub server replaces the real server but must use the same key name (`mcp-outline`, `Notion`, etc.) for tool names to match the agent's `tools:` frontmatter list.

### Footgun: `--strict-mcp-config` Drops User-Level MCP Servers

Using `--strict-mcp-config` drops ALL other MCP servers including user-level ones (brave-search, etc.). If the agent under test uses external search tools, either omit `--strict-mcp-config` (and live with real network calls) or add those servers to `test-mcp.json` as stubs too. [official]

**Recommended for up-docs v2 plan:** Create `tests/stubs/mcp_outline_stub.py` and `tests/stubs/mcp_notion_stub.py` as FastMCP stdio servers; create `tests/stubs/test-mcp.json` with keys matching the plugin's `.mcp.json` exactly (`mcp-outline`, `Notion`); drive tests with `--strict-mcp-config --mcp-config ./tests/stubs/test-mcp.json`.

---

## Angle 5: PostToolUse Hook Safety — Opt-In, Redacted, Scoped

### `tool_response` IS Available

Confirmed: `tool_response: { output: "...", isError: false }` is present in PostToolUse stdin payload. `output` contains the full tool stdout/stderr text as a string. This is the only programmatic path to Bash tool output from a plugin. [official] (<https://code.claude.com/docs/en/hooks>)

New (May 2026 changelog): `PostToolUse hooks can now replace tool output for all tools via hookSpecificOutput.updatedToolOutput` — previously MCP-only. This enables the hook to sanitize the output Claude sees, not just log it. [official] (<https://code.claude.com/docs/en/changelog>)

### Opt-In Pattern via Env Var

```bash
#!/usr/bin/env bash
# capture-transcript.sh — PostToolUse hook, opt-in via UP_DOCS_TRANSCRIPT_LOG

# No-op unless opt-in env var is set
[ -z "${UP_DOCS_TRANSCRIPT_LOG:-}" ] && exit 0

set -uo pipefail
INPUT=$(cat)
TOOL_NAME=$(printf '%s' "$INPUT" | python3 -c "
import sys, json
try: print(json.load(sys.stdin).get('tool_name',''))
except: print('')
" 2>/dev/null)

# Only capture Bash output (not file reads, to avoid leaking file contents)
[ "$TOOL_NAME" != "Bash" ] && exit 0

# Secure log file creation
LOG_FILE="${UP_DOCS_TRANSCRIPT_LOG}"
umask 077
touch "$LOG_FILE" 2>/dev/null || exit 0
chmod 600 "$LOG_FILE"

# Extract and redact before writing
printf '%s' "$INPUT" | python3 - "$LOG_FILE" << 'PYEOF'
import sys, json, re

REDACT = "[REDACTED]"
SECRET_RE = re.compile(
    r'(?i)(?:bearer\s+|token[=:]\s*|password[=:]\s*|bao_token[=:]\s*|'
    r'gh[ps]_[a-z0-9]{36}|AKIA[A-Z0-9]{16}|aws_secret[=:]\s*)'
    r'([^\s\'"]{8,})',
    re.IGNORECASE
)

def redact(s):
    return SECRET_RE.sub(lambda m: m.group(0)[:m.start(1)-m.start(0)] + REDACT, s)

try:
    data = json.load(sys.stdin)
    entry = {
        "session_id": data.get("session_id", ""),
        "tool_name": data.get("tool_name", ""),
        "command": redact(data.get("tool_input", {}).get("command", "")),
        "output": redact(data.get("tool_response", {}).get("output", "")[:4096]),
        "is_error": data.get("tool_response", {}).get("isError", False),
    }
    log_path = sys.argv[1]
    with open(log_path, "a") as f:
        f.write(json.dumps(entry) + "\n")
except Exception as e:
    sys.exit(0)  # fail open
PYEOF
exit 0
```

### File Permission Handling

- `umask 077` before `touch` creates the file mode 600 if not yet existing
- `chmod 600` after ensures it even if the file pre-existed with looser perms
- Write to `${UP_DOCS_TRANSCRIPT_LOG}` (user-supplied absolute path, not plugin root) — plugin root is ephemeral [official]

### Redaction Patterns

Known secret patterns to cover for up-docs context:

- Bearer tokens: `Bearer [A-Za-z0-9._-]{20,}`
- BAO_TOKEN values: `bao_token=...` or env var assignment
- GitHub PATs: `ghp_[a-z0-9]{36}`, `ghs_[a-z0-9]{36}`
- AWS keys: `AKIA[A-Z0-9]{16}` (access key) + `aws_secret_access_key=...`
- Generic password/token assignments: `password=X`, `token=X`, `key=X`

Single-source reference for redaction regex: community gist at <https://gist.github.com/ruvnet/332336ad5e0516daa810d98f8f0ddca9> [community]. No Anthropic advisory specifically on hook-as-data-leak pattern; the risk is inferrable from CVE-2025-59536 (RCE via hooks) and GH issue #44868 (secrets from .env files in transcripts). [official] (<https://github.com/anthropics/claude-code/issues/44868>)

### Cleanup

No official guidance on TTL/rotation. Recommended:

- SessionEnd hook: if `${UP_DOCS_TRANSCRIPT_LOG}` is set and refers to a per-session temp file (`/tmp/up-docs-session-$SESSION_ID.jsonl`), delete it
- Per-session: `UP_DOCS_TRANSCRIPT_LOG=/tmp/up-docs-$(date +%s).jsonl claude ...`
- The `session_id` in the hook payload enables per-session log rotation

### Footgun: `updatedToolOutput` and Context Visibility

PostToolUse cannot undo tool execution. `updatedToolOutput` changes what Claude sees as the tool result but does NOT prevent the tool from having run. If a Bash command exfiltrates data, the PostToolUse hook runs after the exfiltration. [official]

**Recommended for up-docs v2 plan:** Add `capture-transcript.sh` with `[ -z "${UP_DOCS_TRANSCRIPT_LOG:-}" ] && exit 0` guard; use `umask 077`; redact at minimum Bearer, ghp/ghs, AKIA, and generic `key=`/`token=`/`password=` patterns before writing; document that `UP_DOCS_TRANSCRIPT_LOG` must be set explicitly by the user.

---

## Angle 6: Pydantic v2 Schema Patterns for Layer-Pinned Discriminated Unions

### Canonical Pattern: `Field(discriminator="layer")`

```python
from typing import Annotated, Literal, Union
from pydantic import BaseModel, Field, ValidationError

class PropagatorReport(BaseModel):
    """Shared fields for all propagator report types."""
    session_id: str
    findings: list[str]
    propagated_count: int

class RepoReport(PropagatorReport):
    layer: Literal["repo"]
    files_modified: list[str]

class WikiReport(PropagatorReport):
    layer: Literal["wiki"]
    documents_updated: list[str]

class NotionReport(PropagatorReport):
    layer: Literal["notion"]
    pages_updated: list[str]

# Type alias with discriminator annotation
LayeredReport = Annotated[
    Union[RepoReport, WikiReport, NotionReport],
    Field(discriminator="layer")
]

# Usage in a parent model
class PropagatorOutput(BaseModel):
    report: LayeredReport
    success: bool
```

Validation error when discriminator value is wrong:

```text
1 validation error for PropagatorOutput
report
  Input tag 'notion' found using 'layer' does not match any of the
  expected tags: 'repo', 'wiki', 'notion' [type=union_tag_invalid, ...]
```

Wait — if all three are present and `notion` is passed, it will match `NotionReport`. The error fires when `layer` has a value that matches NONE of the expected literals. Example: if `layer: "drift"` is passed when the union has only `repo|wiki|notion`:

```text
Input tag 'drift' found using 'layer' does not match any of the
expected tags: 'repo', 'wiki', 'notion'
```

This is exactly the error CR-001's namespace bug would have produced if the validator existed.

### `Annotated[..., Tag(...)]` Alternative

For cases where the discriminator field differs between models (or for custom discriminator functions):

```python
from pydantic import BaseModel, Discriminator, Tag

def get_layer(v):
    if isinstance(v, dict):
        return v.get("layer")
    return getattr(v, "layer", None)

LayeredReport = Annotated[
    Union[
        Annotated[RepoReport, Tag("repo")],
        Annotated[WikiReport, Tag("wiki")],
        Annotated[NotionReport, Tag("notion")],
    ],
    Discriminator(get_layer)
]
```

Use `Tag` + `Discriminator` when the discriminator field name differs across models. For up-docs (all models have `layer`), `Field(discriminator="layer")` is simpler. [official] (<https://pydantic.dev/docs/validation/latest/concepts/unions>)

### DRY Shared Fields

Use a base class (standard Python inheritance):

```python
class PropagatorReport(BaseModel):
    session_id: str
    findings: list[str]
    propagated_count: int
    # No 'layer' here — each subclass declares its own Literal

class RepoReport(PropagatorReport):
    layer: Literal["repo"]  # discriminator field
    files_modified: list[str]
```

The `model_config` approach (`ConfigDict(arbitrary_types_allowed=True)`) is for non-Pydantic types in fields, not for shared field DRY. For DRY, base class inheritance is the canonical pattern. [official]

### Validation Error Message for Mismatched Discriminator

```text
1 validation error for PropagatorOutput
report
  Input tag 'wrong-value' found using 'layer' does not match any of the
  expected tags: 'repo', 'wiki', 'notion'
  [type=union_tag_invalid, input_value={...}, input_url=...]
```

The error type is `union_tag_invalid`. It explicitly names the bad tag and all valid tags — exactly what's needed to diagnose a propagator writing the wrong `layer` value.

**Recommended for up-docs v2 plan:** Create `tests/validate_output.py` with `RepoReport(PropagatorReport)`, `WikiReport(PropagatorReport)`, `NotionReport(PropagatorReport)` each with `layer: Literal["repo"|"wiki"|"notion"]`, and `LayeredReport = Annotated[Union[...], Field(discriminator="layer")]`; call `PropagatorOutput.model_validate_json(stdout)` in the test.

---

## Angle 7: DeepEval Current API — Verifying CR-012

### CR-012 Confirmed: `LLMTestCaseParams` → `SingleTurnParams`

The DeepEval 2025 changelog explicitly states:

> "LLMTestCaseParams has been renamed to SingleTurnParams, and TurnParams has been renamed to MultiTurnParams ... The old names still work but importing them now emits a DeprecationWarning; switch to SingleTurnParams / MultiTurnParams to silence it." [official] (<https://deepeval.com/changelog/changelog-2025>)

The audit's CR-012 finding is confirmed correct. The stale name still works (no import error) but emits a warning.

### Current `GEval` Signature

```python
from deepeval.metrics import GEval
from deepeval.test_case import LLMTestCase, SingleTurnParams

correctness = GEval(
    name="Correctness",
    criteria="Determine if the actual output matches expected structure and content.",
    evaluation_params=[SingleTurnParams.ACTUAL_OUTPUT, SingleTurnParams.EXPECTED_OUTPUT],
    threshold=0.5
)
```

`evaluation_params` takes `list[SingleTurnParams]`. The `GEval` class docs state: "There are THREE mandatory and SEVEN optional parameters." Mandatory: `name`, `criteria` OR `evaluation_steps` (not both), `evaluation_params`. [official] (<https://deepeval.com/docs/metrics-llm-evals>)

### `LLMTestCase` Signature and `expected_output`

```python
test_case = LLMTestCase(
    input="What is the state of the repo docs?",
    actual_output="The repo has 3 divergences...",  # required
    expected_output="...",  # required if GEval uses EXPECTED_OUTPUT param
    # retrieval_context=[...],  # optional, for RAG metrics
)
```

`expected_output` is required only when `SingleTurnParams.EXPECTED_OUTPUT` is in `evaluation_params`. For rubric-only style (no reference output), omit `SingleTurnParams.EXPECTED_OUTPUT` from the list and omit `expected_output` from `LLMTestCase`. [official] (<https://deepeval.com/docs/getting-started>)

### Anthropic Routing — No OpenAI Key Required

DeepEval ships first-class `AnthropicModel` support:

```python
from deepeval.models import AnthropicModel
from deepeval.metrics import GEval
from deepeval.test_case import SingleTurnParams

model = AnthropicModel(
    model="claude-3-5-sonnet-latest",  # or sonnet-4-6
    temperature=0
)

prose_quality = GEval(
    name="ProseQuality",
    criteria="Evaluate whether the propagator output accurately reflects the session summary without fabricating facts.",
    evaluation_params=[SingleTurnParams.INPUT, SingleTurnParams.ACTUAL_OUTPUT],
    model=model,
    threshold=0.7
)
```

Requires `ANTHROPIC_API_KEY` in environment. No `OPENAI_API_KEY` needed. Alternatively set `USE_ANTHROPIC_MODEL=1` env var to route all metrics to Anthropic by default. [official] (<https://github.com/confident-ai/deepeval/blob/main/docs/integrations/models/anthropic.mdx>)

### Minimal Working Example (pinned)

```python
# tests/test_agent_prose.py
# Requires: pip install deepeval>=1.4.0
# Requires: ANTHROPIC_API_KEY env var
# Run: deepeval test run tests/test_agent_prose.py

import pytest
from deepeval import assert_test
from deepeval.metrics import GEval
from deepeval.test_case import LLMTestCase, SingleTurnParams
from deepeval.models import AnthropicModel

judge = AnthropicModel(model="claude-3-5-sonnet-latest", temperature=0)

no_fabrication = GEval(
    name="NoFabrication",
    criteria=(
        "The actual output must not contain any claims, file names, page titles, "
        "or facts that are not present in the input session summary."
    ),
    evaluation_params=[SingleTurnParams.INPUT, SingleTurnParams.ACTUAL_OUTPUT],
    model=judge,
    threshold=0.8,
)

@pytest.mark.skipif(
    not __import__("os").environ.get("ANTHROPIC_API_KEY"),
    reason="ANTHROPIC_API_KEY not set — skip LLM-judge tests"
)
def test_no_fabrication(session_summary, propagator_output):
    tc = LLMTestCase(input=session_summary, actual_output=propagator_output)
    assert_test(tc, [no_fabrication])
```

**Footgun:** DeepEval by default tries to post results to Confident AI cloud. Run `deepeval login` to authenticate or set `DEEPEVAL_TELEMETRY_OPT_OUT=YES` to disable telemetry. The cloud upload is optional but enabled by default. [official]

**Recommended for up-docs v2 plan:** Replace `LLMTestCaseParams` with `SingleTurnParams` throughout `test_agent_prose.py`; pass `model=AnthropicModel("claude-3-5-sonnet-latest")` to `GEval`; add `@pytest.mark.skipif(not os.environ.get("ANTHROPIC_API_KEY"), ...)` guard; add `DEEPEVAL_TELEMETRY_OPT_OUT=YES` to test environment.

---

## Footguns and Gotchas

- **Plugin `settings.json` scope is narrow** — only `agent` and `subagentStatusLine` keys; `permissions.deny` silently ignored — corroborated by official plugins-reference table and verified by `find plugins -path '*/.claude/settings.json'` returning 0 results. [official] (<https://code.claude.com/docs/en/plugins-reference>)

- **GH issue 34573: plugin PreToolUse/PostToolUse command hooks may be silently dropped** — closed not-planned; verify with `/hooks` menu before relying on plugin security hooks. Prompt hooks work; command hooks have the reported issue. [community] (<https://github.com/anthropics/claude-code/issues/34573>)

- **Tool results not in stream-json CLI output** — `claude -p --output-format stream-json` emits tool inputs but NOT tool outputs. PostToolUse hook is the mandatory capture path. Corroborated by official headless docs and the v1 plan's own "Resolved blockers" section. [official] (<https://code.claude.com/docs/en/headless>)

- **`permissions.deny` file-path syntax quirk** — absolute paths require `//` prefix (double slash), not `/`. Tool-name deny patterns are more reliable: `Bash(curl *)`, not `Read(//etc/*)`. [community] (<https://github.com/anthropics/claude-code/issues/27040>), [community] (<https://www.theregister.com/2026/01/28/claude_code_ai_secrets_files/>)

- **MCP stub key must match plugin's `.mcp.json` key exactly** — `--strict-mcp-config` replaces all MCP servers; stub key must replicate the original server key or tool names won't resolve. Case-sensitive (the `Notion` key example). [official, inferred from tool name inspection]

- **FastMCP `Client(server)` is in-process only** — cannot wire to external `claude -p` subprocess. Use stdio FastMCP server + `--mcp-config` instead. [official] (<https://gofastmcp.com/development/tests>)

- **Plugin agent frontmatter does not support `hooks`, `mcpServers`, or `permissionMode`** — these fields are explicitly excluded for security reasons. [official] (<https://code.claude.com/docs/en/plugins-reference>)

- **`exit 1` is non-blocking in hooks** — only `exit 2` blocks a tool call. Standard Unix convention inverted. [official] (<https://code.claude.com/docs/en/hooks>)

- **PostToolUse cannot undo execution** — `updatedToolOutput` changes what Claude sees, but the tool already ran. Data exfiltration via Bash cannot be prevented by a PostToolUse hook. [official]

- **DeepEval posts results to cloud by default** — set `DEEPEVAL_TELEMETRY_OPT_OUT=YES` to disable. [official]

---

## Existing Tools

| Tool | Maintenance | Link | Fit for use case |
| --- | --- | --- | --- |
| `release-pipeline/scripts/force-push-guard.sh` | Active (this repo) | local | Reference implementation of PreToolUse exit-2 blocking pattern |
| `github-repo-manager/scripts/gh-manager-guard.sh` | Active (this repo) | local | Reference implementation of PostToolUse audit-log capture |
| FastMCP | Active | <https://gofastmcp.com> | MCP stub server for headless test wiring |
| DeepEval | Active | <https://deepeval.com> | LLM-judge eval with Anthropic backend |

---

## Security and Compatibility

- **CVE-2025-59536 / CVE-2026-21852** — RCE and API token exfiltration via malicious `.claude/config.json` hooks, MCP servers, and env vars in project files. Attacker-controlled repos can ship hooks that run before trust prompts. [community] (<https://research.checkpoint.com/2026/rce-and-api-token-exfiltration-through-claude-code-project-files-cve-2025-59536/>)

- **GH issue #44868** — Claude Code reads and echoes `.env` / `.dev.vars` files into conversation transcript despite CLAUDE.md prohibitions. `permissions.deny` with `Read(./.env*)` mitigates. [community] (<https://github.com/anthropics/claude-code/issues/44868>)

- **PostToolUse data-leak vector (CR-006)** — hook capturing `tool_response` receives raw Bash output including any secrets printed by commands. Opt-in guard + redaction patterns are the mitigation; no Anthropic advisory specifically on this. [community] (<https://gist.github.com/ruvnet/332336ad5e0516daa810d98f8f0ddca9>)

---

## Recent Changes

- **PostToolUse `updatedToolOutput` for all tools** (May 2026 changelog) — hooks can now replace the tool output Claude sees for ALL tools, not just MCP tools. New capability for up-docs: the capture hook can sanitize sensitive output before it enters context. [official] (<https://code.claude.com/docs/en/changelog>)

- **`CLAUDE_CODE_SESSION_ID` in Bash subprocess env** (May 2026) — enables per-session log file naming from within hook scripts without parsing the stdin JSON. [official]

- **`--bare` to become default for `-p`** — official docs note `--bare` will become the default for print mode. Headless tests should use `--bare --plugin-dir` explicitly now to be forward-compatible. [official] (<https://code.claude.com/docs/en/headless>)

- **PostToolUse `duration_ms` field** (v2.1.119) — hook inputs now include `duration_ms` for performance monitoring. [official] (<https://code.claude.com/docs/en/changelog>)

- **`LLMTestCaseParams` → `SingleTurnParams`** (DeepEval 2025) — rename confirmed; old name deprecated with warning, not removed. [official] (<https://deepeval.com/changelog/changelog-2025>)

---

## Open Questions

| # | Question | Why unresolved |
| --- | --- | --- |
| 1 | Is GH issue 34573 (plugin PreToolUse/PostToolUse command hooks silently dropped) actually fixed in current Claude Code? The five sibling plugins appear to use command hooks successfully. | Issue is closed-not-planned but production usage contradicts it; needs live verification with `/hooks` menu on current version |
| 2 | When `--strict-mcp-config` replaces plugin MCP servers, do the agent's `tools:` frontmatter entries for the real MCP tools become unavailable (causing the agent to error), or does it silently not find them? | Not explicitly documented; needs empirical test |
| 3 | Does `--agent <plugin>:<agentname>` syntax work for `--plugin-dir`-loaded plugins, or is the agent name bare (without plugin prefix)? | CLI reference says `--agent` overrides agent setting; namespacing for plugin-dir-loaded plugins is not documented |

---

## Handoff

Persisted at `/home/chris/projects/Claude-Code-Plugins/docs/research/2026-05-08-up-docs-plugin-security-eval-infrastructure.md`. Downstream commands that may consume it:

- `/qdev:quality-review` — review the rewritten hardening plan against these findings
- `feature-dev:feature-dev` — start implementation of Phase 2 (PreToolUse guard) and Phase 3 (transcript capture + Pydantic validation)
- `superpowers:executing-plans` — execute the plan rewrite task-by-task using the confirmed primitives above

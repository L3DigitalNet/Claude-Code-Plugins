Mode: research  ·  Topic: Testing and hardening Claude Code plugin sub-agents  ·  Saved: docs/research/2026-05-08-testing-hardening-claude-code-plugin-sub-agents.md

## Summary

| Angle | Sources | Strongest finding |
|-------|---------|-------------------|
| Prompt-level eval frameworks | 8 | DeepEval pytest-native + Promptfoo YAML are the two self-contained options; Inspect AI adds Docker-sandboxed agent harness |
| Mocking MCP servers | 6 | FastMCP `Client(server)` in-memory transport eliminates subprocess flakiness; usable from pytest without a running server process |
| Skill frontmatter permissions schema | 7 | `allowed-tools` is allowlist-only; NO deny field exists in SKILL.md; deny rules live exclusively in `settings.json`; `allowed-tools` enforcement is actively buggy as of early 2026 |
| Anti-fabrication patterns | 6 | Post-hoc transcript parsing + Pydantic output schema are the two structural approaches; tool_use forced output is the constrained-decoding option |
| Anthropic guidance (2025-2026) | 5 | "Demystifying evals for AI agents" (Jan 2026) + "Writing tools for agents" (2025) are the two canonical references; evaluator-optimizer is the official pattern for iterative grounding |
| Claude Code built-in eval CLI | 3 | No `claude eval` command exists; the Evaluation Tool is Console-only (UI); Anthropic's eval cookbook is the closest official harness |

**Queries:** 14  ·  **Results parsed:** ~120  ·  **Deep reads:** 7  ·  **Follow-up pass:** yes (angles 3 and 6 needed targeted pass)

---

## 1. Prompt-level / Behavioral Eval Frameworks

### Official Documentation

- **DeepEval** (Confident AI) runs as a pytest plugin: `deepeval test run`. Supports 50+ metrics including `GEval` (custom rubric), `HallucinationMetric`, and `ToolCallMetric` for multi-step agent traces. MIT-licensed, 13 k+ GitHub stars, 20 M+ daily evals. [official] (https://deepeval.com/docs/introduction)

- **Inspect AI** (UK AI Security Institute / Meridian Labs). `pip install inspect-ai`. Composable `Task → Solver → Scorer` primitives, Docker-sandboxed agent execution, VS Code log viewer, 200+ pre-built evals. Declared MIT-licensed. Used by METR, Apollo Research, other government AISIs, and Anthropic internally. [official] (https://inspect.aisi.org.uk/)

- **Promptfoo** YAML-driven eval runner with an `evaluate-coding-agents` guide (Apr 2026). Runs assertions against agent outputs, supports `claude-code` as a provider. No pytest dependency, runs from CLI. [official] (https://www.promptfoo.dev/docs/guides/evaluate-coding-agents/)

- **pytest-evals** (AlmogBaku). Minimalist pytest plugin for LLM output evaluation; no external service required. [community] (https://github.com/AlmogBaku/pytest-evals)

### Best Patterns for Sub-Agent Prompt Testing

- **Golden snapshot tests**: record a canonical agent output for a fixed input; diff new outputs against it. Useful for regression on the XML-structured `evidence` table and summary-report format. Combine with `pytest --inline-snapshot=fix` (FastMCP pattern) for intentional updates.

- **Invariant / property checks**: run deterministic assertions on every output regardless of exact wording. Examples:
  - `assert not re.search(r'\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b', output)` — no IPv4 strings in Notion table
  - `for e in output["evidence"]: assert e in bash_log` — every evidence substring appears in actual command stdout
  - `assert output["layer"] in {"repo", "wiki", "notion"}` — no invented layer names

- **LLM-as-judge rubric** (DeepEval `GEval`): provide a rubric like "the output contains no file names not present in the bash_log context" with threshold 0.8. Avoids brittle exact-match on prose fields.

- **Anthropic's "Demystifying evals" `tool_calls` grader** (Jan 2026): YAML-spec pattern for asserting required tool calls were made and specific params used:
  ```yaml
  - type: tool_calls
    required:
      - {tool: Read, params: {path: "docs/*"}}
      - {tool: Edit}
  ```
  [official] (https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents)

### Footguns

- **DeepEval requires an API key by default** for many metrics (calls Confident AI cloud). The `GEval` metric makes additional LLM calls — each test case costs real tokens. Mitigate: use `deepeval set-local-model` with a local model or Anthropic API directly; add `@pytest.mark.skipif(not os.getenv("ANTHROPIC_API_KEY"))` guard.

- **Snapshot tests break on every prompt change**, including whitespace normalization. They are high-maintenance. Use them only for the structured JSON/YAML output fields, not for prose summary text.

- **`pytest-evals` has no multi-turn / tool-call support** as of 2026. Suitable only for single-turn assertion checks against stored outputs, not for live agent runs.

- **Inspect AI Docker sandbox** is the right tool for live agent runs with MCP tools, but adds a Docker dependency that will break any CI runner without Docker-in-Docker. Skip for pre-commit; use for nightly.

**Recommended for up-docs:** Write a `tests/eval_outputs/` fixture directory with golden JSON snapshots of each agent's summary-report output. Drive property checks from `bats` via a Python helper: `python3 -c "import json,sys; d=json.load(open('$output_file')); sys.exit(0 if all(e in open('$bash_log').read() for e in d['evidence']) else 1)"`. For the LLM-judge layer, add a single `pytest` file (`tests/test_agent_outputs.py`) using DeepEval `GEval` gated behind `ANTHROPIC_API_KEY`.

---

## 2. Mocking MCP Servers (Outline, Notion) in Tests

### Official Documentation

- **FastMCP in-memory transport** (canonical pattern from gofastmcp.com docs). Pass the server instance directly to `Client(server)` — no subprocess, no port, no JSON-RPC over a socket:
  ```python
  async with Client(mcp_server_instance) as client:
      result = await client.call_tool("search_documents", {"query": "test"})
  ```
  The real MCP protocol runs in-process; debugger works everywhere; deterministic. [official] (https://gofastmcp.com/development/tests)

- **MCP Python SDK `mcp.client.stdio.stdio_client`**: for subprocess-based testing when you need process isolation. Pair with `StdioServerParameters` to launch a test server as a subprocess. [official] (https://github.com/modelcontextprotocol/python-sdk)

- **MCP Inspector** (`npx @modelcontextprotocol/inspector`): real-time JSON-RPC traffic inspection, tool listing, manual invocation. No test-mode hook, but useful for fixture recording. [official] (https://github.com/modelcontextprotocol/inspector)

### Practical Patterns

- **VCR-style recorded-response replay**: record live Outline/Notion MCP tool responses to JSON fixture files during a one-time capture run, then replay them via `unittest.mock.patch`. This avoids any real network dependency in CI:
  ```python
  with patch('mcp_outline.search_documents', return_value=json.load(open('fixtures/outline_search.json'))):
      result = agent_function(input)
  ```

- **Stub stdio server**: a minimal Python script that reads JSON-RPC on stdin and returns canned responses. Useful for bats tests that launch the real agent binary and need a fake MCP endpoint:
  ```python
  # tests/stubs/outline_stub.py
  import sys, json
  for line in sys.stdin:
      req = json.loads(line)
      if req["method"] == "tools/call" and req["params"]["name"] == "search_documents":
          print(json.dumps({"jsonrpc":"2.0","id":req["id"],"result":{"content":[{"type":"text","text":"[]"}]}}), flush=True)
  ```

- **FastMCP in-memory for unit tests of MCP server tools** themselves (not the agent): define a `FastMCP` server in the test file, register stub tools, call via `Client`. Zero dependencies beyond `fastmcp`.

### Footguns

- **Logging to stdout corrupts the stdio JSON-RPC stream**. Any `print()` or default Python logger output to stdout kills the stub silently. Use `sys.stderr` or a file handler exclusively. [community] (https://tech-insider.org/mcp-server-tutorial-python-fastmcp-claude-2026/)

- **`mcp.shared.memory` / in-memory transport exists in the MCP Python SDK but is not the same as FastMCP's `Client(server)` pattern**. The raw SDK path is lower-level and requires manual async event loop management. FastMCP wraps it safely; use FastMCP. [community] (https://fast.io/resources/mocking-mcp-servers-testing/)

- **`subprocess.Popen` + stdio stub is timing-sensitive**: the stub process may not be ready when the client connects. Use `asyncio.sleep(0.1)` or a readiness-check loop before calling tools. FastMCP in-memory eliminates this entirely.

- **`cwd` field in `.mcp.json` is unreliable in plugin context** (confirmed from project MEMORY.md). Stub scripts must use absolute paths or derive their location from `${CLAUDE_PLUGIN_ROOT}` or `BASH_SOURCE[0]`.

**Recommended for up-docs:** Create `tests/stubs/outline_stub.py` and `tests/stubs/notion_stub.py` as minimal stdio JSON-RPC responders. In bats tests, `export MCP_OUTLINE_CMD="python3 $BATS_TEST_DIRNAME/stubs/outline_stub.py"` and patch the agent's MCP config to use the stub. For Python-native tool tests, use FastMCP `Client(server)` directly.

---

## 3. Skill Frontmatter `permissions.deny` Exact Schema

### Official Documentation (authoritative)

Source: `https://code.claude.com/docs/en/skills` and `https://code.claude.com/docs/en/permissions` (retrieved 2026-05-08).

**SKILL.md frontmatter has NO deny field.** The full list of supported frontmatter fields for skills in Claude Code CLI is:

| Field | Effect |
|-------|--------|
| `name` | Display name |
| `description` | When Claude uses the skill |
| `when_to_use` | Additional trigger context |
| `argument-hint` | Autocomplete hint |
| `arguments` | Named positional args |
| `disable-model-invocation` | Block Claude-initiated invocation |
| `user-invocable` | Hide from `/` menu |
| `allowed-tools` | ALLOWLIST — tools usable without per-use approval |
| `model` | Model override |
| `effort` | Effort level |
| `context` | `fork` for subagent execution |
| `agent` | Which subagent type when `context: fork` |
| `hooks` | Skill-scoped hooks |
| `paths` | Glob patterns for auto-activation |
| `shell` | `bash` or `powershell` |

**Agent frontmatter** (`.claude/agents/*.md`) uses `tools` (allowlist) and `disallowedTools` (denylist). Skills do not have `disallowedTools`. [official] (https://code.claude.com/docs/en/skills)

### Deny Rules Live in settings.json

Deny rules use this exact syntax in `~/.claude/settings.json` or `.claude/settings.json`:

```json
{
  "permissions": {
    "deny": [
      "Bash(rm *)",
      "Bash(rm:*)",
      "Bash(git push --force *)",
      "Bash(git push -f *)",
      "Bash(pct destroy *)",
      "Bash(systemctl stop *)",
      "Bash(systemctl disable *)"
    ]
  }
}
```

**Both `Bash(rm *)` and `Bash(rm:*)` are valid and equivalent** — the `:*` suffix is shorthand for a trailing space-wildcard. `Bash(rm *)` is the form written by the permission dialog on "Yes, don't ask again". [official] (https://code.claude.com/docs/en/permissions)

**Key subtlety**: `Bash(rm *)` with a space before `*` enforces a word boundary — matches `rm -rf /tmp` but NOT `rmdir`. `Bash(rm*)` without a space matches both. For safety, use `Bash(rm *)`.

**Compound commands are parsed**: a deny rule for `Bash(rm *)` also blocks `rm -rf /tmp` inside `cd /tmp && rm -rf .` because Claude Code splits on `&&`, `||`, `;`, `|`, and evaluates each subcommand independently.

### Active Bugs (as of early 2026)

**`allowed-tools` in SKILL.md is not reliably enforced.** Multiple open GitHub issues confirm this:
- Issue #18837: `allowed-tools` appears to be ignored entirely — Claude uses any tool regardless of what the skill permits. [community] (https://github.com/anthropics/claude-code/issues/18837)
- Issue #37683 (Mar 2026): "Claude still has unrestricted access to all tools" when skill specifies `allowed-tools`. [community] (https://github.com/anthropics/claude-code/issues/37683)
- Issue #14956: `allowed-tools` in SKILL.md is reported as active but Bash commands matching the pattern are still denied — the behavior is inverted in some cases. [community] (https://github.com/anthropics/claude-code/issues/14956)

**`allowed-tools` is a Claude Code CLI-only field.** It has no effect when skills are used via the API (`skills-2025-10-02` beta header). [official] (https://platform.claude.com/docs/en/agent-sdk/skills)

**`~/.claude/settings.local.json` does not reliably load user permissions.** Only `~/.claude/settings.json` is confirmed to work. [community] (https://github.com/anthropics/claude-code/issues/14956)

**Recommended for up-docs:** Do NOT rely on `allowed-tools` in skill frontmatter to restrict the propagators. Put deny rules in `.claude/settings.json` checked into the plugin directory. For the three Haiku propagators, the critical deny set is:
```json
"deny": ["Bash(rm *)", "Bash(git push *)", "Bash(pct *)", "Bash(systemctl *)"]
```
These belong at the project level, not in skill frontmatter. The `disallowedTools` field on agent frontmatter (`.claude/agents/*.md`) IS supported and enforced — use that for agent-level restrictions.

---

## 4. Structural Anti-Fabrication Patterns for Evidence Fields

### Official Documentation

- **Anthropic "Demystifying evals" — `tool_calls` grader type** (Jan 2026): explicitly validates that specific tools were called with specific parameters. The `llm_rubric` type can assert "Agent's response grounded in fetch_policy tool results." Both are code-based graders with no LLM call overhead. [official] (https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents)

- **Anthropic "Writing tools for agents"** (2025): "each evaluation prompt should be paired with a verifiable response or outcome. Your verifier can be as simple as an exact string comparison between ground truth and sampled responses." Also: semantic identifier resolution ("resolving arbitrary alphanumeric UUIDs to more semantically meaningful language significantly improves Claude's precision in retrieval tasks by reducing hallucinations"). [official] (https://www.anthropic.com/engineering/writing-tools-for-agents)

- **Anthropic `tool_use` forced output** (constrained decoding): use `tool_choice: {"type": "tool", "name": "emit_summary"}` to force the agent to emit a structured JSON object via the tool_use mechanism rather than prose. The tool schema enforces field types, required keys, and enum values at the API level — hallucination of schema-violating fields is mechanically blocked. [official] (https://docs.anthropic.com/en/docs/build-with-claude/tool-use)

### Structural Patterns

- **Post-hoc transcript verification (highest value for up-docs)**:
  After the agent run, parse the Bash tool call log from the agent transcript and assert that every string in the `evidence` field of the summary report appears verbatim in actual command stdout. Implement as a bats helper:
  ```bash
  verify_evidence_grounded() {
    local report_file="$1"
    local bash_log="$2"
    python3 - <<'EOF'
  import json, sys
  report = json.load(open(sys.argv[1]))
  log = open(sys.argv[2]).read()
  missing = [e for e in report.get("evidence", []) if e not in log]
  if missing:
      print("FAIL: fabricated evidence:", missing, file=sys.stderr)
      sys.exit(1)
  EOF
    "$report_file" "$bash_log"
  }
  ```

- **Pydantic output schema validation**: define a `SummaryReport` Pydantic model matching `templates/summary-report.md`'s structure. After each agent run, parse the output and call `SummaryReport.model_validate(output)`. This catches invented fields (like Bug #4's `version.txt`), missing required fields, and type violations. Run this as a post-hoc validator before accepting any agent output.

  ```python
  from pydantic import BaseModel, field_validator
  from typing import Literal
  
  class PropagatorReport(BaseModel):
      layer: Literal["repo", "wiki", "notion"]
      files_changed: list[str]
      evidence: list[str]
      
      @field_validator("files_changed")
      @classmethod
      def no_invented_files(cls, v):
          for f in v:
              assert not f.startswith("version"), "fabricated version file"
          return v
  ```

- **"Citation forcing" via tool_use**: add an `emit_report` tool to each propagator agent with a strict JSON schema that requires every `evidence` entry to be a verbatim substring of a `tool_result_id`. The agent must cite the tool call ID that produced the evidence — hallucinated evidence has no valid tool_result_id and fails the schema.

- **Two-pass verifier pattern** (evaluator-optimizer from Anthropic "Building Effective Agents"): after each propagator run, dispatch a lightweight Haiku verifier with the transcript and the output. Verifier prompt: "Does every claim in the report trace to a tool result in the transcript? Output JSON: {verified: bool, issues: [str]}". Gate the commit on `verified: true`.

### Footguns

- **Post-hoc transcript parsing is only available if you capture stdout**. In Claude Code sub-agents, the transcript is the CLI output. You must pipe or redirect it during tests. In production runs invoked by a skill, the transcript is not automatically persisted — add an `emit_transcript_to_file` hook or use the agent's hooks field.

- **Pydantic validation catches schema violations but not semantic fabrication** — if the agent invents a plausible file name that passes the schema, Pydantic won't catch it. Post-hoc transcript verification catches what Pydantic misses.

- **`tool_choice: {type: tool}` forced output requires every response to use the tool**. If the agent decides it has nothing to report, it will still call the tool with empty/stub data rather than emitting a natural "no changes" response. Add a `NullReport` variant or an explicit `no_changes: bool` field to handle this gracefully.

- **Two-pass verifiers add latency and cost**. For a Haiku-driven propagator verified by a second Haiku call, the verification adds ~50% to the token cost of each run. Gate verifier calls behind a `STRICT_MODE` env var for CI; skip in interactive use.

**Recommended for up-docs:** Implement the Pydantic schema validator immediately — it would have caught both Bug #3 (wrong output format for bare-name dispatch) and Bug #4 (invented `version.txt` file). Add it as `tests/validate_output.py` and call it from the bats test that exercises end-to-end agent runs. The post-hoc transcript evidence check is the second priority.

---

## 5. Recent Anthropic Guidance on Grounding and Hallucination Control

### Official Documentation

- **"Building effective agents"** (Anthropic Engineering, Dec 2024, updated 2025). The evaluator-optimizer pattern: one LLM generates, another evaluates in a loop. For grounding: "it's crucial for the agents to gain 'ground truth' from the environment at each step (such as tool call results or code execution) to assess its progress." [official] (https://www.anthropic.com/research/building-effective-agents)

- **"Demystifying evals for AI agents"** (Anthropic Engineering, Jan 9 2026). Most relevant 2026 document. Introduces `state_check`, `tool_calls`, `transcript`, `llm_rubric` grader types. Explicitly addresses agent-specific eval challenges: "mistakes can propagate and compound." The Swiss Cheese model for layered evaluation: automated evals + production monitoring + human review. [official] (https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents)

- **"Writing effective tools for agents"** (Anthropic Engineering, 2025). Grounding through semantic identifier resolution: replacing UUIDs/opaque IDs with human-readable labels "significantly improves precision in retrieval tasks by reducing hallucinations." Tool evaluation cookbook: `platform.claude.com/cookbook/tool-evaluation-tool-evaluation`. [official] (https://www.anthropic.com/engineering/writing-tools-for-agents)

- **"Building effective AI agents" resources page** (Anthropic, 2025): cookbook recipes for all five workflow patterns including evaluator-optimizer with code generator + code reviewer loop example. [official] (https://resources.anthropic.com/building-effective-ai-agents)

### Key Guidance for Multi-Agent Fabrication Control

- Anthropic explicitly recommends **outcome verification over step verification**: "checking that agents followed very specific steps like a sequence of tool calls in the right order" is discouraged. Grade outcomes (was the doc updated correctly?) rather than prescribing rigid tool-call sequences.

- The **"ground truth from the environment"** principle maps directly to evidence-field verification: the agent should only emit evidence that came from an actual tool result, and the verifier should confirm this by cross-referencing tool_result content.

- Anthropic's recommended grader progression: exact string match first, LLM judge second, human review third. Start cheap; reach for LLM judge only when deterministic checks are insufficient.

**No Anthropic blog post or doc page specific to Claude Code / plugin sub-agents on hallucination or fabrication was found as of May 2026.** The guidance above is from the general agents engineering posts.

**Recommended for up-docs:** Implement the evaluator-optimizer pattern as a lightweight `up-docs-verify` agent that runs after the three propagators and before presenting results to the user. It should check: (1) every edited file path appears in a Read or Glob tool result, (2) no file appears in `files_changed` that was not in the session-change summary. This directly addresses Bug #4.

---

## 6. Claude Code Built-in Eval CLI / Harness

### Official Documentation

- **The Evaluation Tool** exists only in the Claude Console (web UI) at `platform.claude.com`. It is an interactive tool in the prompt editor — not a CLI command. Accessed via the "Evaluate" tab in the Console. [official] (https://platform.claude.com/docs/en/test-and-evaluate/eval-tool)

- **No `claude eval`, `claude test`, or `--eval` flag exists in the Claude Code CLI** as of May 2026. Searches returned zero results for such a command. The changelog at `github.com/anthropics/claude-code` has no entry for an eval CLI subcommand.

- **The Anthropic eval cookbook** (`platform.claude.com/cookbook/tool-evaluation-tool-evaluation`) is the closest official harness: a Python script that runs parallel agent evaluations against tool call fixtures. It is a notebook/script pattern, not a CLI. [official] (https://platform.claude.com/cookbook/tool-evaluation-tool-evaluation)

- **`claude --print` mode** (non-interactive) is the closest CLI approximation: `echo "prompt" | claude --print` runs a single agent turn and returns output to stdout. Combined with `--agent my-agent` flag, this drives sub-agent runs from shell scripts. The `--print` flag now honors `tools:` and `disallowedTools:` frontmatter as of a recent Claude Code release. [official] (https://code.claude.com/docs/en/changelog)

- **`Claude Eval Runner Plugin`** (Daniel Rosehill, Apr 2026): a community Claude Code plugin for scaffolding, running, documenting, and publishing AI evaluations with curated ground-truth datasets. Not official, but purpose-built for this use case. [community] (https://danielrosehill.com/projects/index/)

### What `claude --print` Enables for Testing

```bash
# Drive a sub-agent run from bats
run bash -c 'echo "$(<tests/fixtures/session-change-summary.md)" | \
  claude --print --agent up-docs-propagate-repo 2>&1'
# Assert on output
assert_output --partial '"layer": "repo"'
assert_output --regexp '"files_changed": \['
```

This pattern enables bats-level integration tests for agent prompts without a full interactive session.

### Footguns

- **`claude --print` uses real API calls** — not mocked. Tests that use it will cost tokens and fail without `ANTHROPIC_API_KEY`. Gate behind an integration test marker.

- **The Evaluation Tool in the Console does not support programmatic access** — no API endpoint, no CLI flag. It cannot be scripted.

- **The eval cookbook is Jupyter notebook-oriented**. Adapting it to a bash/bats CI environment requires extracting the Python evaluation loop into a standalone script.

- **No official agent test suite examples exist in the Anthropic GitHub org** for plugin-style sub-agents. The `github.com/anthropics/skills` repo contains skill examples but no test suite pattern.

**Recommended for up-docs:** Use `claude --print --agent <agent-name>` as the integration test driver in a `tests/integration/` subdirectory, gated behind `@integration` markers in bats (i.e., skipped unless `RUN_INTEGRATION=1`). Combine with the Pydantic validator (`validate_output.py`) to assert structural correctness without an LLM judge.

---

## Existing Tools

| Tool | Maintenance | Link | Fit for use case |
|------|-------------|------|------------------|
| DeepEval | Active (Confident AI, 2026) | https://deepeval.com | High — pytest-native, `GEval` rubric, `ToolCallMetric`; add API key guard |
| Inspect AI | Active (UK AISI / Meridian Labs, 2026) | https://inspect.aisi.org.uk | Medium — best for Docker-sandboxed nightly eval of live MCP runs; heavy for pre-commit |
| Promptfoo | Active (2026) | https://www.promptfoo.dev | Medium — YAML-driven, good for snapshot diff of agent outputs; no native MCP stub |
| FastMCP test utilities | Active (2026) | https://gofastmcp.com/development/tests | High — in-memory transport for MCP server mocking; use for Outline/Notion stub tests |
| pytest-evals | Active (community, 2026) | https://github.com/AlmogBaku/pytest-evals | Low — single-turn only, no multi-step agent support |
| Claude Eval Runner Plugin | Community (Apr 2026) | https://danielrosehill.com/projects/index/ | Unknown — fits the plugin context but maintenance/quality unverified |

---

## Security and Compatibility

- **`allowed-tools` in SKILL.md is actively buggy** (multiple open issues as of Mar 2026): it does not reliably restrict tool access. Do NOT depend on it as a security boundary. Use `settings.json` deny rules for hard blocks. [community] (https://github.com/anthropics/claude-code/issues/18837), (https://github.com/anthropics/claude-code/issues/37683)

- **`bypassPermissions` mode skips all deny rules** except `rm -rf /` and `rm -rf ~`. If sub-agents are spawned in `bypassPermissions` mode (e.g., via auto-mode), skill-level `allowed-tools` provides zero protection. Defense: use PreToolUse hooks as the enforcement layer when `bypassPermissions` is active.

- **Bash deny rules are bypassable via shell operator splitting** if not written carefully. A deny on `Bash(rm *)` does NOT block `echo 'rm -rf /tmp/foo' | bash`. For stronger enforcement, enable the sandbox layer (`sandbox.filesystem`).

- **MCP stub servers in tests inherit the parent process's environment variables** including any live API keys. Ensure test stubs do not make real API calls; mock at the HTTP/transport layer.

- **`allowed-tools: Bash(git *)` grants `git push --force`** unless you also add an explicit deny for `Bash(git push --force *)` in settings. The allowlist does not restrict subcommands.

---

## Recent Changes

- **`--print` mode now honors `tools:` and `disallowedTools:` frontmatter** (Claude Code changelog, ~May 2026): this is the prerequisite for reliable bats-level integration testing of agents via `claude --print`. [official] (https://code.claude.com/docs/en/changelog)

- **Agent frontmatter `mcpServers` now loads for main-thread agent sessions via `--agent`** (Claude Code changelog, ~May 2026): means MCP tools in agent frontmatter are available in `--print` mode for integration tests. [official] (https://code.claude.com/docs/en/changelog)

- **FastMCP SDK reached production-level testing docs** with in-memory transport as the primary test pattern (gofastmcp.com, 2026). The `run_server_in_process` utility for subprocess isolation is available since v2.13.0+. [official] (https://gofastmcp.com/development/tests)

- **`allowed-tools` enforcement bugs are still open** as of March 2026 with no closed-fix milestone visible. Do not plan a release against this feature until confirmed fixed. [community] (https://github.com/anthropics/claude-code/issues/37683)

- **Anthropic renamed UK AISI to "AI Security Institute"** (Feb 2025). Inspect AI docs are at `inspect.aisi.org.uk` — all prior `inspect.ai.safety.gov.uk` links redirect. [official] (https://www.aisi.gov.uk/blog/inspect-evals)

---

## Open Questions

| # | Question | Why unresolved |
|---|----------|----------------|
| 1 | Is the `allowed-tools` enforcement bug in SKILL.md fixed in any Claude Code version after March 2026? | GitHub issue #37683 was open as of research date; no fixed milestone found |
| 2 | Does `claude --print --agent` capture the full tool-call transcript (Bash stdout etc.) in its output, or only the final text response? | Changelog confirms `--print` honors frontmatter but does not specify transcript capture format |
| 3 | Can a FastMCP stub for Outline/Notion be configured to accept the exact `mcp__plugin_mcp-outline_*` tool name format that Claude Code uses? | MCP Inspector shows tool names but no authoritative source on whether FastMCP stub tool names must match Claude Code's mangled namespace |
| 4 | Does the two-pass verifier pattern (Haiku verifier after Haiku propagator) work within Claude Code's sub-agent dispatch, or does it require an orchestrator skill? | "Building effective agents" describes the pattern in the API context; Claude Code sub-agent chaining behavior after one agent completes is underdocumented |

---

## Handoff

Persisted at `docs/research/2026-05-08-testing-hardening-claude-code-plugin-sub-agents.md`. Downstream commands that may consume it:

- `/qdev:quality-review` — review the up-docs plugin agent prompts with this research as ground truth
- `superpowers:brainstorming` — feed Open Questions into a design conversation about the verifier-agent architecture
- `feature-dev:feature-dev` — start implementation of `tests/validate_output.py` + Pydantic schema with this background

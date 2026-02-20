# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

A Claude Code plugin marketplace and development workspace. `main` distributes plugins to users; `testing` is where all development happens. GitHub blocks direct pushes to `main` — merge from `testing` when ready to deploy.

## Plugin Design Principles

These govern every plugin. Evaluate every design decision against them.

**[P1] Composable Over Monolithic** — Focused, independently useful units. Complex workflows emerge from combining atomic components at runtime. Each skill, command, or hook does one thing; orchestration is assembled from the outside.

**[P2] Scope Fidelity** — A plugin does exactly what it was invoked to do — no more. Out-of-scope observations are surfaced as notes, never acted upon. Scope creep is a trust violation.

**[P3] Safe Default, Explicit Escalation** — Default posture is minimal, reversible, lowest-impact. Destructive modes and irreversible paths require an explicit user step. Dry-run before live, read before write, narrow scope before wide.

**[P4] Human Consent Before Consequence** — No autonomous destructive or irreversible actions. Every high-impact operation is announced before execution. Confirming once in one context does not authorise the same action in another.

**[P5] Explainability Precedes Action** — Explain what and why before acting, in plain language. Proportionate: brief for routine actions, detailed for high-impact ones.

**[P6] Conversation-Native Interaction** — Honour the terminal conversation medium. Prefer bounded `AskUserQuestion` choices over open-ended prompts. Lead with the answer. Output longer than ~10 lines should be chunked. Errors are actionable, never raw stack traces.

**[P7] Fail Fast, Never Silently** — Stop immediately on failure and surface it completely. No autonomous recovery, no continuing past a known failure.

**[P8] Done is Measured, Not Declared** — Iterative plugins define completion as a measurable state (zero findings, all checks green) and drive toward it across cycles. Success is not declared after a single pass.

**[P9] One Concept Per Skill** — Each skill covers one tightly-scoped concept whose trigger fits in one sentence without "or". A skill spanning five topics loads all five even when only one applies. If the trigger needs "or", it's two skills.

## Repository Structure

```
Claude-Code-Plugins/
├── .claude-plugin/marketplace.json   # Marketplace catalog
├── .github/workflows/                # CI: codeql, ha-dev-plugin-tests, plugin-test-harness-ci
├── plugins/
│   ├── agent-orchestrator/           # Agent team orchestration (reference implementation)
│   ├── design-assistant/             # Design document authoring and review
│   ├── github-repo-manager/          # Conversational GitHub repo maintenance
│   ├── home-assistant-dev/           # HA integration dev toolkit + MCP server
│   ├── linux-sysadmin-mcp/           # Linux sysadmin MCP server (~100 tools, TypeScript)
│   ├── plugin-review/                # Plugin quality review via orchestrator
│   ├── plugin-test-harness/          # Iterative test/fix/reload loop (TypeScript)
│   └── release-pipeline/             # Autonomous release pipeline
├── scripts/validate-marketplace.sh   # Zod-schema marketplace validation
└── docs/                             # Plugin development documentation
```

## Plugin Structure

Every plugin requires `.claude-plugin/plugin.json`:
```json
{ "name": "plugin-name", "version": "1.0.0", "description": "...", "author": { "name": "...", "url": "..." } }
```

Optional components (all directories are optional):
- **`commands/`** — User-invocable slash commands
- **`skills/`** — AI-invoked domain knowledge (loads when contextually relevant)
- **`agents/`** — Custom subagent definitions with tool restrictions
- **`hooks/`** — Lifecycle event handlers (PreToolUse, PostToolUse, PreCompact, etc.)
- **`scripts/`** — External shell scripts for hooks or commands
- **`templates/`** — Files copied to projects during plugin operation
- **`.mcp.json`** — MCP server config at plugin root (not inside `.claude-plugin/`)

`.mcp.json` for stdio: `{"name": {"command": "node", "args": ["dist/server.js"]}}`. For npx: `{"command": "npx", "args": ["-y", "@scope/pkg"]}`. For HTTP: `{"type": "http", "url": "..."}`.

## Testing & Validation

No root-level test runner — each plugin is self-contained. TypeScript plugins must be built before testing.

```bash
# Python plugins (home-assistant-dev, design-assistant)
pytest plugins/home-assistant-dev/tests/scripts/ -m unit
pytest plugins/home-assistant-dev/tests/scripts/ -m integration

# TypeScript plugins (linux-sysadmin-mcp, plugin-test-harness)
cd plugins/linux-sysadmin-mcp   # or plugin-test-harness
npm ci && npm run build && npm test

# Marketplace validation — always run before merging to main
./scripts/validate-marketplace.sh

# Local plugin load test
claude --plugin-dir ./plugins/plugin-name
```

CI runs the full matrix automatically on push to `testing` or `main`.

## Development Workflow

**New plugin checklist:**
1. Create `plugins/my-plugin/.claude-plugin/plugin.json` (name, version, description, author)
2. Add entry to `.claude-plugin/marketplace.json` (see Marketplace Schema below)
3. Add `CHANGELOG.md` using Keep a Changelog format (sections: Added, Changed, Fixed, Removed, Security)
4. Run `./scripts/validate-marketplace.sh`
5. Commit to `testing`, push, merge to `main` when ready

**Updating a plugin — both files must change together:**
1. Bump version in `plugins/<name>/.claude-plugin/plugin.json`
2. Update matching version in `.claude-plugin/marketplace.json`
3. Update `CHANGELOG.md`
4. Run `./scripts/validate-marketplace.sh`

**Deploy to main:**
```bash
git checkout main && git merge testing --no-ff -m "Deploy: <description>" && git push origin main && git checkout testing
```

See [BRANCH_PROTECTION.md](BRANCH_PROTECTION.md) for emergency hotfix workflow.

## Key Architectural Patterns

### Context Footprint

Claude Code sessions degrade when context fills. Effective plugins minimise context cost:

| Component | Enters context? | When? |
|-----------|-----------------|-------|
| Command markdown | Yes | On `/command` invocation |
| Skill markdown | Conditionally | When AI deems relevant |
| Agent definitions | No (for parent) | Loaded by spawned agent |
| Hook scripts | No | Run externally; only stdout returns |
| Templates | No | Copied to disk, read independently |

**Rule**: Keep inline command/skill content minimal. Move large instruction sets to templates. Use hooks for enforcement rather than lengthy behavioral instructions.

### Enforcement Layers (strongest to weakest)

1. **Mechanical** — Hooks that deterministically block/warn regardless of AI behavior
2. **Structural** — Architectural constraints (e.g., git worktrees for file isolation)
3. **Behavioral** — Instructions in prompts (weakest; covers widest surface)

Don't rely solely on behavioral instructions. Add mechanical enforcement for critical constraints.

### Hooks Reference

`hooks.json` — `hooks` must be a **record keyed by event name**, not an array:
```json
{
  "hooks": {
    "PostToolUse": [{ "matcher": "Write|Edit|MultiEdit", "hooks": [{ "type": "command", "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/hook.sh" }] }]
  }
}
```

Hook scripts receive tool context as JSON on stdin (`${CLAUDE_PLUGIN_ROOT}` is the only available variable):
```bash
FILE_PATH=$(python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('file_path',''))")
```

PreToolUse blocking (exit 2): `echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","decision":"block","reason":"..."}}'`

PostToolUse warnings: write to stdout — injected into agent context.

Prefer one hook per event type with a dispatcher script routing by file path over multiple hooks with pattern matching (not supported by schema).

Reference implementation: `plugins/agent-orchestrator/hooks/hooks.json`

## Marketplace Schema

Validator uses Zod strict mode — unknown fields are rejected.

**`marketplace.json` root** — required: `name`, `owner` (object), `plugins` (array). Optional: `description`. **INVALID**: `version`, `homepage`, `repository`, `license`.

**Plugin entries** — required: `name`, `description`, `source`. Optional: `version`, `author` (object), `category`, `homepage`, `tags`, `strict`. **INVALID**: `displayName`, `keywords`, `license`.

**`plugin.json` manifests** — valid fields: `name`, `version`, `description`, `author`. `category` is rejected. `homepage` is tolerated.

Canonical entry template:
```json
{
  "name": "plugin-name",
  "description": "One or two sentences.",
  "version": "1.0.0",
  "author": { "name": "L3DigitalNet", "url": "https://github.com/L3DigitalNet" },
  "source": "./plugins/plugin-name",
  "homepage": "https://github.com/L3DigitalNet/Claude-Code-Plugins/tree/main/plugins/plugin-name"
}
```

Ground truth schema: `~/.claude/plugins/marketplaces/claude-plugins-official/.claude-plugin/marketplace.json`

## Gotchas

- **`((var++))` with `set -e`** — exits with code 1 when var=0. Use `var=$((var + 1))` instead.
- **Marketplace cache is a git clone** — editing one file doesn't update the tree. To refresh: `cd ~/.claude/plugins/marketplaces/<name> && git fetch origin && git reset --hard origin/main`.
- **Stale `enabledPlugins` entries** — removing a marketplace leaves stale `"plugin@marketplace": true` entries in `~/.claude/settings.json` that cause load errors. Remove manually.
- **MCP plugins need `npm install`** — plugin install doesn't run it. Use `npx` in `.mcp.json` or pre-build.
- **`installed_plugins.json` is the load source of truth** — editing `settings.json` alone doesn't unload a plugin.

## Documentation Reference

- `docs/plugins.md` — Plugin development guide
- `docs/plugins-reference.md` — Complete manifest schema, CLI commands
- `docs/skills.md` — Skill YAML frontmatter, trigger patterns
- `docs/hooks.md` — All hook types, event schemas, debugging
- `docs/sub-agents.md` — Custom agent definitions, tool restrictions
- `docs/mcp.md` — MCP server integration
- `docs/plugin-marketplaces.md` — Creating and hosting marketplaces

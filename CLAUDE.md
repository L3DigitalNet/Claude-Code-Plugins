# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

A Claude Code plugin marketplace and development workspace. `main` distributes plugins to users; `testing` is where all development happens. GitHub blocks direct pushes to `main` — merge from `testing` when ready to deploy.

## Plugin Design Principles

These govern every plugin. Evaluate every design decision against them.

**[P1] Act on Intent** — Invoking a command is consent. Execute on clear intent without restating what's about to happen or asking for confirmation of the obvious. Confirmation gates exist only for operations that are truly irreversible and whose scope materially exceeds what the invocation implies — not for operations that are merely large or look dangerous. Routine friction is a tax, not a safeguard.

**[P2] Scope Fidelity** — Execute the full scope of what was asked — completely, without hedging or stopping to confirm sub-tasks. Do not act beyond the declared scope; surface out-of-scope observations as notes only. Scope creep in either direction is a failure.

**[P3] Inform at Pause Points, Not Every Step** — Succeed quietly: output results, not narration; lead with findings, not intent. At logical pause points — phase transitions, pre-decision moments — surface a compact summary; at the natural conclusion of a process, a brief factual record of what was done — not why, just what changed. Timely, dense information enables decisions; status updates after every action are noise. When something fails, stop immediately and surface the complete failure — raw output included, nothing softened, no autonomous recovery.

**[P4] Use the Full Toolkit** — When interaction is required, use Claude Code's rich primitives: bounded `AskUserQuestion` choices over open-ended prompts, markdown previews for side-by-side comparisons, multi-select for non-exclusive options. Lead with findings, not preamble. Format with purpose — status symbols, structured lists — never decoratively.

**[P5] Convergence is the Contract** — Iterative work defines completion as a measurable state — zero findings, all checks green, all tests passing — and drives toward it across cycles without check-ins. Report the trend; stop only when the criterion is met or the user intervenes.

**[P6] Composable, Focused Units** — Every plugin component — command, skill, hook — does one thing and is independently useful. Complex workflows emerge from combining atomic units at runtime; orchestration is assembled from the outside, not baked in. Skills are the sharpest expression of this: each covers a single concept narrow enough that its trigger fits in one sentence without "or". Skills load in full when triggered; wide scope silently taxes every loosely related task with tokens that do no work. If a trigger requires "or", it's two skills.

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

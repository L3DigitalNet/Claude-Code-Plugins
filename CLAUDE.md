# CLAUDE.md

**Session handoff:** [`docs/handoff.md`](docs/handoff.md) — read this first. Current deployed state, remaining work, bugs log, architecture, credentials, and gotchas.

**Full conventions reference:** [`docs/conventions.md`](docs/conventions.md) — LLM-targeted pattern library. Every convention follows the six-field schema (Applies-when / Rule / Code / Why / Sources / Related) with a Quick Reference table at the top for O(1) lookup. Do not introduce new patterns without checking conventions first.

## Repository Purpose

Claude Code plugin marketplace and development workspace. `main` distributes to users; `testing` is where all development happens. GitHub blocks direct pushes to `main`.

## Plugin Design Principles

Evaluate every design decision against these.

**[P1] Act on Intent** — Invoking a command is consent to its implied scope. When intent is ambiguous, clarify before executing — not after. When intent is clear, execute without narration or confirmation of the obvious. Gate only on operations that are both truly irreversible and whose scope materially exceeds what the invocation implies — not merely large or dangerous-looking. If scope materially changes mid-execution, stop and re-confirm. Routine friction is a tax, not a safeguard.

**[P2] Scope Fidelity** — Execute the full scope asked — completely, without routine sub-task confirmation gates. When a sub-task's scope is genuinely ambiguous, clarify before proceeding rather than assuming. Surface only material out-of-scope findings as notes — routine adjacent observations are not worth raising. Scope undershoot triggers additional iteration; scope overshoot violates the consent established at invocation.

**[P3] Succeed Quietly, Fail Transparently** — Lead with findings — not intent, not preamble. Emit a compact factual summary at task completion — not after every step. Retry transient or infrastructure errors silently. On critical failures, stop immediately and surface the complete failure — raw output included — with a recovery plan; do not attempt autonomous workarounds.

**[P4] Use the Full Toolkit** — When interaction is required, prefer structured choices over open-ended prompts — bound the user's decision space before presenting it. Use Claude Code's interaction primitives: bounded choices (`AskUserQuestion`), markdown previews for side-by-side comparisons, multi-select for non-exclusive options.

**[P5] Convergence is the Contract** — Iterative work drives toward a measurable criterion — set by the plugin, the user, or collaboratively — without check-ins. Proceed quietly when converging normally; surface immediately if progress stalls or regresses unexpectedly. If the cycle begins oscillating — making and undoing the same changes repeatedly — flag the pattern and stop. Stop only when the criterion is met, oscillation is detected, or the user intervenes.

**[P6] Composable, Focused Units** — Each component does one thing and is independently useful. Complex workflows emerge from combining atomic units at runtime; orchestration is assembled from the outside, not baked in.

## Repository Structure

```
Claude-Code-Plugins/
├── .claude-plugin/marketplace.json   # Marketplace catalog
├── .github/workflows/                # CI: codeql, ha-dev-plugin-tests, plugin-test-harness-ci
├── plugins/
│   ├── design-assistant/             # Design document authoring and review
│   ├── docs-manager/                 # Documentation lifecycle management (legacy)
│   ├── github-repo-manager/          # Conversational GitHub repo maintenance
│   ├── handoff/                      # Cross-machine task continuity (save/load)
│   ├── home-assistant-dev/           # HA integration dev toolkit + MCP server
│   ├── linux-sysadmin/               # Linux sysadmin skills (163 service, tool, and filesystem guides)
│   ├── nominal/                      # Infrastructure verification (preflight/postflight/abort)
│   ├── opus-context/                 # 1M context window optimizer for Opus 4.6
│   ├── plugin-test-harness/          # Iterative test/fix/reload loop (TypeScript)
│   ├── python-dev/                   # Python development skills (11 domain skills)
│   ├── qt-suite/                     # Qt development and testing toolkit
│   ├── release-pipeline/             # Autonomous release pipeline
│   ├── repo-hygiene/                 # Autonomous repo maintenance sweep
│   ├── test-driver/                  # Proactive testing via gap analysis and convergence
│   └── up-docs/                      # Three-layer documentation updater + drift analysis
├── scripts/validate-marketplace.sh   # Zod-schema marketplace validation
└── docs/                             # Plugin development documentation
```

## Plugin Structure

Every plugin requires `.claude-plugin/plugin.json`:
```json
{ "name": "plugin-name", "version": "1.0.0", "description": "...", "author": { "name": "...", "url": "..." } }
```

Optional components:
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
pytest plugins/home-assistant-dev/tests/scripts/ -m unit
pytest plugins/home-assistant-dev/tests/scripts/ -m integration

cd plugins/plugin-test-harness
npm ci && npm run build && npm test

./scripts/validate-marketplace.sh   # always run before merging to main
claude --plugin-dir ./plugins/plugin-name
```

CI runs the full matrix automatically on push to `testing` or `main`.

## Plugin Test Harness (PTH)

- PTH loads tests from previous sessions. ALWAYS clear/regenerate tests for the current target plugin before running.
- PTH does NOT auto-execute tests — you must manually call MCP tools and record results.
- When testing a plugin, confirm the target plugin name explicitly before generating tests to avoid stale/mismatched test data.

## Development Workflow

**New plugin checklist:**
1. Create `plugins/my-plugin/.claude-plugin/plugin.json` (name, version, description, author)
2. Add entry to `.claude-plugin/marketplace.json`
3. Add `CHANGELOG.md` (Keep a Changelog format: Added, Changed, Fixed, Removed, Security)
4. Create `README.md` from `docs/plugin-readme-template.md` — fill in all required sections; delete optional sections that don't apply
5. Run `./scripts/validate-marketplace.sh`
6. Commit to `testing`, push, merge to `main` when ready

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

## Release Pipeline

- Reconcile existing remote tags gracefully — compare local vs remote before pushing; never fail on pre-existing tags.
- Handle API 400 errors with retry logic; save progress so releases can be resumed.
- When releasing plugins: expect pre-existing tags or dirty state from prior sessions. Check remote tags before pushing; handle selective staging carefully when unrelated changes are present.
- When the user waives pre-flight failures (dirty tree, missing tests, email config), proceed without re-asking — these are intentional overrides.

## Key Architectural Patterns

### Context Footprint

| Component | Enters context? | When? |
|-----------|-----------------|-------|
| Command markdown | Yes | On `/command` invocation |
| Skill markdown | Conditionally | When AI deems relevant |
| Agent definitions | No (for parent) | Loaded by spawned agent |
| Hook scripts | No | Run externally; only stdout returns |
| Templates | No | Copied to disk, read independently |

Keep inline command/skill content minimal. Move large instruction sets to templates. Use hooks for enforcement rather than lengthy behavioral instructions.

### Enforcement Layers (strongest to weakest)

1. **Mechanical** — Hooks that deterministically block/warn regardless of AI behavior
2. **Structural** — Architectural constraints (e.g., git worktrees for file isolation)
3. **Behavioral** — Instructions in prompts (weakest; covers widest surface)

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

Prefer one hook per event type with a dispatcher script routing by file path. Reference: `plugins/github-repo-manager/hooks/hooks.json`

## Marketplace Schema

Validator uses Zod strict mode — unknown fields are rejected.

**`marketplace.json` root** — required: `name`, `owner` (object), `plugins` (array). Optional: `description`. **INVALID**: `version`, `homepage`, `repository`, `license`.

**Plugin entries** — required: `name`, `description`, `source`. Optional: `version`, `author` (object), `category`, `homepage`, `tags`, `strict`. **INVALID**: `displayName`, `keywords`, `license`.

**`plugin.json` manifests** — valid fields: `name`, `version`, `description`, `author`. Optional: `homepage`. **INVALID (rejected):** `category`, `keywords`, `repository`, `license`. Note: `validate-marketplace.sh` only validates `marketplace.json` entries — it does **not** catch invalid `plugin.json` fields, so violations are silent locally but rejected on install.

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
- **Marketplace cache is a git clone** — editing one file doesn't update the tree. Refresh: `cd ~/.claude/plugins/marketplaces/<name> && git fetch origin && git reset --hard origin/main`.
- **Stale `enabledPlugins` entries** — removing a marketplace leaves stale `"plugin@marketplace": true` in `~/.claude/settings.json`. Remove manually.
- **MCP plugins need `npm install`** — plugin install doesn't run it. Use `npx` in `.mcp.json` or pre-build.
- **`installed_plugins.json` is the load source of truth** — editing `settings.json` alone doesn't unload a plugin.
- **MCP server must be restarted after binary/cache updates** — ask which specific plugin(s) to target, kill the old process, verify the new process is running the updated binary before testing.

## Documentation Reference

- `docs/plugins.md` — Plugin development guide
- `docs/plugins-reference.md` — Complete manifest schema, CLI commands
- `docs/skills.md` — Skill YAML frontmatter, trigger patterns
- `docs/hooks.md` — All hook types, event schemas, debugging
- `docs/sub-agents.md` — Custom agent definitions, tool restrictions
- `docs/mcp.md` — MCP server integration
- `docs/plugin-marketplaces.md` — Creating and hosting marketplaces
- `docs/plugin-readme-template.md` — Canonical README template for all plugin directories

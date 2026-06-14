# Architecture

## From handoff.md

**up-docs 0.4.0 (new architecture):**

- Orchestrator (main agent) receives session-change summary and dispatches three Sonnet propagators in parallel: repo, wiki, notion.
- Each propagator runs in isolated context window with `model: sonnet` frontmatter override; reads pages, applies targeted edits, returns markdown summary.
- Drift auditor (Sonnet) receives session-change summary after propagators complete; checks for contradictions in propagator output; emits convergence loop phases.
- Parallel dispatch reduces wall time to `max(repo, wiki, notion)` + drift; sequential phases protect consistency.

**All plugins:** follow plugin-marketplace canonical structure (plugin.json, CHANGELOG.md, README.md from template, optional agents/hooks/skills). 7 plugins total in marketplace as of 2026-06-09 (uv-strict-python v0.1.0 added). Was 6 as of 2026-06-08 (github-repo-manager, plugin-test-harness, repo-hygiene de-listed as unused). Was 9 as of 2026-05-30 (was 12; opus-context, handoff, nominal removed). Prior cut 2026-05-08: 17 → 12 (claude-sync, design-assistant, docs-manager, linux-sysadmin, python-dev removed in commit 3b8323e).

## Handoff Gotchas

- **Branch workflow:** Direct commit to `main`. No `testing` branch — that convention was retired 2026-05-07. Local pre-commit hooks (noreply email, marketplace validation) provide the guardrails branch protection used to provide. For tagged plugin releases, use `/release-pipeline:release`.
- **Marketplace cache:** `~/.claude/plugins/marketplaces/l3digitalnet-plugins/` is a git clone. Editing source repo `.claude-plugin/marketplace.json` does NOT auto-update cache — manually `git fetch && git reset --hard origin/main` or re-add the marketplace.
- **Plugin removal requires three updates:** `settings.json` (enabledPlugins), `installed_plugins.json` (load source of truth), and plugin cache directory. Editing settings.json alone leaves the plugin loaded.
- **MCP server .mcp.json is flat format, not wrapped:** `{"server-name": {"command": "..."}}` not `{"mcpServers": {"server-name": ...}}`. Incorrect format causes "invalid mcp" errors.
- **TypeScript plugins must `npm run build`** before testing — plugin install does not run npm/pip automatically.
- **Release pipeline expects matching versions:** plugin.json version and marketplace.json version must match. Validation catches these mismatches.
- **Test frameworks standardized:** bash plugins use bats-core, Python plugins use pytest, TypeScript plugins use Jest. See `docs/handoff/conventions.md` TEST-001 for canonical layout and rationale. Bats on Fedora 44+ requires `tests/run-bats.sh` wrapper due to gnu env stripping bash function exports (TEST-002).

## Test Coverage Snapshot (2026-06-03)

Marketplace-wide tests use canonical frameworks and plugin-local suites. Keep counts in `docs/handoff/conventions.md` TEST-001 current when adding tests.

**Quick reference:**

- Strategic overview: `docs/handoff/conventions.md` TEST-001/TEST-002 (frameworks, naming, bats wrapper)
- Per-plugin execution: `plugins/<plugin>/tests/` plus session rows in `docs/handoff/sessions/`
- In scope: 7 plugins (uv-strict-python added 2026-06-09; github-repo-manager, plugin-test-harness, repo-hygiene de-listed 2026-06-08). Was 9 with qdev's research-KB scripts (qdev is no longer pure-markdown; its grounding-sanitizer was removed in qdev 2.0.0). Was 8 before qdev gained Python tests; was 11 before the 2026-05-30 cut (opus-context, handoff, nominal removed); was 15 before 2026-05-08 cleanup (claude-sync, design-assistant, docs-manager, linux-sysadmin removed from scope alongside their plugin dirs; python-dev, already excluded as pure-markdown, also deleted).
- Frameworks: bats (bash), pytest (Python), Jest (TypeScript)
- Enforcement mapping: every test tagged with layer it exercises (Mechanical strongest, Behavioral weakest)
- Branch workflow: direct commits to `main`.

---

## CLAUDE.md detail (pre-extracted 2026-04-24)

The "Plugin Design Principles" [P1]–[P6] are behavioral cross-cutting rules and are Phase 5 candidates for migration to `.claude/rules/global.md`. Deferred with the rest of this repo's Phase 5 for batch-dispatch reasons.

## Repository Purpose

Claude Code plugin marketplace and development workspace. `main` is the only branch — direct commits, no `testing` intermediate. Local pre-commit hooks (noreply email enforcement, marketplace validation) provide the guardrails that server-side branch protection used to provide.

## Plugin Design Principles

Evaluate every design decision against these.

**[P1] Act on Intent** — Invoking a command is consent to its implied scope. When intent is ambiguous, clarify before executing — not after. When intent is clear, execute without narration or confirmation of the obvious. Gate only on operations that are both truly irreversible and whose scope materially exceeds what the invocation implies — not merely large or dangerous-looking. If scope materially changes mid-execution, stop and re-confirm. Routine friction is a tax, not a safeguard.

**[P2] Scope Fidelity** — Execute the full scope asked — completely, without routine sub-task confirmation gates. When a sub-task's scope is genuinely ambiguous, clarify before proceeding rather than assuming. Surface only material out-of-scope findings as notes — routine adjacent observations are not worth raising. Scope undershoot triggers additional iteration; scope overshoot violates the consent established at invocation.

**[P3] Succeed Quietly, Fail Transparently** — Lead with findings — not intent, not preamble. Emit a compact factual summary at task completion — not after every step. Retry transient or infrastructure errors silently. On critical failures, stop immediately and surface the complete failure — raw output included — with a recovery plan; do not attempt autonomous workarounds.

**[P4] Use the Full Toolkit** — When interaction is required, prefer structured choices over open-ended prompts — bound the user's decision space before presenting it. Use Claude Code's interaction primitives: bounded choices (`AskUserQuestion`), markdown previews for side-by-side comparisons, multi-select for non-exclusive options.

**[P5] Convergence is the Contract** — Iterative work drives toward a measurable criterion — set by the plugin, the user, or collaboratively — without check-ins. Proceed quietly when converging normally; surface immediately if progress stalls or regresses unexpectedly. If the cycle begins oscillating — making and undoing the same changes repeatedly — flag the pattern and stop. Stop only when the criterion is met, oscillation is detected, or the user intervenes.

**[P6] Composable, Focused Units** — Each component does one thing and is independently useful. Complex workflows emerge from combining atomic units at runtime; orchestration is assembled from the outside, not baked in.

## Repository Structure

```text
Claude-Code-Plugins/
├── .claude-plugin/marketplace.json   # Marketplace catalog
├── .github/workflows/                # CI: codeql, format, ha-dev-plugin-tests, lint-markdown, plugin-test-harness-ci
├── plugins/
│   ├── home-assistant-dev/           # HA integration dev toolkit + MCP server
│   ├── qdev/                         # Deep web research (commands/research.md + qdev-researcher; research-KB scripts under scripts/)
│   ├── qt-suite/                     # Qt development and testing toolkit
│   ├── release-pipeline/             # Autonomous release pipeline
│   ├── test-driver/                  # Proactive testing via gap analysis and convergence
│   ├── up-docs/                      # Three-layer documentation updater + drift analysis
│   └── uv-strict-python/             # Python tooling standard (uv, Ruff, BasedPyright strict; added 2026-06-09)
├── scripts/validate-marketplace.sh   # Zod-schema marketplace validation
└── docs/                             # Plugin development documentation
```

## Plugin Structure

Every plugin requires `.claude-plugin/plugin.json`:

```json
{
	"name": "plugin-name",
	"version": "1.0.0",
	"description": "...",
	"author": { "name": "...", "url": "..." }
}
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

./scripts/validate-marketplace.sh   # always run before merging to main
claude --plugin-dir ./plugins/plugin-name
```

CI runs the full matrix automatically on push to `main`.

## Development Workflow

**New plugin checklist:**

1. Create `plugins/my-plugin/.claude-plugin/plugin.json` (name, version, description, author)
2. Add entry to `.claude-plugin/marketplace.json`
3. Add `CHANGELOG.md` (Keep a Changelog format: Added, Changed, Fixed, Removed, Security)
4. Create `README.md` from `docs/plugin-readme-template.md` — fill in all required sections; delete optional sections that don't apply
5. Run `./scripts/validate-marketplace.sh`
6. Commit + push directly to `main`. For tagged releases (with version bump + changelog + GitHub release), use `/release-pipeline:release`.

**Updating a plugin — both files must change together:**

1. Bump version in `plugins/<name>/.claude-plugin/plugin.json`
2. Update matching version in `.claude-plugin/marketplace.json`
3. Update `CHANGELOG.md`
4. Run `./scripts/validate-marketplace.sh`

**Commit + push to main:**

```bash
git add <specific files> && git commit -m "..." && git push origin main
```

For tagged plugin releases (with version bump + changelog + GitHub release), use `/release-pipeline:release`. See [BRANCH_PROTECTION.md](../../BRANCH_PROTECTION.md).

## Release Pipeline

- Reconcile existing remote tags gracefully — compare local vs remote before pushing; never fail on pre-existing tags.
- Handle API 400 errors with retry logic; save progress so releases can be resumed.
- When releasing plugins: expect pre-existing tags or dirty state from prior sessions. Check remote tags before pushing; handle selective staging carefully when unrelated changes are present.
- When the user waives pre-flight failures (dirty tree, missing tests, email config), proceed without re-asking — these are intentional overrides.

## Key Architectural Patterns

### Context Footprint

| Component         | Enters context? | When?                               |
| ----------------- | --------------- | ----------------------------------- |
| Command markdown  | Yes             | On `/command` invocation            |
| Skill markdown    | Conditionally   | When AI deems relevant              |
| Agent definitions | No (for parent) | Loaded by spawned agent             |
| Hook scripts      | No              | Run externally; only stdout returns |
| Templates         | No              | Copied to disk, read independently  |

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
		"PostToolUse": [
			{
				"matcher": "Write|Edit|MultiEdit",
				"hooks": [
					{ "type": "command", "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/hook.sh" }
				]
			}
		]
	}
}
```

Hook scripts receive tool context as JSON on stdin (`${CLAUDE_PLUGIN_ROOT}` is the only available variable):

```bash
FILE_PATH=$(python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('file_path',''))")
```

PreToolUse blocking (exit 2): `echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","decision":"block","reason":"..."}}'`

PostToolUse warnings: write to stdout — injected into agent context.

Prefer one hook per event type with a dispatcher script routing by file path. Reference: `plugins/home-assistant-dev/hooks/hooks.json`

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

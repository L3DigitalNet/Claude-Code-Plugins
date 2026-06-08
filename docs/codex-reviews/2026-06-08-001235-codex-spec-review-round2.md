### Executive summary

Claude Code’s corrections resolved most prior findings, especially the `.claude/` placement, version bump, retained `/qdev:research` cleanup, handoff-state cleanup, and commit-staging guards. Significant findings remain because the corrected search-tool section still hardcodes an unsupported Tavily MCP namespace and the new skill validation still points at a live, write-producing deploy command without an isolated-home or explicit-consent guard.

New internet research was limited to official Claude Code skills docs and Tavily Search API docs; the remaining blocker is primarily local installed-tool/schema evidence, not an external documentation gap.

### Verdict

Needs major specification correction before planning/implementation

### Audit loop status

- Audit type: Follow-up audit
- Spec path: /home/chris/projects/Claude-Code-Plugins/docs/superpowers/specs/2026-06-07-qdev-search-decoupling-design.md
- Prior audit issue count: 7
- Resolved issue count: 5
- Still open issue count: 0
- Partially resolved issue count: 2
- New issue count: 0
- Regression count: 0
- Significant findings remaining: Yes

### Adversarial review performed

Re-read the revised spec, current git state, repo handoff state, qdev manifests/docs/tests, agent-configs skill placement/deploy rules, and current MCP tool metadata. Retested prior SA-001..SA-007 fixes, attacked the new acceptance criteria for false positives and side effects, and checked whether the proposed search skill would be deployable and callable using the actual available tool schemas.

Could not run pytest or deploy validation in read-only audit mode because pytest may write caches and `deploy-skill.sh` writes to live skill roots unless isolated.

### Prior findings status

#### SA-001: Proposed `.agents` search skill violates agent-configs portability gates

- Previous severity: High
- Current status: Resolved
- Evidence: Revised spec lines 33-40 and 114-119 move the skill to `skills/.claude/skills/web-search/`, set `compatibility: Claude Code`, and remove `agents/openai.yaml`. This matches `agent-configs/skills/README.md:56-67` and `:80-85`.
- Remaining action for Claude Code: None for placement; keep the skill Claude-only unless it stops naming MCP tools.

#### SA-002: Marketplace version bump is omitted

- Previous severity: High
- Current status: Resolved
- Evidence: Revised spec lines 42-43 and 86-90 explicitly bump both `plugins/qdev/.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` to `2.0.0`. `scripts/validate-marketplace.sh:198-206` enforces this equality.
- Remaining action for Claude Code: None; implement exactly both version edits.

#### SA-003: Kept `/qdev:research` still references removed qdev commands

- Previous severity: High
- Current status: Resolved
- Evidence: Revised spec lines 79-85 explicitly remove the `/qdev:quality-review` chaining references from both `plugins/qdev/commands/research.md` and `plugins/qdev/agents/qdev-researcher.md`, while preserving research behavior.
- Remaining action for Claude Code: Apply those text-only edits and run the no-dangling-reference check after implementation.

#### SA-004: Two-repo commit instruction lacks dirty-worktree protection

- Previous severity: High
- Current status: Resolved
- Evidence: Revised spec lines 155-170 require status checks, explicit-path staging, cached diff review, and stopping if unrelated files cannot be isolated. Current evidence differs from the spec’s static inventory: `Claude-Code-Plugins` currently has `M TODO.md` and one untracked codex review file; `agent-configs` currently appears clean.
- Remaining action for Claude Code: Keep the dynamic guards; update or remove the stale static dirty-file examples before planning if desired.

#### SA-005: Handoff state active incident is omitted from current-truth updates

- Previous severity: Medium
- Current status: Resolved
- Evidence: Revised spec lines 98-102 add `docs/handoff/state.md` and scope it to closing/superseding the active qdev D2 grounding incident currently present at `docs/handoff/state.md:13`.
- Remaining action for Claude Code: None beyond implementing that scoped handoff edit.

#### SA-006: Tavily news/finance routing conflicts with installed MCP schema

- Previous severity: High
- Current status: Partially resolved
- Evidence: Revised spec lines 127-129 correctly stop prescribing Tavily `topic=news|finance` and require live schema re-verification. However, lines 122-126 hardcode `mcp__tavily__tavily_*`, while repo evidence says that exact prefix was previously wrong: `plugins/qdev/CHANGELOG.md:53` records `mcp__tavily__tavily_*` → `mcp__tavily-mcp__tavily_*` because the wrong server key meant Tavily tools were not granted. Current qdev files use `mcp__tavily-mcp__...`; current Codex tool metadata exposes `mcp__tavily_mcp`, `mcp__brave_search`, and `mcp__serper_search`.
- Remaining action for Claude Code: Replace the hardcoded Tavily namespace with the verified Claude Code server key, likely `mcp__tavily-mcp__...` based on current qdev evidence, or make the spec require live Claude metadata inspection before writing any concrete tool names.

#### SA-007: New skill acceptance criteria do not prove deployability or invocation behavior

- Previous severity: Medium
- Current status: Partially resolved
- Evidence: Revised spec lines 114-119 and 143-146 now specify `SKILL.md` frontmatter and the README inventory row. Remaining problem: line 184 uses `bash agent-configs/scripts/skills/deploy-skill.sh` as validation. That script writes to `$HOME/.claude/skills`, `$HOME/.codex/skills`, and `$HOME/.agents/skills`; its own tests show equal-version reruns intentionally refresh installed copies and wipe local installed edits.
- Remaining action for Claude Code: Change validation to use an isolated temp `HOME` or the existing bats suite. Require explicit user approval before live deployment to real skill roots.

### New blocking issues

None found.

### New non-blocking issues

None found.

### Regressions

None found. The Tavily namespace problem is captured as SA-006 partially resolved, not a separate regression.

### Remaining ambiguities and decisions needed

- Ambiguity: Which concrete Claude Code MCP namespace should `web-search` name for Tavily?
- Why it matters: `mcp__tavily__...` is contradicted by qdev’s own corrected current files and changelog.
- Recommended clarification: Require live Claude Code tool metadata verification, then use the verified namespace.
- Blocking or non-blocking: Blocking.

- Ambiguity: Is live deployment to `~/.claude/skills/web-search/` in scope, or is this repo-only implementation plus isolated validation?
- Why it matters: `deploy-skill.sh` mutates live harness skill roots.
- Recommended clarification: Make live deploy an explicit, user-approved post-implementation step; use temp-`HOME` validation otherwise.
- Blocking or non-blocking: Non-blocking.

- Ambiguity: The no-dangling-ref grep includes “current handoff docs” but `docs/handoff/specs-plans.md` is partly a pointer table to historical dated specs/plans.
- Why it matters: A too-broad grep could force removal of useful historical context instead of only stale current-surface references.
- Recommended clarification: Define exact paths and allow explicitly historical/superseded pointer rows where appropriate.
- Blocking or non-blocking: Non-blocking.

### Internet research performed

- Source name: Claude Code skills documentation
- URL: https://docs.claude.com/en/docs/claude-code/skills
- Access date: 2026-06-08
- What it was used to verify: Claude Code skill shape and install expectations.
- Relevant conclusion: Supports SKILL.md-based Claude Code skills under Claude skill roots; does not resolve local MCP server namespace names.

- Source name: Tavily Search API documentation
- URL: https://docs.tavily.com/documentation/api-reference/endpoint/search
- Access date: 2026-06-08
- What it was used to verify: Tavily `topic` API behavior.
- Relevant conclusion: Official API supports more topics than the installed MCP metadata exposed here; local MCP schema remains authoritative for this skill.

### Read-only validation performed

- `pwd`, `git status --short`, `git branch --show-current`, `git log --oneline -n 10`: confirmed repo root, branch `main`, latest spec-revision commit, and current unrelated dirty state.
- Read `docs/handoff/state.md`, `AGENTS.md`, `docs/handoff/conventions.md`, and handoff-system-v3 skill summary: confirmed startup context and active qdev D2 incident.
- Read the revised spec with line numbers: inventoried corrected requirements and acceptance criteria.
- Inspected qdev command/agent/test/manifests/docs surfaces: confirmed prior stale references and version surfaces the spec targets.
- Inspected `scripts/validate-marketplace.sh`: confirmed marketplace/manifest version equality check.
- Inspected `agent-configs/skills/README.md`, `populate-config`, `deploy-skill.sh`, and `deploy.bats`: confirmed `.claude` placement, deploy routing, and live deploy side effects.
- Ran `tool_search` for Tavily/Brave/Serper metadata: confirmed current Codex-exposed namespaces and Tavily `topic: "general"` schema.
- Searched current qdev and agent-configs skill files for MCP tool prefixes: confirmed `mcp__tavily__...` is documented as a previously broken prefix.

### Recommended planning/implementation validation

- Run before edits and commits: `git status --short` in both repos.
- Run before commits: `git diff --name-only --cached` in both repos; only intended files may be staged.
- Run only after implementation: `cd plugins/qdev && python -m pytest`
- Run after implementation: `bash scripts/validate-marketplace.sh`
- Run after implementation: targeted `rg` for removed qdev command/skill/script references over non-historical current surfaces.
- Run only after implementation in `agent-configs`: `HOME="$(mktemp -d)" bash scripts/skills/deploy-skill.sh` from the agent-configs repo root to verify routing without touching live skill roots.
- Run only after implementation in `agent-configs`: `bash scripts/tests/run.sh`
- Run live `bash scripts/skills/deploy-skill.sh` only if the user explicitly approves installing/updating live skills.

### Final recommendation

Claude Code should revise the specification using the findings above

### Review ledger for next loop

- Spec path: /home/chris/projects/Claude-Code-Plugins/docs/superpowers/specs/2026-06-07-qdev-search-decoupling-design.md
- Audit round: 2
- Open issue IDs: SA-006, SA-007
- Resolved issue IDs: SA-001, SA-002, SA-003, SA-004, SA-005
- Superseded issue IDs:
- Significant findings remaining: Yes
- Next audit should focus on: corrected concrete MCP namespaces for the Claude-only web-search skill, isolated-vs-live skill deployment validation, and exact dangling-reference search scope.

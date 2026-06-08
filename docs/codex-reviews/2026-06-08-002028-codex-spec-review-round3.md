### Executive summary

Claude Code’s round-3 corrections resolved the Tavily namespace and isolated deployment validation issues from round 2. One significant regression remains: the Problem section still says the new routine-search skill lives under `skills/.agents/skills/`, contradicting the corrected locked decision and Part B requirement to place it under `skills/.claude/skills/web-search/`.

New internet research was used to re-check Claude Code skill loading/permission semantics and Tavily topic behavior.

### Verdict

Needs major specification correction before planning/implementation

### Audit loop status

- Audit type: Follow-up audit
- Spec path: /home/chris/projects/Claude-Code-Plugins/docs/superpowers/specs/2026-06-07-qdev-search-decoupling-design.md
- Prior audit issue count: 7
- Resolved issue count: 6
- Still open issue count: 0
- Partially resolved issue count: 1
- New issue count: 0
- Regression count: 1
- Significant findings remaining: Yes

### Adversarial review performed

Re-read the revised spec, repo startup docs, qdev manifests/commands/agents/tests/docs, agent-configs skill placement/deploy docs, deploy script/tests, current git state in both repos, local Claude MCP/search-tool evidence, current Codex tool metadata, and official Claude/Tavily docs.

Retested prior SA-001..SA-007. Could not run pytest or deployment commands in read-only audit mode because they may write caches or skill installs. Could not obtain a fully healthy live Claude MCP schema noninteractively; `claude mcp list` reported server names but failed connection checks in this restricted audit.

### Prior findings status

#### SA-001: Proposed `.agents` search skill violates agent-configs portability gates

- Previous severity: High
- Current status: Partially resolved
- Evidence: Spec lines 33-40 and 114-119 correctly require `skills/.claude/skills/web-search/`, `compatibility: Claude Code`, and `SKILL.md` only. But lines 21-23 still state the routine-search skill lives at `skills/.agents/skills/`. That contradicts agent-configs Gate 2: `skills/README.md` says shared `.agents/` skills may not call MCP tools, while the spec explicitly names MCP tools at lines 34 and 120-153.
- Remaining action for Claude Code: Replace the stale Problem-section `.agents` path with the locked `.claude/skills/web-search/` placement and ensure no remaining prose suggests shared `.agents` placement.

#### SA-002: Marketplace version bump is omitted

- Previous severity: High
- Current status: Resolved
- Evidence: Spec lines 42-43 and 86-90 require bumping both qdev manifest and marketplace entry to `2.0.0`; `scripts/validate-marketplace.sh` enforces equality at lines 198-206.
- Remaining action for Claude Code: None.

#### SA-003: Kept `/qdev:research` still references removed qdev commands

- Previous severity: High
- Current status: Resolved
- Evidence: Spec lines 79-85 remove `/qdev:quality-review` chaining text from `research.md` and `qdev-researcher.md`. Lines 186-193 now scope dangling-reference checks to live qdev surfaces while preserving historical docs.
- Remaining action for Claude Code: None.

#### SA-004: Two-repo commit instruction lacks dirty-worktree protection

- Previous severity: High
- Current status: Resolved
- Evidence: Spec lines 162-176 require live status checks, explicit-path staging, cached diff review, and stop-on-unisolatable-unrelated-changes. Current repo evidence confirms this matters: `Claude-Code-Plugins` has unrelated `TODO.md` plus review artifacts, and `agent-configs` has unrelated deleted skill/template files.
- Remaining action for Claude Code: None.

#### SA-005: Handoff state active incident is omitted from current-truth updates

- Previous severity: Medium
- Current status: Resolved
- Evidence: Spec lines 98-104 explicitly include `docs/handoff/state.md` and limit the edit to closing/superseding the active qdev D2 grounding incident while preserving historical sessions/specs/plans.
- Remaining action for Claude Code: None.

#### SA-006: Tavily news/finance routing conflicts with installed MCP schema

- Previous severity: High
- Current status: Resolved
- Evidence: Spec lines 120-136 now make live Claude Code MCP schema authoritative, list the current Claude-style tool prefixes, preserve the `topic: general` constraint, and require re-running ToolSearch at implementation time. Local Claude settings allow `mcp__tavily__*`, `mcp__brave-search__*`, and `mcp__serper-search__*`; `claude mcp list` reported servers named `tavily`, `brave-search`, and `serper-search`. Current Codex ToolSearch still exposes underscore namespaces, which the spec correctly treats as non-authoritative for a Claude-only skill.
- Remaining action for Claude Code: Re-run live Claude Code schema verification at implementation time as the spec says.

#### SA-007: New skill acceptance criteria do not prove deployability or invocation behavior

- Previous severity: Medium
- Current status: Resolved
- Evidence: Spec lines 194-201 now forbid live deploy without explicit consent, require isolated `HOME="$(mktemp -d)" bash scripts/skills/deploy-skill.sh`, confirm copy placement at `$HOME/.claude/skills/web-search/`, run deploy tests, and compare shape/frontmatter. This matches `deploy-skill.sh` routing and the isolated-home contract in `deploy.bats`.
- Remaining action for Claude Code: None for deploy safety; add a post-approved live invocation smoke only if live install is later approved.

### New blocking issues

None found.

### New non-blocking issues

None found.

### Regressions

SA-001 regressed: although the locked decision and Part B now specify `.claude/`, the Problem section still says `skills/.agents/skills/`. This can mislead planning into the exact portability violation the prior audit marked resolved.

### Remaining ambiguities and decisions needed

- Ambiguity: Should the routine-search skill live under `.agents/skills/` or `.claude/skills/`?
- Why it matters: The spec currently says both; `.agents/` is invalid for a skill that names MCP tools under agent-configs Gate 2.
- Recommended clarification: Make `.claude/skills/web-search/` the only placement throughout the spec.
- Blocking or non-blocking: Blocking.

### Internet research performed

- Source name: Claude Code skills documentation
- URL: <https://docs.claude.com/en/docs/claude-code/skills>
- Access date: 2026-06-08
- What it was used to verify: Skill layout, `SKILL.md`, direct/model invocation, and `allowed-tools` behavior.
- Relevant conclusion: Claude Code skills load from `~/.claude/skills/<name>/SKILL.md` or project `.claude/skills/<name>/SKILL.md`; description drives automatic use, and `allowed-tools` grants permission but does not restrict all other tools.

- Source name: Claude Code tools reference
- URL: <https://code.claude.com/docs/en/tools-reference>
- Access date: 2026-06-08
- What it was used to verify: Tool-name authority and MCP custom-tool relationship.
- Relevant conclusion: Tool names are exact strings used in permissions/subagent tool lists; environment-specific MCP metadata remains the right authority.

- Source name: Tavily Search API documentation
- URL: <https://docs.tavily.com/documentation/api-reference/endpoint/search>
- Access date: 2026-06-08
- What it was used to verify: External Tavily `topic` options.
- Relevant conclusion: Official API supports `general`, `news`, and `finance`, but the installed local MCP schema may be narrower; the spec is correct to defer to installed schema.

### Read-only validation performed

- `pwd`, `git status --short`, `git branch --show-current`, `git log --oneline -n 10`: confirmed repo root, branch `main`, round-3 spec commit, and current unrelated dirty state.
- Read `docs/handoff/state.md`, `AGENTS.md`, `docs/handoff/conventions.md`, and the revised spec with line numbers.
- Inspected qdev commands, agents, README, CHANGELOG, manifests, tests, root README, and handoff docs for targeted deletions, stale references, version surfaces, and MCP prefixes.
- Inspected `scripts/validate-marketplace.sh`: confirmed marketplace/manifest version equality check.
- Inspected `agent-configs` status, `skills/README.md`, `deploy-skill.sh`, `deploy.bats`, and `populate-config` skill shape.
- Ran `tool_search` for Tavily/Brave/Serper: confirmed current Codex-exposed namespaces and Tavily `topic: general` schema, non-authoritative for Claude-only naming.
- Queried local Claude settings for allowed MCP prefixes and ran `claude mcp list`; server names matched the spec, but connection checks failed and credential-bearing output is intentionally not reproduced.
- Consulted official Claude Code and Tavily documentation.

### Recommended planning/implementation validation

- Before edits and commits: `git status --short` in both repos.
- Before commits: `git diff --name-only --cached` in both repos; only intended paths may be staged.
- Run only after implementation: `cd plugins/qdev && python -m pytest`.
- Run after implementation: `bash scripts/validate-marketplace.sh`.
- Run after implementation: targeted `rg` for removed qdev command/skill/script references over live current surfaces, excluding historical docs and CHANGELOG.
- Run only after implementation in `agent-configs`: `HOME="$(mktemp -d)" bash scripts/skills/deploy-skill.sh` from the agent-configs root.
- Run only after implementation in `agent-configs`: `bash scripts/tests/run.sh`.
- Re-run live Claude Code MCP schema verification before writing concrete tool names; do not paste raw credential-bearing MCP output into docs or review artifacts.
- Run live deploy/invocation smoke only after explicit user approval for updating real `~/.claude/skills`.

### Final recommendation

Claude Code should revise the specification using the findings above

### Review ledger for next loop

- Spec path: /home/chris/projects/Claude-Code-Plugins/docs/superpowers/specs/2026-06-07-qdev-search-decoupling-design.md
- Audit round: 3
- Open issue IDs: SA-001
- Resolved issue IDs: SA-002, SA-003, SA-004, SA-005, SA-006, SA-007
- Superseded issue IDs:
- Significant findings remaining: Yes
- Next audit should focus on: removing the stale `.agents/skills/` placement from the Problem section and confirming the spec consistently names `.claude/skills/web-search/` as the only routine-search skill location.

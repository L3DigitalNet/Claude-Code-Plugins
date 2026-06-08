### Executive summary

Claude Code’s round-5 correction substantively resolves the remaining SA-004 issue. The specification now names the observed same-file dirty-worktree hazard in `agent-configs/skills/README.md`, requires pre-edit target diff review, forbids whole-file staging for already-dirty target files, requires non-interactive hunk isolation, requires content review of staged hunks, and stops if the spec change cannot be separated from unrelated user work.

No significant findings remain. New internet research was performed only to refresh the still-relevant external assumptions around Claude Code skill placement, MCP tool naming/tool search, and Tavily topic behavior; it did not contradict the corrected spec.

### Verdict

No significant findings remain

### Audit loop status

* Audit type: Follow-up audit
* Spec path: /home/chris/projects/Claude-Code-Plugins/docs/superpowers/specs/2026-06-07-qdev-search-decoupling-design.md
* Prior audit issue count: 7
* Resolved issue count: 7
* Still open issue count: 0
* Partially resolved issue count: 0
* New issue count: 0
* Regression count: 0
* Significant findings remaining: No

### Adversarial review performed

Re-read the current spec and retested all prior findings against repository evidence, `agent-configs` evidence, current git state, qdev command/agent/skill/test surfaces, qdev manifests, marketplace validation, handoff docs, deploy-skill routing, isolated deploy tests, local Claude MCP permission prefixes, Codex ToolSearch-exposed schemas, and official Claude/Tavily documentation.

The strongest re-test was SA-004: current `agent-configs/skills/README.md` remains dirty with unrelated same-file hunks, so I attacked whether the revised commit-safety text could still pass while committing foreign hunks. The new same-file guard now blocks that failure mode if followed.

I did not run pytest, deploy scripts, live Claude deploys, or `claude mcp list`; tests/deploys may write artifacts or live skill roots, and `claude mcp list` previously emitted credential-bearing MCP URL data.

### Prior findings status

#### SA-001: Proposed `.agents` search skill violates agent-configs portability gates

* Previous severity: High
* Current status: Resolved
* Evidence: Spec lines 21-25 and 35-42 consistently place the new skill at `skills/.claude/skills/web-search/`, mark it Claude Code-only, and explicitly supersede the original `.agents/` idea. `agent-configs/skills/README.md` lines 63-67 still define Gate 2 as forbidding MCP tools in shared `.agents/` skills, while lines 100-106 show the `.claude/skills/` inventory where MCP-coupled skills belong.
* Remaining action for Claude Code: None.

#### SA-002: Marketplace version bump is omitted

* Previous severity: High
* Current status: Resolved
* Evidence: Spec lines 44-45 and 88-92 require bumping qdev from `1.6.0` to `2.0.0` in both `plugins/qdev/.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`. `scripts/validate-marketplace.sh` lines 198-206 enforce marketplace/manifest version equality.
* Remaining action for Claude Code: None.

#### SA-003: Kept `/qdev:research` still references removed qdev commands

* Previous severity: High
* Current status: Resolved
* Evidence: Spec lines 81-87 require removing `/qdev:quality-review` chaining from both `plugins/qdev/commands/research.md` and `plugins/qdev/agents/qdev-researcher.md`. Lines 204-211 add a dangling-reference check over current live qdev surfaces while preserving historical docs by hand.
* Remaining action for Claude Code: None.

#### SA-004: Two-repo commit instruction lacks dirty-worktree protection

* Previous severity: High
* Current status: Resolved
* Evidence: Spec lines 164-194 now add an explicit same-file dirty guard. It calls out the observed `agent-configs/skills/README.md` hazard, requires `git diff -- <target>` before editing already-modified target files, requires classifying existing hunks, requires non-interactive hunk isolation such as a constructed cached patch, forbids whole-file `git add`, requires `git diff --cached -- <target>` content review, and requires stopping if isolation fails. Current `agent-configs` still has ` M skills/README.md`, and `git diff -- skills/README.md` confirms unrelated table reformatting and row removals; the revised spec now directly addresses that case.
* Remaining action for Claude Code: None, beyond following the guard during implementation.

#### SA-005: Handoff state active incident is omitted from current-truth updates

* Previous severity: Medium
* Current status: Resolved
* Evidence: Spec lines 100-106 include `docs/handoff/state.md` and scope the edit to closing/superseding the active qdev D2 grounding incident while preserving historical sessions/specs/plans. Current `docs/handoff/state.md` line 13 still contains that active incident, so the target is real.
* Remaining action for Claude Code: None.

#### SA-006: Tavily news/finance routing conflicts with installed MCP schema

* Previous severity: High
* Current status: Resolved
* Evidence: Spec lines 122-138 make the live Claude Code MCP schema authoritative, preserve the locally allowed Claude prefixes `mcp__tavily__*`, `mcp__brave-search__*`, and `mcp__serper-search__*`, and require re-verification at implementation time. Codex ToolSearch currently exposes `mcp__tavily_mcp` with `topic?: "general"`, which remains non-authoritative for a Claude-only skill but supports the spec’s warning not to rely on stale global routing assumptions.
* Remaining action for Claude Code: Re-run live Claude Code schema verification at implementation time without pasting credential-bearing output.

#### SA-007: New skill acceptance criteria do not prove deployability or invocation behavior

* Previous severity: Medium
* Current status: Resolved
* Evidence: Spec lines 212-219 require isolated-HOME deploy validation, confirmation that `web-search` lands at `$HOME/.claude/skills/web-search/`, deploy test execution, frontmatter/shape comparison with `populate-config`, and no live deploy without explicit user approval. `agent-configs/scripts/skills/deploy-skill.sh` lines 335-338 route Claude-only skills to `$HOME/.claude/skills`, and `scripts/tests/deploy.bats` lines 6-11 establish the isolated-HOME testing contract.
* Remaining action for Claude Code: None for repo implementation; live install/invocation smoke remains a separately approved post-implementation step.

### New blocking issues

None found.

### New non-blocking issues

None found.

### Regressions

None found.

### Remaining ambiguities and decisions needed

None found.

### Internet research performed

* Source name: Claude Code skills documentation
* URL: https://code.claude.com/docs/en/skills
* Access date: 2026-06-08
* What it was used to verify: Skill placement, `SKILL.md` entrypoint, automatic invocation, and `allowed-tools` behavior.
* Relevant conclusion: `~/.claude/skills/<skill-name>/SKILL.md` is a valid personal skill location; `description` drives automatic loading; `allowed-tools` pre-approves tools while active but does not restrict all other tools.

* Source name: Claude Code MCP documentation
* URL: https://code.claude.com/docs/en/agent-sdk/mcp
* Access date: 2026-06-08
* What it was used to verify: MCP tool naming and tool-search behavior.
* Relevant conclusion: MCP tools follow `mcp__<server-name>__<tool-name>` naming, and tool search can defer tool definitions until needed. This supports the spec’s requirement to re-check live Claude Code server names before writing concrete tool names.

* Source name: Tavily Search API documentation
* URL: https://docs.tavily.com/documentation/api-reference/endpoint/search
* Access date: 2026-06-08
* What it was used to verify: Tavily upstream `topic` options.
* Relevant conclusion: Upstream Tavily supports `general`, `news`, and `finance`, but the installed MCP schema exposed here remains narrower. The spec is correct to defer to the installed schema.

### Read-only validation performed

* `git status --short`, `git branch --show-current`, `git log --oneline -n 10`, `git show --stat --oneline -1`, and `git show -- docs/superpowers/specs/2026-06-07-qdev-search-decoupling-design.md` in `Claude-Code-Plugins`: confirmed branch `main`, latest round-5 SA-004 commit, and current unrelated dirty `TODO.md` plus codex review artifacts.
* Read the revised spec with line numbers: confirmed the new same-file dirty guard at lines 179-194.
* Read `docs/handoff/state.md`, `AGENTS.md`, `CLAUDE.md`, `BRANCH_PROTECTION.md`, and `docs/handoff/conventions.md`: confirmed startup rules, direct-commit workflow, active qdev grounding incident, and plugin/test conventions.
* Inspected qdev commands, agents, skills, tests, manifest, marketplace, README, CHANGELOG, root README, and handoff docs with `rg`, `find`, and numbered reads: confirmed the referenced current surfaces and stale references targeted by the spec.
* Inspected `scripts/validate-marketplace.sh`: confirmed qdev marketplace/manifest version equality enforcement.
* In `agent-configs`, ran `git status --short`, `git branch --show-current`, `git log --oneline -n 5`, `git diff -- skills/README.md`, and `git diff --cached --stat`: confirmed `skills/README.md` is still dirty with unrelated same-file hunks and no staged changes.
* Read `agent-configs/skills/README.md`, `skills/.claude/skills/populate-config/SKILL.md`, `scripts/skills/deploy-skill.sh`, `scripts/tests/deploy.bats`, and `scripts/tests/run.sh`: confirmed Gate 2, Claude-only skill inventory, deploy routing, and isolated deploy test behavior.
* Queried local Claude settings for MCP permission prefixes only: confirmed `mcp__tavily__*`, `mcp__brave-search__*`, and `mcp__serper-search__*` without printing secrets.
* Ran ToolSearch for Tavily/Brave/Serper: confirmed current Codex-exposed search tool names and Tavily `topic` narrowed to `general`; treated as non-authoritative for Claude-only naming.
* Consulted official Claude Code and Tavily documentation.

### Recommended planning/implementation validation

* Before edits in both repos: `git status --short`.
* Before editing any already-dirty target file: `git diff -- <target-file>` and, if staged changes exist, `git diff --cached -- <target-file>`.
* For already-dirty target files: isolate only spec hunks with a non-interactive mechanism; do not use whole-file `git add <target>`.
* Before commits in both repos: run `git diff --cached` and `git diff --name-only --cached`; content and names must show only intended spec-owned changes.
* Run only after implementation: `cd plugins/qdev && python -m pytest`.
* Run after implementation: `bash scripts/validate-marketplace.sh`.
* Run after implementation: targeted `grep`/`rg` for removed qdev command/skill/script references over live current surfaces, excluding historical docs and CHANGELOG.
* Run only after implementation in `agent-configs`: `HOME="$(mktemp -d)" bash scripts/skills/deploy-skill.sh`.
* Run only after implementation in `agent-configs`: `bash scripts/tests/run.sh`.
* Re-run live Claude Code MCP schema verification before writing concrete tool names; do not paste raw credential-bearing MCP output into docs or review artifacts.
* Run live deploy/invocation smoke only after explicit user approval for updating real `~/.claude/skills`.

### Final recommendation

No significant findings remain; the audit/fix loop can stop

### Review ledger for next loop

* Spec path: /home/chris/projects/Claude-Code-Plugins/docs/superpowers/specs/2026-06-07-qdev-search-decoupling-design.md
* Audit round: 5
* Open issue IDs: None
* Resolved issue IDs: SA-001, SA-002, SA-003, SA-004, SA-005, SA-006, SA-007
* Superseded issue IDs:
* Significant findings remaining: No
* Next audit should focus on: No significant findings remain; stop unless the spec changes.


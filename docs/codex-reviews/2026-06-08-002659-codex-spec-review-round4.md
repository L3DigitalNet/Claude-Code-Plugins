### Executive summary

Claude Code’s round-4 correction resolves the prior SA-001 placement regression: the specification now consistently makes `skills/.claude/skills/web-search/` the active routine-search location and treats the earlier `.agents/` idea as superseded.

One significant finding remains after rechecking current repository evidence. SA-004 is only partially resolved because the current `agent-configs` worktree has pre-existing changes in `skills/README.md`, which is also a spec-owned target file. The spec’s current commit guard can still pass while sweeping unrelated same-file hunks into the agent-configs commit.

New internet research was used to re-check Claude Code skill loading/tool permission semantics and Tavily topic behavior.

### Verdict

Needs major specification correction before planning/implementation

### Audit loop status

* Audit type: Follow-up audit
* Spec path: /home/chris/projects/Claude-Code-Plugins/docs/superpowers/specs/2026-06-07-qdev-search-decoupling-design.md
* Prior audit issue count: 7
* Resolved issue count: 6
* Still open issue count: 0
* Partially resolved issue count: 1
* New issue count: 0
* Regression count: 0
* Significant findings remaining: Yes

### Adversarial review performed

Re-read the revised spec, repo startup docs, qdev command/agent/skill/test surfaces, qdev manifests, marketplace validator, root and qdev documentation targets, handoff docs, current git state in both repos, `agent-configs` skill placement/deploy docs, deploy script/tests, local Claude MCP permission evidence, current Codex ToolSearch metadata, and official Claude/Tavily docs.

Retested prior SA-001 through SA-007, attacked the acceptance criteria for false positives, and rechecked blast radius around two-repo commits, live skill deployment, stale qdev references, MCP namespace drift, and credential-bearing command output. I did not run pytest or deploy commands because this audit is read-only and those checks can write caches, installed skills, or test artifacts. Live `claude mcp list` still failed health checks noninteractively; it confirmed server names but emitted credential-bearing MCP URL data that is intentionally not reproduced.

### Prior findings status

#### SA-001: Proposed `.agents` search skill violates agent-configs portability gates

* Previous severity: High
* Current status: Resolved
* Evidence: Spec lines 21-25 now place routine search at `skills/.claude/skills/web-search/` and explicitly say the original `.agents/` idea is superseded. Lines 35-42, 116-121, and 152-155 consistently require Claude Code-only placement, `compatibility: Claude Code`, `SKILL.md` only, and no `.agents/skills/` inventory row. `agent-configs/skills/README.md` still confirms Gate 2 forbids MCP-tool references in shared `.agents/` skills.
* Remaining action for Claude Code: None.

#### SA-002: Marketplace version bump is omitted

* Previous severity: High
* Current status: Resolved
* Evidence: Spec lines 44-45 and 88-92 require bumping both qdev manifest and marketplace entry to `2.0.0`; `scripts/validate-marketplace.sh` checks marketplace/manifest version equality at lines 198-206.
* Remaining action for Claude Code: None.

#### SA-003: Kept `/qdev:research` still references removed qdev commands

* Previous severity: High
* Current status: Resolved
* Evidence: Spec lines 81-87 require removing `/qdev:quality-review` chaining text from both `plugins/qdev/commands/research.md` and `plugins/qdev/agents/qdev-researcher.md`; lines 188-195 scope dangling-reference checks to live current qdev surfaces while leaving historical docs intact.
* Remaining action for Claude Code: None.

#### SA-004: Two-repo commit instruction lacks dirty-worktree protection

* Previous severity: High
* Current status: Partially resolved
* Evidence: Spec lines 164-178 add live status checks, explicit-path staging, cached name checks, and stop-on-unisolatable-unrelated-changes. Current `agent-configs` evidence exposes a remaining hole: `git status --short` shows `M skills/README.md`, and Part B line 152 requires editing that same file. `git diff -- skills/README.md` shows pre-existing table reformatting plus removals of existing rows unrelated to adding `web-search`. A whole-file `git add skills/README.md` followed by `git diff --name-only --cached` would still pass while staging unrelated same-file hunks.
* Remaining action for Claude Code: Add a same-file dirty guard: inspect `git diff -- <target>` before editing already-dirty target files, preserve existing hunks, use hunk-level staging or equivalent patch isolation, require `git diff --cached` content review, and stop if spec hunks cannot be isolated.

#### SA-005: Handoff state active incident is omitted from current-truth updates

* Previous severity: Medium
* Current status: Resolved
* Evidence: Spec lines 100-106 explicitly include `docs/handoff/state.md` and scope the edit to closing/superseding the active qdev D2 grounding incident while preserving historical sessions/specs/plans.
* Remaining action for Claude Code: None.

#### SA-006: Tavily news/finance routing conflicts with installed MCP schema

* Previous severity: High
* Current status: Resolved
* Evidence: Spec lines 122-138 make live Claude Code MCP schema authoritative, list the current Claude-style prefixes, preserve `topic: general`, and require re-running schema verification at implementation time. Local Claude settings allow `mcp__tavily__*`, `mcp__brave-search__*`, and `mcp__serper-search__*`; `claude mcp list` reported servers named `tavily`, `brave-search`, and `serper-search`, though health checks failed. Current Codex ToolSearch exposes underscore namespaces, which the spec correctly treats as non-authoritative for a Claude-only skill.
* Remaining action for Claude Code: Re-run live Claude Code schema verification at implementation time, as the spec says, without pasting credential-bearing output.

#### SA-007: New skill acceptance criteria do not prove deployability or invocation behavior

* Previous severity: Medium
* Current status: Resolved
* Evidence: Spec lines 196-203 forbid live deploy without explicit consent, require isolated `HOME="$(mktemp -d)" bash scripts/skills/deploy-skill.sh`, confirm copy placement at `$HOME/.claude/skills/web-search/`, run deploy tests, and compare shape/frontmatter with `populate-config`. This matches `deploy-skill.sh` routing and `scripts/tests/deploy.bats` isolated-HOME contract.
* Remaining action for Claude Code: None for repo implementation; live install/invocation smoke remains a separately approved post-implementation step.

### New blocking issues

None found.

### New non-blocking issues

None found.

### Regressions

None found.

### Remaining ambiguities and decisions needed

* Ambiguity: How should implementation isolate pre-existing unrelated hunks in `agent-configs/skills/README.md`, which is already dirty and is also a required target file?
* Why it matters: The current spec’s path-level staging and name-only cached diff checks can commit unrelated same-file user work.
* Recommended clarification: Require pre-edit `git diff -- <target>` review for dirty target files, hunk-level staging or equivalent isolation, full `git diff --cached` review, and a stop condition if isolation is not possible.
* Blocking or non-blocking: Blocking.

### Internet research performed

* Source name: Claude Code skills documentation
* URL: https://code.claude.com/docs/en/skills
* Access date: 2026-06-08
* What it was used to verify: Skill layout, `SKILL.md`, personal/project/plugin skill paths, automatic invocation, and `allowed-tools`.
* Relevant conclusion: `~/.claude/skills/<skill-name>/SKILL.md` is a valid Claude Code personal skill location; `description` drives automatic loading; `allowed-tools` grants permission while active but does not restrict all other tools.

* Source name: Claude Code MCP documentation
* URL: https://code.claude.com/docs/en/agent-sdk/mcp
* Access date: 2026-06-08
* What it was used to verify: MCP tool naming and permission behavior.
* Relevant conclusion: MCP tools use `mcp__<server-name>__<tool-name>` naming, so local server names remain the relevant source for concrete Claude Code tool prefixes.

* Source name: Tavily Search API documentation
* URL: https://docs.tavily.com/documentation/api-reference/endpoint/search
* Access date: 2026-06-08
* What it was used to verify: External Tavily `topic` options and raw-content behavior.
* Relevant conclusion: Official Tavily API supports `general`, `news`, and `finance`, but the local MCP schema exposed here remains narrower; the spec is correct to defer to installed schema.

### Read-only validation performed

* `git status --short`, `git branch --show-current`, `git log --oneline -n 10` in `Claude-Code-Plugins`: confirmed branch `main`, latest SA-001 fix commit, and unrelated dirty `TODO.md` plus codex review artifacts.
* Read `docs/handoff/state.md`, `AGENTS.md`, `CLAUDE.md`, `BRANCH_PROTECTION.md`, and `docs/handoff/conventions.md`: confirmed startup rules, direct-commit workflow, qdev active incident, and plugin/test conventions.
* Read the revised spec with line numbers and searched it for `.agents/skills`, `.claude/skills`, `web-search`, MCP prefixes, and removed qdev commands.
* Inspected qdev command/agent/skill/test/manifest files and targeted qdev docs: confirmed current qdev has five commands, four agents, one grounding skill, sanitizer script/test, and the stale references the spec targets.
* Inspected `.claude-plugin/marketplace.json`, `plugins/qdev/.claude-plugin/plugin.json`, and `scripts/validate-marketplace.sh`: confirmed current qdev version is `1.6.0` and validator enforces marketplace/manifest version equality.
* Inspected `docs/handoff/state.md`, `architecture.md`, `deployed.md`, `conventions.md`, and `specs-plans.md`: confirmed current-truth qdev docs still describe the grounding skill and need scoped update.
* `git status --short`, `git branch --show-current`, `git log --oneline -n 5`, and `git diff -- skills/README.md` in `agent-configs`: confirmed branch `main` and pre-existing dirty target-file changes in `skills/README.md`.
* Inspected `agent-configs/skills/README.md`, `.claude/skills/populate-config/SKILL.md`, `scripts/skills/deploy-skill.sh`, `scripts/tests/deploy.bats`, and `scripts/tests/run.sh`: confirmed Gate 2, Claude-only routing, isolated deploy tests, and version-guarded copy behavior.
* Ran `tool_search` for Tavily/Brave/Serper: confirmed current Codex-exposed namespaces and Tavily `topic: general` schema, non-authoritative for Claude-only naming.
* Queried local Claude settings for MCP permission prefixes and ran `claude mcp list`: confirmed allowed Claude prefixes and server names; health checks failed and credential-bearing output is not reproduced.
* Consulted official Claude Code and Tavily documentation.

### Recommended planning/implementation validation

* Before edits in both repos: `git status --short`.
* Before editing any already-dirty target file: `git diff -- <target-file>` and decide whether existing hunks are unrelated.
* Before commits in both repos: stage only intended hunks, then run `git diff --cached` and `git diff --name-only --cached`; both must show only spec-owned changes.
* Run only after implementation: `cd plugins/qdev && python -m pytest`.
* Run after implementation: `bash scripts/validate-marketplace.sh`.
* Run after implementation: targeted `rg` for removed qdev command/skill/script references over live current surfaces, excluding historical docs and CHANGELOG.
* Run only after implementation in `agent-configs`: `HOME="$(mktemp -d)" bash scripts/skills/deploy-skill.sh` from the agent-configs root.
* Run only after implementation in `agent-configs`: `bash scripts/tests/run.sh`.
* Re-run live Claude Code MCP schema verification before writing concrete tool names; do not paste raw credential-bearing MCP output into docs or review artifacts.
* Run live deploy/invocation smoke only after explicit user approval for updating real `~/.claude/skills`.

### Final recommendation

Claude Code should revise the specification using the findings above

### Review ledger for next loop

* Spec path: /home/chris/projects/Claude-Code-Plugins/docs/superpowers/specs/2026-06-07-qdev-search-decoupling-design.md
* Audit round: 4
* Open issue IDs: SA-004
* Resolved issue IDs: SA-001, SA-002, SA-003, SA-005, SA-006, SA-007
* Superseded issue IDs:
* Significant findings remaining: Yes
* Next audit should focus on: same-file dirty-worktree protection for `agent-configs/skills/README.md`, including pre-edit target diff review, hunk-level isolation, and full cached diff review before commit.


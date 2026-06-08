### Executive summary

The specification needs major correction before Claude Code uses it for planning or implementation. The qdev slimming direction is coherent, but the spec has several repo-fit and operational defects: the proposed shared `.agents` search skill conflicts with `agent-configs` portability rules, the marketplace version bump is incomplete, the kept `/qdev:research` path would still call removed qdev commands, and the commit instructions are unsafe against current dirty worktrees.

Internet research was required for the search-tool assumptions. Official Tavily docs support `topic=news|finance`, but the current installed Tavily MCP metadata exposed in this session only permits `topic: "general"`, so the spec must validate the installed MCP schema instead of copying the global routing table blindly.

### Verdict

Needs major specification correction before planning/implementation

### Audit loop status

- Audit type: First audit
- Spec path: /home/chris/projects/Claude-Code-Plugins/docs/superpowers/specs/2026-06-07-qdev-search-decoupling-design.md
- Significant findings remaining: Yes
- Blocking issue count: 5
- Non-blocking issue count: 2

### What the specification gets right

- The current qdev surface inventory is mostly accurate: five commands, four agents, the `research-grounding` skill, and `sanitize_query.py` exist.
- The `test_plugin_structure.py` edits target real hard-coded assumptions that will fail after removing qdev’s only skill.
- It correctly separates historical dated docs from current-truth docs.
- It correctly treats qdev v2.0.0 as a breaking change and keeps release/tagging out of the implementation scope.

### Adversarial review performed

Performed requirement inventory, repository-fit falsification, internal-consistency, blast-radius, failure-mode, acceptance-criteria attack, external-assumption, and maintainability passes. Strongest assumptions tested: `.agents` skill portability, MCP search tool schema freshness, qdev command removal safety, marketplace version validation, handoff current-truth coverage, and two-repo commit safety.

Could not safely run pytest because pytest may write `.pytest_cache` and `__pycache__`; those checks are listed for post-implementation validation.

### Blocking issues

#### SA-001: Proposed `.agents` search skill violates agent-configs portability gates

- Severity: High
- Status: Confirmed
- Adversarial angle: Repository-fit / cross-harness compatibility
- Spec reference: Lines 21-23, 33-34, 89-108
- Finding: The spec places a routine-search skill under `agent-configs/skills/.agents/skills/web-search/` with `compatibility: Claude Code and Codex CLI`, but its stated purpose is to instruct use of MCP search servers. `agent-configs/skills/README.md` says `.agents/skills/` bodies must not depend on MCP tools, Claude-specific tool names, `WebFetch`, or subagent orchestration. The existing `populate-config` skill is Claude-only specifically because it uses MCP/WebFetch-style tooling.
- Repository evidence: `/home/chris/projects/agent-configs/skills/README.md:56-67`, `:91-99`; `/home/chris/projects/agent-configs/skills/.claude/skills/populate-config/SKILL.md:1-9`
- External research evidence: Not applicable.
- Why it matters: A shared skill that tells both harnesses to use harness-specific MCP tool names can silently fail or teach invalid tool calls. This defeats the purpose of moving routine search into a reusable skill.
- Recommended action for Claude Code: Revise Part B to either create harness-specific skills (`.claude/skills/` and `.codex/skills/`) or make the `.agents` skill genuinely portable prose that does not name or instruct direct MCP calls.
- Suggested validation: Compare the corrected target path and `compatibility:` against `agent-configs/skills/README.md` placement gates before planning.

#### SA-002: Marketplace version bump is omitted

- Severity: High
- Status: Confirmed
- Adversarial angle: Acceptance criteria / release metadata mismatch
- Spec reference: Lines 35, 71-78, 123-124
- Finding: The spec bumps `plugins/qdev/.claude-plugin/plugin.json` to `2.0.0` but only says to update the qdev marketplace description, not `.claude-plugin/marketplace.json` version. The repo validator enforces marketplace/plugin version equality.
- Repository evidence: `plugins/qdev/.claude-plugin/plugin.json:2-4`; `.claude-plugin/marketplace.json:99-101`; `scripts/validate-marketplace.sh:198-206`
- External research evidence: Not applicable.
- Why it matters: Following the spec literally can make `bash scripts/validate-marketplace.sh` fail after implementation.
- Recommended action for Claude Code: Add an explicit requirement to bump `.claude-plugin/marketplace.json` qdev version to `2.0.0` alongside the manifest.
- Suggested validation: Run `bash scripts/validate-marketplace.sh` after implementation.

#### SA-003: Kept `/qdev:research` still references removed qdev commands

- Severity: High
- Status: Confirmed
- Adversarial angle: Functional completeness / stale user workflow
- Spec reference: Lines 56-57, 128-130
- Finding: The spec keeps `plugins/qdev/commands/research.md` and says not to change `qdev-researcher` behavior/report machinery, but both current files reference `/qdev:quality-review`, which the spec deletes. The only remaining qdev command would offer or document a follow-up command that no longer exists.
- Repository evidence: `plugins/qdev/commands/research.md:75-85`; `plugins/qdev/agents/qdev-researcher.md:193-199`
- External research evidence: Not applicable.
- Why it matters: Acceptance could pass while the retained command still has a broken post-research workflow.
- Recommended action for Claude Code: Explicitly require removing or replacing qdev-local downstream chaining references in `research.md` and the researcher output/handoff text, or narrow the non-goal so output text can be updated without changing research behavior.
- Suggested validation: After implementation, search non-historical current files for removed command references.

#### SA-004: Two-repo commit instruction lacks dirty-worktree protection

- Severity: High
- Status: Confirmed
- Adversarial angle: Operational safety / unrelated local work
- Spec reference: Lines 110-115
- Finding: The spec instructs two direct commits but does not require clean-tree checks or explicit staging. Both involved repos currently have unrelated dirty state.
- Repository evidence: `Claude-Code-Plugins` has `M TODO.md`; `agent-configs` has modified `.claude/settings.json`, `TODO.md`, `configs/openbao-wrapper.md`, and an untracked review doc.
- External research evidence: Not applicable.
- Why it matters: A later implementation could accidentally commit unrelated local work or sensitive config changes while following the spec’s commit section.
- Recommended action for Claude Code: Add a pre-commit safety requirement: inspect both worktrees, preserve unrelated changes, stage only spec-owned files, and do not commit if unrelated dirty files cannot be isolated.
- Suggested validation: `git status --short` in both repos before edits and before commit; `git diff --name-only --cached` must list only intended files.

#### SA-006: Tavily news/finance routing conflicts with installed MCP schema

- Severity: High
- Status: Confirmed
- Adversarial angle: External-assumption freshness / tool contract mismatch
- Spec reference: Line 98
- Finding: The spec copies the global rule “Tavily with `topic=news`/`finance`”, but the installed Tavily MCP metadata exposed in this session only allows `topic: "general"`. Existing qdev routing also says the MCP schema is general-only and routes news/finance elsewhere.
- Repository evidence: `plugins/qdev/agents/qdev-researcher.md:67-73`; `agent-configs/global/codex/AGENTS.md:83-88`; `agent-configs/global/claude/CLAUDE.md:27-32`
- External research evidence: Tavily Search API docs list `topic` options `general`, `news`, and `finance` (<https://docs.tavily.com/documentation/api-reference/endpoint/search>, accessed 2026-06-08), but current local MCP tool metadata exposed `topic?: "general"` only.
- Why it matters: The new skill could instruct agents to make invalid tool calls in this environment.
- Recommended action for Claude Code: Require installed-tool schema inspection during spec correction. For the current schema, route news to `brave_news_search` and do not prescribe Tavily `topic=news|finance` unless the installed MCP schema is updated.
- Suggested validation: Re-run MCP tool metadata discovery for Tavily, Brave, and Serper before writing the skill.

### Non-blocking issues

#### SA-005: Handoff state active incident is omitted from current-truth updates

- Severity: Medium
- Status: Confirmed
- Adversarial angle: Repository continuity / stale eager context
- Spec reference: Lines 79-83
- Finding: The spec lists current-truth handoff docs to update but omits `docs/handoff/state.md`, which currently has an active incident for qdev D2 grounding manual matrix work. Removing the grounding skill should close or supersede that incident.
- Repository evidence: `docs/handoff/state.md` active incident for “qdev D2 (grounding skill) Task 7 — manual matrix pending”
- External research evidence: Not applicable.
- Why it matters: Future sessions would start from stale state about a deleted skill.
- Recommended action for Claude Code: Add `docs/handoff/state.md` to the current-truth update list, scoped only to clearing/superseding the qdev grounding incident.
- Suggested validation: After implementation, read `docs/handoff/state.md` and confirm no active incident remains for deleted qdev grounding work.

#### SA-007: New skill acceptance criteria do not prove deployability or invocation behavior

- Severity: Medium
- Status: Confirmed
- Adversarial angle: Acceptance-criteria false positive
- Spec reference: Lines 91-108, 117-126
- Finding: “Compare against `markdown-frontmatter`” is too weak. The spec does not define the required `agents/openai.yaml` contents, inventory update expectations, deployment behavior, or validation against `deploy-skill.sh` routing/version rules.
- Repository evidence: `markdown-frontmatter/agents/openai.yaml:1-6`; `agent-configs/skills/README.md:24-32`, `:89-99`, `:119-122`; `agent-configs/scripts/skills/deploy-skill.sh` routes by `compatibility:`
- External research evidence: Not applicable.
- Why it matters: The skill could have a valid-looking `SKILL.md` but fail to be discoverable or routed as intended.
- Recommended action for Claude Code: Specify exact `agents/openai.yaml` fields, README inventory row, version value, and deployment validation expectations.
- Suggested validation: After implementation, run agent-configs skill tests and inspect deploy routing without overwriting unrelated installed skills unless explicitly approved.

### Missing specification considerations

- Blocking: Resolve whether routine search is a shared portable `.agents` skill or harness-specific search guidance.
- Blocking: Add a dirty-worktree/staging guard for both repos before any commit.
- Blocking: Define installed MCP schema verification before copying the global routing table.
- Non-blocking: Update root README qdev “Type” from “Skills” to a command/agent-appropriate label after qdev has no skill.
- Non-blocking: Clarify whether local marketplace cache refresh is out of scope alongside release/tagging.
- Non-blocking: Define how to handle current qdev CHANGELOG historical references versus the new `2.0.0` removal entry.

### Ambiguities and decisions needed

- Ambiguity: `web-search` is marked “name subject to confirmation.”
- Why it matters: A noninteractive implementation cannot know the stable skill path/invocation name.
- Recommended clarification: Lock the skill name or require user confirmation before planning.
- Blocking or non-blocking: Blocking.

- Ambiguity: “No changes to qdev-researcher behavior or report machinery” conflicts with removing qdev commands referenced in its output.
- Why it matters: The planner must know whether output/handoff text may be changed.
- Recommended clarification: Permit non-behavioral output text cleanup for deleted command references.
- Blocking or non-blocking: Blocking.

### Internet research performed

- Source name: Tavily MCP Server docs
- URL: <https://docs.tavily.com/documentation/mcp>
- Access date: 2026-06-08
- What it was used to verify: Current Tavily MCP capabilities and setup.
- Relevant conclusion: Tavily MCP provides search and extract tooling, but local installed schema still must be checked.

- Source name: Tavily Search API docs
- URL: <https://docs.tavily.com/documentation/api-reference/endpoint/search>
- Access date: 2026-06-08
- What it was used to verify: Search parameters including `topic`, `search_depth`, and `include_raw_content`.
- Relevant conclusion: Official API supports `topic=general|news|finance`, but this conflicts with the installed MCP schema exposed in-session.

- Source name: Brave Search MCP Server README
- URL: <https://github.com/brave/brave-search-mcp-server>
- Access date: 2026-06-08
- What it was used to verify: Brave MCP tool surface.
- Relevant conclusion: Brave MCP documents `brave_web_search` and `brave_news_search`, supporting the spec’s use of Brave for general/news search.

### Items Claude Code should verify before correcting the specification

- Current MCP tool schemas for Tavily, Brave, and Serper in both Claude Code and Codex.
- Correct agent-configs skill placement after applying `.agents` portability gates.
- Current dirty worktree state in both repos.
- All non-historical qdev references to removed commands, agents, skills, and `sanitize_query.py`.
- Marketplace and plugin manifest version consistency.
- Whether `docs/handoff/state.md` should close the qdev grounding manual-matrix incident.

### Suggested corrections for Claude Code’s specification

- Replace the `.agents` routine-search design with either harness-specific skills or a truly portable `.agents` skill.
- Add explicit marketplace qdev version bump to `2.0.0`.
- Add explicit edits for `plugins/qdev/commands/research.md` and `plugins/qdev/agents/qdev-researcher.md` stale `/qdev:quality-review` references.
- Add `docs/handoff/state.md` to current-truth handoff updates.
- Replace Tavily `topic=news|finance` guidance with installed-schema-aware routing.
- Add clean-tree/explicit-staging safeguards for both repo commits.
- Lock the new skill name and specify `agents/openai.yaml` contents and README inventory updates.

### Read-only validation performed

- `git status --short`, `git branch --show-current`, `git log --oneline -n 10` in `Claude-Code-Plugins`: confirmed branch `main`, recent qdev design commit, and dirty `TODO.md`.
- Read `docs/handoff/state.md`, `AGENTS.md`, and `docs/handoff/conventions.md`: confirmed repo startup context and qdev active incident.
- Read target spec with line numbers: inventoried requirements and acceptance criteria.
- Listed and inspected `plugins/qdev` files: confirmed delete/keep targets exist.
- Inspected `test_plugin_structure.py`, qdev manifests, README, CHANGELOG, `research.md`, and `qdev-researcher.md`: found stale removed-command references and version surfaces.
- Inspected `scripts/validate-marketplace.sh`: confirmed manifest/marketplace version equality check.
- Inspected `agent-configs` skill README, `markdown-frontmatter`, `populate-config`, and deploy script: confirmed `.agents` placement gates and deployment routing.
- `git -C /home/chris/projects/agent-configs status --short`: confirmed unrelated dirty files in the second repo.
- `tool_search` for Tavily/search MCP metadata: confirmed current Tavily MCP schema exposes `topic` as `general` only.
- Official web docs for Tavily and Brave: checked current external tool documentation.

### Recommended planning/implementation validation

- Run only after implementation: `cd plugins/qdev && python -m pytest`
- Run after implementation: `bash scripts/validate-marketplace.sh`
- Run after implementation: search current non-historical surfaces for removed qdev references.
- Run before any commit: `git status --short` in both repos.
- Run before any commit: `git diff --name-only --cached` in both repos and confirm only intended files are staged.
- Run only after implementation in `agent-configs`: the skill deployment/test validation appropriate to the corrected target location; avoid writing installed skill roots without explicit approval.

### Final recommendation

Claude Code should revise the specification using the findings above

### Review ledger for next loop

- Spec path: /home/chris/projects/Claude-Code-Plugins/docs/superpowers/specs/2026-06-07-qdev-search-decoupling-design.md
- Audit round: 1
- Open issue IDs: SA-001, SA-002, SA-003, SA-004, SA-005, SA-006, SA-007
- Resolved issue IDs:
- Superseded issue IDs:
- Significant findings remaining: Yes
- Next audit should focus on: corrected routine-search skill placement/tool schema, qdev retained-command references, marketplace version consistency, handoff state cleanup, and dirty-worktree commit safeguards.

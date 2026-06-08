### Executive summary

The implementation plan is close, but it should be corrected before execution. The main confirmed gap is that the plan preserves a stale active `## [Unreleased]` changelog section that still advertises the soon-to-be-removed qdev grounding/sanitizer work. Internet research was used for current Claude Code skills and MCP ToolSearch behavior; it supports the plan’s Claude-only skill shape, but the live MCP tool names still require Claude Code-side ToolSearch verification during implementation.

### Verdict

Needs minor correction before execution

### Audit loop status

- Audit type: First audit
- Plan path: `/home/chris/projects/Claude-Code-Plugins/docs/superpowers/plans/2026-06-07-qdev-search-decoupling-plan.md`
- Significant findings remaining: Yes
- Blocking issue count: 0
- Non-blocking issue count: 3

### What the plan gets right

- The qdev delete/keep list matches the current plugin surface.
- The structural-test changes match the current hard-coded assumptions in `test_plugin_structure.py`.
- The qdev manifest/marketplace version bump is correctly paired with the repository validator’s version-equality check.
- The `agent-configs` `.claude/skills/` placement matches the local Gate 2 rule: skills that name MCP tools do not belong under shared `.agents/skills/`.
- The isolated-`HOME` deploy validation is appropriate; the live deploy is correctly left out of scope.

### Adversarial review performed

I inventoried and falsified plan claims against the current qdev files, manifests, marketplace validator, handoff docs, root README, `agent-configs` skill deployment docs, `deploy-skill.sh`, Bats tests, and both git worktrees. I attacked validation false positives around changelog refs, cached/staged-path checks, final clean-tree proof, and commands whose exit status may not prove the stated claim.

I did not run pytest, marketplace validation, Bats, deploy scripts, or generated-index commands because this audit is read-only and those commands may write caches, temp deploy trees, or other artifacts. I could not verify the live Claude Code MCP tool schema from this Codex audit; the plan’s own B1 ToolSearch re-verification remains required.

### Blocking issues

None found.

### Non-blocking issues

#### CR-001: Plan preserves a stale active Unreleased changelog section

- Severity: Medium
- Status: Confirmed
- Adversarial angle: A doc scrub can pass while current release notes still claim removed behavior exists.
- Plan reference: Task A7, lines 402-422.
- Finding: The plan inserts `2.0.0` above existing sections and explicitly says to leave `## [Unreleased]` untouched. In the current file, `## [Unreleased]` is not empty historical record; it still lists `qdev-grounding` and `sanitize_query.py` as added/fixed content.
- Repository evidence: `plugins/qdev/CHANGELOG.md:7-31` already has a `1.6.0` section; `plugins/qdev/CHANGELOG.md:34-54` has `## [Unreleased]` entries naming `qdev-grounding`, `sanitize_query.py`, and removed qdev command fixes.
- External research evidence: Not applicable.
- Why it matters: After implementation, the active changelog would contradict qdev 2.0.0 by advertising the removed grounding skill and sanitizer as unreleased/current work. The plan’s grep intentionally excludes `CHANGELOG.md`, so validation would not catch this.
- Recommended action for Claude Code: Revise Task A7 to normalize the changelog: put an empty `## [Unreleased]` at the top, then `## [2.0.0]`, then historical sections. Remove or correctly fold the stale Unreleased entries rather than leaving them untouched.
- Suggested validation: Inspect the active top changelog block and confirm `## [Unreleased]` contains no removed qdev commands, grounding skill, or sanitizer references.

#### CR-002: Final verification does not prove clean plan-owned paths

- Severity: Medium
- Status: Confirmed
- Adversarial angle: The final gate can pass while plan-owned files remain unstaged or dirty.
- Plan reference: Final verification Step 3, lines 860-866; Step 1, lines 847-850.
- Finding: The section title promises both commits and clean plan-owned paths, but the commands only show the last commit in each repo. Also, the final qdev command runs pytest and then `ls` on the next line, so a shell may return the `ls` status even if pytest failed.
- Repository evidence: Current `Claude-Code-Plugins` already has unrelated dirty state (`TODO.md` plus untracked review reports), so name-only log checks are insufficient to distinguish expected dirt from plan leftovers.
- External research evidence: Not applicable.
- Why it matters: A missed staged file, unstaged qdev doc update, or incomplete Part B README/SKILL commit could escape the final gate.
- Recommended action for Claude Code: Add explicit post-commit status checks in both repos and make the qdev final command fail on pytest failure.
- Suggested validation: Use `git -C <repo> status --short`, `git -C <repo> diff --name-only`, and `git -C <repo> diff --cached --name-only` after each commit; chain final qdev pytest and `ls` with `&&` or run under `set -e`.

#### CR-003: Skills-directory check has an impossible “no output” expectation

- Severity: Low
- Status: Confirmed
- Adversarial angle: A verification step can falsely look failed even when the desired state is achieved.
- Plan reference: Task A2 Step 3, lines 76-79.
- Finding: The command `find plugins/qdev/skills -name SKILL.md 2>/dev/null; echo "exit:$?"` always prints an `exit:` line. The expected result says “no output.”
- Repository evidence: This is shell behavior independent of repository state; the current qdev skills directory also contains `research-grounding/SKILL.md` before deletion.
- External research evidence: Not applicable.
- Why it matters: An implementer following the expected output literally may stop or “fix” a non-problem.
- Recommended action for Claude Code: Change the expectation to “no path output; exit line may be `exit:0` if the directory remains or `exit:1` if it was removed,” or replace the command with a cleaner check.
- Suggested validation: Use `find plugins/qdev/skills -name SKILL.md -print 2>/dev/null` and expect no printed paths.

### Missing considerations

- Non-blocking: The changelog cleanup should distinguish active `## [Unreleased]` from historical entries; historical sections may keep removed command names, but active Unreleased should not.
- Non-blocking: Final verification should include post-commit status/diff checks for both repos, not only `git log`.
- Non-blocking: Claude Code must re-run ToolSearch in the actual Claude Code session before writing `web-search`, because Codex-side tool metadata is explicitly non-authoritative for that skill.

### Internet research performed

- Source name: Claude Code Docs — Extend Claude with skills
- URL: <https://code.claude.com/docs/en/skills>
- Access date: 2026-06-08
- What it was used to verify: Claude Code skill directory layout, `SKILL.md` frontmatter, model invocation control, and `.claude/skills` loading.
- Relevant conclusion: The planned Claude-only `SKILL.md` shape is compatible; omitting `disable-model-invocation` is consistent with a model-invocable skill.

- Source name: Claude Code Docs — Connect Claude Code to tools via MCP
- URL: <https://docs.anthropic.com/en/docs/claude-code/mcp>
- Access date: 2026-06-08
- What it was used to verify: MCP ToolSearch behavior and the need to discover deferred MCP tools from the live session.
- Relevant conclusion: ToolSearch is enabled by default in Claude Code and discovers deferred MCP tools on demand, so the plan’s B1 live-schema recheck is appropriate.

### Items Claude Code should verify before correcting the plan

- Verify the current `plugins/qdev/CHANGELOG.md` ordering and decide how to normalize the stale `## [Unreleased]` section.
- Verify both worktrees immediately before implementation: `Claude-Code-Plugins` is dirty with unrelated files; `agent-configs` was clean during this audit.
- Re-run Claude Code ToolSearch for `tavily`, `brave search`, and `serper` before writing `web-search`.
- Verify `agent-configs/skills/README.md` is still clean before adding the inventory row.
- After qdev deletion, derive the real qdev pytest count from the implemented test run before editing `docs/handoff/conventions.md`.

### Suggested corrections for Claude Code's plan

- Revise Task A7 to create/keep an empty top `## [Unreleased]`, add `## [2.0.0]` below it, and remove or relocate the stale Unreleased qdev-grounding/sanitizer entries.
- Add a changelog validation check limited to the active Unreleased block.
- Fix Task A2 Step 3’s expected output.
- Strengthen final verification with `git status --short`, unstaged diff checks, cached diff checks, and fail-fast command chaining.

### Read-only validation performed

- `git status --short`, `git branch --show-current`, `git log --oneline -n 10` in `Claude-Code-Plugins`: established branch `main`, current dirty state, and recent qdev search-decoupling plan commits.
- `rg --files docs/handoff AGENTS.md CLAUDE.md AGENTS.reviews.md docs/superpowers/plans`: confirmed v3 handoff layout and target plan path.
- Inspected `docs/handoff/state.md`, `AGENTS.md`, `docs/handoff/conventions.md`, and `AGENTS.reviews.md`: confirmed repo startup rules and review-workflow boundaries.
- Inspected the plan and spec with `sed`/`nl`: inventoried material claims and line references.
- `find plugins/qdev -maxdepth 3 -type f | sort`: confirmed the current qdev delete/keep surface.
- Inspected qdev command, agent, structural test, manifest, marketplace, README, CHANGELOG, root README, and handoff docs with `nl`, `sed`, and `rg`: confirmed plan matches most current paths and found the stale Unreleased issue.
- Inspected `scripts/validate-marketplace.sh`: confirmed marketplace/manifest version equality is enforced.
- `git -C /home/chris/projects/agent-configs status --short`, branch, log, `rg --files`, and targeted reads of `skills/README.md`, `populate-config`, `deploy-skill.sh`, and deploy Bats tests: confirmed Part B placement and isolated deploy validation are consistent with repo tooling.
- Web research against official Claude Code docs: checked current skills and MCP ToolSearch assumptions.

### Recommended implementation validation

- Run only after implementation: `cd /home/chris/projects/Claude-Code-Plugins/plugins/qdev && PATH=/usr/bin:/bin:$PATH python -m pytest -q`
- Run only after implementation: `cd /home/chris/projects/Claude-Code-Plugins && bash scripts/validate-marketplace.sh`
- Run only after implementation: the plan’s dangling-ref grep over qdev live surface, plus a separate check that the active `## [Unreleased]` changelog block does not mention removed qdev surfaces.
- Run only after implementation: `cd /home/chris/projects/agent-configs && TMPH="$(mktemp -d)"; HOME="$TMPH" bash scripts/skills/deploy-skill.sh`
- Run only after implementation: `cd /home/chris/projects/agent-configs && bash scripts/tests/run.sh`
- After each commit: `git -C <repo> status --short`, `git -C <repo> diff --name-only`, and `git -C <repo> diff --cached --name-only`.

### Final recommendation

Claude Code should revise the plan using the findings above

### Review ledger for next loop

- Plan path: `/home/chris/projects/Claude-Code-Plugins/docs/superpowers/plans/2026-06-07-qdev-search-decoupling-plan.md`
- Audit round: 1
- Open issue IDs: CR-001, CR-002, CR-003
- Resolved issue IDs: None
- Superseded issue IDs: None
- Significant findings remaining: Yes
- Next audit should focus on: changelog Unreleased cleanup, stronger final clean-tree validation, corrected skills-directory check expectation, and live Claude Code ToolSearch re-verification wording.

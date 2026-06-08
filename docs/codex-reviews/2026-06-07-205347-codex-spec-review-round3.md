### Executive summary

Claude Code’s round-2 corrections resolved the prior schema and routing defects, but significant findings remain. The new D8 commit-safety model no longer depends on `written_paths`, but it now overclaims that `dirty now - baseline dirty` proves a path was written by this run. Git can show which paths are dirty and stage their current contents; it cannot identify who or what changed a clean-baseline file after the snapshot.

New internet research was required for Git status/add behavior. No new Claude Code external assumptions were introduced beyond those already researched in the prior pass.

### Verdict

Needs major specification correction before planning/implementation

### Audit loop status

* Audit type: Follow-up audit
* Spec path: /home/chris/projects/Claude-Code-Plugins/docs/plans/2026-06-07-up-docs-orchestration-improvements-design.md
* Prior audit issue count: 9
* Resolved issue count: 9
* Still open issue count: 0
* Partially resolved issue count: 0
* New issue count: 2
* Regression count: 0
* Significant findings remaining: Yes

### Adversarial review performed

Retested SA-001 through SA-006 and SA-NEW-001 through SA-NEW-003 against the revised spec and current repository contracts. Rechecked the tracker, auditor, propagator schemas, `/up-docs:all` and `/up-docs:repo` skill prompts, post-propagation template, specs/plans index, plugin manifests, changelog, and llm-wiki contract docs.

Attacked the new D7/D8/D11 assumptions: dropping A2 instead of adding finding keys, replacing `written_paths` with git baseline diffing, and specifying a routing matrix plus fail-open fixtures. Could not run tests or plugin smoke because this audit is read-only and those checks may write caches, invoke agents, or mutate repo/wiki/Notion state.

### Prior findings status

#### SA-001: A1 assumes a page set that the tracker does not persist

* Previous severity: High
* Current status: Resolved
* Evidence: D6 and §3.A still specify a new per-iteration `touched_pages` path list and redefine `pages_touched` as `len(touched_pages)`.
* Remaining action for Claude Code: Implement the tracker/auditor contract and tests exactly.

#### SA-002: Commit offer can commit pre-existing llm-wiki changes

* Previous severity: High
* Current status: Resolved
* Evidence: §3.C still requires pre-propagation baseline-dirty path sets and excludes baseline-dirty paths, including same-path collisions.
* Remaining action for Claude Code: Address SA-NEW-004, which is a new post-baseline safety gap.

#### SA-003: A2 skips whole touched pages before independent audit

* Previous severity: High
* Current status: Resolved
* Evidence: D7 and §4 drop cross-propagator report dedup and explicitly keep full audit coverage of freshly updated pages.
* Remaining action for Claude Code: None for the original issue.

#### SA-004: `Skipped` rows do not fit the current report/schema contract

* Previous severity: Medium
* Current status: Resolved
* Evidence: D9 and §3.B keep `Skipped` presentation-only in the combined report and leave the agent action enum untouched.
* Remaining action for Claude Code: Keep implementation out of validated agent rows.

#### SA-005: The new design is not indexed in `docs/handoff/specs-plans.md`

* Previous severity: Medium
* Current status: Resolved
* Evidence: `docs/handoff/specs-plans.md` contains a row for the design.
* Remaining action for Claude Code: Fix SA-NEW-005 because the existing row is now stale.

#### SA-006: Acceptance criteria can pass without proving the cost outcome

* Previous severity: Medium
* Current status: Resolved
* Evidence: §6 still requires prompt-conformance assertions plus behavioral checks for A1, B, and C.
* Remaining action for Claude Code: Add the new SA-NEW-004 post-baseline unrelated-change fixture.

#### SA-NEW-001: A2’s “exact” finding signature is undefined and too coarse

* Previous severity: High
* Current status: Resolved
* Evidence: D7 drops A2 entirely and says no `discrepancy_type`, `finding_key`, or `fixed_findings` schema work is required.
* Remaining action for Claude Code: None for A2.

#### SA-NEW-002: `written_paths` is required for safe commits but absent from the validated output contract

* Previous severity: High
* Current status: Resolved
* Evidence: D8 removes the `written_paths` dependency and leaves the strict propagator schema untouched.
* Remaining action for Claude Code: Address SA-NEW-004, the new safety flaw in the replacement git-baseline model.

#### SA-NEW-003: Fast-path layer routing relies on an under-specified boundary table

* Previous severity: Medium
* Current status: Resolved
* Evidence: D11 and §3.B require an explicit routing matrix in `/up-docs:all`, synced to agent layer boundaries, with fail-open ambiguous routing and routing fixtures.
* Remaining action for Claude Code: Ensure the implementation includes the matrix and fixtures rather than only prose.

### New blocking issues

#### SA-NEW-004: Git-baseline candidates do not prove run ownership

* Severity: High
* Status: Confirmed
* Adversarial angle: Commit-safety false-positive attack.
* Spec reference: §2 D8; §3.C lines 90-106; risk table line 133; §6 C tests lines 149-151.
* Finding: The spec says `candidates = dirty now - baseline-dirty` are “exactly the paths clean at baseline and written by this run.” That is not true. The formula only proves those paths were clean at baseline and dirty later. A user, editor, hook, background process, or separate agent could modify a clean-baseline file after the snapshot, and the repo-level approval would allow it to be staged and committed.
* Repository evidence: The revised spec intentionally avoids `written_paths`/`fixed_findings`; current propagator schemas have only `rows` and `totals`; current post-propagation template has no path-level diff review or per-path approval contract. `plugins/up-docs/skills/all/SKILL.md` dispatches agents in parallel, so the orchestrator’s baseline and later commit step are separated by agent work.
* External research evidence: Official Git docs say `git status --porcelain` reports changed paths in a stable parseable format, and `git add` stages the specified files’ current contents at the time `git add` runs. Git does not attribute a working-tree change to a specific process.
* Why it matters: The spec can still commit unrelated local work if that work appears after baseline. This reintroduces the safety class SA-002 was meant to eliminate, just through a different path.
* Recommended action for Claude Code: Either restore a validated run-owned path contract, or downgrade the claim: candidates are “changed since baseline,” not “written by this run.” Require path-level candidate disclosure with diff preview and explicit approval, plus a late recheck immediately before staging. Prefer `--porcelain=v1 -z` and NUL/literal pathspec staging for safety.
* Suggested validation: Add a C fixture where an unrelated clean-baseline path becomes dirty after baseline but before the commit offer. The commit step must not silently include it; it must either exclude it or require explicit path/diff approval.

### New non-blocking issues

#### SA-NEW-005: The specs/plans index still describes the dropped A2 design

* Severity: Medium
* Status: Confirmed
* Adversarial angle: Repository source-of-truth drift.
* Spec reference: §6 rollout lines 153-155; §8 review ledger.
* Finding: The spec says the index row should stay status-current, but `docs/handoff/specs-plans.md` still says “round 1 applied” and describes “signature-level (not whole-page) dedup.” The current spec says rounds 1-2 are applied and D7 drops A2 entirely.
* Repository evidence: `docs/handoff/specs-plans.md:19` is stale. `git show --stat --name-only HEAD` shows the round-2 commit updated the spec and review artifact, not the index row.
* External research evidence: Not applicable.
* Why it matters: `AGENTS.md` treats `docs/handoff/specs-plans.md` as the indexed architectural source of truth. Future planning could resurrect the signature-dedup work the spec intentionally dropped.
* Recommended action for Claude Code: Update the row to reflect D7/D8/D11 and the current audit status when revising the spec.
* Suggested validation: Re-read `docs/handoff/specs-plans.md` and confirm the row no longer mentions signature-level dedup or only round-1 corrections.

### Regressions

None found.

### Remaining ambiguities and decisions needed

* Ambiguity: Should Step 6 commit only machine-attributed run-owned paths, or offer “changed since baseline” paths for human diff review?
  * Why it matters: Without this decision, the safety contract can still stage unrelated post-baseline edits.
  * Recommended clarification: Pick one model and state its limits. If using git-only evidence, require path-level disclosure and approval.
  * Blocking or non-blocking: Blocking.

* Ambiguity: The spec says `/up-docs:repo` has no dirty guard, but the current skill has a Step 0 dirty-tree guard.
  * Why it matters: It is a stale repo-fit claim, although the baseline requirement remains harmless.
  * Recommended clarification: Correct the text so planning does not duplicate or mis-handle the existing guard.
  * Blocking or non-blocking: Non-blocking.

### Internet research performed

* Source name: Git documentation - git-status
  * URL: https://git-scm.com/docs/git-status/2.24.0.html
  * Access date: 2026-06-08
  * What it was used to verify: `git status --porcelain` path/status semantics and machine parsing.
  * Relevant conclusion: Porcelain status is stable for scripts and reports path states; `-z` avoids quoting and is safer for machine parsing.

* Source name: Git documentation - git-add
  * URL: https://git-scm.com/docs/git-add
  * Access date: 2026-06-08
  * What it was used to verify: What `git add -- <path>` stages.
  * Relevant conclusion: `git add` stages the specified path contents at the time the command runs; it does not prove who produced those contents.

### Read-only validation performed

* `git status --short`, `git branch --show-current`, `git log --oneline -n 10` - repo is on `main`; working tree is clean; HEAD is the round-2 spec fix commit.
* `git show --stat --name-only HEAD` - round-2 commit revised the spec and added the audit artifact, but did not update `docs/handoff/specs-plans.md`.
* Inspected `docs/handoff/state.md`, `AGENTS.md`, `CLAUDE.md`, and `docs/handoff/conventions.md` - confirmed v3 session rules and repo conventions.
* Inspected the revised spec with line numbers - retested D6-D11, §3 design, §6 tests/rollout, and §8 ledger.
* Inspected `/up-docs` skills, propagator agents, summary/post-propagation templates, tracker script/tests, and output validators - confirmed current schema/routing/commit surfaces.
* `rg` searches for `discrepancy_type`, `fixed_findings`, `written_paths`, `touched_pages`, `routing matrix`, baseline terms, and `Skipped` - confirmed A2/written-path schema work is dropped and routing/baseline are spec-only changes.
* Inspected `docs/handoff/specs-plans.md`, plugin manifest, marketplace manifest, and changelog - confirmed current baseline is `0.10.1` and the index row is stale.
* `git ls-files --error-unmatch ...` - confirmed the spec and key referenced files are tracked.
* `git diff --stat` and `git diff --check` - no local diff or whitespace errors.
* Inspected llm-wiki `AGENTS.md` and conventions; rechecked llm-wiki git status/log - current llm-wiki state is clean on `main` after recheck, with validation/dirty-baseline contracts relevant to Step 6.

### Recommended planning/implementation validation

* Run only after implementation: `bash plugins/up-docs/tests/run-bats.sh plugins/up-docs/tests/prompt-conformance.bats plugins/up-docs/tests/convergence-tracker.bats`
* Run only after implementation: `cd plugins/up-docs/tests && .venv/bin/python -m pytest -v`
* Run only after implementation: `./scripts/validate-marketplace.sh`
* Add C commit-safety fixtures for clean baseline, baseline-dirty different path, baseline-dirty same path, post-baseline unrelated dirty path, headless `-p`, path names with spaces, deleted files, and untracked files.
* Add B routing fixtures for repo-only, wiki-only, Notion-only, multi-layer, and ambiguous fail-open routing.
* Add A1 tracker/auditor tests proving `touched_pages` path round-trip and pass-2 candidate narrowing.
* Add a docs-index assertion or manual acceptance check for `docs/handoff/specs-plans.md`.

### Final recommendation

Claude Code should revise the specification using the findings above

### Review ledger for next loop

* Spec path: /home/chris/projects/Claude-Code-Plugins/docs/plans/2026-06-07-up-docs-orchestration-improvements-design.md
* Audit round: 3
* Open issue IDs: SA-NEW-004, SA-NEW-005
* Resolved issue IDs: SA-001, SA-002, SA-003, SA-004, SA-005, SA-006, SA-NEW-001, SA-NEW-002, SA-NEW-003
* Superseded issue IDs: None
* Significant findings remaining: Yes
* Next audit should focus on: Step 6 post-baseline commit safety and path/diff approval semantics, stale `docs/handoff/specs-plans.md` row correction, and preservation of the resolved D6/D7/D9/D11 decisions.
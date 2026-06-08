### Executive summary

The implementation plan needs major correction before Claude Code executes it. The core repo/file claims mostly match the current tree, and the plan correctly targets up-docs 0.11.0, but two safety/completeness assumptions are not strong enough as written: the commit-offer late re-check can still stage content the user did not approve, and the routing matrix can skip real propagation work for ambiguous system-of-record items.

Internet research was required for Git status/porcelain behavior and Claude Code non-interactive mode. Git’s official docs support the use of porcelain `-z` for parsing, but also show `git status` can write optional index refresh state unless `--no-optional-locks` is used.

### Verdict

Needs major correction before execution

### Audit loop status

- Audit type: First audit
- Plan path: `/home/chris/projects/Claude-Code-Plugins/docs/plans/2026-06-07-up-docs-orchestration-improvements-plan.md`
- Significant findings remaining: Yes
- Blocking issue count: 2
- Non-blocking issue count: 3

### What the plan gets right

- The referenced plan, design, handoff index, plugin files, manifests, test harness, and current `0.10.1` version all exist where the plan says they do.
- The plan follows repo conventions: explicit staging, direct `main` workflow, up-docs test wrapper, marketplace validation, and namespaced `up-docs:` agent dispatch.
- The Git porcelain `-z` parsing choice is directionally correct for path/status enumeration.

### Adversarial review performed

I inventoried and challenged material claims about target files, version state, test harnesses, prompt edits, tracker semantics, routing behavior, commit safety, validation commands, manifest updates, and specs-plans status. I inspected current repository state, the plan, the converged design, handoff docs, up-docs scripts/tests/skills/agents/templates, manifests, changelog, CI/workflow references, and relevant repo conventions.

I did not run the bats/pytest suites because this audit is read-only and those suites create temp repos/cache/test artifacts. Dynamic Claude Code behavior such as actual `Agent` dispatch and `AskUserQuestion` availability was not executable in this read-only audit.

### Blocking issues

#### CR-001: Commit late re-check does not protect the approved diff content

- Severity: High
- Status: Confirmed
- Adversarial angle: Consent gate can pass while staging content the user never approved.
- Plan reference: Task 5 Step 3, especially lines 573-583; design §3C lines 104-110.
- Finding: The plan discloses a diff, asks for approval, then late re-checks only the candidate set/path presence before staging. If an approved file’s content changes after disclosure but remains dirty under the same path, the path set is unchanged and the plan can stage undisclosed content.
- Repository evidence: The proposed `commit-candidates.sh` surfaces paths only, not content hashes or diff fingerprints. Task 5’s prompt says to re-run candidates and re-confirm only when an approved path is gone or unexpected new paths appear.
- External research evidence: Git status porcelain is path/status oriented; Git docs describe `git status` as showing paths that differ from HEAD/index/worktree, not an immutable approved diff. Source: <https://git-scm.com/docs/git-status>, accessed 2026-06-08.
- Why it matters: This breaks the plan’s core “consent-gated” safety claim and can commit unrelated or malicious same-path changes made between approval and staging.
- Recommended action for Claude Code: Revise the plan to capture the exact offered diff or blob/index/worktree fingerprint per candidate at disclosure time, then compare it immediately before staging. If the diff changed, re-disclose and ask again.
- Suggested validation: Add a commit-offer test/smoke scenario where a candidate path is approved, then modified again before staging; expected behavior is re-disclosure and no blind staging.

#### CR-002: Routing matrix can skip real propagation work for system-of-record-adjacent items

- Severity: High
- Status: Confirmed
- Adversarial angle: Fast-path skip can misroute an item to “no propagator” even though current agents would update repo/wiki/Notion.
- Plan reference: Task 3 routing matrix lines 306-310.
- Finding: The matrix says “Live system-of-record fact (NetBox/OpenBao/DNS/firewall inventory)” routes to no doc layer. Existing up-docs agent boundaries are more nuanced: OpenBao listener/config examples are wiki-eligible, Notion may record strategic status, and repo credentials docs update secret-path references. An LLM router could classify an OpenBao listener or credential-reference change under the “none” row and skip propagation incorrectly.
- Repository evidence: `up-docs-propagate-wiki.md` says implementation references include configuration details, env vars, file paths, authentication/networking, and includes an OpenBao listener update example. `up-docs-propagate-notion.md` allows credential locations/URLs and includes an OpenBao strategic note example. `up-docs-propagate-repo.md` explicitly updates `docs/handoff/credentials.md` for added/rotated/removed secret paths.
- External research evidence: Not applicable.
- Why it matters: This is the core completeness risk of the fast-path feature. The auditor still running later does not make the propagation step correct; it can leave avoidable stale docs and create false confidence.
- Recommended action for Claude Code: Split the “system-of-record” row into precise cases: secret values/live inventory records route to none; credential references, env var names, config paths, procedures, implementation notes, and strategic status route to the appropriate layers. Add worked examples.
- Suggested validation: Add routing fixtures for OpenBao listener rebind, secret path rotation, DNS record-only inventory, repo-only CLI change, wiki-only procedure, Notion-only strategy, multi-layer service addition, and ambiguous items.

### Non-blocking issues

#### CR-003: Validation relies on grep assertions where the design requires behavioral fixtures

- Severity: Medium
- Status: Confirmed
- Adversarial angle: The plan’s tests can pass while the behavior remains wrong.
- Plan reference: Task 2 lines 200-211, Task 3 lines 270-288 and 338-340, Task 5 lines 523-545; self-review line 685.
- Finding: The design requires behavioral checks for A1 narrowing, B routing fixtures, and C headless/commit safety. The plan mostly adds grep-level prompt-conformance checks plus one manual note. Those checks prove strings exist, not that routing/narrowing/commit behavior works.
- Repository evidence: `prompt-conformance.bats` currently contains grep guards only. No planned routing fixture file exists, and Task 3 explicitly defers transcript behavior to a comment.
- External research evidence: Claude Code docs confirm `claude -p` is non-interactive/print mode, making the headless behavior materially testable. Source: <https://code.claude.com/docs/en/cli-usage>, accessed 2026-06-08.
- Why it matters: The validation attack pass has obvious false positives: a prompt can contain “touched_pages” or “ambiguous” while still not routing or narrowing correctly.
- Recommended action for Claude Code: Add deterministic fixtures or transcript-smoke checks for the behavioral contract, not just text presence.
- Suggested validation: Add fixture tests for routing classification and a documented disposable `/up-docs:all` transcript smoke for repo-only and ambiguous summaries.

#### CR-004: Baseline files are predictable and `git status` may take optional locks/write index state

- Severity: Medium
- Status: Confirmed
- Adversarial angle: Baseline capture can collide across runs and mutate Git metadata before consent.
- Plan reference: Task 5 Step 4 lines 594-598; Task 4 script lines 457-479.
- Finding: The plan writes fixed baseline files under `${TMPDIR:-/tmp}/up-docs-baseline-repo.txt` and `...wiki.txt`. Concurrent runs can overwrite each other. Also, the helper uses plain `git status`; official Git docs note status may refresh/write the index and recommend `git --no-optional-locks status` for background scripts.
- Repository evidence: Existing `convergence-tracker.sh` already avoids state collisions with `CLAUDE_CODE_SESSION_ID`, showing this repo has learned from cross-process state issues.
- External research evidence: Git docs state porcelain v1 is stable and `-z` is machine-parsable, but also state background scripts should consider `git --no-optional-locks status` because status can write the index. Source: <https://git-scm.com/docs/git-status>, accessed 2026-06-08.
- Why it matters: A commit-safety helper should not have cross-session state collisions or surprise Git lock/index side effects before user consent.
- Recommended action for Claude Code: Use `mktemp` or a session-scoped baseline directory, pass the generated paths through Step 6, and call `git --no-optional-locks -C "$repo" status --porcelain=v1 -z`.
- Suggested validation: Add tests/inspection for unique baseline path creation and update the shellcheck/bash-n gate after changing the helper.

#### CR-005: Task 1 replacement scope can double-count `changes_applied`

- Severity: Low
- Status: Confirmed
- Adversarial angle: Literal implementation of the edit instruction can introduce a bug even though the intended code is fine.
- Plan reference: Task 1 Step 4 lines 123-144.
- Finding: The plan says to replace only the `pages_touched` line and `p['history'].append(...)` call with a snippet that also includes `fixes = ...` and `p['changes_applied'] += fixes`. In the current file those two lines already exist immediately before `pages_touched`. A literal narrow replacement would duplicate them and double-count changes.
- Repository evidence: Current `convergence-tracker.sh` has `fixes = findings.get(...)` and `p['changes_applied'] += fixes` at lines 96-97, followed by `p['pages_touched']` and history append at lines 98-104.
- External research evidence: Not applicable.
- Why it matters: Existing tests would likely catch this, but the plan is unnecessarily easy to misapply.
- Recommended action for Claude Code: Change the instruction to replace the whole block from `fixes = findings.get(...)` through the history append.
- Suggested validation: Keep the existing `record-iteration accumulates changes_applied` test and add a touched_pages test that also asserts `changes_applied` remains exact.

### Missing considerations

- Blocking: The commit approval step needs a same-path content-mutation guard, not just candidate path-set re-check.
- Blocking: Routing needs fixture coverage and clearer system-of-record exceptions before the skip feature is safe.
- Non-blocking: Current working tree is not clean (`?? TODO.md`), so Task 0 would stop if executed now. Claude Code must not overwrite or sweep it.
- Non-blocking: The plan should explicitly use session-scoped temp baseline files and `git --no-optional-locks status`.
- Non-blocking: The plan should verify the current installed Claude Code `Agent`/`Task` alias behavior if relying on that historical note; I did not find official docs confirming the alias.

### Internet research performed

- Source name: Git `git-status` documentation
- URL: <https://git-scm.com/docs/git-status>
- Access date: 2026-06-08
- What it was used to verify: Porcelain v1 stability, `-z` path format, rename ordering, and optional index refresh behavior.
- Relevant conclusion: Porcelain `-z` is suitable for path parsing, but `git status` may write optional index state; scripts should consider `git --no-optional-locks status`.

- Source name: Claude Code CLI reference
- URL: <https://code.claude.com/docs/en/cli-usage>
- Access date: 2026-06-08
- What it was used to verify: Non-interactive print mode.
- Relevant conclusion: `claude -p` / `--print` is documented as print/non-interactive mode, supporting the plan’s need for a report-only headless path.

### Items Claude Code should verify before correcting the plan

- Confirm whether `TODO.md` is user-owned and clear the dirty tree only with explicit user intent before executing Task 0.
- Verify current Claude Code/plugin runtime behavior for `Agent` dispatch and any `Task` alias if that note remains in the skill.
- Verify `~/projects/llm-wiki` exists before adding wiki baseline capture behavior.
- Verify whether shellcheck remains available on the implementation machine.
- Verify whether prompt behavioral tests can be automated through transcript fixtures or must remain documented smoke tests.

### Suggested corrections for Claude Code's plan

- Add same-path content mutation protection to the commit-offer late re-check.
- Replace fixed `/tmp/up-docs-baseline-*.txt` paths with `mktemp` or session-scoped paths.
- Use `git --no-optional-locks -C "$repo" status --porcelain=v1 -z` in `commit-candidates.sh`.
- Refine the routing matrix with explicit system-of-record exceptions and examples.
- Add real routing fixtures and commit-offer race/headless validation, not only grep assertions.
- Clarify Task 1’s replacement range so `changes_applied` is not duplicated.

### Read-only validation performed

- `git status --short`: established the tree is currently dirty with untracked `TODO.md`.
- `git branch --show-current` and `git log --oneline -n 10`: established current branch is `main` and the plan commit is the latest.
- `git diff --stat` and `git diff --check`: established no tracked diff/stat/check issues are present.
- Read `docs/handoff/state.md`, `AGENTS.md`, `docs/handoff/conventions.md`, and `docs/handoff/specs-plans.md`: established repo startup context and plan/design index status.
- Read the implementation plan and converged design: inventoried material claims and cross-checked spec coverage.
- Inspected up-docs scripts/tests/skills/agents/templates/manifests/changelog: verified target files exist, current version is `0.10.1`, commit-candidates files do not yet exist, and current prompt/tests match the plan’s assumptions.
- Used `rg`, `test -e`, `jq`, `command -v`, and `.venv/bin/python --version`: checked referenced paths, tools, plugin versions, shellcheck availability, and test virtualenv availability.

### Recommended implementation validation

- Run only after implementation: `PATH="/usr/bin:/bin:$PATH" bash plugins/up-docs/tests/run-bats.sh plugins/up-docs/tests/convergence-tracker.bats plugins/up-docs/tests/commit-candidates.bats plugins/up-docs/tests/prompt-conformance.bats`
- Run only after implementation: `bash -n plugins/up-docs/scripts/convergence-tracker.sh plugins/up-docs/scripts/commit-candidates.sh && shellcheck -S warning plugins/up-docs/scripts/convergence-tracker.sh plugins/up-docs/scripts/commit-candidates.sh`
- Run only after implementation: `(cd plugins/up-docs/tests && .venv/bin/python -m pytest -q)`
- Run only after implementation: `./scripts/validate-marketplace.sh`
- Run only after implementation: disposable transcript smoke for repo-only, wiki-only, Notion-only, multi-layer, ambiguous, and headless `-p` commit-offer cases.

### Final recommendation

Claude Code should revise the plan using the findings above

### Review ledger for next loop

- Plan path: `/home/chris/projects/Claude-Code-Plugins/docs/plans/2026-06-07-up-docs-orchestration-improvements-plan.md`
- Audit round: 1
- Open issue IDs: CR-001, CR-002, CR-003, CR-004, CR-005
- Resolved issue IDs: None
- Superseded issue IDs: None
- Significant findings remaining: Yes
- Next audit should focus on: commit-offer late re-check content safety, routing matrix examples/fixtures, baseline temp-file and Git optional-lock behavior, and Task 1 replacement-scope clarity.

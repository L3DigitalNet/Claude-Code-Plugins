### Executive summary

Claude Code’s revisions resolved the routing-matrix over-skip, baseline temp-file, Git optional-lock, and tracker replacement-scope findings. Significant findings still remain: the commit-offer flow can still fail to disclose untracked candidate content, the validation plan is still partly grep/manual where the design calls for behavioral checks, and the new routing fixture is not staged in the task that creates it.

New internet research was required for Git diff/status behavior and Claude Code non-interactive mode.

### Verdict

Needs major correction before execution

### Audit loop status

- Audit type: Follow-up audit
- Plan path: `/home/chris/projects/Claude-Code-Plugins/docs/plans/2026-06-07-up-docs-orchestration-improvements-plan.md`
- Prior audit issue count: 5
- Resolved issue count: 3
- Still open issue count: 0
- Partially resolved issue count: 2
- New issue count: 3
- Regression count: 0
- Significant findings remaining: Yes

### Adversarial review performed

Re-read the revised plan, prior ledger, current repo state, handoff conventions, design spec, up-docs skill/agent/templates/scripts/tests, manifests, and current Git status. Retested prior fixes for same-path content approval, system-of-record routing, behavioral validation, temp baseline paths, `--no-optional-locks`, and Task 1 replacement scope.

I did not run bats/pytest because these suites create temp repos, caches, and test artifacts. I did not execute Claude Code Agent dispatch or AskUserQuestion behavior. Current repo execution is also blocked by unrelated tracked local modifications, which the plan’s Task 0 would stop on.

### Prior findings status

#### CR-001: Commit late re-check does not protect the approved diff content

- Previous severity: High
- Current status: Partially resolved
- Evidence: The plan adds a `fingerprint` subcommand and late fingerprint comparison at lines 529-538 and 643-649, plus mutation tests at lines 460-473. However, disclosure still says to show `git -C <repo> diff -- <path>` for each candidate at line 634. Local evidence: `git diff -- TODO.md` and `git diff --stat -- TODO.md` produced no output for the current untracked `TODO.md`. Git docs describe untracked status entries separately from tracked changes, and `git diff` without `--no-index` compares working tree/index/tree endpoints, so untracked new-file content can be undisclosed.
- Remaining action for Claude Code: Revise the commit-offer plan so untracked candidates are disclosed with actual content, e.g. enumerate untracked files and show a `/dev/null` comparison or equivalent safe new-file preview. Add a test/smoke scenario proving an untracked candidate’s content is visible before approval.

#### CR-002: Routing matrix can skip real propagation work for system-of-record-adjacent items

- Previous severity: High
- Current status: Resolved
- Evidence: The revised matrix splits credential references, implementation references, strategic facts, and “secret value/live inventory record only” at lines 316-323, with worked cases at lines 330-344. This matches the current repo/wiki/Notion agent boundaries for OpenBao listener/config/reference cases.
- Remaining action for Claude Code: None for the routing semantics; see CR-NEW-001 for staging the new fixture file.

#### CR-003: Validation relies on grep assertions where the design requires behavioral fixtures

- Previous severity: Medium
- Current status: Partially resolved
- Evidence: The plan adds tracker behavior tests and commit-candidate behavior tests, plus routing fixtures and a manual transcript note. But Task 2 still validates auditor narrowing only with grep assertions at lines 202-214, while the design calls for a behavioral A1 check proving pass-2 scope narrows from pass-1. Task 5 also lacks a conformance assertion for `skills/repo/SKILL.md` baseline capture.
- Remaining action for Claude Code: Add the missing behavioral/fixture checks or explicit post-implementation smoke checks with pass/fail criteria for auditor narrowing and `/up-docs:repo` baseline capture.

#### CR-004: Baseline files are predictable and `git status` may take optional locks/write index state

- Previous severity: Medium
- Current status: Resolved
- Evidence: The plan now uses `mktemp` baseline files at lines 661-667 and `git --no-optional-locks ... status --porcelain=v1 -z` in the helper at lines 502-505.
- Remaining action for Claude Code: None.

#### CR-005: Task 1 replacement scope can double-count `changes_applied`

- Previous severity: Low
- Current status: Resolved
- Evidence: Task 1 now explicitly replaces the entire block from `fixes = ...` through history append at lines 125-147 and includes a `changes_applied` exactness assertion at line 76.
- Remaining action for Claude Code: None.

### New blocking issues

#### CR-NEW-001: Routing fixture is created but never staged

- Severity: High
- Status: Confirmed
- Adversarial angle: Local validation can pass with an untracked fixture while the committed implementation is broken.
- Plan reference: Task 3 Step 3b lines 326-344; Task 3 commit lines 375-377.
- Finding: The plan creates `plugins/up-docs/tests/fixtures/routing-cases.md` and adds prompt-conformance tests requiring it, but the Task 3 `git add` omits that file.
- Repository evidence: `git ls-files plugins/up-docs/tests/fixtures` currently tracks only `plugins/up-docs/tests/fixtures/stubs/ssh`; the planned fixture path does not exist or appear in tracked files.
- External research evidence: Not applicable.
- Why it matters: Task 3 can pass locally because the file exists untracked, then commit only `prompt-conformance.bats`; a clean checkout would fail the fixture test.
- Recommended action for Claude Code: Add `plugins/up-docs/tests/fixtures/routing-cases.md` to the Task 3 `git add` command.
- Suggested validation: After Task 3 commit, verify `git ls-files plugins/up-docs/tests/fixtures/routing-cases.md` prints the fixture path and `prompt-conformance.bats` passes from tracked state.

### New non-blocking issues

#### CR-NEW-002: New bats tests create temp git repos without neutralizing global hooks/signing

- Severity: Medium
- Status: Confirmed
- Adversarial angle: The test suite can fail on this workstation for reasons unrelated to the helper behavior.
- Plan reference: Task 4 test setup lines 398-405.
- Finding: `commit-candidates.bats` creates a temp repo and runs `git commit`, but does not `load helpers`, call `setup_test_env`, set `core.hooksPath /dev/null`, or export `GIT_CONFIG_GLOBAL=/dev/null` / `GIT_CONFIG_NOSYSTEM=1`.
- Repository evidence: `docs/handoff/conventions.md` TEST-003 requires tmpdir git repos to disable hooks/config; `plugins/up-docs/tests/helpers.bash` already exports the needed env vars at lines 11-12.
- External research evidence: Not applicable.
- Why it matters: Global pre-commit hooks or signing config can break fixture commits before the candidate-helper behavior is tested.
- Recommended action for Claude Code: Make `commit-candidates.bats` load the existing helpers and use `setup_test_env`, or explicitly neutralize global Git config/hooks in setup.
- Suggested validation: Run the new bats file through `plugins/up-docs/tests/run-bats.sh` on the target workstation after implementation.

#### CR-NEW-003: `/up-docs:repo` baseline capture is untested

- Severity: Medium
- Status: Confirmed
- Adversarial angle: Validation can pass while the single-layer repo skill misses the commit baseline.
- Plan reference: Task 5 Step 1 lines 604-607; Task 5 Step 4 lines 658-670.
- Finding: The conformance test checks only `skills/all/SKILL.md` for `commit-candidates.sh snapshot`, but Task 5 also requires adding the project-repo baseline to `skills/repo/SKILL.md`.
- Repository evidence: Current `skills/repo/SKILL.md` has its own pre-flight and post-propagation flow, so missing this edit would affect `/up-docs:repo` independently.
- External research evidence: Not applicable.
- Why it matters: `/up-docs:repo` could reach Step 5 without a baseline and degrade to report-only or unsafe behavior, while the planned conformance suite still passes.
- Recommended action for Claude Code: Add a prompt-conformance test that checks `plugins/up-docs/skills/repo/SKILL.md` for the baseline snapshot and Step 5/commit-offer wiring.
- Suggested validation: Run `prompt-conformance.bats` after intentionally omitting the repo-skill edit and confirm the new test fails.

### Regressions

None found.

### Internet research performed

- Source name: Git `git-status` documentation
- URL: <https://git-scm.com/docs/git-status>
- Access date: 2026-06-08
- What it was used to verify: Porcelain status format, untracked entry representation, and `-z` pathname handling.
- Relevant conclusion: Porcelain v1 is parseable and untracked entries are distinct status records; `-z` is appropriate for machine path parsing.

- Source name: Git `git-diff` documentation
- URL: <https://git-scm.com/docs/git-diff>
- Access date: 2026-06-08
- What it was used to verify: What plain `git diff -- <path>` compares.
- Relevant conclusion: Plain `git diff` compares tracked endpoints such as working tree vs index/tree; it is not sufficient as the only disclosure mechanism for untracked new-file content.

- Source name: Git documentation
- URL: <https://git-scm.com/docs/git>
- Access date: 2026-06-08
- What it was used to verify: `--no-optional-locks` behavior.
- Relevant conclusion: The revised helper’s use of `--no-optional-locks` matches official Git guidance.

- Source name: Claude Code CLI reference / headless docs
- URL: <https://code.claude.com/docs/en/cli-usage> and <https://code.claude.com/docs/en/headless>
- Access date: 2026-06-08
- What it was used to verify: `claude -p` / `--print` non-interactive behavior.
- Relevant conclusion: The report-only non-interactive commit guard remains a valid plan requirement.

### Read-only validation performed

- `git --no-optional-locks status --short`: current tree has many tracked doc modifications plus untracked `TODO.md`; Task 0 would stop now.
- `git branch --show-current`, `git log --oneline -n 10`, `git show --stat --oneline -1`: confirmed branch `main` and latest commit is the round-1 plan revision.
- Read `docs/handoff/state.md`, `AGENTS.md`, `docs/handoff/conventions.md`, and `docs/handoff/specs-plans.md`: confirmed repo startup rules, TEST-003, direct-main workflow, and plan/design index.
- Read revised plan and design spec with line numbers: retested all CR-001..CR-005 corrections.
- Inspected up-docs skills/agents/templates/scripts/tests/manifests: confirmed current repo state, version `0.10.1`, existing helper patterns, and target files.
- `git diff -- TODO.md` and `git diff --stat -- TODO.md`: confirmed plain diff emits nothing for the current untracked candidate path.
- `git ls-files plugins/up-docs/tests/fixtures`: confirmed the planned routing fixture would be a new tracked file and is omitted from Task 3 staging.
- `plugins/up-docs/tests/.venv/bin/python --version`, `command -v shellcheck`, `test -x plugins/up-docs/tests/run-bats.sh`: confirmed validation tools exist.

### Recommended implementation validation

- Run only after implementation: `PATH="/usr/bin:/bin:$PATH" bash plugins/up-docs/tests/run-bats.sh plugins/up-docs/tests/convergence-tracker.bats plugins/up-docs/tests/commit-candidates.bats plugins/up-docs/tests/prompt-conformance.bats`
- Run only after implementation: `bash -n plugins/up-docs/scripts/convergence-tracker.sh plugins/up-docs/scripts/commit-candidates.sh && shellcheck -S warning plugins/up-docs/scripts/convergence-tracker.sh plugins/up-docs/scripts/commit-candidates.sh`
- Run only after implementation: `(cd plugins/up-docs/tests && .venv/bin/python -m pytest -q)`
- Run only after implementation: `./scripts/validate-marketplace.sh`
- Run only after implementation: clean-checkout or tracked-state check proving `plugins/up-docs/tests/fixtures/routing-cases.md` is committed.
- Run only after implementation: commit-offer smoke covering modified tracked file, untracked file, untracked directory or nested new file, deleted file, content mutation after disclosure, and headless `-p` report-only behavior.

### Final recommendation

Claude Code should revise the plan using the findings above

### Review ledger for next loop

- Plan path: `/home/chris/projects/Claude-Code-Plugins/docs/plans/2026-06-07-up-docs-orchestration-improvements-plan.md`
- Audit round: 2
- Open issue IDs: CR-001, CR-003, CR-NEW-001, CR-NEW-002, CR-NEW-003
- Resolved issue IDs: CR-002, CR-004, CR-005
- Superseded issue IDs: None
- Significant findings remaining: Yes
- Next audit should focus on: untracked candidate disclosure in the commit offer, routing fixture staging, remaining behavioral validation gaps, repo-skill baseline conformance, and tmpdir git-test hook/signing neutralization.

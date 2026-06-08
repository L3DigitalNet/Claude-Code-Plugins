### Executive summary

Claude Code’s round-3 corrections resolved the routing fixture staging, temp-repo hook/signing neutralization, and `/up-docs:repo` baseline conformance gaps. Significant findings still remain: CR-001 is only partially resolved because the candidate helper still uses Git’s default untracked-file mode, which can surface untracked directories instead of individual files, defeating per-file disclosure/fingerprinting; CR-003 is only partially resolved because the auditor-narrowing behavioral smoke has no concrete tracked target.

New internet research was required for Git `status` untracked-file behavior and re-checking related Git/Claude Code assumptions.

### Verdict

Needs major correction before execution

### Audit loop status

- Audit type: Follow-up audit
- Plan path: `/home/chris/projects/Claude-Code-Plugins/docs/plans/2026-06-07-up-docs-orchestration-improvements-plan.md`
- Prior audit issue count: 8
- Resolved issue count: 6
- Still open issue count: 0
- Partially resolved issue count: 2
- New issue count: 0
- Regression count: 0
- Significant findings remaining: Yes

### Adversarial review performed

Re-read the revised plan, design spec, handoff state, repo conventions, review guidance, current up-docs skills/agents/templates/scripts/tests/manifests, and current Git state. Retested prior fixes for untracked disclosure, behavioral validation, routing fixture staging, temp-repo Git isolation, repo-skill baseline capture, and tracker replacement scope.

I did not run bats/pytest because the relevant tests create temp repos, caches, and artifacts. I did not run any Claude Code Agent or `AskUserQuestion` behavior. Current repository execution is also blocked by unrelated tracked local modifications; Task 0 would stop before implementation.

### Prior findings status

#### CR-001: Commit late re-check does not protect the approved diff content

- Previous severity: High
- Current status: Partially resolved
- Evidence: The plan now discloses single untracked files with `git diff --no-index -- /dev/null <path>` at lines 655-659 and captures/rechecks fingerprints at lines 660-673. However, `commit-candidates.sh` still runs `git --no-optional-locks -C "$1" status --porcelain=v1 -z` without `--untracked-files=all` at line 519. Official Git docs state that when `-u` is not used, Git shows untracked files and directories in `normal` mode, while `all` shows individual files inside untracked directories. The wiki propagator can create new draft pages via `Write` under `wiki/` (`plugins/up-docs/agents/up-docs-propagate-wiki.md` lines 50, 66-68, 149-151). A new untracked directory can therefore become one approved candidate path, not per-file content. The plan has no nested untracked-file/untracked-directory test, and the `fingerprint` command hashes `$path` directly at lines 550-552.
- Remaining action for Claude Code: Change the helper to enumerate individual untracked files, e.g. `git status --porcelain=v1 -z --untracked-files=all`, and add bats/smoke coverage for a nested untracked file under a newly created directory. Make disclosure/fingerprint fail closed if a candidate cannot be shown as exact file content.

#### CR-002: Routing matrix can skip real propagation work for system-of-record-adjacent items

- Previous severity: High
- Current status: Resolved
- Evidence: The routing matrix and CR-002 clarification remain present at lines 316-327, with worked OpenBao/secret/system-of-record cases at lines 337-348.
- Remaining action for Claude Code: None.

#### CR-003: Validation relies on grep assertions where the design requires behavioral fixtures

- Previous severity: Medium
- Current status: Partially resolved
- Evidence: The plan adds an A1 narrowing smoke with pass/fail criteria at line 251 and adds `/up-docs:repo` baseline conformance at lines 613-616 and 682-694. The repo-skill side is resolved. The A1 smoke is still not tied to a concrete tracked file: `rg` found no current manual-smoke notes file, only the historical `plugins/up-docs/docs/phase-2-smoke-result.txt`; Task 2’s file list and `git add` at lines 190-193 and 255-257 do not stage any manual-smoke artifact.
- Remaining action for Claude Code: Name a tracked smoke-check file and stage it, or move the A1 transcript check into Task 7 as an explicit post-implementation validation item with pass/fail criteria. Avoid leaving it as an unattached instruction.

#### CR-004: Baseline files are predictable and `git status` may take optional locks/write index state

- Previous severity: Medium
- Current status: Resolved
- Evidence: Baselines use `mktemp` at lines 685-691, and the helper uses `git --no-optional-locks` at line 519.
- Remaining action for Claude Code: None.

#### CR-005: Task 1 replacement scope can double-count `changes_applied`

- Previous severity: Low
- Current status: Resolved
- Evidence: Task 1 still replaces the whole `fixes` through history block at lines 127-147 and tests exact `changes_applied` at line 76.
- Remaining action for Claude Code: None.

#### CR-NEW-001: Routing fixture is created but never staged

- Previous severity: High
- Current status: Resolved
- Evidence: Task 3’s `git add` now includes `plugins/up-docs/tests/fixtures/routing-cases.md` at line 380, followed by `git ls-files` verification at lines 384-389.
- Remaining action for Claude Code: None.

#### CR-NEW-002: New bats tests create temp git repos without neutralizing global hooks/signing

- Previous severity: Medium
- Current status: Resolved
- Evidence: The planned `commit-candidates.bats` now loads helpers and calls `setup_test_env` at lines 407-410. Current `plugins/up-docs/tests/helpers.bash` exports `GIT_CONFIG_GLOBAL=/dev/null` and `GIT_CONFIG_NOSYSTEM=1` at lines 11-12, matching TEST-003.
- Remaining action for Claude Code: None.

#### CR-NEW-003: `/up-docs:repo` baseline capture is untested

- Previous severity: Medium
- Current status: Resolved
- Evidence: The plan now adds a conformance assertion for `skills/repo/SKILL.md` at lines 613-616, adds the repo-skill baseline instruction at line 694, and stages `skills/repo/SKILL.md` at line 704.
- Remaining action for Claude Code: None.

### New blocking issues

None found.

### New non-blocking issues

None found.

### Regressions

None found.

### Internet research performed

- Source name: Git `git-status` documentation
- URL: https://git-scm.com/docs/git-status
- Access date: 2026-06-08
- What it was used to verify: Porcelain status parsing, `-z`, `--no-optional-locks` context, and default untracked-file behavior.
- Relevant conclusion: Without `--untracked-files=all`, Git’s default reports untracked files and directories, not necessarily individual files inside untracked directories.

- Source name: Git `git-diff` documentation
- URL: https://git-scm.com/docs/git-diff
- Access date: 2026-06-08
- What it was used to verify: `--no-index` behavior for filesystem path comparison.
- Relevant conclusion: `--no-index` is the right family for untracked file disclosure, but the plan still needs individual file candidates.

- Source name: Git documentation
- URL: https://git-scm.com/docs/git
- Access date: 2026-06-08
- What it was used to verify: `--no-optional-locks`.
- Relevant conclusion: The helper’s use of `--no-optional-locks` remains aligned with official Git behavior.

- Source name: Claude Code CLI reference
- URL: https://code.claude.com/docs/en/cli-usage
- Access date: 2026-06-08
- What it was used to verify: `claude -p` / `--print` non-interactive mode.
- Relevant conclusion: The plan’s non-interactive report-only guard remains appropriate.

### Read-only validation performed

- `git --no-optional-locks status --short`: current tree has unrelated tracked doc modifications plus untracked `TODO.md`; Task 0 would stop now.
- `git branch --show-current` and `git log --oneline -n 10`: confirmed branch `main` and recent plan-review commits through round 2.
- Read `docs/handoff/state.md`, `AGENTS.md`, `AGENTS.reviews.md`, `docs/handoff/conventions.md`, and `docs/handoff/specs-plans.md`: confirmed repo startup rules, direct-main workflow, TEST-003, and the indexed design/plan.
- Read the revised plan and design spec with line numbers: retested all prior findings against current text.
- Inspected up-docs skills, agents, templates, scripts, tests, manifests, and changelog: confirmed current implementation state and target files.
- `rg` searches for manual-smoke, transcript, untracked-file, `--no-index`, and `git status` references: found no concrete manual-smoke target and no `--untracked-files=all` usage.
- `git ls-files plugins/up-docs/tests/fixtures`: confirmed the routing fixture is not currently tracked pre-implementation, and the revised plan now stages/verifies it.
- `git diff -- docs/plans/2026-06-07-up-docs-orchestration-improvements-plan.md`: confirmed no uncommitted local delta in the plan file.
- `command -v shellcheck`, `plugins/up-docs/tests/.venv/bin/python --version`, and `test -x plugins/up-docs/tests/run-bats.sh`: confirmed planned validation tooling exists.

### Recommended implementation validation

- Run only after implementation: `PATH="/usr/bin:/bin:$PATH" bash plugins/up-docs/tests/run-bats.sh plugins/up-docs/tests/convergence-tracker.bats plugins/up-docs/tests/commit-candidates.bats plugins/up-docs/tests/prompt-conformance.bats`
- Run only after implementation: add and run a commit-candidates scenario for `newdir/nested.md` proving the helper emits the file path, discloses its content, fingerprints it, and stages only that file.
- Run only after implementation: `bash -n plugins/up-docs/scripts/convergence-tracker.sh plugins/up-docs/scripts/commit-candidates.sh && shellcheck -S warning plugins/up-docs/scripts/convergence-tracker.sh plugins/up-docs/scripts/commit-candidates.sh`
- Run only after implementation: `(cd plugins/up-docs/tests && .venv/bin/python -m pytest -q)`
- Run only after implementation: `./scripts/validate-marketplace.sh`
- Run only after implementation: tracked-state check proving `plugins/up-docs/tests/fixtures/routing-cases.md` is committed.
- Run only after implementation: transcript/manual smoke for A1 narrowing proving pass 2 scans only prior `touched_pages` plus one-hop related dependents.
- Run only after implementation: headless `-p` commit-offer smoke proving report-only and no commit.

### Final recommendation

Claude Code should revise the plan using the findings above

### Review ledger for next loop

- Plan path: `/home/chris/projects/Claude-Code-Plugins/docs/plans/2026-06-07-up-docs-orchestration-improvements-plan.md`
- Audit round: 3
- Open issue IDs: CR-001, CR-003
- Resolved issue IDs: CR-002, CR-004, CR-005, CR-NEW-001, CR-NEW-002, CR-NEW-003
- Superseded issue IDs: None
- Significant findings remaining: Yes
- Next audit should focus on: nested untracked-file/untracked-directory commit disclosure and fingerprinting, plus a concrete tracked or Task-7 validation target for the auditor-narrowing behavioral smoke.

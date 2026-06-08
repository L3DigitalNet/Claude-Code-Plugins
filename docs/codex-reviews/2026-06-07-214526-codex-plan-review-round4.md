### Executive summary

Claude Code’s round-4 revisions resolve the two remaining prior findings: `commit-candidates.sh` now plans `--untracked-files=all` plus nested-untracked coverage for CR-001, and the A1 smoke is now attached to a concrete tracked acceptance document for CR-003.

One new non-blocking safety gap remains in the commit-offer plan: the plan claims literal per-path staging and content-safe late rechecks, but the proposed commands still use normal Git pathspecs and fingerprint only blob content/status, not pathspec interpretation or file mode/type metadata. New internet research was required for Git pathspec, status, diff, and hash-object behavior.

### Verdict

Needs minor correction before execution

### Audit loop status

- Audit type: Follow-up audit
- Plan path: `/home/chris/projects/Claude-Code-Plugins/docs/plans/2026-06-07-up-docs-orchestration-improvements-plan.md`
- Prior audit issue count: 8
- Resolved issue count: 8
- Still open issue count: 0
- Partially resolved issue count: 0
- New issue count: 1
- Regression count: 0
- Significant findings remaining: Yes

### Adversarial review performed

Re-read the revised plan, design spec, repo startup/handoff docs, conventions, review guidance, current up-docs skills/agents/templates/scripts/tests/manifests, and current Git state. Retested prior fixes for nested untracked candidate enumeration, directory fingerprint fail-closed behavior, staged acceptance-smoke target, routing fixture staging, temp-repo hook/signing neutralization, `/up-docs:repo` baseline conformance, and baseline temp-file handling.

I did not run bats/pytest because the relevant tests create temp repos/caches/artifacts. I did not run Claude Code Agent or `AskUserQuestion` behavior. Current repository execution is also blocked by unrelated tracked local modifications; Task 0 would stop before implementation.

### Prior findings status

#### CR-001: Commit late re-check does not protect the approved diff content

- Previous severity: High
- Current status: Resolved
- Evidence: The plan now adds nested-untracked coverage at lines 489-503, changes `dirty_paths()` to `git ... status --porcelain=v1 -z --untracked-files=all` at line 538, documents why directory collapse is unsafe at lines 534-536, and makes `fingerprint` fail closed for directory candidates at lines 569-572. The disclosure/re-fingerprint flow remains present at lines 678-696. Git status docs confirm `--untracked-files=all` shows individual files in untracked directories.
- Remaining action for Claude Code: None for the prior nested-untracked/directory-candidate issue. See CR-NEW-004 for a newly identified edge in the same commit-safety area.

#### CR-002: Routing matrix can skip real propagation work for system-of-record-adjacent items

- Previous severity: High
- Current status: Resolved
- Evidence: The routing matrix still separates secret/live inventory records from references and implementation facts at lines 316-327, with worked OpenBao/secret/system-of-record cases at lines 337-348.
- Remaining action for Claude Code: None.

#### CR-003: Validation relies on grep assertions where the design requires behavioral fixtures

- Previous severity: Medium
- Current status: Resolved
- Evidence: Task 2 now explicitly points A1 to Task 7 Step 1b at lines 249-251. Task 7 creates `plugins/up-docs/docs/0.11.0-acceptance.md` with explicit A1/B/C pass/fail smokes at lines 782-792 and stages it at lines 800-804.
- Remaining action for Claude Code: None.

#### CR-004: Baseline files are predictable and `git status` may take optional locks/write index state

- Previous severity: Medium
- Current status: Resolved
- Evidence: The helper uses `git --no-optional-locks` at line 538, and baseline files are `mktemp`-created at lines 708-714. Git docs confirm `--no-optional-locks` avoids optional lock-taking operations.
- Remaining action for Claude Code: None.

#### CR-005: Task 1 replacement scope can double-count `changes_applied`

- Previous severity: Low
- Current status: Resolved
- Evidence: Task 1 still replaces the full `fixes` through `history.append` block at lines 127-147 and asserts `changes_applied` remains `1` at line 76.
- Remaining action for Claude Code: None.

#### CR-NEW-001: Routing fixture is created but never staged

- Previous severity: High
- Current status: Resolved
- Evidence: Task 3 stages `plugins/up-docs/tests/fixtures/routing-cases.md` at line 380 and verifies it with `git ls-files` at lines 384-389.
- Remaining action for Claude Code: None.

#### CR-NEW-002: New bats tests create temp git repos without neutralizing global hooks/signing

- Previous severity: Medium
- Current status: Resolved
- Evidence: Planned `commit-candidates.bats` loads helpers and calls `setup_test_env` at lines 407-412. Current `plugins/up-docs/tests/helpers.bash` exports `GIT_CONFIG_GLOBAL=/dev/null` and `GIT_CONFIG_NOSYSTEM=1`.
- Remaining action for Claude Code: None.

#### CR-NEW-003: `/up-docs:repo` baseline capture is untested

- Previous severity: Medium
- Current status: Resolved
- Evidence: The plan includes a conformance assertion against `skills/repo/SKILL.md` at lines 636-639, adds the repo-skill baseline instruction at line 717, and stages `skills/repo/SKILL.md` at line 727.
- Remaining action for Claude Code: None.

### New blocking issues

None found.

### New non-blocking issues

#### CR-NEW-004: Commit offer still does not guarantee literal-path or metadata-safe staging

- Severity: Medium
- Status: Confirmed
- Adversarial angle: Validation attack against the “stage only approved, fingerprint-matched paths” safety claim.
- Plan reference: Task 4 `fingerprint` at lines 562-575; Task 5 disclosure/staging flow at lines 678-697; design D8 at `docs/plans/2026-06-07-up-docs-orchestration-improvements-design.md` lines 39 and 104-112.
- Finding: The plan fingerprints only Git status plus `git hash-object` content and stages with `git -C <repo> add -- <path>`. `--` stops option parsing, but it does not make Git pathspecs literal. A candidate path containing Git pathspec metacharacters such as `*`, `?`, brackets, or `:(...)` can be interpreted as a pattern/magic pathspec during `diff`, `status`, or `add`. Separately, `git hash-object` fingerprints blob content, while Git diffs and commits also track file mode/type metadata. A post-disclosure chmod/file-type change under the same path and status can therefore pass the current fingerprint while still staging metadata the user did not approve.
- Repository evidence: The plan’s “paths with spaces” test at lines 458-463 covers shell spacing only, not Git pathspec magic. The proposed `fingerprint` uses `git ... status ... -- "$path"` and `git hash-object -- "$path"` at lines 573-575. The proposed final staging instruction is `git -C <repo> add -- <path>` at line 697. No planned test covers wildcard/pathspec-magic filenames or chmod/mode mutation after disclosure.
- External research evidence: Git glossary documents pathspecs as patterns and says `*`/`?` matching and colon magic are part of pathspec syntax; Git’s top-level docs provide `--literal-pathspecs`; Git diff docs show patch headers include file modes; Git hash-object docs say it computes an object ID from file contents.
- Why it matters: The validation suite could pass while the consent gate still stages a wider path set than the selected candidate or stages undisclosed metadata changes. That weakens the main safety invariant of the new commit offer, even though the common doc-path case is likely fine.
- Recommended action for Claude Code: Update the plan so every per-candidate Git path operation uses literal pathspec handling, e.g. `git -C "$repo" --literal-pathspecs diff/status/add -- "$path"` or explicit `:(literal)` pathspecs. Extend `fingerprint` to include mode/type metadata, not just blob hash/status. Add bats coverage for a literal filename containing glob/pathspec magic and for a chmod/file-mode mutation after disclosure.
- Suggested validation: Add post-implementation bats tests proving a candidate named like `docs/*.md` or `:(top)odd.md` stages only that exact file, and proving a post-disclosure executable-bit change changes the fingerprint or forces re-disclosure.

### Regressions

None found.

### Internet research performed

- Source name: Git `git-status` documentation
- URL: <https://git-scm.com/docs/git-status>
- Access date: 2026-06-08
- What it was used to verify: `--untracked-files=all`, porcelain `-z`, and `--no-optional-locks` context.
- Relevant conclusion: The CR-001 nested-untracked fix is aligned; `all` shows individual files inside untracked directories.

- Source name: Git documentation
- URL: <https://git-scm.com/docs/git>
- Access date: 2026-06-08
- What it was used to verify: `--no-optional-locks` and `--literal-pathspecs`.
- Relevant conclusion: `--no-optional-locks` supports the read-only helper goal; `--literal-pathspecs` is needed when treating candidate strings as literal filenames.

- Source name: Git glossary pathspec documentation
- URL: <https://git-scm.com/docs/gitglossary>
- Access date: 2026-06-08
- What it was used to verify: Git pathspec pattern/magic behavior.
- Relevant conclusion: Plain `<path>` arguments to `git add/diff/status` are pathspecs, not necessarily literal filenames.

- Source name: Git `git-diff` documentation
- URL: <https://git-scm.com/docs/git-diff>
- Access date: 2026-06-08
- What it was used to verify: `--no-index` and patch metadata.
- Relevant conclusion: `--no-index` is appropriate for untracked content disclosure; diffs also expose file mode metadata that the current fingerprint does not cover.

- Source name: Git `git-hash-object` documentation
- URL: <https://git-scm.com/docs/git-hash-object>
- Access date: 2026-06-08
- What it was used to verify: What `hash-object` fingerprints.
- Relevant conclusion: `hash-object` computes a blob ID from file contents, so it is insufficient by itself for mode/type-safe commit approval.

- Source name: Claude Code CLI reference
- URL: <https://code.claude.com/docs/en/cli-reference>
- Access date: 2026-06-08
- What it was used to verify: `claude -p` / print-mode non-interactive behavior.
- Relevant conclusion: The plan’s non-interactive report-only commit guard remains appropriate.

### Read-only validation performed

- `git --no-optional-locks status --short`: current tree has unrelated tracked doc modifications plus untracked `TODO.md`; Task 0 would stop now.
- `git branch --show-current` and `git log --oneline -n 10`: confirmed branch `main` and recent plan-review commits through round 3.
- Read `docs/handoff/state.md`, `AGENTS.md`, `AGENTS.reviews.md`, `docs/handoff/conventions.md`, and `docs/handoff/specs-plans.md`: confirmed repo startup rules, direct-main workflow, TEST-003, and the indexed design/plan.
- Read the revised plan and design spec with line numbers: retested all prior findings against current text.
- Inspected current up-docs skills, agents, templates, scripts, tests, manifests, and changelog: confirmed current implementation state and target files.
- `rg` searches for `--untracked-files=all`, `A1-SMOKE`, `0.11.0-acceptance`, `routing-cases`, `commit-candidates`, `fingerprint`, `no-index`, and `touched-pages`: confirmed the revised plan includes the prior requested fixes and found the remaining pathspec/fingerprint gap.
- `git ls-files plugins/up-docs/tests/fixtures plugins/up-docs/docs/0.11.0-acceptance.md plugins/up-docs/scripts/commit-candidates.sh plugins/up-docs/tests/commit-candidates.bats`: confirmed the new fixture/acceptance/helper/test files are not tracked pre-implementation and must be staged by the plan.
- `git diff -- docs/plans/2026-06-07-up-docs-orchestration-improvements-plan.md`: confirmed no uncommitted local delta in the plan file.
- `command -v shellcheck`, `plugins/up-docs/tests/.venv/bin/python --version`, `test -x plugins/up-docs/tests/run-bats.sh`, and manifest version grep: confirmed planned validation tooling exists and current up-docs version is `0.10.1`.

### Recommended implementation validation

- Run only after implementation: `PATH="/usr/bin:/bin:$PATH" bash plugins/up-docs/tests/run-bats.sh plugins/up-docs/tests/convergence-tracker.bats plugins/up-docs/tests/commit-candidates.bats plugins/up-docs/tests/prompt-conformance.bats`
- Run only after implementation: add and run commit-candidates scenarios for nested untracked files, literal pathspec-magic filenames, and chmod/mode mutation after disclosure.
- Run only after implementation: `bash -n plugins/up-docs/scripts/convergence-tracker.sh plugins/up-docs/scripts/commit-candidates.sh && shellcheck -S warning plugins/up-docs/scripts/convergence-tracker.sh plugins/up-docs/scripts/commit-candidates.sh`
- Run only after implementation: `(cd plugins/up-docs/tests && .venv/bin/python -m pytest -q)`
- Run only after implementation: `./scripts/validate-marketplace.sh`
- Run only after implementation: tracked-state check proving `plugins/up-docs/tests/fixtures/routing-cases.md` and `plugins/up-docs/docs/0.11.0-acceptance.md` are committed.
- Run only after implementation: transcript/manual smoke for A1 narrowing proving pass 2 scans only prior `touched_pages` plus one-hop related dependents.
- Run only after implementation: headless `-p` commit-offer smoke proving report-only and no commit.

### Final recommendation

Claude Code should revise the plan using the findings above

### Review ledger for next loop

- Plan path: `/home/chris/projects/Claude-Code-Plugins/docs/plans/2026-06-07-up-docs-orchestration-improvements-plan.md`
- Audit round: 4
- Open issue IDs: CR-NEW-004
- Resolved issue IDs: CR-001, CR-002, CR-003, CR-004, CR-005, CR-NEW-001, CR-NEW-002, CR-NEW-003
- Superseded issue IDs: None
- Significant findings remaining: Yes
- Next audit should focus on: literal Git pathspec handling and metadata-inclusive fingerprinting for the consent-gated commit offer.

### Executive summary

The implementation plan is not ready for Claude Code to execute as written. The repo fit is mostly sound, but two blocking validation/safety defects remain in the proposed `record-red`/`record-green` implementation: the default pytest RED path can accept unrelated nonzero commands as valid RED evidence, and timeout handling can crash instead of recording a rejected gate when a timed-out process emitted output.

Internet research was required for current `uv`, Claude Code plugin, and Python `subprocess` behavior. The major stale-assumption finding is in Python timeout handling, where official docs contradict the plan’s string-concatenation implementation.

### Verdict

Needs major correction before execution

### Audit loop status

* Audit type: First audit
* Plan path: `/home/chris/projects/Claude-Code-Plugins/docs/superpowers/plans/2026-07-01-spec-pipeline-plugin.md`
* Significant findings remaining: Yes
* Blocking issue count: 2
* Non-blocking issue count: 3

### What the plan gets right

* The proposed plugin root layout matches Claude Code plugin docs: `plugin.json` under `.claude-plugin/`, with `skills/`, `commands/`, `references/`, `templates/`, and `scripts/` at plugin root.
* The source skill paths exist, and the shared `spec-construction.md` files are byte-identical by SHA-256.
* The plan correctly keeps `specpipe` out of Python project machinery and uses `uv run --no-project`; official uv docs confirm this avoids project/workspace discovery.
* The plan adds both local marketplace validation and `claude plugin validate --strict`, which is aligned with current Claude Code plugin validation guidance.
* The worktree is clean on `main`, matching the repo’s direct-commit workflow.

### Adversarial review performed

Performed claim inventory, repository falsification, blast-radius, failure-mode, validation-attack, external-assumption, and maintainability passes. I checked the plan against the governing spec, source skills in `agent-configs`, marketplace metadata, repo validation scripts, plugin docs, markdown tooling rules, git status/history, and official docs for Claude Code plugins, uv, and Python subprocess behavior.

Could not execute implementation tests, formatters, `claude plugin validate`, or `specpipe` because the plugin is not implemented yet and those commands would either fail for missing files or may write caches/artifacts. I treated them as recommended post-implementation validation instead.

### Blocking issues

#### CR-001: Pytest RED path accepts unrelated nonzero commands as valid RED evidence

* Severity: High
* Status: Confirmed
* Adversarial angle: Can the RED gate pass while no failing test was actually proven?
* Plan reference: [docs/superpowers/plans/2026-07-01-spec-pipeline-plugin.md](/home/chris/projects/Claude-Code-Plugins/docs/superpowers/plans/2026-07-01-spec-pipeline-plugin.md:1735)
* Finding: The plan claims `record-red` establishes a genuine assertion/missing-symbol RED for pytest, but the proposed implementation only rejects known collection/import/syntax signatures. Any other nonzero command under the default `framework="pytest"` is accepted. The plan’s own `test_command_string_redacted` expects `python -c "raise SystemExit(1)"` to return success as RED, proving the false-positive path.
* Repository evidence: Plan lines 1735 and 1884-1886 state the fails-for-the-right-reason contract. Lines 1834-1839 add a passing test for a non-pytest `SystemExit(1)` command using the default framework. Lines 1971-1989 accept every default-framework nonzero return that does not match `COLLECTION_ERROR_RE`.
* External research evidence: Not applicable.
* Why it matters: This undermines the central TDD evidence trail. A runner crash, setup failure, “no tests collected,” or arbitrary `exit 1` can be committed as RED evidence.
* Recommended action for Claude Code: Require a positive failure signature for RED. Prefer making `--expect-failure-regex` mandatory for all `record-red` calls, including pytest, or add a pytest-specific positive classifier plus adversarial rejection tests for empty output, no tests collected, config errors, command-not-found, and non-pytest commands.
* Suggested validation: Add tests proving default pytest mode rejects bare `SystemExit(1)`, pytest “no tests ran,” pytest config/plugin errors, and empty-output nonzero failures unless an expected failure regex is supplied and matched.

#### CR-002: Timeout handling can crash instead of recording a rejected gate

* Severity: High
* Status: Confirmed
* Adversarial angle: Does the safety contract hold when a timed-out command emits partial output?
* Plan reference: [docs/superpowers/plans/2026-07-01-spec-pipeline-plugin.md](/home/chris/projects/Claude-Code-Plugins/docs/superpowers/plans/2026-07-01-spec-pipeline-plugin.md:1958)
* Finding: The `TimeoutExpired` handler concatenates `exc.stdout` / `exc.stderr` with strings. Python documents those timeout attributes as bytes when captured, even with `text=True`. A timed-out process that emitted output can raise `TypeError`, skip `_append`, and fail to record the rejected timeout.
* Repository evidence: Plan line 1735 promises timeout rejection and rejected-attempt recording. Lines 1958-1963 build `output` directly from `exc.stdout` and `exc.stderr`. The only timeout test at lines 1814-1818 sleeps without output, so it misses the bytes/str edge case.
* External research evidence: Python `subprocess.TimeoutExpired` docs state captured timeout output is bytes regardless of `text=True`: https://docs.python.org/3/library/subprocess.html#subprocess.TimeoutExpired, accessed 2026-07-01.
* Why it matters: Timeout recording is part of the audit-file safety contract. A noisy hung test can produce an unhandled traceback and no committed evidence.
* Recommended action for Claude Code: Normalize timeout output with a helper that decodes bytes safely before concatenation, then add a test where the child prints to stdout/stderr before sleeping past the timeout.
* Suggested validation: Add a fixture command that prints output, flushes, then sleeps; assert `record(..., timeout=...) == 1`, the audit file exists, contains `REJECTED`, and contains redacted/decoded output without traceback.

### Non-blocking issues

#### CR-003: CLI does not implement the spec’s “every subcommand supports --json” contract

* Severity: Medium
* Status: Confirmed
* Adversarial angle: Can documented automation flags fail at runtime while tests pass?
* Plan reference: [docs/superpowers/plans/2026-07-01-spec-pipeline-plugin.md](/home/chris/projects/Claude-Code-Plugins/docs/superpowers/plans/2026-07-01-spec-pipeline-plugin.md:317)
* Finding: The governing spec and README say every subcommand supports `--json`, but the parser only adds `--json` to `validate`, `next-phase`, and `status`. `set-status`, `record-red`, `record-green`, `rounds`, and `init-project` lack it. The spec also names `rounds --check`; the parser has no explicit `--check`.
* Repository evidence: Spec lines 82 and 98 define the contract. Plan lines 326, 333, 338, 343, and 356 are the only parser `--json` registrations; README text at line 2938 repeats the all-subcommands claim.
* External research evidence: Not applicable.
* Why it matters: The plan can pass its current dispatch tests while shipping a CLI that contradicts the source-of-truth spec and its own README.
* Recommended action for Claude Code: Either implement `--json` for all subcommands and add dispatch/behavior tests, or narrow the spec/README to the subcommands that actually support JSON. Add `--check` or revise the spec to define “check” as omitting `--increment`.
* Suggested validation: Test each subcommand with `--json`; test `rounds --check` or the explicitly documented replacement.

#### CR-004: Plan validator permits commit/gate before GREEN

* Severity: Medium
* Status: Confirmed
* Adversarial angle: Can `validate plan` pass a task whose commit step is out of TDD order?
* Plan reference: [docs/superpowers/plans/2026-07-01-spec-pipeline-plugin.md](/home/chris/projects/Claude-Code-Plugins/docs/superpowers/plans/2026-07-01-spec-pipeline-plugin.md:1607)
* Finding: `_tdd_ok` checks for `write-test -> run-fail -> implement -> run-pass`, then only checks that `"commit"` appears somewhere. A commit step before RED or before GREEN can still pass.
* Repository evidence: Plan lines 1572-1575 claim TDD order includes commit; lines 1607-1613 implement commit as unordered membership; lines 1678-1681 emit an error message that does not enforce commit placement.
* External research evidence: Not applicable.
* Why it matters: The validator can approve plans that commit before the task is green, weakening the deterministic TDD-order guarantee.
* Recommended action for Claude Code: Treat commit/gate as the final ordered element after `run-pass`, or explicitly document that commit placement is not mechanized and downgrade the claim.
* Suggested validation: Add failing fixtures where `Commit` appears before the failing run and before the passing run.

#### CR-005: Final markdown/tooling gate omits the repo’s required markdownlint fix pass and has an incomplete staging path

* Severity: Medium
* Status: Confirmed
* Adversarial angle: Can formatting/lint remediation happen but be left uncommitted or outside repo convention?
* Plan reference: [docs/superpowers/plans/2026-07-01-spec-pipeline-plugin.md](/home/chris/projects/Claude-Code-Plugins/docs/superpowers/plans/2026-07-01-spec-pipeline-plugin.md:3026)
* Finding: The repo instructions require `npx prettier --write .` and `npx markdownlint-cli2 --fix "**/*.md"` before checks. The plan runs `npm run format` and markdownlint check, but not markdownlint `--fix`. It also says to include files rewritten by format in the commit, but Task 14’s final `git add` stages only `docs/handoff/specs-plans.md`.
* Repository evidence: AGENTS.md lines 27-40 define the fix/check contract. Plan lines 3028-3036 omit markdownlint `--fix`; lines 3060-3062 stage only the handoff index.
* External research evidence: Not applicable.
* Why it matters: The final gate can leave plugin files dirty after formatting/fixes, or fail to follow the repo’s markdown tooling standard.
* Recommended action for Claude Code: Add the markdownlint fix pass to Task 14 and make the final staging step include any plugin files changed by formatting/lint fixes, after inspecting `git status --short`.
* Suggested validation: After final formatting/lint fixes, run `git status --short`, rerun the test suite if plugin templates changed, then stage explicit changed paths.

### Missing considerations

* Blocking: RED evidence needs positive failure verification, not only collection-error rejection.
* Blocking: Timeout tests need partial stdout/stderr coverage.
* Non-blocking: JSON output behavior must be tested for every documented CLI subcommand or the docs/spec must be narrowed.
* Non-blocking: TDD-order tests should include commit-before-green false positives.
* Non-blocking: Final gate should include `npx markdownlint-cli2 --fix "**/*.md"` and explicit staging of any formatter/linter rewrites.

### Internet research performed

* Source name: Python subprocess documentation
* URL: https://docs.python.org/3/library/subprocess.html#subprocess.TimeoutExpired
* Access date: 2026-07-01
* What it was used to verify: `TimeoutExpired.stdout` / `stderr` typing under captured output.
* Relevant conclusion: Captured timeout output is bytes even with `text=True`, contradicting the plan’s timeout concatenation.

* Source name: uv CLI reference
* URL: https://docs.astral.sh/uv/reference/cli/#uv-run
* Access date: 2026-07-01
* What it was used to verify: `uv run` project behavior and `--no-project`.
* Relevant conclusion: `uv run` creates/updates project environments when used in a project; `--no-project` avoids project/workspace discovery.

* Source name: Claude Code plugin docs
* URL: https://code.claude.com/docs/en/plugins
* Access date: 2026-07-01
* What it was used to verify: Plugin structure and local plugin validation guidance.
* Relevant conclusion: Plugin component directories belong at plugin root, and `claude plugin validate` is the recommended local validation before submission.

* Source name: Claude Code plugins reference
* URL: https://code.claude.com/docs/en/plugins-reference
* Access date: 2026-07-01
* What it was used to verify: Component path behavior, `${CLAUDE_PLUGIN_ROOT}`, and `--strict`.
* Relevant conclusion: `${CLAUDE_PLUGIN_ROOT}` is for bundled plugin files and should be treated as ephemeral; `claude plugin validate ./my-plugin --strict` is documented for CI-style warning-as-error validation.

### Items Claude Code should verify before correcting the plan

* Whether the intended `record-red` UX should require `--expect-failure-regex` for all RED captures or only for non-pytest runners.
* Whether `--json` is truly required for operational subcommands like `record-red`, `record-green`, and `init-project`.
* Whether the repo’s current Claude CLI version accepts the proposed `plugin.json` fields under `--strict`.
* Whether `npm run format` rewrites any planned Markdown/JSON snippets before the final commit.
* Whether final `specpipe` tests should assert no dirty plugin files after format/lint fixes separately from AC9 generated-artifact checks.

### Suggested corrections for Claude Code's plan

* Strengthen `record-red` so default pytest mode cannot accept arbitrary nonzero commands as RED.
* Add RED false-positive tests: no tests collected, bare `SystemExit(1)`, pytest config error, command-not-found, and empty-output failure.
* Decode `TimeoutExpired` stdout/stderr safely and add a noisy-timeout test.
* Implement or remove the universal `--json` claim; align `rounds --check`.
* Enforce commit/gate ordering after `run-pass` in `plandoc`.
* Add the markdownlint fix pass and broaden Task 14 staging to include any plugin files changed by format/lint.

### Read-only validation performed

* `pwd`, `git branch --show-current`, `git status --short`, `git log --oneline -n 10`: confirmed repo root, branch `main`, clean worktree, and recent spec-pipeline commits.
* `git diff --stat`, `git diff --check`: confirmed no current unstaged diff or whitespace-error diff.
* Read the implementation plan with line-numbered `nl -ba` chunks and `rg`: inventoried all 14 tasks, CLI code, validators, templates, skill edits, and acceptance gates.
* Read the governing spec: checked plan/spec contract mismatches for `record-red`, `--json`, `rounds`, and acceptance criteria.
* Read `.claude-plugin/marketplace.json` and `scripts/validate-marketplace.sh`: confirmed marketplace shape and local manifest/version validation.
* Listed `plugins/` and checked `plugins/spec-pipeline` absence: confirmed this is a new plugin.
* Read source skill files and reference file hashes under `/home/chris/projects/agent-configs/skills/.claude/skills`: confirmed source paths and dedupe claim.
* Read `AGENTS.md`, `docs/handoff/conventions.md`, `.prettierrc.json`, `.prettierignore`, `.markdownlint.json`, README/plugin docs, and branch workflow docs: checked repo conventions and validation expectations.
* Used official external docs for Python subprocess, uv, and Claude Code plugin behavior.

### Recommended implementation validation

* Run only after implementation: `bash plugins/spec-pipeline/tests/run_tests.sh -v`.
* Run only after implementation: add adversarial `record-red` tests for false REDs and noisy timeouts, then rerun the wrapper.
* Run only after implementation: `bash scripts/validate-marketplace.sh`.
* Run only after implementation: `claude plugin validate --strict plugins/spec-pipeline`.
* Run only after implementation: `npx prettier --write .` and `npx markdownlint-cli2 --fix "**/*.md"`, then `npx prettier --check .` and `npx markdownlint-cli2 "**/*.md"`.
* Run only after implementation: `PYTHONPATH="$PWD/plugins/spec-pipeline/scripts/specpipe" uv run --no-project python -B -m specpipe --help >/dev/null`.
* Run only after implementation: `git status --short --ignored plugins/spec-pipeline` and explicit `find` checks for `.venv`, `uv.lock`, `.pytest_cache`, `.ruff_cache`, and `__pycache__`.

### Final recommendation

Claude Code should revise the plan using the findings above

### Review ledger for next loop

* Plan path: `/home/chris/projects/Claude-Code-Plugins/docs/superpowers/plans/2026-07-01-spec-pipeline-plugin.md`
* Audit round: 1
* Open issue IDs: CR-001, CR-002, CR-003, CR-004, CR-005
* Resolved issue IDs: None
* Superseded issue IDs: None
* Significant findings remaining: Yes
* Next audit should focus on: `record-red` positive RED verification, noisy-timeout handling, `--json` / `rounds --check` contract alignment, TDD commit-order enforcement, and final markdown tooling/staging fixes.


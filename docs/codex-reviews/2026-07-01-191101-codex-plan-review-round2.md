### Executive summary

Claude Code’s corrections substantively resolved all five prior findings. The revised plan now aligns the governing spec, CLI parser, README contract, RED/GREEN evidence handling, TDD commit ordering, and final markdown/tooling gate.

New internet research was performed against the same authoritative external assumptions; no new stale-assumption conflict was found.

### Verdict

No significant findings remain

### Audit loop status

* Audit type: Follow-up audit
* Plan path: `/home/chris/projects/Claude-Code-Plugins/docs/superpowers/plans/2026-07-01-spec-pipeline-plugin.md`
* Prior audit issue count: 5
* Resolved issue count: 5
* Still open issue count: 0
* Partially resolved issue count: 0
* New issue count: 0
* Regression count: 0
* Significant findings remaining: No

### Adversarial review performed

Retested all prior findings against the revised plan and governing spec. Rechecked `record-red` positive pytest failure verification, noisy timeout handling, CLI `--json` contract alignment, `rounds` read-only check semantics, TDD commit-after-green enforcement, and final markdownlint/format/staging gates.

Also rechecked repository reality: branch/worktree status, absence of an implemented `plugins/spec-pipeline/` tree, source skill paths, reference-file hashes, marketplace validation script behavior, repo markdown tooling rules, and handoff index entries.

Could not execute `specpipe`, plugin tests, formatters, or `claude plugin validate` because the plugin is not implemented yet and several validation commands may write caches or formatting changes. These remain implementation-time validation steps.

### Prior findings status

#### CR-001: Pytest RED path accepts unrelated nonzero commands as valid RED evidence

* Previous severity: High
* Current status: Resolved
* Evidence: The plan now requires a positive pytest failure marker for RED, not just nonzero exit, at plan lines 1750 and 1933-1936. It adds adversarial tests for arbitrary nonzero commands and pytest “no tests ran” at lines 1862-1875. The implementation rejects pytest RED without `PYTEST_FAILURE_RE` at lines 2037-2048, after collection-error rejection.
* Remaining action for Claude Code: None beyond running the planned tests after implementation.

#### CR-002: Timeout handling can crash instead of recording a rejected gate

* Previous severity: High
* Current status: Resolved
* Evidence: The plan adds a noisy timeout test at lines 1878-1890. The implementation adds `_to_text()` to decode timeout stdout/stderr defensively at lines 1976-1982 and uses it in the `TimeoutExpired` handler at lines 2021-2029. Python’s official subprocess docs still confirm timeout-captured output may be bytes despite `text=True`.
* Remaining action for Claude Code: None beyond running the planned noisy-timeout test after implementation.

#### CR-003: CLI does not implement the spec’s “every subcommand supports --json” contract

* Previous severity: Medium
* Current status: Resolved
* Evidence: The governing spec now narrows `--json` to query subcommands only at spec line 82, and defines `rounds` check mode as omitting `--increment` at spec line 98. The parser matches that shape: `--json` appears on `validate`, `next-phase`, and `status` at plan lines 324-356, while mutating/state subcommands omit it. The README text now states the same query/state split at plan line 3011.
* Remaining action for Claude Code: None.

#### CR-004: Plan validator permits commit/gate before GREEN

* Previous severity: Medium
* Current status: Resolved
* Evidence: The plan adds a failing fixture for commit-before-green at lines 1520-1526. `_tdd_ok()` now only counts a commit after the full `write-test → run-fail → implement → run-pass` chain completes at lines 1616-1627, and the emitted error text names commit after the passing run at lines 1692-1696.
* Remaining action for Claude Code: None.

#### CR-005: Final markdown/tooling gate omits the repo’s required markdownlint fix pass and has an incomplete staging path

* Previous severity: Medium
* Current status: Resolved
* Evidence: `AGENTS.md` requires `npx prettier --write .` plus `npx markdownlint-cli2 --fix "**/*.md"` before non-mutating checks at lines 27-40. Task 14 now includes both fix passes and checks at plan lines 3104-3108, tells Claude Code to rerun tests if fixers rewrite files at line 3111, and stages `docs/handoff/specs-plans.md` plus each rewritten path explicitly at lines 3135-3139.
* Remaining action for Claude Code: None.

### New blocking issues

None found.

### New non-blocking issues

None found.

### Regressions

None found.

### Internet research performed

* Source name: Python subprocess documentation
* URL: https://docs.python.org/3/library/subprocess.html#subprocess.TimeoutExpired
* Access date: 2026-07-01
* What it was used to verify: Timeout output typing for `TimeoutExpired.stdout` / `stderr`.
* Relevant conclusion: Captured timeout output may be bytes regardless of `text=True`; the revised `_to_text()` handling is appropriate.

* Source name: uv CLI reference
* URL: https://docs.astral.sh/uv/reference/cli/#uv-run
* Access date: 2026-07-01
* What it was used to verify: `uv run`, project discovery, and `--no-project` assumptions.
* Relevant conclusion: `uv run` updates project environments when used in a project; `--no-project` avoids project/workspace discovery, matching the plan’s no-plugin-tree-state design.

* Source name: Claude Code plugin docs
* URL: https://code.claude.com/docs/en/plugins
* Access date: 2026-07-01
* What it was used to verify: Plugin structure and validation expectations.
* Relevant conclusion: `plugin.json` belongs under `.claude-plugin/`, component directories belong at plugin root, and local plugin validation before submission is documented.

* Source name: Claude Code plugins reference
* URL: https://code.claude.com/docs/en/plugins-reference
* Access date: 2026-07-01
* What it was used to verify: Manifest behavior and `claude plugin validate --strict`.
* Relevant conclusion: Strict validation treats warning-level schema issues as errors, which supports the plan’s final acceptance gate.

### Read-only validation performed

* `git branch --show-current`, `git status --short`, `git log --oneline -n 10`: confirmed branch `main`, clean worktree, and the latest plan-fix commit.
* `git diff --stat`, `git diff --check`: confirmed no current unstaged diff or whitespace-error diff.
* `rg` and line-numbered reads of the plan and spec: retested all prior findings against current plan/spec text.
* Read `AGENTS.md`, `docs/handoff/conventions.md`, `docs/handoff/specs-plans.md`, `.prettierignore`, `.markdownlint-cli2.jsonc`, marketplace JSON, and `scripts/validate-marketplace.sh`: confirmed repo conventions and validation expectations.
* Listed `plugins/` and checked `plugins/spec-pipeline`: confirmed this remains a proposed new plugin, not implemented code.
* Checked source skill paths and SHA-256 hashes under `agent-configs`: confirmed referenced source files exist and the shared `spec-construction.md` copies are byte-identical.
* Opened official Python, uv, and Claude Code plugin documentation for current external assumptions.

### Recommended implementation validation

* Run only after implementation: `bash plugins/spec-pipeline/tests/run_tests.sh -v`.
* Run only after implementation: `bash scripts/validate-marketplace.sh`.
* Run only after implementation: `claude plugin validate --strict plugins/spec-pipeline`.
* Run only after implementation: `npx prettier --write .` and `npx markdownlint-cli2 --fix "**/*.md"`, then `npx prettier --check .` and `npx markdownlint-cli2 "**/*.md"`.
* Run only after implementation: `PYTHONPATH="$PWD/plugins/spec-pipeline/scripts/specpipe" uv run --no-project python -B -m specpipe --help >/dev/null`.
* Run only after implementation: `git status --short --ignored plugins/spec-pipeline` plus `find plugins/spec-pipeline \( -name .venv -o -name uv.lock -o -name .pytest_cache -o -name .ruff_cache -o -name __pycache__ \)`.

### Final recommendation

No significant findings remain; the audit/fix loop can stop

### Review ledger for next loop

* Plan path: `/home/chris/projects/Claude-Code-Plugins/docs/superpowers/plans/2026-07-01-spec-pipeline-plugin.md`
* Audit round: 2
* Open issue IDs: None
* Resolved issue IDs: CR-001, CR-002, CR-003, CR-004, CR-005
* Superseded issue IDs: None
* Significant findings remaining: No
* Next audit should focus on: None; proceed to implementation with the validation gates above.
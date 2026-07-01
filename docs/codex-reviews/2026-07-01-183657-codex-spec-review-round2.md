### Executive summary

Claude Code’s corrections resolved the three prior blocking findings and two of the three prior non-blocking findings. One prior Medium finding remains partially resolved: `--framework generic` now documents the limitation, but it can still accept runner/setup failures as valid RED evidence for bats/Jest/other non-pytest projects. New internet research was required for the `uv run` invocation claim; official uv docs contradict the spec’s “nothing to resolve” assumption because `uv run` automatically locks and syncs project environments.

### Verdict

Needs minor specification correction before planning/implementation

### Audit loop status

* Audit type: Follow-up audit
* Spec path: `/home/chris/projects/Claude-Code-Plugins/docs/superpowers/specs/2026-07-01-spec-pipeline-plugin-design.md`
* Prior audit issue count: 6
* Resolved issue count: 5
* Still open issue count: 0
* Partially resolved issue count: 1
* New issue count: 1
* Regression count: 0
* Significant findings remaining: Yes

### Adversarial review performed

Retested all prior fixes against the revised spec, the source `agent-configs` skills, handoff conventions, marketplace validator, local Claude/uv CLI help, and official Claude Code and uv documentation. Re-attacked acceptance criteria for false positives around RED evidence, stale `in_progress` recovery, official plugin validation, non-default handoff layouts, and runtime command side effects.

Could not safely test actual plugin loading or specpipe execution because `plugins/spec-pipeline/` does not exist yet and `uv run` / plugin loading can write local state.

### Prior findings status

#### SA-001: Structural validator scope does not cover the master-spec coverage contract

* Previous severity: High
* Current status: Resolved
* Evidence: Spec lines 22 and 31 now explicitly exclude requirement/scope coverage from mechanized validation and leave it to the review panel; line 191 records a future v2 coverage validator only if needed.
* Remaining action for Claude Code: None.

#### SA-002: Phase status transitions can strand execution after partial failure

* Previous severity: High
* Current status: Resolved
* Evidence: Spec lines 94-95 define resume-first `next-phase`, `in_progress→pending`, `in_progress→blocked`, and `blocked→in_progress`; line 148 defines reassessment/abandon behavior; line 170 requires recovery fixtures.
* Remaining action for Claude Code: None.

#### SA-003: RED/GREEN evidence capture lacks a command-safety and redaction contract

* Previous severity: High
* Current status: Resolved
* Evidence: Spec lines 102-112 now define no-shell argv execution, cwd, timeout, output cap, redaction, single-write append, and rejected evidence labeling; line 171 requires adversarial tests for timeout, inert metacharacters, and redaction.
* Remaining action for Claude Code: None beyond implementing the specified tests.

#### SA-004: RED failure classification is pytest-specific despite generic command input

* Previous severity: Medium
* Current status: Partially resolved
* Evidence: Spec line 97 adds `--framework pytest|generic`, but `generic` accepts any non-zero exit as RED. That is weaker than the source executor’s rule that RED must fail for the right reason, not collection/import/syntax/setup failure (`autonomous-phase-execution/SKILL.md:69`). Repo convention TEST-001 also treats bats, pytest, and Jest as canonical frameworks (`docs/handoff/conventions.md:126-139`).
* Remaining action for Claude Code: Add a generic expected-failure contract, such as `--expect-failure-regex`, or specific adapters for bats/Jest; at minimum reject runner/setup failures that are not test assertions.

#### SA-005: Layout-agnostic state handling is incomplete for round counters and status

* Previous severity: Medium
* Current status: Resolved
* Evidence: Spec line 96 adds `status <phase-plan> [--state <path>]` with upward search from the phase-plan directory; line 128 states subcommands take explicit phase-plan/audit paths and `init-project --handoff-dir` locates audit beside the phase plan.
* Remaining action for Claude Code: None.

#### SA-006: Acceptance omits the current official plugin validator and repeats stale local validation assumptions

* Previous severity: Medium
* Current status: Resolved
* Evidence: Spec lines 173-174 and 183 require both `validate-marketplace.sh` and `claude plugin validate --strict plugins/spec-pipeline`; local `scripts/validate-marketplace.sh:161-187` validates plugin manifests; local `claude plugin validate --help` confirms `--strict`.
* Remaining action for Claude Code: None.

### New blocking issues

None found.

### New non-blocking issues

#### SA-NEW-001: `uv run --directory` may write lock and environment state despite the stdlib-only claim

* Severity: Medium
* Status: Confirmed
* Adversarial angle: Can the validator command dirty the repo or plugin cache even though the spec claims zero dependency resolution?
* Spec reference: Lines 60 and 70.
* Finding: The spec says `uv run` has “nothing to resolve” because specpipe is stdlib-only, but `uv run` in a project with `pyproject.toml` still performs automatic lock and sync unless flags prevent it. The spec does not say whether `uv.lock` is committed, whether `--locked`, `--frozen`, `--no-sync`, or `--no-project` is required, or how to prevent `.venv`/`uv.lock` churn in source or installed plugin cache.
* Repository evidence: The proposed layout includes `scripts/specpipe/pyproject.toml` but no `uv.lock` in the spec. Root `.gitignore` ignores `.venv/` but not `uv.lock`. `uv run --help` locally exposes `--locked`, `--frozen`, `--no-sync`, and `--no-project`.
* External research evidence: Official uv docs state `uv run` locks and syncs before running commands. Official Claude Code plugin docs say `${CLAUDE_PLUGIN_ROOT}` points at the installed plugin directory and should not be used for persistent state.
* Why it matters: The first validator run can create or update artifacts, dirtying the repo or plugin cache and undermining the “deterministic and fast” validation claim. In a stricter installed-plugin context, writing into the plugin root may also be brittle.
* Recommended action for Claude Code: Specify the runtime contract: either commit a lockfile and use `--locked`/`--frozen`, or use a no-project/no-sync invocation that avoids plugin-root writes. Add an acceptance check proving specpipe help/validation leaves `plugins/spec-pipeline/scripts/specpipe` clean.
* Suggested validation: After implementation, run the finalized specpipe invocation in a clean tree and verify `git status --short plugins/spec-pipeline/scripts/specpipe` stays empty.

### Regressions

None found.

### Remaining ambiguities and decisions needed

* Ambiguity: How should non-pytest RED evidence prove “right reason” failure?
* Why it matters: `generic` can pass on setup failures that do not prove TDD RED.
* Recommended clarification: Require `--expect-failure-regex` for `generic`, or define bats/Jest adapters.
* Blocking or non-blocking: Non-blocking.

* Ambiguity: Is specpipe meant to be a uv project with committed lockfile, or a stdlib module run without uv project lock/sync?
* Why it matters: It determines whether validator gates are non-mutating and reproducible.
* Recommended clarification: Pin the exact invocation and artifact policy.
* Blocking or non-blocking: Non-blocking.

### Internet research performed

* Source name: Claude Code Docs — Create plugins
* URL: https://code.claude.com/docs/en/plugins
* Access date: 2026-07-01
* What it was used to verify: Plugin layout, namespacing, local `--plugin-dir` testing, and `claude plugin validate`.
* Relevant conclusion: The revised plugin validation acceptance is aligned with current docs.

* Source name: Claude Code Docs — Plugins reference
* URL: https://code.claude.com/docs/en/plugins-reference
* Access date: 2026-07-01
* What it was used to verify: Component locations, `${CLAUDE_PLUGIN_ROOT}`, CLI validation commands.
* Relevant conclusion: Plugin root paths are valid for bundled files, but plugin-root writes should not be relied on for persistent state.

* Source name: uv Docs — Running commands
* URL: https://docs.astral.sh/uv/concepts/projects/run/
* Access date: 2026-07-01
* What it was used to verify: `uv run` project-environment behavior.
* Relevant conclusion: `uv run` ensures the project environment is up to date before command execution.

* Source name: uv Docs — Locking and syncing
* URL: https://docs.astral.sh/uv/concepts/projects/sync/
* Access date: 2026-07-01
* What it was used to verify: Automatic lock/sync behavior and flags.
* Relevant conclusion: `uv run` automatically locks and syncs unless `--locked`, `--frozen`, or `--no-sync` changes behavior.

### Read-only validation performed

* `pwd`, `git branch --show-current`, `git log --oneline -n 10`: Confirmed repo root and branch `main`; latest commit is the spec revision.
* `git status --short`, `git diff --stat`, `git diff --check`: Found one unrelated/in-progress plan-file diff; no whitespace errors.
* Read target spec with line numbers: Verified revised requirements and prior ledger.
* Read `docs/handoff/state.md`, `conventions.md`, `specs-plans.md`, `architecture.md`, `credentials.md`: Verified repo conventions, test frameworks, marketplace expectations, and current docs.
* Read source `agent-configs` skills and standards: Verified versions, phase-plan contract, TDD RED rule, and master coverage obligation.
* `sha256sum` on duplicated `spec-construction.md`: Confirmed source copies remain byte-identical.
* Read `.claude-plugin/marketplace.json` and `scripts/validate-marketplace.sh`: Confirmed actual marketplace/manifest validation behavior.
* `claude --version`, `claude plugin --help`, `claude plugin validate --help`: Confirmed Claude Code 2.1.198 and `--strict`.
* `uv --version`, `uv run --help`, `python3 --version`: Confirmed uv 0.11.6, uv run flags, and Python 3.14.6.
* `find plugins/spec-pipeline`: Confirmed proposed plugin directory does not yet exist.
* Official web docs: Rechecked Claude Code plugin behavior and uv run lock/sync behavior.

### Recommended planning/implementation validation

* Run only after implementation: `bash plugins/spec-pipeline/tests/run_tests.sh`.
* Run only after implementation: finalized non-mutating specpipe invocation for `python -m specpipe --help`.
* Run only after implementation: verify the specpipe invocation leaves `git status --short plugins/spec-pipeline/scripts/specpipe` empty.
* Run only after implementation: adversarial RED fixtures for command-not-found, runner setup error, bats/Jest assertion failure, and expected-failure matching.
* Run only after implementation: `claude plugin validate --strict plugins/spec-pipeline`.
* Run only after implementation: `bash scripts/validate-marketplace.sh`.
* Run only after implementation: `claude --plugin-dir ./plugins/spec-pipeline` and verify all five surfaces resolve.
* Run only after implementation: `npx prettier --check .` and `npx markdownlint-cli2 "**/*.md"`.

### Final recommendation

Claude Code should revise the specification using the findings above

### Review ledger for next loop

* Spec path: `/home/chris/projects/Claude-Code-Plugins/docs/superpowers/specs/2026-07-01-spec-pipeline-plugin-design.md`
* Audit round: 2
* Open issue IDs: SA-004, SA-NEW-001
* Resolved issue IDs: SA-001, SA-002, SA-003, SA-005, SA-006
* Superseded issue IDs:
* Significant findings remaining: Yes
* Next audit should focus on: non-pytest RED false positives and uv invocation lock/sync side effects


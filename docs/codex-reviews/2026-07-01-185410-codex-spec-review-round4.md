### Executive summary

Claude Code’s round-4 corrections resolved the two remaining prior findings: committed evidence redaction now covers the whole evidence block, including command strings and rejected attempts, and generic RED now requires `--expect-failure-regex` with missing regex treated as bad invocation.

One new non-blocking validation weakness remains: the clean-tree acceptance check can miss ignored plugin-tree artifacts such as `.venv/`, so it does not fully prove the “no plugin-tree writes” claim. New internet research was used to re-check the `uv run --no-project` and Claude plugin validation assumptions.

### Verdict

Needs minor specification correction before planning/implementation

### Audit loop status

* Audit type: Follow-up audit
* Spec path: `/home/chris/projects/Claude-Code-Plugins/docs/superpowers/specs/2026-07-01-spec-pipeline-plugin-design.md`
* Prior audit issue count: 7
* Resolved issue count: 7
* Still open issue count: 0
* Partially resolved issue count: 0
* New issue count: 1
* Regression count: 0
* Significant findings remaining: Yes

### Adversarial review performed

Retested all prior findings against the revised spec, source `agent-configs` skills, repo handoff conventions, local marketplace validation, up-docs redaction precedent, local Claude/uv help, `.gitignore`, and current official Claude Code and uv documentation. Re-attacked acceptance criteria for false positives around committed evidence redaction, generic RED verification, uv project discovery, plugin-root state, and clean-tree validation.

Could not safely execute plugin loading, specpipe commands, or pytest because `plugins/spec-pipeline/` does not exist yet and those checks are post-implementation and potentially write-producing.

### Prior findings status

#### SA-001: Structural validator scope does not cover the master-spec coverage contract

* Previous severity: High
* Current status: Resolved
* Evidence: Spec lines 22, 31, and 192 continue to explicitly keep semantic requirement/scope coverage out of specpipe and with the review panel.
* Remaining action for Claude Code: None.

#### SA-002: Phase status transitions can strand execution after partial failure

* Previous severity: High
* Current status: Resolved
* Evidence: Spec lines 93-95 define resume-first `next-phase`, legal recovery transitions, and state lookup; line 148 defines stale-run reassessment or clean abandon; line 170 requires recovery fixtures.
* Remaining action for Claude Code: None.

#### SA-003: RED/GREEN evidence capture lacks a command-safety and redaction contract

* Previous severity: High
* Current status: Resolved
* Evidence: Spec lines 103-112 now define no-shell argv execution, cwd, timeout, output cap, full-block redaction, append semantics, and rejected-attempt recording. Line 110 explicitly covers command strings, stdout/stderr excerpts, accepted and rejected attempts, and no raw secret-shaped values in committed evidence.
* Remaining action for Claude Code: None.

#### SA-004: RED failure classification is pytest-specific despite generic command input

* Previous severity: Medium
* Current status: Resolved
* Evidence: Spec line 96 makes `--expect-failure-regex` mandatory with `--framework generic`, makes missing regex exit 2, and removes the verification-free generic path. Line 109 restates the plan-supplied regex requirement; line 185 requires unmatched regex rejection and missing-regex bad invocation acceptance tests.
* Remaining action for Claude Code: None.

#### SA-005: Layout-agnostic state handling is incomplete for round counters and status

* Previous severity: Medium
* Current status: Resolved
* Evidence: Spec lines 95 and 128 define explicit phase-plan/audit paths, `status --state`, upward `.spec-pipeline/state.json` search from the phase-plan directory, and `init-project --handoff-dir`.
* Remaining action for Claude Code: None.

#### SA-006: Acceptance omits the current official plugin validator and repeats stale local validation assumptions

* Previous severity: Medium
* Current status: Resolved
* Evidence: Spec lines 173-174 and 183 require both `scripts/validate-marketplace.sh` and `claude plugin validate --strict plugins/spec-pipeline`; local `claude plugin validate --help` confirms `--strict`.
* Remaining action for Claude Code: None.

#### SA-NEW-001: `uv run --directory` may write lock and environment state despite the stdlib-only claim

* Previous severity: Medium
* Current status: Resolved
* Evidence: Spec lines 60 and 69 now specify no `pyproject.toml`, no venv, no lockfile, plain `PYTHONPATH`, and `uv run --no-project`; official uv docs confirm `--no-project` avoids project/workspace discovery.
* Remaining action for Claude Code: None for the runtime direction; see SA-NEW-002 for tightening the validation proof.

### New blocking issues

None found.

### New non-blocking issues

#### SA-NEW-002: Clean-tree proof can miss ignored plugin-tree artifacts

* Severity: Medium
* Status: Confirmed
* Adversarial angle: Can the acceptance check pass while the plugin tree still contains forbidden generated state?
* Spec reference: Spec lines 69 and 186.
* Finding: The spec’s clean-tree proof uses `git status --short plugins/spec-pipeline/scripts/specpipe`, but repo `.gitignore` ignores `.venv/`, `.pytest_cache/`, and similar generated directories. That command can pass even if an implementation accidentally writes ignored state under the plugin tree.
* Repository evidence: `.gitignore` lines 13, 15, and 17 ignore `.venv/`, `.pytest_cache/`, and `.ruff_cache/`. `git check-ignore -v --no-index plugins/spec-pipeline/scripts/specpipe/.venv/foo` confirms `.venv/` would be ignored.
* External research evidence: uv CLI docs confirm `--no-project` avoids project/workspace discovery; this supports the runtime choice but not the git-status-only validation proof. Source: https://docs.astral.sh/uv/reference/cli/, accessed 2026-07-01.
* Why it matters: The acceptance criterion could pass while leaving exactly the kind of plugin-root state the spec says must not exist.
* Recommended action for Claude Code: Replace or supplement the clean-tree check with a check that covers ignored artifacts, such as `git status --short --ignored plugins/spec-pipeline` plus explicit absence checks for `.venv`, `uv.lock`, `.pytest_cache`, `.ruff_cache`, and cache-like directories under `plugins/spec-pipeline`.
* Suggested validation: After implementation, run the canonical specpipe invocation, then verify both tracked/untracked status and ignored/generated artifact absence across the whole plugin directory.

### Regressions

None found.

### Remaining ambiguities and decisions needed

* Ambiguity: What exact post-invocation check proves specpipe did not create ignored state under the plugin tree?
* Why it matters: The current acceptance text can miss ignored generated directories.
* Recommended clarification: Define a whole-plugin-tree validation that includes ignored artifacts or explicit `find`/absence checks.
* Blocking or non-blocking: Non-blocking.

### Internet research performed

* Source name: uv Docs — CLI reference
* URL: https://docs.astral.sh/uv/reference/cli/
* Access date: 2026-07-01
* What it was used to verify: `uv run --no-project`, cache flags, and project/workspace discovery behavior.
* Relevant conclusion: `--no-project` avoids project/workspace discovery and supports the revised no-project runtime direction.

* Source name: uv Docs — Running commands
* URL: https://docs.astral.sh/uv/concepts/projects/run/
* Access date: 2026-07-01
* What it was used to verify: Default project-mode `uv run` behavior.
* Relevant conclusion: Project-mode behavior remains the reason the spec should avoid project discovery for bundled plugin code.

* Source name: Claude Code Docs — Plugins reference
* URL: https://code.claude.com/docs/en/plugins-reference
* Access date: 2026-07-01
* What it was used to verify: `${CLAUDE_PLUGIN_ROOT}`, persistent plugin state guidance, and `claude plugin validate --strict`.
* Relevant conclusion: Plugin root is ephemeral and should not receive persistent state; `--strict` is the correct CI-style validator mode.

* Source name: Claude Code Docs — Create plugins
* URL: https://code.claude.com/docs/en/plugins
* Access date: 2026-07-01
* What it was used to verify: Plugin testing and validation workflow.
* Relevant conclusion: Local plugin validation before sharing remains official guidance.

### Read-only validation performed

* `pwd`, `git branch --show-current`, `git log --oneline -n 10`: Confirmed repo root, branch `main`, and latest round-3 fix commit `064e9a7`.
* `git status --short`, `git diff --stat`, `git diff --check`: Confirmed the working tree is clean.
* Read target spec with line numbers: Verified updated redaction, generic RED, uv invocation, validation, acceptance, and review ledger text.
* Read `docs/handoff/state.md`, `docs/handoff/conventions.md`, `docs/handoff/specs-plans.md`, and `docs/handoff/architecture.md`: Verified repo conventions, canonical test frameworks, marketplace expectations, and spec/plan index.
* Read source `author-master-spec` and `autonomous-phase-execution` skills and references; ran `sha256sum` on duplicated `spec-construction.md`: Confirmed source versions, TDD RED rule, and byte-identical shared reference.
* `find plugins/spec-pipeline`: Confirmed the proposed plugin directory still does not exist.
* Read `.claude-plugin/marketplace.json` and `scripts/validate-marketplace.sh`: Confirmed manifest/marketplace validation behavior.
* Read `plugins/up-docs/scripts/capture-transcript.sh`, `_capture-redactor.py`, and tests: Confirmed repo precedent for redacting command/tool input and output before writing evidence.
* `claude --version`, `claude plugin --help`, `claude plugin validate --help`: Confirmed Claude Code 2.1.198 and local `--strict` support.
* `uv --version`, `uv run --help`, `python3 --version`: Confirmed uv 0.11.6, `--no-project` support, and Python 3.14.6.
* Read `.gitignore` and ran `git check-ignore -v --no-index ...`: Confirmed ignored generated directories can evade plain `git status --short`.
* Official web docs: Rechecked Claude Code plugin behavior and uv project-discovery behavior.

### Recommended planning/implementation validation

* Run only after implementation: `bash plugins/spec-pipeline/tests/run_tests.sh`.
* Run only after implementation: finalized canonical `specpipe --help` / `python -m specpipe` invocation.
* Run only after implementation: verify the canonical specpipe invocation leaves `plugins/spec-pipeline` free of tracked, untracked, and ignored generated artifacts.
* Run only after implementation: adversarial `record-red` fixtures for command-not-found, runner setup error, bats/Jest assertion failure, missing `--expect-failure-regex`, unmatched `--expect-failure-regex`, and matched expected failure.
* Run only after implementation: evidence redaction fixtures where token-shaped text appears in the command string, stdout, stderr, timeout/rejected records, and GREEN records.
* Run only after implementation: `claude plugin validate --strict plugins/spec-pipeline`.
* Run only after implementation: `bash scripts/validate-marketplace.sh`.
* Run only after implementation: `claude --plugin-dir ./plugins/spec-pipeline` and verify all five surfaces resolve.
* Run only after implementation: `npx prettier --check .` and `npx markdownlint-cli2 "**/*.md"`.

### Final recommendation

Claude Code should revise the specification using the findings above

### Review ledger for next loop

* Spec path: `/home/chris/projects/Claude-Code-Plugins/docs/superpowers/specs/2026-07-01-spec-pipeline-plugin-design.md`
* Audit round: 4
* Open issue IDs: SA-NEW-002
* Resolved issue IDs: SA-001, SA-002, SA-003, SA-004, SA-005, SA-006, SA-NEW-001
* Superseded issue IDs:
* Significant findings remaining: Yes
* Next audit should focus on: whole-plugin-tree clean-state validation that detects ignored generated artifacts


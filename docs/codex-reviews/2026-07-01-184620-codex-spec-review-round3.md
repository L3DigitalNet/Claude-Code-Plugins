### Executive summary

Claude Code’s latest corrections resolved the `uv run` lock/sync side-effect finding: the spec now removes Python project machinery and uses `uv run --no-project` with a clean-tree acceptance check. Significant findings still remain because two prior safety/validation findings are only partially resolved: committed evidence redaction does not cover the recorded command string, and generic RED still has an unverified non-zero fallback when `--expect-failure-regex` is omitted.

New internet research was required to re-check `uv run --no-project`, `${CLAUDE_PLUGIN_ROOT}` state guidance, and `claude plugin validate --strict`.

### Verdict

Needs major specification correction before planning/implementation

### Audit loop status

* Audit type: Follow-up audit
* Spec path: `/home/chris/projects/Claude-Code-Plugins/docs/superpowers/specs/2026-07-01-spec-pipeline-plugin-design.md`
* Prior audit issue count: 7
* Resolved issue count: 5
* Still open issue count: 0
* Partially resolved issue count: 2
* New issue count: 0
* Regression count: 0
* Significant findings remaining: Yes

### Adversarial review performed

Retested prior fixes against the revised spec, source `agent-configs` skills, repo handoff conventions, marketplace validator behavior, local Claude/uv help, existing repo redaction precedent, and current official Claude Code and uv documentation. Re-attacked acceptance criteria for false positives around generic RED evidence, uv lock/sync writes, plugin-root state, official plugin validation, and committed audit-file secret exposure.

Could not safely execute plugin loading, specpipe commands, or pytest because `plugins/spec-pipeline/` does not exist yet and those checks may write local state after implementation.

### Prior findings status

#### SA-001: Structural validator scope does not cover the master-spec coverage contract

* Previous severity: High
* Current status: Resolved
* Evidence: Spec lines 22 and 31 continue to explicitly exclude semantic requirement/scope coverage from mechanized validation and keep it with the review panel; line 192 keeps a possible v2 coverage validator as a follow-up.
* Remaining action for Claude Code: None.

#### SA-002: Phase status transitions can strand execution after partial failure

* Previous severity: High
* Current status: Resolved
* Evidence: Spec lines 93-95 define resume-first `next-phase`, legal recovery transitions including `in_progress→pending`, and state lookup; line 148 tells the skill to reassess or abandon a stale run cleanly; line 170 requires recovery fixtures.
* Remaining action for Claude Code: None.

#### SA-003: RED/GREEN evidence capture lacks a command-safety and redaction contract

* Previous severity: High
* Current status: Partially resolved
* Evidence: The spec now covers no-shell argv execution, timeout, output cap, append semantics, and rejected-attempt recording at lines 103-112. However, line 96 says the committed evidence block includes the raw command, while line 110 only redacts the output excerpt before append. Existing repo precedent in `plugins/up-docs/tests/capture-transcript.bats:52-63` and `plugins/up-docs/scripts/capture-transcript.sh:18-21` redacts secret-shaped values in command/tool input as well as output before writing evidence.
* Remaining action for Claude Code: Extend the redaction contract and acceptance tests to cover the entire evidence block, especially the recorded command string and rejected attempts. The spec should state that no raw secret-shaped value may be committed in command, stdout, stderr, or failure excerpts.

#### SA-004: RED failure classification is pytest-specific despite generic command input

* Previous severity: Medium
* Current status: Partially resolved
* Evidence: Spec lines 96 and 109 add `--expect-failure-regex` and require the plan to supply it for generic-framework RED evidence. But line 96 still allows `--framework generic` with no regex to accept any non-zero exit and merely note that failure-reason verification was unavailable. That still conflicts with the source executor’s rule that RED must fail for the right reason, not setup/import/syntax failure (`autonomous-phase-execution/SKILL.md:69`).
* Remaining action for Claude Code: Make `--expect-failure-regex` mandatory for `--framework generic`, or require an explicit opt-out flag that the migrated skills never use. Add acceptance for missing-regex rejection, not only unmatched-regex rejection.

#### SA-005: Layout-agnostic state handling is incomplete for round counters and status

* Previous severity: Medium
* Current status: Resolved
* Evidence: Spec lines 95 and 128 keep explicit phase-plan/audit paths, `status --state`, upward `.spec-pipeline/state.json` search from the phase-plan directory, and `init-project --handoff-dir`.
* Remaining action for Claude Code: None.

#### SA-006: Acceptance omits the current official plugin validator and repeats stale local validation assumptions

* Previous severity: Medium
* Current status: Resolved
* Evidence: Spec lines 173-174 and 183 require both `scripts/validate-marketplace.sh` and `claude plugin validate --strict plugins/spec-pipeline`; local `claude plugin validate --help` confirms `--strict`.
* Remaining action for Claude Code: None.

#### SA-NEW-001: `uv run --directory` may write lock and environment state despite the stdlib-only claim

* Previous severity: Medium
* Current status: Resolved
* Evidence: Spec lines 60 and 69 now specify no `pyproject.toml`, no venv, no lockfile, plain `PYTHONPATH`, and `uv run --no-project`; line 186 requires a clean-tree proof. Local `uv run --help` and official uv docs confirm `--no-project` avoids project/workspace discovery.
* Remaining action for Claude Code: None beyond implementing the clean-tree acceptance check.

### New blocking issues

None found.

### New non-blocking issues

None found.

### Regressions

None found.

### Remaining ambiguities and decisions needed

* Ambiguity: Is the committed evidence redactor responsible for the command string or only subprocess output?
* Why it matters: The audit file is committed, and the spec currently records the command while only redacting the excerpt.
* Recommended clarification: Redact the entire evidence block before append and add fixtures where the command itself contains token-shaped text.
* Blocking or non-blocking: Blocking.

* Ambiguity: Can `--framework generic` ever accept RED without `--expect-failure-regex`?
* Why it matters: Any non-zero runner/setup failure can still satisfy RED if the regex is omitted.
* Recommended clarification: Require the regex for generic RED, or make unverified generic RED a separate explicit mode outside the migrated skills.
* Blocking or non-blocking: Non-blocking.

### Internet research performed

* Source name: uv Docs — CLI reference
* URL: https://docs.astral.sh/uv/reference/cli/
* Access date: 2026-07-01
* What it was used to verify: `uv run --no-project`, config/cache flags, and project/workspace discovery behavior.
* Relevant conclusion: `--no-project` avoids project/workspace discovery; this supports the revised no-lock/no-sync runtime direction.

* Source name: uv Docs — Running commands
* URL: https://docs.astral.sh/uv/concepts/projects/run/
* Access date: 2026-07-01
* What it was used to verify: Default `uv run` project-environment behavior.
* Relevant conclusion: Ordinary project-mode `uv run` keeps project environments up to date, so the spec’s move away from project machinery is justified.

* Source name: Claude Code Docs — Plugins reference
* URL: https://code.claude.com/docs/en/plugins-reference
* Access date: 2026-07-01
* What it was used to verify: `${CLAUDE_PLUGIN_ROOT}`, `${CLAUDE_PLUGIN_DATA}`, plugin component layout, and `claude plugin validate --strict`.
* Relevant conclusion: Plugin root is valid for bundled files but ephemeral and not for persistent state; `--strict` is the correct CI-style validator mode.

* Source name: Claude Code Docs — Create plugins
* URL: https://code.claude.com/docs/en/plugins
* Access date: 2026-07-01
* What it was used to verify: Plugin testing and validation workflow.
* Relevant conclusion: Running `claude plugin validate` locally before publication is aligned with official guidance.

### Read-only validation performed

* `pwd`, `git branch --show-current`, `git log --oneline -n 10`: Confirmed repo root, branch `main`, and latest commit `00e3b4a` describing the round-2 spec fixes.
* `git status --short`, `git diff --stat`, `git diff --check`: Confirmed the working tree is clean and no whitespace errors are present.
* Read target spec with line numbers: Verified revised generic RED, uv invocation, evidence safety, testing, acceptance, and review-ledger text.
* Read `docs/handoff/state.md`, `docs/handoff/conventions.md`, `docs/handoff/specs-plans.md`, and `docs/handoff/architecture.md`: Verified repo conventions, canonical test frameworks, marketplace expectations, and current spec/plan index.
* `rg --files` and `nl` over source `author-master-spec` / `autonomous-phase-execution` skills and references: Verified source versions, TDD RED rule, phase-plan schema, and shared standards.
* `sha256sum` on duplicated `spec-construction.md`: Confirmed source copies are still byte-identical.
* `find plugins/spec-pipeline`: Confirmed the proposed plugin directory still does not exist.
* Read `.claude-plugin/marketplace.json` and `scripts/validate-marketplace.sh`: Confirmed local marketplace/manifest validation behavior.
* `claude --version`, `claude plugin --help`, `claude plugin validate --help`: Confirmed Claude Code 2.1.198 and local `--strict` support.
* `uv --version`, `uv run --help`, `python3 --version`: Confirmed uv 0.11.6, local `--no-project` support, and Python 3.14.6.
* Read `plugins/up-docs/scripts/capture-transcript.sh` and `plugins/up-docs/tests/capture-transcript.bats`: Verified repo precedent for redacting command/tool input as well as output before writing evidence.
* Official web docs: Rechecked Claude Code plugin behavior and uv `run` project-discovery behavior.

### Recommended planning/implementation validation

* Run only after implementation: `bash plugins/spec-pipeline/tests/run_tests.sh`.
* Run only after implementation: finalized canonical `specpipe --help` / `python -m specpipe` invocation.
* Run only after implementation: verify the canonical specpipe invocation leaves `git status --short plugins/spec-pipeline/scripts/specpipe` empty.
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
* Audit round: 3
* Open issue IDs: SA-003, SA-004
* Resolved issue IDs: SA-001, SA-002, SA-005, SA-006, SA-NEW-001
* Superseded issue IDs:
* Significant findings remaining: Yes
* Next audit should focus on: committed evidence redaction covering command strings and mandatory failure-reason verification for generic RED
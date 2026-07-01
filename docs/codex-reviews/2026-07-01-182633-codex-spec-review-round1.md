### Executive summary

The specification is not ready to use as the basis for planning or implementation as written. The core direction fits the repository, and several repo-fit claims are confirmed, but three blocking gaps remain: the claimed structural validation does not actually cover the master-spec scope-coverage contract, the new status workflow can strand a phase in `in_progress` after partial failure, and `record-red` / `record-green` introduce an underspecified arbitrary-command-and-audit-log surface.

Internet research was required because the spec depends on current Claude Code plugin behavior. Official Claude Code docs and the local Claude CLI confirm additional validation surfaces (`claude plugin validate --strict`) that the spec does not require, and local repo evidence contradicts one validation assumption in the spec.

### Verdict

Needs major specification correction before planning/implementation

### Audit loop status

* Audit type: First audit
* Spec path: `/home/chris/projects/Claude-Code-Plugins/docs/superpowers/specs/2026-07-01-spec-pipeline-plugin-design.md`
* Significant findings remaining: Yes
* Blocking issue count: 3
* Non-blocking issue count: 3

### What the specification gets right

* The two source skills exist at the stated `agent-configs` path, with the stated versions `author-master-spec` v1.6 and `autonomous-phase-execution` v1.11.
* The duplicated `spec-construction.md` copies are byte-identical by SHA-256, so the dedupe goal is repo-supported.
* The proposed plugin root layout matches the repo’s existing plugin structure and official Claude Code plugin layout.
* The pytest location under `plugins/spec-pipeline/tests/` aligns with `TEST-001`.
* Deferring enforcement hooks is internally consistent with the stated “validators only” cycle.

### Adversarial review performed

I inventoried the spec’s material requirements, CLI contracts, state model, template/parser contract, validation expectations, acceptance criteria, and external Claude Code plugin assumptions. I falsified them against the target spec, source skills in `agent-configs`, repo conventions, marketplace validation script, plugin docs, current local CLI help, and official Claude Code plugin documentation.

Strongest assumptions tested: “every structural check” is mechanized, phase state can be computed safely, RED/GREEN audit capture is trustworthy, non-handoff layouts are supported, marketplace validation is sufficient, and acceptance criteria prove installability.

Could not safely check actual plugin loading because `plugins/spec-pipeline/` does not exist yet and install/load tests can write user/plugin state.

### Blocking issues

#### SA-001: Structural validator scope does not cover the master-spec coverage contract

* Severity: High
* Status: Confirmed
* Adversarial angle: Can the acceptance criteria pass while the authored master spec omits or duplicates real requirements across phases?
* Spec reference: [spec design](/home/chris/projects/Claude-Code-Plugins/docs/superpowers/specs/2026-07-01-spec-pipeline-plugin-design.md:22), lines 22, 31, 91-93, 157
* Finding: The spec claims `specpipe` will mechanize every structural check the standards define, but the proposed validators do not define a requirement ID inventory, requirement-to-phase coverage map, or cross-artifact check proving every requirement maps to exactly one phase. The spec also classifies “scope coverage judgment” as semantic review-panel work, which contradicts the broader “every structural check” goal.
* Repository evidence: The master standard requires the build plan to cover every requirement exactly once and makes scope coverage a master self-review obligation: `/home/chris/projects/agent-configs/skills/.claude/skills/author-master-spec/references/spec-construction-master.md:14` and `:20`. The proposed `validate spec` and `validate phase-plan` checks list section presence, decision IDs, schema, uniqueness, and graph order, but not requirement coverage.
* External research evidence: Not applicable.
* Why it matters: Claude Code could generate a structurally valid master spec and acyclic phase plan that silently drops a requirement or assigns it to two phases. That defeats the main reason to introduce deterministic validation before expensive reviews.
* Recommended action for Claude Code: Either narrow the goal/non-goal language so scope coverage remains explicitly review-only, or add a machine-readable requirement inventory plus phase coverage map and validator rules for orphaned and duplicated coverage.
* Suggested validation: Add failing/pass fixtures where a master requirement is omitted from all phases, duplicated across phases, and correctly mapped once.

#### SA-002: Phase status transitions can strand execution after partial failure

* Severity: High
* Status: Confirmed
* Adversarial angle: What happens if `execute-phase` marks a phase `in_progress` and the session crashes, is interrupted, or cannot complete?
* Spec reference: [spec design](/home/chris/projects/Claude-Code-Plugins/docs/superpowers/specs/2026-07-01-spec-pipeline-plugin-design.md:94), lines 94-96, 136, 141
* Finding: `next-phase` resolves only the first `pending` phase whose dependencies are complete, while `set-status` allows no `in_progress→pending`, `complete→pending`, explicit resume, or abort/reset transition. Because `execute-phase` marks the selected phase `in_progress` at Step 1, a partial run can leave the plan wedged with no deterministic recovery path.
* Repository evidence: The existing source skill resolves the next phase from the phase-plan status projection but does not introduce an early `in_progress` mutation. The new spec adds that mutation without crash recovery.
* External research evidence: Not applicable.
* Why it matters: A single failed or interrupted run can make future `next-phase` calls return no resolvable phase, forcing manual edits to a committed planning artifact.
* Recommended action for Claude Code: Define resume semantics for existing `in_progress` phases, a stale-state policy, and explicit legal recovery transitions such as `in_progress→pending` or `in_progress→blocked` with a reason. Specify whether `next-phase` should resume `in_progress` before selecting new `pending`.
* Suggested validation: Add fixtures for one stale `in_progress` phase, all-complete, blocked dependency chains, and recovery transitions that prove files remain untouched on illegal transitions.

#### SA-003: RED/GREEN evidence capture lacks a command-safety and redaction contract

* Severity: High
* Status: Confirmed
* Adversarial angle: Can a test evidence command leak secrets, hang, mutate unexpected state, or commit raw sensitive output?
* Spec reference: [spec design](/home/chris/projects/Claude-Code-Plugins/docs/superpowers/specs/2026-07-01-spec-pipeline-plugin-design.md:97), lines 97-98, 111, 139
* Finding: `record-red` and `record-green` run arbitrary `--cmd <test-cmd>` via subprocess and append output excerpts to committed audit files, but the spec does not define shell vs argv behavior, cwd, timeout, output size limits, redaction, environment handling, allowed command classes, or atomic/locked appends.
* Repository evidence: The spec says RED/GREEN audit trails are committed close-out evidence under `docs/handoff/audit/phase-<id>.md`. Repo docs explicitly treat credentials as references only; committed docs should not receive secret values.
* External research evidence: Not applicable.
* Why it matters: Test output can include tokens, private URLs, env dumps, or customer data. An underspecified command string can also accidentally run destructive shell syntax or hang indefinitely.
* Recommended action for Claude Code: Specify a safe execution contract: no shell by default, argv/remainder parsing, cwd rooted in the target project, timeout, max captured bytes, redaction patterns, env minimization, audit append locking, and a clear rule that only test/validation commands from the reviewed plan may be passed.
* Suggested validation: Add tests for shell metacharacter handling, timeout, output truncation, secret-like redaction, collection-error rejection, unexpected pass, and atomic append behavior.

### Non-blocking issues

#### SA-004: RED failure classification is pytest-specific despite generic command input

* Severity: Medium
* Status: Confirmed
* Adversarial angle: Can `record-red` correctly validate RED for non-pytest projects?
* Spec reference: [spec design](/home/chris/projects/Claude-Code-Plugins/docs/superpowers/specs/2026-07-01-spec-pipeline-plugin-design.md:97), lines 97, 156-158
* Finding: The spec’s RED classifier rejects pytest collection/import/syntax signatures, but `--cmd <test-cmd>` is generic and the repo supports bash, Python, and TypeScript plugin test frameworks.
* Repository evidence: `docs/handoff/conventions.md:128-139` defines bats, pytest, and Jest as canonical frameworks by language.
* External research evidence: Not applicable.
* Why it matters: A Jest, bats, CTest, or language-specific failure can be misclassified as valid RED or invalid RED, giving false TDD evidence.
* Recommended action for Claude Code: Either constrain `record-red` to pytest-only commands and state that target projects must use pytest, or add framework adapters / `--expect-failure-regex` / `--framework` semantics.
* Suggested validation: Add fixtures for pytest assertion failure, pytest collection error, Jest assertion failure, bats assertion failure, and a syntax/import failure per supported framework.

#### SA-005: Layout-agnostic state handling is incomplete for round counters and status

* Severity: Medium
* Status: Confirmed
* Adversarial angle: Does `--handoff-dir` actually make the CLI layout-agnostic?
* Spec reference: [spec design](/home/chris/projects/Claude-Code-Plugins/docs/superpowers/specs/2026-07-01-spec-pipeline-plugin-design.md:96), lines 96, 99, 112, 116
* Finding: The spec says every subcommand takes explicit phase-plan/audit paths, but `status <phase-plan>` reads `.spec-pipeline/state.json` “when present” with no explicit target root or state-file argument. `rounds` takes a state-file path, but `status` has no way to know which state file belongs to a non-default project or invocation cwd.
* Repository evidence: Handoff v3 paths are repo-relative, and the spec explicitly supports non-handoff-v3 projects via `--handoff-dir`.
* External research evidence: Not applicable.
* Why it matters: `status` can silently show missing or wrong round counters when invoked from the plugin directory, a subdirectory, or a project with a non-default layout.
* Recommended action for Claude Code: Add `--state-file` or `--project-dir` to `status`, define default resolution relative to the phase-plan’s project root, and make the skills pass the same state path used by `rounds`.
* Suggested validation: Add fixtures invoking `status` from a different cwd and with a non-default `--handoff-dir`.

#### SA-006: Acceptance omits the current official plugin validator and repeats stale local validation assumptions

* Severity: Medium
* Status: Confirmed
* Adversarial angle: Can local acceptance pass while Claude Code’s current plugin validator would report warnings or errors?
* Spec reference: [spec design](/home/chris/projects/Claude-Code-Plugins/docs/superpowers/specs/2026-07-01-spec-pipeline-plugin-design.md:160), lines 160, 164, 169
* Finding: The spec says `validate-marketplace.sh` does not validate `plugin.json`, but the current script does validate manifest existence, required fields, allowed fields, author shape, version consistency, and name consistency. The acceptance criteria also do not require `claude plugin validate --strict`, even though the local CLI supports it.
* Repository evidence: `scripts/validate-marketplace.sh:161-187` validates `plugin.json`; `claude plugin validate --help` reports `--strict`.
* External research evidence: Official Claude Code docs say to run `claude plugin validate` before plugin submission and describe CLI plugin management/validation. Source: https://code.claude.com/docs/en/plugins, accessed 2026-07-01; https://code.claude.com/docs/en/plugins-reference, accessed 2026-07-01.
* Why it matters: The spec’s validation story can drift from the runtime validator and from the repo’s actual validator. It also under-specifies a non-mutating check that would catch plugin packaging issues earlier than install/load smoke tests.
* Recommended action for Claude Code: Correct the stale statement and add `claude plugin validate --strict plugins/spec-pipeline` plus marketplace validation to acceptance and implementation validation.
* Suggested validation: Run `claude plugin validate --strict plugins/spec-pipeline` after implementation, plus `bash scripts/validate-marketplace.sh`.

### Missing specification considerations

* Blocking: Requirement/phase coverage model. The spec needs either structured IDs and a coverage validator or explicit text that coverage remains review-only.
* Blocking: Crash recovery and idempotency for phase status mutations, especially stale `in_progress`.
* Blocking: Safe command execution and redaction for committed RED/GREEN audit evidence.
* Non-blocking: Framework support boundary for `record-red`; pytest-only vs adapters.
* Non-blocking: `status` and round-counter path resolution for non-default target layouts.
* Non-blocking: Official plugin validation via `claude plugin validate --strict`.
* Non-blocking: Output rendering contract for the three thin commands, including `--json` passthrough and exit-code propagation.
* Non-blocking: `init-project` behavior when `.gitignore` is absent, nested, read-only, or already contains equivalent ignore patterns.
* Non-blocking: Round-counter concurrency/atomicity and duplicate audit evidence behavior.
* Non-blocking: Explicit prerequisite checks for hard-required `/codex-review` and ultracode workflows.

### Ambiguities and decisions needed

* Ambiguity: Is scope coverage intended to be structural/mechanical or semantic/review-only?
* Why it matters: This determines whether `specpipe` needs requirement IDs and coverage maps.
* Recommended clarification: State the boundary explicitly and update goals, non-goals, validators, and acceptance accordingly.
* Blocking or non-blocking: Blocking

* Ambiguity: What should a future run do with an existing `in_progress` phase?
* Why it matters: This is the main recovery path after interrupted execution.
* Recommended clarification: Define resume-first behavior or explicit recovery transitions.
* Blocking or non-blocking: Blocking

* Ambiguity: Is `record-red` only for pytest?
* Why it matters: The repo’s plugin test conventions include bats and Jest too.
* Recommended clarification: Declare pytest-only or add framework-aware classification.
* Blocking or non-blocking: Non-blocking

### Internet research performed

* Source name: Claude Code Docs — Create plugins
* URL: https://code.claude.com/docs/en/plugins
* Access date: 2026-07-01
* What it was used to verify: Current plugin structure, `--plugin-dir` testing, plugin namespacing, and `claude plugin validate` recommendation.
* Relevant conclusion: The proposed plugin structure is broadly valid, but acceptance should include current Claude validation.

* Source name: Claude Code Docs — Plugins reference
* URL: https://code.claude.com/docs/en/plugins-reference
* Access date: 2026-07-01
* What it was used to verify: Current CLI plugin commands and component locations.
* Relevant conclusion: `claude plugin install/list/details/validate` are current non-interactive CLI surfaces; `commands/` are flat Markdown skills and `skills/` are `<name>/SKILL.md`.

* Source name: Claude Code Docs — Create and distribute a plugin marketplace
* URL: https://code.claude.com/docs/en/plugin-marketplaces
* Access date: 2026-07-01
* What it was used to verify: Marketplace schema, relative plugin paths, strict mode, and `${CLAUDE_PLUGIN_ROOT}` use.
* Relevant conclusion: Relative `./plugins/<name>` sources and plugin-root component paths are supported; official docs support richer validation and packaging behavior than the spec currently requires.

### Items Claude Code should verify before correcting the specification

* Decide whether master requirement coverage will be machine-checkable or review-only.
* Verify intended target-project test frameworks for `record-red` / `record-green`.
* Verify desired recovery semantics for stale `in_progress` phase-plan entries.
* Verify whether the official `claude plugin validate --strict` gate should supplement or replace parts of `validate-marketplace.sh`.
* Verify whether `status` should infer `.spec-pipeline/state.json` from project root, phase-plan location, or an explicit CLI argument.

### Suggested corrections for Claude Code’s specification

* Add or narrow the scope-coverage contract: either structured requirement IDs + coverage validator, or explicit review-only scope coverage.
* Add resume/recovery semantics for `in_progress`, blocked phases, interrupted runs, and illegal transition handling.
* Add a command execution safety contract for RED/GREEN capture: no shell by default, timeout, cwd, env, output cap, redaction, allowed command classes, and atomic audit append.
* Clarify pytest-only vs multi-framework RED classification.
* Add explicit state path arguments or resolution rules for `status` and round counters.
* Correct the `validate-marketplace.sh` statement and add `claude plugin validate --strict` to acceptance.
* Add validation fixtures for false-positive acceptance cases, not only happy-path parser fixtures.

### Read-only validation performed

* `pwd`: Confirmed repository root `/home/chris/projects/Claude-Code-Plugins`.
* `git status --short`: Confirmed clean working tree.
* `git branch --show-current`: Confirmed branch `main`.
* `git log --oneline -n 10`: Confirmed recent spec and plan commits exist.
* Read target spec with line numbers: Inventoried requirements, CLI contract, state model, templates, tests, acceptance.
* Read `AGENTS.md`, `docs/handoff/conventions.md`, `docs/handoff/specs-plans.md`, `docs/handoff/architecture.md`, `docs/handoff/credentials.md`: Verified repo conventions, marketplace rules, test framework conventions, and spec index state.
* `find /home/chris/projects/agent-configs/skills/.claude/skills`: Confirmed source skill paths.
* Read both source `SKILL.md` files and referenced construction standards: Verified versions, source contracts, and required coverage/decomposition rules.
* `sha256sum` on reference files: Confirmed duplicated `spec-construction.md` is byte-identical.
* Read `.claude-plugin/marketplace.json` and `scripts/validate-marketplace.sh`: Verified marketplace structure and actual local validation behavior.
* Read repo plugin docs and existing plugin manifests/commands/skills: Checked proposed layout against current repo patterns.
* `claude --version`, `claude plugin --help`, `claude plugin validate --help`: Confirmed local Claude Code 2.1.198 and non-mutating plugin validation CLI support.
* `uv --version`, `python3 --version`: Confirmed local uv 0.11.6 and Python 3.14.6.
* `find plugins/spec-pipeline`: Confirmed proposed plugin directory does not yet exist.
* `git diff --stat` and `git diff --check`: Confirmed no local diff and no whitespace errors.
* Internet research against official Claude Code docs: Verified current plugin and marketplace assumptions.

### Recommended planning/implementation validation

* Run only after implementation: `bash plugins/spec-pipeline/tests/run_tests.sh`.
* Run only after implementation: `uv run --directory plugins/spec-pipeline/scripts/specpipe python -m specpipe --help`.
* Run only after implementation: `uv run --directory plugins/spec-pipeline/scripts/specpipe python -m specpipe validate phase-plan <fixture>`.
* Run only after implementation: `claude plugin validate --strict plugins/spec-pipeline`.
* Run only after implementation: `bash scripts/validate-marketplace.sh`.
* Run only after implementation: `claude --plugin-dir ./plugins/spec-pipeline` and verify `/spec-pipeline:author`, `/spec-pipeline:execute-phase`, `/spec-pipeline:validate`, `/spec-pipeline:status`, and `/spec-pipeline:init-project`.
* Run only after implementation: `npx prettier --check .` and `npx markdownlint-cli2 "**/*.md"`.
* Run only after implementation: adversarial fixtures for stale `in_progress`, orphaned/duplicated requirement coverage if mechanized, redaction, timeout, and non-pytest RED behavior if supported.

### Final recommendation

Claude Code should revise the specification using the findings above

### Review ledger for next loop

* Spec path: `/home/chris/projects/Claude-Code-Plugins/docs/superpowers/specs/2026-07-01-spec-pipeline-plugin-design.md`
* Audit round: 1
* Open issue IDs: SA-001, SA-002, SA-003, SA-004, SA-005, SA-006
* Resolved issue IDs:
* Superseded issue IDs:
* Significant findings remaining: Yes
* Next audit should focus on: requirement coverage boundary, stale `in_progress` recovery, RED/GREEN command safety/redaction, framework support, state path resolution, and official plugin validation acceptance


### Executive summary

The specification is not ready for Claude Code to use as the basis for planning or implementation. The direction is plausible, but three blocking issues remain: A1 depends on a `pages_touched` set that does not exist in the current tracker contract, A2 can turn the auditor into a false-green by skipping whole touched pages before verification, and C can commit pre-existing `llm-wiki` work because it lacks a before/after dirty-state baseline.

Internet research was required because the spec depends on current Claude Code plugin, Agent, and `AskUserQuestion` behavior. Official Claude Code docs corroborate those primitives; the major findings are repository-contract and safety issues, not external API drift.

### Verdict

Needs major specification correction before planning/implementation

### Audit loop status

- Audit type: First audit
- Spec path: /home/chris/projects/Claude-Code-Plugins/docs/plans/2026-06-07-up-docs-orchestration-improvements-design.md
- Significant findings remaining: Yes
- Blocking issue count: 3
- Non-blocking issue count: 3

### What the specification gets right

- Targets real up-docs cost centers: unconditional propagator dispatch, post-scan dedup, and repeated Notion/wiki work.
- Preserves the important no-auto-push rule and adds an explicit user consent gate for commits.
- Keeps standalone `/up-docs:drift` first-pass completeness as a non-goal boundary.
- Correctly uses this repo’s `docs/plans/` location and current up-docs version baseline `0.10.1`.

### Adversarial review performed

Performed requirement inventory, repository-fit checks, internal consistency review, blast-radius review for commit behavior, failure-mode review, acceptance-criteria attack, external-assumption check against official Claude Code docs, and maintainability/minimality review.

Strongest assumptions tested: `pages_touched` is a path set; skipped-layer rows fit existing output schemas; `Updated`/`Created` rows are safe enough to exclude whole pages before audit; consent-gated explicit-path staging prevents unintended commits; the spec is indexed as repo source-of-truth.

Could not verify the historical `~188k subagent tokens + 103 tool calls` and “Notion propagator: 7 tool calls” claims from committed repo evidence. I did not run tests because this was read-only and tests may write caches/temp artifacts.

### Blocking issues

#### SA-001: A1 assumes a page set that the tracker does not persist

- Severity: High
- Status: Confirmed
- Adversarial angle: Data-contract falsification.
- Spec reference: §3.A1, lines 53-65.
- Finding: The spec says `scripts/convergence-tracker.sh` already persists a `pages_touched` set and asks pass N+1 to scan that set plus one-hop dependents. The actual script persists only a numeric maximum count, so there is no path list from which to compute narrowed scan candidates.
- Repository evidence: `plugins/up-docs/scripts/convergence-tracker.sh:63` initializes `'pages_touched': 0`; line 98 stores `max(... findings.get('pages_touched', 0))`; `plugins/up-docs/tests/convergence-tracker.bats:162-172` asserts the value is numeric `5`. The auditor output schema at `plugins/up-docs/agents/up-docs-audit-drift.md:321-352` has no touched-page list.
- External research evidence: Not applicable.
- Why it matters: Claude Code could implement the prompt text and pass the proposed prompt-conformance assertion while still having no reliable page-path source for narrowing. That forces guessing, a full scan, or an unsound ad hoc parser.
- Recommended action for Claude Code: Define an explicit machine-readable path contract, such as `touched_pages_by_phase: {"1": ["wiki/...md"]}`, and update the tracker schema, auditor output contract, and tests. If deriving from findings instead, specify the exact fields used and how repo/wiki/Notion targets normalize to comparable IDs.
- Suggested validation: Add tracker tests proving page paths round-trip across `record-iteration` and `status`; add an auditor prompt/schema assertion that pass N+1 reads those paths and expands one-hop `related` dependents.

#### SA-002: Commit offer can commit pre-existing llm-wiki changes

- Severity: High
- Status: Confirmed
- Adversarial angle: Dirty-tree and unintended-staging failure mode.
- Spec reference: §3.C, lines 108-118; risk table line 148.
- Finding: The spec detects dirty trees only after propagation and stages propagation-written paths by explicit name. That is not enough to prevent committing pre-existing local edits in `~/projects/llm-wiki`, especially when a pre-existing dirty file is later also touched by the wiki propagator.
- Repository evidence: `/up-docs:all` currently guards only the active project repo with `git status --porcelain` before work (`plugins/up-docs/skills/all/SKILL.md:31-44`). The wiki propagator preflight checks only that `LLM_WIKI_ROOT` exists and reads contract docs (`plugins/up-docs/agents/up-docs-propagate-wiki.md:39-44`); it has no dirty-tree baseline. `git -C /home/chris/projects/llm-wiki status --short` was clean during this audit, but the spec must be safe when it is not.
- External research evidence: Official Claude Code hooks docs confirm `AskUserQuestion` supports multiple-choice questions with optional `multiSelect`, so the consent mechanism is plausible, but consent does not prove the staged diff is scoped correctly: <https://code.claude.com/docs/en/hooks> (accessed 2026-06-08).
- Why it matters: `git add -- path` stages all hunks in that path, including pre-existing user work. The user may approve “commit propagation-written paths” while the implementation silently includes unrelated edits.
- Recommended action for Claude Code: Add a pre-propagation baseline for every repo that may be committed. For any repo or path dirty before propagation, either exclude it from the commit offer or present it as a separate explicit risk. Require after-propagation diff checks that prove selected paths were clean at baseline and were written by this run.
- Suggested validation: Scenario test with `llm-wiki` dirty before `/up-docs:all`, including same-path dirtiness; approving the commit must not commit the pre-existing change and should refuse or require separate user approval.

#### SA-003: A2 skips whole touched pages before independent audit

- Severity: High
- Status: Confirmed
- Adversarial angle: False-green acceptance attack.
- Spec reference: §3.A2, lines 67-73; risk table line 146.
- Finding: The spec moves dedup from post-scan to pre-scan by excluding all pages marked `Updated`/`Created` in propagator reports. That trusts the propagator’s self-report and can skip independent validation of pages most likely to contain fresh mistakes.
- Repository evidence: Current auditor guardrail only prevents re-reporting already-fixed drift (`plugins/up-docs/agents/up-docs-audit-drift.md:99`); it does not say to skip whole pages. The auditor currently has a full llm-wiki validator gate (`plugins/up-docs/agents/up-docs-audit-drift.md:59-75`) and draft-authority check (`:77`) that are stronger than report-level trust. The proposed risk mitigation assumes any remaining drift would have been a propagator `FAILED` row, but that is exactly the assumption an independent auditor is supposed to test.
- External research evidence: Not applicable.
- Why it matters: `/up-docs:all` could report zero drift while a newly updated page still has bad frontmatter, a broken relation, or a cross-page contradiction introduced by the update.
- Recommended action for Claude Code: Narrow dedup to exact already-fixed finding signatures, not whole pages. Keep touched pages eligible for validator, draft-status, link, and cross-page contradiction checks. If whole-page skipping remains desired, require machine-verified clean results from the propagator and state which checks are still always run.
- Suggested validation: Add a scenario where a propagator reports `Updated` for a wiki page but the page still has a broken `related` link or contradiction; the auditor must still find it.

### Non-blocking issues

#### SA-004: `Skipped` rows do not fit the current report/schema contract

- Severity: Medium
- Status: Confirmed
- Adversarial angle: Schema and test-contract mismatch.
- Spec reference: §3.B, lines 87-97.
- Finding: The spec introduces a `Skipped` action row, but the current report template and Pydantic validator allow only `Created`, `Updated`, `No change needed`, and `FAILED`.
- Repository evidence: `plugins/up-docs/templates/summary-report.md:24-28` defines the four allowed actions. `plugins/up-docs/tests/validate_output.py:52-57` has the same closed enum, and `plugins/up-docs/tests/test_validate_output.py:86-90` rejects unknown actions.
- External research evidence: Not applicable.
- Why it matters: An implementation can update the prose template but leave validators/tests stale, or the combined report can diverge from the canonical action vocabulary.
- Recommended action for Claude Code: Either represent skipped propagation with existing `No change needed` wording, or explicitly add `Skipped` to `summary-report.md`, `validate_output.py`, totals semantics, and tests.
- Suggested validation: Add a validator test for the chosen skip representation and a prompt-conformance assertion that skipped-layer totals are counted consistently.

#### SA-005: The new design is not indexed in `docs/handoff/specs-plans.md`

- Severity: Medium
- Status: Confirmed
- Adversarial angle: Repository convention and discoverability check.
- Spec reference: §2.D4 and §6 rollout, lines 39 and 151-158.
- Finding: The spec chooses the correct `docs/plans/` location but does not include updating `docs/handoff/specs-plans.md`, and the current index has no row for this design.
- Repository evidence: `docs/handoff/specs-plans.md` lists the older up-docs llm-wiki design/plan but not `docs/plans/2026-06-07-up-docs-orchestration-improvements-design.md`. `plugins/up-docs/agents/up-docs-propagate-repo.md:114` says new specs/plans should be added to that table.
- External research evidence: Not applicable.
- Why it matters: Repo instructions treat indexed specs/plans as architectural source-of-truth. A later planning session may miss or misclassify this draft.
- Recommended action for Claude Code: Add a spec correction requiring the design row to be indexed now, and requiring status updates when the spec converges and when the implementation plan is created.
- Suggested validation: `rg -n "2026-06-07-up-docs-orchestration-improvements-design" docs/handoff/specs-plans.md` should find exactly one current row.

#### SA-006: Acceptance criteria can pass without proving the cost outcome

- Severity: Medium
- Status: Confirmed
- Adversarial angle: Acceptance-criteria false positive.
- Spec reference: §3.A/B/C verifiability notes and §6, lines 78-80, 99-101, 127-129, 151-156.
- Finding: Most validation is prompt-conformance text plus one manual scenario. It does not require proving fewer Agent calls, fewer Notion calls, narrowed re-pass candidates, or safe commit behavior under negative cases.
- Repository evidence: Existing `plugins/up-docs/tests/prompt-conformance.bats` is grep-level prompt conformance. The proposed additions follow the same pattern but do not exercise behavior.
- External research evidence: Official Claude Code hooks docs expose Agent tool response telemetry fields such as `totalTokens` and `totalToolUseCount`, which could support a stronger measurement strategy in hooks/transcripts: <https://code.claude.com/docs/en/hooks> (accessed 2026-06-08).
- Why it matters: The main problem is cost-to-outcome. A spec that only checks prompt wording can ship a version that still dispatches too much work or silently loses checks.
- Recommended action for Claude Code: Add at least one behavioral/smoke validation for each change: skipped propagator call count, narrowed re-pass candidate set, and dirty-baseline commit refusal.
- Suggested validation: Use a captured transcript or disposable plugin smoke run to assert no Notion/wiki Agent call occurs for repo-only routed items, and that the auditor receives or computes a smaller pass-N candidate set.

### Missing specification considerations

- Blocking: A concrete `pages_touched` path-set schema and normalization rules for repo/wiki/Notion targets.
- Blocking: Dirty-tree baselines for every repo that the commit offer may touch, including same-path pre-existing edits.
- Blocking: Touched-page audit boundaries after A2; validators and cross-page contradiction checks must remain meaningful.
- Non-blocking: Whether `Skipped` is a new canonical action or just a presentation variant of `No change needed`.
- Non-blocking: `docs/handoff/specs-plans.md` indexing and status lifecycle for this design and its future implementation plan.
- Non-blocking: Cost measurement success criteria, not just prompt wording.
- Non-blocking: Exact definition of “propagation-written paths,” including generated files like bug indexes and user-approved stale-file deletions.

### Ambiguities and decisions needed

- Ambiguity: Is `pages_touched` supposed to be a count, a list, or a map by phase?
  - Why it matters: A1 cannot be implemented reliably without this contract.
  - Recommended clarification: Define a path-list schema and update tracker/auditor output tests.
  - Blocking or non-blocking: Blocking.

- Ambiguity: Should A2 skip entire pages or only exact already-fixed finding signatures?
  - Why it matters: Whole-page skip can bypass validation of fresh mistakes.
  - Recommended clarification: Keep touched pages in validator/cross-reference checks; dedup only duplicate findings.
  - Blocking or non-blocking: Blocking.

- Ambiguity: What happens if `llm-wiki` is dirty before `/up-docs:all` starts?
  - Why it matters: Commit approval may include unrelated work.
  - Recommended clarification: Baseline and refuse/separate pre-existing dirty paths.
  - Blocking or non-blocking: Blocking.

- Ambiguity: Is `Skipped` a first-class report action?
  - Why it matters: Template, schema, totals, and tests must agree.
  - Recommended clarification: Either avoid new enum or update every consumer.
  - Blocking or non-blocking: Non-blocking.

### Internet research performed

- Source name: Claude Code Docs — Create plugins
  - URL: <https://code.claude.com/docs/en/plugins>
  - Access date: 2026-06-08
  - What it was used to verify: Plugin component locations and plugin root structure.
  - Relevant conclusion: `agents/`, `skills/`, `hooks/`, and `.claude-plugin/plugin.json` are valid plugin-root components.

- Source name: Claude Code Docs — Create custom subagents
  - URL: <https://code.claude.com/docs/en/sub-agents>
  - Access date: 2026-06-08
  - What it was used to verify: Agent frontmatter, model aliases, plugin subagents, Agent/Task rename behavior.
  - Relevant conclusion: `model: haiku|sonnet|opus` and Agent tool spawning are current; `Task` was renamed to `Agent` in 2.1.63.

- Source name: Claude Code Docs — Hooks reference
  - URL: <https://code.claude.com/docs/en/hooks>
  - Access date: 2026-06-08
  - What it was used to verify: `Agent` and `AskUserQuestion` tool input shape, `multiSelect`, and Agent telemetry.
  - Relevant conclusion: `AskUserQuestion` supports multiple-choice questions with optional `multiSelect`; Agent tool responses can expose token/tool-use telemetry.

- Source name: Claude Code Docs — Settings
  - URL: <https://code.claude.com/docs/en/settings>
  - Access date: 2026-06-08
  - What it was used to verify: Current permission-rule syntax.
  - Relevant conclusion: Deny/allow permission rules are current but do not affect the repository-contract findings above.

### Items Claude Code should verify before correcting the specification

- Whether the intended A1 source of truth should be tracker state, auditor findings, or a new auditor report field.
- Whether `validate_output.py` is intended to govern future combined reports or only agent JSON outputs.
- Current `llm-wiki` commit conventions and whether commit signing is guaranteed by hooks or git config.
- Whether propagation-written paths can be derived safely from reports, or whether propagators must emit a machine-readable `written_paths` artifact.
- Whether `/up-docs:all` is expected to run interactively only; `AskUserQuestion` behavior differs in non-interactive `-p` contexts unless a hook supplies answers.

### Suggested corrections for Claude Code’s specification

- Replace the A1 `pages_touched` set assumption with an explicit path-list schema and update tracker/output/test scope.
- Change A2 to dedup exact already-fixed findings, while still auditing touched pages for validators, draft status, links, and cross-page contradictions.
- Add pre-propagation dirty baselines for the active project repo and `~/projects/llm-wiki`; refuse or separately disclose pre-existing dirty paths.
- Define `propagation-written paths` as machine-readable output, not inferred prose.
- Decide whether `Skipped` is a new enum; update templates, validators, totals, and tests if so.
- Add `docs/handoff/specs-plans.md` indexing/status updates to rollout.
- Add behavioral validations that prove reduced dispatch/scanning and safe commit refusal under negative cases.

### Read-only validation performed

- `git status --short` — working tree was clean.
- `git branch --show-current` — branch is `main`.
- `git log --oneline -n 10` and `git show --stat --oneline --decorate --no-renames HEAD` — HEAD is the design-spec commit adding this file only.
- Inspected `docs/handoff/state.md`, `AGENTS.md`, `CLAUDE.md`, `docs/handoff/conventions.md`, `docs/handoff/architecture.md`, and `docs/handoff/specs-plans.md` — confirmed repo conventions and missing spec index row.
- Inspected the spec with line numbers — inventoried requirements A/B/C, risks, and validation claims.
- Inspected `plugins/up-docs/agents/up-docs-audit-drift.md`, `scripts/convergence-tracker.sh`, `skills/drift/references/convergence-tracking.md`, `skills/all/SKILL.md`, `templates/summary-report.md`, `templates/post-propagation-steps.md`, `tests/validate_output.py`, and relevant tests.
- `rg` searches for `pages_touched`, `Skipped`, `specs-plans`, commit/staging terms, and validation hooks — confirmed the contract mismatches.
- `git diff --stat` and `git diff --check` — no local diff and no whitespace errors.
- `git ls-files --error-unmatch ...` — confirmed the spec and referenced up-docs files are tracked.
- `wc -c docs/handoff/state.md AGENTS.md CLAUDE.md ...` — repo instruction files are within current byte budgets.
- Inspected `/home/chris/projects/llm-wiki/AGENTS.md` and conventions, and ran `git -C /home/chris/projects/llm-wiki status --short` — confirmed current llm-wiki contract and clean state at audit time.

### Recommended planning/implementation validation

- Run only after implementation: `bash plugins/up-docs/tests/run-bats.sh plugins/up-docs/tests/prompt-conformance.bats`
- Run only after implementation: `cd plugins/up-docs/tests && .venv/bin/python -m pytest -v`
- Run only after implementation: `./scripts/validate-marketplace.sh`
- Add tracker tests proving touched page paths, not counts, persist and drive narrowing.
- Add negative dirty-tree scenario tests for `llm-wiki` pre-existing dirty files and same-path dirtiness.
- Add skipped-layer schema/totals tests for the chosen representation.
- Add a disposable plugin smoke or transcript-based check proving repo-only input skips wiki/Notion propagation while preserving all-layer audit coverage.
- Add a touched-page false-green regression where a page marked `Updated` still has validator or cross-page drift and the auditor catches it.

### Final recommendation

Claude Code should revise the specification using the findings above

### Review ledger for next loop

- Spec path: /home/chris/projects/Claude-Code-Plugins/docs/plans/2026-06-07-up-docs-orchestration-improvements-design.md
- Audit round: 1
- Open issue IDs: SA-001, SA-002, SA-003, SA-004, SA-005, SA-006
- Resolved issue IDs: None
- Superseded issue IDs: None
- Significant findings remaining: Yes
- Next audit should focus on: A1 page-path data contract, A2 touched-page audit semantics, Step 6 dirty-baseline safety, skipped-row schema consistency, specs-plans indexing, and behavioral validation strength.

### Executive summary

Claude Code’s corrections resolved the six prior audit findings at the level of the original defects, including the missing spec index row and the dirty-baseline commit safety gap. Significant findings still remain because the revised spec introduces new under-specified machine-readable contracts: A2’s `(page, discrepancy_type)` dedup key is not supported by the current schemas and is too coarse to prevent false suppression, and C’s `written_paths` safety contract is not integrated with the existing strict propagator output schema.

New internet research was performed against current Claude Code documentation; no external-doc drift invalidated the plugin, Agent, `AskUserQuestion`, `-p`, or version-bump assumptions. The remaining blockers are repository-contract issues.

### Verdict

Needs major specification correction before planning/implementation

### Audit loop status

* Audit type: Follow-up audit
* Spec path: /home/chris/projects/Claude-Code-Plugins/docs/plans/2026-06-07-up-docs-orchestration-improvements-design.md
* Prior audit issue count: 6
* Resolved issue count: 6
* Still open issue count: 0
* Partially resolved issue count: 0
* New issue count: 3
* Regression count: 0
* Significant findings remaining: Yes

### Adversarial review performed

Retested prior fixes SA-001 through SA-006 against the revised spec and current repository contracts. Re-ran repository-fit checks for tracker state, drift finding schema, propagator output schema, summary templates, `/up-docs:all` routing, commit-offer safety, specs/plans indexing, marketplace/version files, and llm-wiki dirty-state assumptions.

Attacked new assumptions introduced by the corrections: that `(page, discrepancy_type)` is an exact finding signature, that propagators can emit `written_paths` without schema work, that an orchestrator can prove zero routed items from the current layer-boundary table, and that the new behavioral tests prove the intended cost/safety outcomes.

Could not run tests or plugin smoke because this audit is read-only and those checks may write caches, invoke agents, or mutate repo/wiki/Notion state.

### Prior findings status

#### SA-001: A1 assumes a page set that the tracker does not persist

* Previous severity: High
* Current status: Resolved
* Evidence: The revised spec no longer assumes the existing tracker already has a path set. It explicitly introduces a new `touched_pages` array contract, keeps numeric `pages_touched` as `len(touched_pages)`, and requires path round-trip tests in `convergence-tracker.bats` (`docs/plans/2026-06-07-up-docs-orchestration-improvements-design.md:41`, `:53-67`, `:165-168`).
* Remaining action for Claude Code: Implement the new tracker/auditor contract exactly; clarify per-pass versus cumulative path storage if planning needs that detail.

#### SA-002: Commit offer can commit pre-existing llm-wiki changes

* Previous severity: High
* Current status: Resolved
* Evidence: The revised spec adds pre-propagation dirty baselines for every committable repo, excludes baseline-dirty paths including same-path collisions, discloses excluded paths, and makes headless runs report-only (`docs/plans/2026-06-07-up-docs-orchestration-improvements-design.md:43`, `:110-133`, `:174-176`). Current llm-wiki status was clean during audit, but the spec now covers the dirty case.
* Remaining action for Claude Code: Address SA-NEW-002 before planning, because the safety model now depends on a `written_paths` contract that is not yet schema-integrated.

#### SA-003: A2 skips whole touched pages before independent audit

* Previous severity: High
* Current status: Resolved
* Evidence: The revised spec explicitly rejects whole-page skipping and requires validator, draft-status, link, and cross-page contradiction checks to run on every page, including touched pages (`docs/plans/2026-06-07-up-docs-orchestration-improvements-design.md:69-81`, `:144-147`).
* Remaining action for Claude Code: Address SA-NEW-001 before planning, because the replacement signature dedup key is not yet safe or implementable as written.

#### SA-004: `Skipped` rows do not fit the current report/schema contract

* Previous severity: Medium
* Current status: Resolved
* Evidence: The revised spec makes `Skipped` presentation-only at the orchestrator combined-report level, not a new table action or `validate_output.py` enum value (`docs/plans/2026-06-07-up-docs-orchestration-improvements-design.md:44`, `:97-101`). This matches the current closed action enum in `plugins/up-docs/tests/validate_output.py:52-57`.
* Remaining action for Claude Code: Keep the implementation out of agent JSON/table action rows; add a presentation-only template/conformance test.

#### SA-005: The new design is not indexed in `docs/handoff/specs-plans.md`

* Previous severity: Medium
* Current status: Resolved
* Evidence: `docs/handoff/specs-plans.md:19` now contains a row for `docs/plans/2026-06-07-up-docs-orchestration-improvements-design.md`, and the spec rollout section requires status updates for this design and the future plan (`docs/plans/2026-06-07-up-docs-orchestration-improvements-design.md:178-181`).
* Remaining action for Claude Code: Update the row’s status when the spec converges and when the implementation plan is created.

#### SA-006: Acceptance criteria can pass without proving the cost outcome

* Previous severity: Medium
* Current status: Resolved
* Evidence: The revised §6 now requires prompt-conformance assertions plus behavioral checks for A1 candidate narrowing, A2 false-green prevention, B skipped Agent dispatch, and C dirty-baseline safety (`docs/plans/2026-06-07-up-docs-orchestration-improvements-design.md:162-176`).
* Remaining action for Claude Code: Update the A2 behavioral test after fixing SA-NEW-001 so it covers signature collisions, not just broken-link/contradiction examples.

### New blocking issues

#### SA-NEW-001: A2’s “exact” finding signature is undefined and too coarse

* Severity: High
* Status: Confirmed
* Adversarial angle: False-green acceptance attack against the replacement for whole-page skipping.
* Spec reference: §3.A2 lines 69-76; risk table line 154.
* Finding: The spec says to dedup “exact finding signatures” but defines the signature as `(page, discrepancy_type)`. Current propagator rows do not emit `discrepancy_type`, current auditor findings do not contain `discrepancy_type`, and `(page, discrepancy_type)` is not exact enough to distinguish two separate defects of the same class on the same page.
* Repository evidence: `plugins/up-docs/templates/summary-report.md:14-19` and `:27` define propagator rows as page/file, action, summary only. `plugins/up-docs/tests/validate_output.py:52-57` validates the same row fields/actions. `plugins/up-docs/templates/drift-finding.md:42-52` and `plugins/up-docs/tests/validate_output.py:149-159` define auditor findings without `discrepancy_type`. `rg -n "discrepancy_type"` found occurrences only in the revised spec.
* External research evidence: Not applicable.
* Why it matters: The acceptance claim “a different defect on a touched page is still reported” is false if the different defect has the same page and discrepancy type. Claude Code could suppress a real unresolved finding while reporting a clean audit.
* Recommended action for Claude Code: Define a machine-readable finding key that is actually exact, for example `finding_key` or `fixed_findings[]` with `layer`, stable target id/path, stale line or field identifier, and intended replacement. Do not infer it from prose summaries. Update auditor/propagator schema and tests accordingly.
* Suggested validation: Add a regression where a propagator fixes one finding on a page while another same-page, same-type finding remains. The auditor must suppress only the fixed key and emit the remaining finding.

#### SA-NEW-002: `written_paths` is required for safe commits but absent from the validated output contract

* Severity: High
* Status: Confirmed
* Adversarial angle: Safety contract/schema mismatch.
* Spec reference: §3.C lines 115-118 and 135-137.
* Finding: The commit offer’s safety model depends on a machine-readable `written_paths` list from propagators, but the spec does not say where that list lives in the current strict report schema. Existing agent output prompts say to return exactly markdown tables, and the Pydantic validator forbids extra top-level fields.
* Repository evidence: Repo, wiki, and Notion propagator output formats are markdown table-only (`plugins/up-docs/agents/up-docs-propagate-repo.md:374-406`, `plugins/up-docs/agents/up-docs-propagate-wiki.md:202-220`, `plugins/up-docs/agents/up-docs-propagate-notion.md:242-260`). `plugins/up-docs/tests/validate_output.py:68-72` defines propagator reports with only `rows` and `totals`, and `plugins/up-docs/tests/test_validate_output.py:101-105` explicitly rejects an extra top-level field.
* External research evidence: Claude Code plugin docs confirm plugin structure and versioning but do not define this repo’s internal report schema.
* Why it matters: If `written_paths` is left as prose or an unvalidated add-on, the commit step may infer paths from tables, miss generated files, include Notion non-file “writes,” or silently lose the very guard that prevents staging unrelated work.
* Recommended action for Claude Code: Specify the contract precisely: either extend validated propagator JSON with `written_paths` or `written_paths_by_repo`, or define a separate sidecar artifact consumed by Step 6. Scope it only to committable repos; Notion should not produce file paths unless represented separately as non-committable page ids.
* Suggested validation: Add schema tests accepting the chosen `written_paths` shape and rejecting invalid/absolute/out-of-repo paths; add dirty-baseline tests proving only validated candidate paths can be staged.

### New non-blocking issues

#### SA-NEW-003: Fast-path layer routing relies on an under-specified boundary table

* Severity: Medium
* Status: Confirmed
* Adversarial angle: Completeness attack against the “provably zero routed items” skip condition.
* Spec reference: §3.B lines 89-95; risk table line 156.
* Finding: The spec tells `/up-docs:all` to tag each item with target layers via the existing Layer Boundaries table, but the current table is only a three-row content-level guide. The detailed routing rules live inside the individual agent prompts, while `/up-docs:all` currently tells the orchestrator not to re-enforce those boundaries.
* Repository evidence: `plugins/up-docs/skills/all/SKILL.md:109-117` has only generic Repo/Wiki/Notion examples and says each sub-agent enforces its own layer boundary. The actual detailed boundaries are distributed across `plugins/up-docs/agents/up-docs-propagate-repo.md:200-214`, `plugins/up-docs/agents/up-docs-propagate-wiki.md:85-100`, and `plugins/up-docs/agents/up-docs-propagate-notion.md:82-120`.
* External research evidence: Not applicable.
* Why it matters: A fast-path skip is only safe if “zero routed items” is operationally decidable. With the current spec, a planner may invent a shallow classifier that skips wiki or Notion for an item the skipped agent would have updated.
* Recommended action for Claude Code: Add a shared routing matrix or classifier contract to `/up-docs:all`, including ambiguous examples and fail-open rules. Keep it synchronized with agent layer boundaries or make the agents expose a dry-run routing result before skipping.
* Suggested validation: Add routing fixtures covering repo-only, wiki-only, Notion-only, repo+wiki, wiki+Notion, and ambiguous items; assert ambiguous items dispatch all candidate layers.

### Regressions

None found.

### Remaining ambiguities and decisions needed

* Ambiguity: What is the canonical A2 dedup key, and which component emits it?
  * Why it matters: `(page, discrepancy_type)` is neither present in current schemas nor exact enough to avoid suppressing real findings.
  * Recommended clarification: Define a validated `finding_key` or `fixed_findings[]` contract with collision-resistant fields.
  * Blocking or non-blocking: Blocking.

* Ambiguity: Is `written_paths` part of agent JSON, markdown, or a separate sidecar?
  * Why it matters: The Step 6 commit offer must not infer safety-critical paths from prose.
  * Recommended clarification: Pick one machine-readable artifact, validate it, and define repo scoping.
  * Blocking or non-blocking: Blocking.

* Ambiguity: What makes a layer “provably” zero-routed?
  * Why it matters: The fast path can skip useful propagation if the orchestrator’s classifier is weaker than agent layer rules.
  * Recommended clarification: Add a routing matrix and negative/ambiguous fixtures.
  * Blocking or non-blocking: Non-blocking.

### Internet research performed

* Source name: Claude Code Docs — Hooks reference
  * URL: https://code.claude.com/docs/en/hooks
  * Access date: 2026-06-08
  * What it was used to verify: `Agent` response telemetry and `AskUserQuestion` input shape.
  * Relevant conclusion: Agent responses expose `totalTokens` and `totalToolUseCount`; `AskUserQuestion` supports multiple-choice questions with optional `multiSelect`.

* Source name: Claude Code Docs — CLI reference
  * URL: https://code.claude.com/docs/en/cli-usage
  * Access date: 2026-06-08
  * What it was used to verify: `claude -p` print/non-interactive mode and prompt-tool behavior.
  * Relevant conclusion: `-p` is non-interactive print mode, and non-interactive permission prompting can be handled via `--permission-prompt-tool`; the spec’s “no consent → no commit” fallback is directionally safe.

* Source name: Claude Code Docs — Create plugins
  * URL: https://code.claude.com/docs/en/plugins
  * Access date: 2026-06-08
  * What it was used to verify: Plugin structure and component placement.
  * Relevant conclusion: `.claude-plugin/plugin.json` is the manifest path, and `skills/`, `commands/`, `agents/`, and hooks belong at plugin root.

* Source name: Claude Code Docs — Plugins reference
  * URL: https://code.claude.com/docs/en/plugins-reference
  * Access date: 2026-06-08
  * What it was used to verify: Version management.
  * Relevant conclusion: Explicit `version` in `plugin.json` or marketplace entry is the update cache key, so the 0.11.0 rollout bump is necessary.

* Source name: Claude Code Docs — Create custom subagents
  * URL: https://code.claude.com/docs/en/sub-agents
  * Access date: 2026-06-08
  * What it was used to verify: Current subagent documentation availability and plugin-agent context.
  * Relevant conclusion: No conflict found with the spec’s continued use of plugin agents.

### Read-only validation performed

* `git status --short` — current repository working tree is clean.
* `git branch --show-current` — branch is `main`.
* `git log --oneline -n 10` — HEAD is `1faa360 docs(plans): up-docs orchestration spec — Codex round 1 fixes (SA-001..006)`.
* `git show --stat --name-only HEAD` — current commit revised the spec, added the round-1 audit artifact, and updated `docs/handoff/specs-plans.md`.
* Inspected `docs/handoff/state.md`, `AGENTS.md`, `CLAUDE.md`, and `docs/handoff/conventions.md` — confirmed v3 session-state conventions and branch/direct-commit rules.
* Inspected the revised spec with line numbers — retested all prior issue corrections and new D6-D10 decisions.
* Inspected `plugins/up-docs/scripts/convergence-tracker.sh`, `plugins/up-docs/tests/convergence-tracker.bats`, `plugins/up-docs/agents/up-docs-audit-drift.md`, `plugins/up-docs/templates/drift-finding.md`, and `plugins/up-docs/tests/validate_output.py` — confirmed current tracker and finding schemas.
* Inspected `plugins/up-docs/skills/all/SKILL.md`, `plugins/up-docs/skills/repo/SKILL.md`, `plugins/up-docs/templates/summary-report.md`, `plugins/up-docs/templates/post-propagation-steps.md`, and all three propagator agent prompts — confirmed current output/routing contracts.
* `rg` searches for `discrepancy_type`, `finding-signature`, `touched_pages`, `written_paths`, `Skipped`, `AskUserQuestion`, and baseline terms — confirmed new signature/written-path fields exist only in the revised spec, not current schemas.
* Inspected `docs/handoff/specs-plans.md` — confirmed the design is indexed at line 19.
* Inspected `.claude-plugin/marketplace.json`, `plugins/up-docs/.claude-plugin/plugin.json`, and `plugins/up-docs/CHANGELOG.md` — confirmed current released baseline is 0.10.1 and rollout paths are `.claude-plugin/...`.
* `git ls-files --error-unmatch ...` — confirmed the spec and key referenced files are tracked.
* `git diff --stat` and `git diff --check` — no local diff and no whitespace errors.
* `git -C /home/chris/projects/llm-wiki status --short` and `git -C /home/chris/projects/llm-wiki branch --show-current` — llm-wiki is currently clean on `main`.
* Inspected `/home/chris/projects/llm-wiki/AGENTS.md` and `docs/handoff/conventions.md` — confirmed llm-wiki validation and draft/page-link contracts relevant to the dirty-baseline and wiki-propagation assumptions.

### Recommended planning/implementation validation

* Run only after implementation: `bash plugins/up-docs/tests/run-bats.sh plugins/up-docs/tests/prompt-conformance.bats plugins/up-docs/tests/convergence-tracker.bats`
* Run only after implementation: `cd plugins/up-docs/tests && .venv/bin/python -m pytest -v`
* Run only after implementation: `./scripts/validate-marketplace.sh`
* Add an A2 collision regression: same page, same discrepancy type, one fixed finding and one still-open finding; only the fixed key is suppressed.
* Add schema tests for the chosen `written_paths` or sidecar contract, including invalid absolute paths, out-of-repo paths, Notion non-file outputs, and generated repo files.
* Add C dirty-baseline tests for clean baseline, baseline-dirty different path, baseline-dirty same path, and headless `-p` no-commit behavior.
* Add B routing fixtures proving skip decisions for repo-only, wiki-only, Notion-only, multi-layer, and ambiguous items.

### Final recommendation

Claude Code should revise the specification using the findings above

### Review ledger for next loop

* Spec path: /home/chris/projects/Claude-Code-Plugins/docs/plans/2026-06-07-up-docs-orchestration-improvements-design.md
* Audit round: 2
* Open issue IDs: SA-NEW-001, SA-NEW-002, SA-NEW-003
* Resolved issue IDs: SA-001, SA-002, SA-003, SA-004, SA-005, SA-006
* Superseded issue IDs: None
* Significant findings remaining: Yes
* Next audit should focus on: A2 exact signature schema and collision regression, Step 6 `written_paths` schema integration, fast-path routing matrix/fixtures, and preservation of the six resolved round-1 fixes.


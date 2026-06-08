# up-docs Hardening Plan v1 — Adversarial Audit

**Audit date:** 2026-05-08 **Plan audited:** `docs/plans/2026-05-08-up-docs-hardening-plan.md` (v1, 2576 lines, 22 tasks across 5 phases) **Verdict:** Unsafe / do not execute as written. 7 blocking + 5 non-blocking findings. v2 rewrite required.

The audit was performed by an external reviewer (qdev-quality-reviewer pattern: claim inventory → repository falsification → blast-radius → failure-mode → validation attack → external-assumption → maintainability passes). It uncovered structural defects in the plan's central security/eval mechanism that make v1 unsafe to execute.

---

## Executive Summary

The plan correctly identifies several real repo issues, but its highest-leverage hardening work depends on unsupported/incorrect Claude Code plugin configuration, weak evidence validation, and integration tests that would skip, hit the wrong plugin, or never exercise the proposed MCP stubs.

Major stale-assumption finding: `plugins/up-docs/.claude/settings.json` is not a supported plugin component location for the proposed permissions/hooks. Current Claude Code plugin docs place plugin hooks at `hooks/hooks.json` or manifest `hooks`; plugin `settings.json` currently supports only `agent` and `subagentStatusLine`.

---

## What v1 gets right (preserve in v2)

- The stale README Opus claim exists, and `up-docs-audit-drift` currently has `model: sonnet`.
- The duplicate `## [0.3.0] - 2026-04-09` CHANGELOG sections exist.
- `plugins/up-docs/tests/link-audit.bats` currently uses the unsafe `echo '$md'` nested-bash pattern.
- `plugins/up-docs/scripts/convergence-tracker.sh` currently hardcodes `/tmp/up-docs-drift-tracker.json`.
- Current plugin version is `0.7.1` in both `plugins/up-docs/.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`.
- Agent frontmatter `disallowedTools` is supported by current Claude Code docs for subagents, so Task 10's direction is plausible if smoke-tested.

---

## Blocking Issues

### CR-001: Proposed `.claude/settings.json` location will not load as a plugin security or hook layer

- Severity: Critical
- Status: Confirmed
- Adversarial angle: The plan's core security/evidence layer may never run.
- Plan reference: Task 9 and Task 11, lines 606-911.
- Finding: The plan creates `plugins/up-docs/.claude/settings.json` and puts both `permissions.deny` and `hooks` there. Current Claude Code plugin docs do not define `plugin-root/.claude/settings.json` as a plugin component. Plugin hooks belong in `hooks/hooks.json` or manifest `hooks`; plugin `settings.json` is at plugin root and currently supports only `agent` and `subagentStatusLine`.
- Repository evidence: `plugins/up-docs/` currently follows plugin-root layout with `.claude-plugin/`, `skills/`, `agents/`, `scripts/`, `tests/`; no `hooks/` or plugin-root `settings.json`. `claude plugin validate plugins/up-docs` only validated the manifest and did not validate any proposed `.claude/settings.json`.
- External research evidence: Claude Code Plugins reference: `hooks/hooks.json` is the hook component location, plugin `settings.json` supports only `agent` and `subagentStatusLine`, and project plugin installation scopes use project `.claude/settings.json`.
- Why it matters: The plan can appear to ship an enforced security boundary and transcript hook while neither is active for users.
- Recommended action: Replace this with supported plugin hook packaging (`hooks/hooks.json` or manifest `hooks`) and either a supported per-agent deny strategy or an explicit consuming-project settings requirement. Do not claim plugin-shipped `permissions.deny` unless verified in current docs/runtime.
- Suggested validation: Run Claude Code with `--plugin-dir ./plugins/up-docs --debug "hooks"` and verify the hook appears as source `Plugin`; run an actual denied-command smoke test in the plugin context.

### CR-002: The deny list does not mirror the auditor's forbidden commands

- Severity: High
- Status: Confirmed
- Adversarial angle: The plan's "enforced layer" leaves documented forbidden operations uncovered.
- Plan reference: Task 9 lines 623-681; auditor forbidden table in `plugins/up-docs/agents/up-docs-audit-drift.md`.
- Finding: The plan says the deny list covers every forbidden verb, but it omits `cp` overwrite cases, output redirections, `tee`, SQL writes, `service X stop`, `ip route add/del`, `pip install`, broad `npm install`, and several package/config edit patterns.
- Repository evidence: Auditor forbidden table lists those categories; planned JSON only includes selected Bash command patterns.
- External research evidence: Claude Code permission docs support pattern-based permission rules, but pattern count is not semantic coverage.
- Why it matters: A validation command like `grep -c "Bash("` can pass while destructive classes remain allowed.
- Recommended action: Either narrow the claim to "partial denylist" or implement a real `PreToolUse` shell-command validator that parses and blocks the full forbidden table.
- Suggested validation: Add smoke tests for `cp`, redirection, `tee`, `service stop`, `ip route add`, `pip install`, `npm install`, and SQL write commands.

### CR-003: Evidence verifier can pass when command ran but output contradicts the evidence

- Severity: High
- Status: Confirmed
- Adversarial angle: The validation can pass while fabricated evidence remains fabricated.
- Plan reference: Task 14 lines 1287-1426.
- Finding: `evidence_signature()` takes the first 40 chars of the evidence string after the first colon. For evidence like `ssh host 'cat version.txt' returned 1.0.0`, the signature is mostly the command. `load_transcript()` searches both `tool_input` and `tool_response`, so the check passes if the command appears even when stdout says `0.8.0`.
- Repository evidence: The proposed code in the plan appends `json.dumps(tool_input)` to the searchable transcript before `tool_response`.
- External research evidence: Claude Code hooks docs confirm PostToolUse includes both `tool_input` and `tool_response`; therefore output-specific assertions are possible.
- Why it matters: This directly undermines the plan's claim that Bug #4 fabrication becomes structurally impossible.
- Recommended action: Change the evidence schema to structured fields such as `command`, `expected_output_signature`, and `source_tool_use_id`, or parse `returned <observation>` and require the observation to appear in `tool_response`, not merely `tool_input`.
- Suggested validation: Add a negative test where the transcript command matches but the response contradicts the claimed value; it must fail.

### CR-004: Integration tests are not wired to the plugin under test or the MCP stubs

- Severity: High
- Status: Confirmed
- Adversarial angle: The plan's integration tests can skip, use an installed stale plugin, or hit real services.
- Plan reference: Tasks 17-18 lines 1741-2094.
- Finding: The tests call `claude --print --agent up-docs:...` without `--plugin-dir ./plugins/up-docs`, do not pass `--mcp-config`, and do not connect the FastMCP stubs to the agent tool names. `tests/run-bats.sh` ignores path arguments and always runs only `tests/*.bats`, so the plan's integration commands will not run the new integration files. `audit-drift.bats` gates all tests in `setup()`, so the "no API needed" Bug #4 test skips unless `RUN_INTEGRATION=1`.
- Repository evidence: `plugins/up-docs/tests/run-bats.sh` lines 1-10 always executes `"$TESTS_DIR"/*.bats`; current plugin agents use real plugin MCP tool names in frontmatter.
- External research evidence: Claude Code CLI docs support `--plugin-dir`; FastMCP docs describe in-memory or configured transports, but the plan does not configure either for Claude Code.
- Why it matters: The v0.8.1 gate can pass without proving the integration surface works.
- Recommended action: Update the Bats wrapper to honor args; pass the plugin under test explicitly; wire stubs through a real Claude Code MCP config or another verified supported mechanism; move the non-API verifier regression outside the integration-gated setup.
- Suggested validation: Prove stub calls were received and no real Notion/Outline tools were used.

### CR-005: `$$` default tracker state breaks normal multi-command drift flow

- Severity: High
- Status: Confirmed
- Adversarial angle: Fixing concurrency can break single-run state persistence.
- Plan reference: Task 6 lines 358-407; Task 21 lines 2344-2368.
- Finding: The proposed default `${TMPDIR:-/tmp}/up-docs-drift-tracker-$$.json` changes on every separate shell process. The drift skill invokes `convergence-tracker.sh` repeatedly as separate commands, and Task 21 does not export a stable `UP_DOCS_TRACKER_STATE`.
- Repository evidence: Current `skills/drift/SKILL.md` calls `context-gather.sh` and `convergence-tracker.sh init`; Task 21 adds more separate invocations.
- External research evidence: Not applicable.
- Why it matters: Without a stable env var, `start-phase`, `record-iteration`, and `check-convergence` can read different files and lose state.
- Recommended action: Establish and export one session/run-scoped state file before all tracker invocations, and test the normal no-manual-env skill flow.
- Suggested validation: Run `init`, `start-phase`, `record-iteration`, and `status` as the skill would, and verify one shared state file is used.

### CR-006: Transcript hook would capture sensitive Bash/Read outputs broadly

- Severity: High
- Status: Confirmed
- Adversarial angle: A testing hook can become a data-leak mechanism.
- Plan reference: Task 11 lines 778-905.
- Finding: The hook captures every Bash and Read `tool_input/tool_response` to `/tmp` by default. If packaged correctly as a plugin hook, it may capture unrelated session commands and file reads whenever the plugin is enabled. It does not set restrictive permissions, scope itself to tests, redact secrets, or clean up logs.
- Repository evidence: Up-docs agents read repo docs and can run SSH/pct/curl against infrastructure; the planned hook captures Bash and Read responses.
- External research evidence: Claude Code hooks docs say PostToolUse input includes tool response; PostToolBatch docs explicitly note Read output can include file content.
- Why it matters: The plan could leak secrets, credentials, environment output, or infrastructure details into temp files.
- Recommended action: Make transcript capture opt-in for tests only, require `UP_DOCS_TRANSCRIPT_LOG`, set `umask 077`, write under the test temp dir, redact known-sensitive fields, and document cleanup.
- Suggested validation: Verify no hook file is produced unless the test env var is set; verify permissions are `0600`.

### CR-007: Python dependency plan is non-reproducible and currently fails in this environment

- Severity: High
- Status: Confirmed
- Adversarial angle: Validation may fail or mutate the user environment instead of proving repo correctness.
- Plan reference: Tasks 12, 13, 17, 19 lines 923-926, 1133-1136, 1749-1752, 2142-2145.
- Finding: The plan uses `pip install --user` fallbacks and adds no repo dependency file. In the current environment, importing `pydantic` fails due a `typing_extensions` import error; `fastmcp` and `deepeval` are not installed. `pip install --user pydantic` may not fix an already-satisfied but broken install.
- Repository evidence: No `pyproject.toml`, `requirements*.txt`, `pytest.ini`, or plugin-local Python dependency manifest exists for up-docs.
- External research evidence: DeepEval docs also indicate LLM-as-judge metrics require model provider credentials by default.
- Why it matters: Release gates become workstation-dependent and can pollute `~/.local`.
- Recommended action: Add a pinned test dependency file or plugin test venv instructions, include `typing_extensions`, and avoid implicit global installs in the plan.
- Suggested validation: Fresh venv: install declared deps, run pytest, then repeat on this machine without relying on existing user-site packages.

---

## Non-Blocking Issues

### CR-008: Pydantic validators are too weak for claimed coverage

- Severity: Medium
- Status: Confirmed
- Adversarial angle: Schema checks can pass wrong-layer outputs.
- Plan reference: Task 12 lines 976-1068.
- Finding: `up-docs-propagate-repo` and `up-docs-propagate-wiki` both use `PropagatorReport`, which allows `layer: "repo" | "wiki" | "notion"`. Totals are not checked against row actions. This does not catch a wiki report labeled repo or inconsistent totals.
- Repository evidence: Proposed validator map sends both repo and wiki agents to the same permissive model.
- External research evidence: Not applicable.
- Why it matters: Validation quality is lower than the plan claims.
- Recommended action: Add distinct Repo/Wiki/Notion report classes and totals consistency validators.
- Suggested validation: Add negative tests for wrong layer and mismatched totals.

### CR-009: Layout config documents `auto`, `v1`, `v2`, and `none` but only implements new SIMPLE/DIATAXIS handling

- Severity: Medium
- Status: Confirmed
- Adversarial angle: Config values documented to users may fall into no branch.
- Plan reference: Task 20 lines 2239-2310.
- Finding: The probe echoes `AUTO` when config says `"layout": "auto"`, but the plan only says existing V1/V2/NONE branches are reused and adds SIMPLE/DIATAXIS. README documents `auto`, `v1`, `v2`, `none`.
- Repository evidence: Current agent only has V1/V2/NONE detection; plan replacement would bypass that when config exists.
- External research evidence: Not applicable.
- Why it matters: A user following README with `"layout": "auto"` could get an unhandled layout.
- Recommended action: Define exact branch behavior for `auto`, `v1`, `v2`, and `none`, including validation for unknown values.
- Suggested validation: Add prompt/examples or tests for every documented layout value.

### CR-010: Link-audit regression test does not prove the current pattern is fragile

- Severity: Low
- Status: Confirmed
- Adversarial angle: A regression test can pass before the fix.
- Plan reference: Task 5 lines 261-278.
- Finding: The new test uses the proposed safe `printf "$1"` pattern from the start, so it does not fail against the current unsafe pattern.
- Repository evidence: Existing `link-audit.bats` uses `run bash -c "echo '$md' | ..."` in several tests.
- External research evidence: Not applicable.
- Why it matters: The plan's red/green signal is weak.
- Recommended action: First add a failing test that exercises the old invocation path, or make the rewrite and then validate all invocations are safe.
- Suggested validation: `rg "echo '\\$md'|echo '\\$" plugins/up-docs/tests/link-audit.bats` should return no unsafe invocations after the rewrite.

### CR-011: README v2.1.92 task contradicts itself

- Severity: Low
- Status: Confirmed
- Adversarial angle: Task intent and instructions diverge.
- Plan reference: Task 3 lines 163-188.
- Finding: The task says to move the note to a "Resolved" subsection, but the steps delete it and verify `grep -c "v2.1.92"` is `0`.
- Repository evidence: README currently contains the v2.1.92 Known Issues bullet.
- External research evidence: GitHub issue check not needed for this plan contradiction.
- Why it matters: Claude Code may implement a different outcome than the task title promises.
- Recommended action: Decide whether to delete or move to resolved history; update task wording accordingly.
- Suggested validation: README contains either no `v2.1.92` or a deliberate Resolved subsection, matching the plan.

### CR-012: Optional DeepEval code appears stale against current docs

- Severity: Low
- Status: Needs verification (resolved by 2026-05-08 research: confirmed stale)
- Adversarial angle: Optional task may fail after install.
- Plan reference: Task 19 lines 2164-2205.
- Finding: The plan imports `LLMTestCaseParams`; current DeepEval docs use `SingleTurnParams` for GEval evaluation parameters and note GEval defaults to an LLM provider requiring credentials.
- Repository evidence: DeepEval is not installed locally.
- External research evidence: DeepEval GEval docs accessed 2026-05-08 show `SingleTurnParams` in examples and required `input`/`actual_output`.
- Why it matters: Optional v0.9.1 may fail or silently require OpenAI credentials despite the plan mentioning Anthropic.
- Recommended action: Verify against installed DeepEval version before writing Task 19 code; pin the dependency if kept.
- Suggested validation: In a clean venv, run the optional test skipped and enabled with the intended provider config.

---

## Static verification performed by maintainer (2026-05-08, post-audit)

| Finding | Verification | Result |
| --- | --- | --- |
| CR-001 | `find plugins -path '*/.claude/settings.json'` → 0 hits; `find plugins -name "hooks.json"` → 5 sibling plugins (release-pipeline, opus-context, github-repo-manager, home-assistant-dev, plugin-test-harness fixture) | Confirmed: hooks ship via `hooks/hooks.json`; plan's `.claude/settings.json` packaging is invalid. |
| CR-003 | Traced `evidence_signature()` on Bug #4 fixture: signature is 40 chars of the _command_, not response. `load_transcript()` searches `tool_input` + `tool_response` union — signature matches even when response contradicts evidence claim. | Confirmed: anti-fabrication argument is broken as written. |
| CR-005 | Three sequential `bash -c 'echo $$'` calls: PIDs 137702 → 137703 → 137704 | Confirmed: `-$$.json` default breaks multi-call skill flow. |
| CR-004 | `run-bats.sh` line 10: `"$TESTS_DIR"/*.bats` — passed paths ignored. `audit-drift.bats setup()` gates ALL tests on `RUN_INTEGRATION` AND `ANTHROPIC_API_KEY`. No `--plugin-dir`, no `--mcp-config` wiring to FastMCP stubs. | Confirmed on every sub-claim. |

Remaining 8 findings accepted on inspection of v1 plan text without further repository falsification.

---

## Items the v2 plan must address (consolidated checklist)

Blocking — must be resolved or v2 cannot be shipped:

- [ ] Hook packaging via `hooks/hooks.json` (CR-001)
- [ ] Deny list scope clearly stated; `PreToolUse` validator script handles full command lines including shell metacharacters and inline SQL (CR-002)
- [ ] Evidence schema with structured `command`/`expected_output_signature` fields; verifier requires signature in `tool_response` not the union (CR-003)
- [ ] Integration tests pass `--plugin-dir`, `--mcp-config`, and `--strict-mcp-config`; MCP stubs wired via stdio transport; `run-bats.sh` honors path arguments; non-API regression test moved out of integration-gated setup (CR-004)
- [ ] Tracker state defaults to `${CLAUDE_CODE_SESSION_ID}` (May 2026 env var) for stable per-session keying (CR-005)
- [ ] Transcript hook is opt-in via env var; uses `umask 077`; redacts known secret patterns; cleans up on `Stop` event (CR-006)
- [ ] Python deps pinned in plugin-local `pyproject.toml` or `requirements-test.txt`; no `pip install --user` fallbacks (CR-007)

Non-blocking — preferred for v2 completeness:

- [ ] Pydantic discriminated union over `layer` Literal types (CR-008)
- [ ] Layout config: explicit branch behavior for every documented value (CR-009)
- [ ] Link-audit regression test exercises the OLD pattern first (CR-010)
- [ ] v2.1.92 task pick-one: either delete fully or move to a Resolved subsection consistently (CR-011)
- [ ] DeepEval pinned ≥1.4.0; uses `SingleTurnParams` and `AnthropicModel`; sets `DEEPEVAL_TELEMETRY_OPT_OUT=YES` (CR-012)

---

## Audit ledger

- Plan path: `docs/plans/2026-05-08-up-docs-hardening-plan.md` (v1)
- Audit round: 1
- Open issue IDs: CR-001 through CR-012
- Resolved issue IDs: None
- Significant findings remaining: Yes
- Verdict: Do not execute v1; produce v2 grounded in `docs/research/2026-05-08-up-docs-plugin-security-eval-infrastructure.md`.

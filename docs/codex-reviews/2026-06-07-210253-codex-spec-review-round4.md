### Executive summary

Claude Code’s round-3 corrections resolve the two remaining findings from the prior pass. The revised D8 text no longer overclaims git-run ownership: it correctly treats git output as a changed-since-baseline candidate surface and moves safety to per-path diff disclosure, explicit approval, late re-check, and literal pathspec staging. The `docs/handoff/specs-plans.md` row now matches the current D7/D8/D11 design.

New internet research was performed for the git and Claude Code CLI assumptions that still matter to this spec. No significant findings remain.

### Verdict

No significant findings remain

### Audit loop status

- Audit type: Follow-up audit
- Spec path: /home/chris/projects/Claude-Code-Plugins/docs/plans/2026-06-07-up-docs-orchestration-improvements-design.md
- Prior audit issue count: 2
- Resolved issue count: 2
- Still open issue count: 0
- Partially resolved issue count: 0
- New issue count: 0
- Regression count: 0
- Significant findings remaining: No

### Adversarial review performed

Retested SA-NEW-004 and SA-NEW-005 against the revised spec and repository evidence. Rechecked the current spec, specs/plans index, `/up-docs:all` and `/up-docs:repo` skill prompts, post-propagation template, summary template, tracker script/tests, drift auditor prompt, propagator schemas, plugin/marketplace version state, current git history, and the llm-wiki repo state.

Attacked the corrected D8 path-ownership model, baseline/late-recheck timing, non-interactive behavior, baseline-dirty collision handling, approval false positives, D7 dropped-dedup preservation, D11 routing preservation, and the stale index-row correction. Tests and plugin smoke were not run because this is a read-only audit and those checks can write caches/artifacts or invoke agents.

### Prior findings status

#### SA-NEW-004: Git-baseline candidates do not prove run ownership

- Previous severity: High
- Current status: Resolved
- Evidence: The revised D8 decision explicitly says candidates are paths “changed since baseline” and “NOT asserted to be run-owned” (`docs/plans/2026-06-07-up-docs-orchestration-improvements-design.md:39`). §3.C repeats that a hook/editor/other process may dirty a clean-baseline path, and that ownership is established by human diff review rather than git (`docs/plans/2026-06-07-up-docs-orchestration-improvements-design.md:97-102`). The offer now requires per-path diff disclosure, multi-select approval, a late porcelain re-check, re-disclosure on unexpected changes, literal pathspec staging, and no push (`docs/plans/2026-06-07-up-docs-orchestration-improvements-design.md:104-114`). The risk table and tests now include the post-baseline unrelated-dirty case (`docs/plans/2026-06-07-up-docs-orchestration-improvements-design.md:141`, `157-161`).
- Remaining action for Claude Code: None before planning. During implementation, preserve the distinction between “changed since baseline” and “run-owned,” and make the approval UI disclose enough diff content for a meaningful human decision.

#### SA-NEW-005: The specs/plans index still describes the dropped A2 design

- Previous severity: Medium
- Current status: Resolved
- Evidence: `docs/handoff/specs-plans.md:19` now describes A2 as dropped via D7, D8 as “changed since baseline” with per-path diff approval and late re-check, and D11 as fail-open routing. It no longer says only round 1 was applied or that signature-level dedup remains planned.
- Remaining action for Claude Code: None before planning. Keep the row status-current when the spec converges and when the implementation plan is created.

### New blocking issues

None found.

### New non-blocking issues

None found.

### Regressions

None found.

### Remaining ambiguities and decisions needed

None found.

### Internet research performed

- Source name: Git documentation — git-status
- URL: <https://git-scm.com/docs/git-status>
- Access date: 2026-06-08
- What it was used to verify: `git status --porcelain=v1 -z` parsing semantics and whether status output proves changed paths rather than process ownership.
- Relevant conclusion: Porcelain status is stable for scripts; `-z` uses NUL-delimited entries. It reports path state, not who changed the path.

- Source name: Git documentation — git-add
- URL: <https://git-scm.com/docs/git-add>
- Access date: 2026-06-08
- What it was used to verify: Safe staging of selected pathspecs.
- Relevant conclusion: Git supports `--pathspec-from-file` and `--pathspec-file-nul`; staging selected current contents still does not prove authorship.

- Source name: Git documentation — git-diff
- URL: <https://git-scm.com/docs/git-diff>
- Access date: 2026-06-08
- What it was used to verify: Difference between full diff output and summary/stat output.
- Relevant conclusion: Summary/stat forms are condensed; implementation should ensure the user gets enough per-path diff disclosure to approve safely.

- Source name: Claude Code CLI reference
- URL: <https://code.claude.com/docs/en/cli-usage>
- Access date: 2026-06-08
- What it was used to verify: `-p` / `--print` non-interactive mode.
- Relevant conclusion: `claude -p` is a non-interactive SDK-style invocation, so D10’s “no consent, no commit” rule is appropriate.

### Read-only validation performed

- `git status --short`, `git branch --show-current`, `git log --oneline -n 10` — repo is on `main`, working tree is clean, HEAD is the round-3 fix commit.
- `git show --stat --name-only HEAD` — confirmed the latest commit updated the spec, the specs/plans index, and the round-3 audit artifact.
- Inspected `docs/handoff/state.md`, `AGENTS.md`, `CLAUDE.md`, and `docs/handoff/conventions.md` — confirmed repo startup/session rules and v3 handoff conventions.
- Inspected the revised spec with line numbers — retested D6-D11, §3.A-C, §6 test/rollout, and §8 ledger.
- Inspected `docs/handoff/specs-plans.md` — confirmed the orchestration design row now reflects D7/D8/D11 and round-1 through round-3 status.
- Inspected `/up-docs` skills, templates, propagator prompts, auditor prompt, tracker script/tests, and output validator — confirmed current baseline surfaces the spec intends to change.
- `rg` searches for `written_paths`, `fixed_findings`, `discrepancy_type`, `touched_pages`, `baseline`, `porcelain`, `routing matrix`, `Skipped`, `AskUserQuestion`, and `git diff` — confirmed A2 and `written_paths` schema work remain dropped, and D8/D11 are spec-only changes awaiting implementation.
- Inspected plugin manifest, marketplace manifest, and changelog — confirmed current shipped baseline remains `up-docs` 0.10.1 and the spec’s 0.11.0 target is future work.
- `git ls-files --error-unmatch ...` — confirmed the spec and key referenced repo files are tracked.
- `git diff --stat` and `git diff --check` — no local diff or whitespace errors.
- `git -C /home/chris/projects/llm-wiki status --short`, branch, and recent log — llm-wiki is clean on `main`, relevant to Step 6 baseline behavior.

### Recommended planning/implementation validation

- Run only after implementation: `bash plugins/up-docs/tests/run-bats.sh plugins/up-docs/tests/prompt-conformance.bats plugins/up-docs/tests/convergence-tracker.bats`
- Run only after implementation: `cd plugins/up-docs/tests && .venv/bin/python -m pytest -v`
- Run only after implementation: `./scripts/validate-marketplace.sh`
- Add C commit-safety fixtures for clean baseline, baseline-dirty different path, baseline-dirty same path, post-baseline unrelated dirty path, headless `-p`, paths with spaces/special characters, deleted files, untracked files, and non-approved candidate paths.
- Add B routing fixtures for repo-only, wiki-only, Notion-only, multi-layer, and ambiguous fail-open routing.
- Add A1 tracker/auditor tests proving `touched_pages` path round-trip and pass-2 candidate narrowing.
- For staging implementation, prefer NUL/literal pathspec handling such as `--pathspec-from-file=- --pathspec-file-nul` or an equivalently safe array-based implementation.

### Final recommendation

No significant findings remain; the audit/fix loop can stop

### Review ledger for next loop

- Spec path: /home/chris/projects/Claude-Code-Plugins/docs/plans/2026-06-07-up-docs-orchestration-improvements-design.md
- Audit round: 4
- Open issue IDs: None
- Resolved issue IDs: SA-001, SA-002, SA-003, SA-004, SA-005, SA-006, SA-NEW-001, SA-NEW-002, SA-NEW-003, SA-NEW-004, SA-NEW-005
- Superseded issue IDs: None
- Significant findings remaining: No
- Next audit should focus on: Not needed unless the spec changes again; if it does, recheck D8 commit-safety wording, specs/plans index freshness, and preservation of D6/D7/D9/D11 decisions.

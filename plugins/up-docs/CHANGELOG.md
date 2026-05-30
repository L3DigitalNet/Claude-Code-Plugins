# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [0.9.1] - 2026-05-30

### Changed
- propagate-repo: the `AGENTS.md` / `AGENTS.reviews.md` / `conventions.md` mandatory audit now explicitly scans for **retired V1/V2 layout-detection** language — pre-v3 `detect layout first. V2:… V1:…` Session-state conditionals, `V2 repos read… / V1 legacy…` review-input conditionals, and stale `(V2 handoff layout)` version labels — and relabels them to the v3 single-path form. The catch was previously non-deterministic: a `/up-docs:repo` run after v0.9.0 shipped left two `AGENTS.md` stragglers and a `conventions.md` label that only a later `/up-docs:all` drift audit caught. New `tests/prompt-conformance.bats` guard (52 bats total).

### Added
- README "Propagation vs. drift" section + `/up-docs:repo` skill note: the propagators (`/up-docs:repo|wiki|notion`) run no drift auditor and will not catch pre-existing drift the current session didn't introduce; run `/up-docs:drift` or `/up-docs:all` periodically (e.g. after a release).

## [0.9.0] - 2026-05-30

### Fixed
- propagate-repo: `AGENTS.md` remediation now emits the handoff v3 three-line block (`Session state:` / `Full conventions reference:` / `Detailed review workflows:`) — prior output failed `validate-layout.sh`'s Codex block. (Bug #6)
- propagate-repo: new bug files include `## Lesson` (handoff v3 Cause/Fix/Lesson body). (Bug #6)
- propagate-repo: state.md over-cap trim is route-first (route to sessions/deployed/architecture before deleting), per handoff v3.

### Added
- propagate-repo: enforces `CLAUDE.md` (≤2048) and `AGENTS.md` (≤4096) byte caps; audits `docs/specs-plans.md`; verifies bug-index regen with `git diff --exit-code`.
- audit-drift: conditional handoff-layout conformance phase — runs `~/projects/agent-configs/scripts/validate-layout.sh` against the project root when present and surfaces failures as `layer: "layout"` findings (read-only; never fixes).

### Changed
- Relabeled handoff "v2" → "v3"; removed stale `/mnt/share/` migration pointer and superseded "Phase 5 / §9.2 / ≤200-line rules cap" references (not part of the v3 contract).


## [0.8.4] - 2026-05-29

### Fixed
- state-condition the docs/state.md 2KB cap enforcement


## [0.8.3] - 2026-05-29

### Changed
- de-dup skills, fix stale evidence schema, drop orphaned reference


## [0.8.2] - 2026-05-29

### Fixed
- remove unsound deny-guard PreToolUse hook


## [0.8.1] - 2026-05-25

### Fixed
- repair bats suite — neutralize global git hook + add deny-guard transcript fixture
- scope deny-guard to up-docs subagents only


## [0.8.0] - 2026-05-08

### Added
- `hooks/hooks.json` — plugin-shipped hook component (PreToolUse + PostToolUse) at the supported plugin path; replaces v1's invalid `.claude/settings.json` packaging.
- `scripts/deny-guard.sh` — PreToolUse forbidden-command validator. Parses pipes, redirects, `&&` chains, `$()`, backticks; mirrors the auditor's `<forbidden_commands>` table. Defense-in-depth, NOT an enforced security boundary. 13 bats tests.
- `scripts/capture-transcript.sh` + `scripts/_capture-redactor.py` — opt-in PostToolUse capture hook. No-op unless `UP_DOCS_TRANSCRIPT_LOG` is set; uses `umask 077`; redacts Bearer/ghp/ghs/AKIA/BAO_TOKEN/password/token/sk-ant-/aws_secret patterns; truncates output at 4 KiB; Bash only (Read excluded — file contents leak per GH-44868). 10 bats tests.
- `tests/pyproject.toml` — pinned test deps (pydantic ≥2.5, pytest ≥8.0, fastmcp optional, deepeval optional). Run from `plugins/up-docs/tests/.venv`.
- `tests/validate_output.py` — Pydantic v2 discriminated-union validators for all four agent outputs. Layered reports use `Annotated[Union[RepoReport, WikiReport, NotionReport], Field(discriminator="layer")]`; structural mismatch produces `union_tag_invalid` naming the bad tag and the expected literals. NotionReport additionally rejects IPv4 leaks; totals are reconciled against row actions.
- `tests/verify_evidence_grounded.py` — structured-evidence transcript verifier. Requires `expected_output_signature` to literally appear in `tool_response.output` of a transcript record matching `evidence.command`; closes the v1 audit's CR-003 gap (the command-but-output-contradicts case).
- `tests/test_validate_output.py` and `tests/test_verify_evidence_grounded.py` — 26 self-tests including a CR-003-specific contradiction case and a Bug #4 no-record case.
- `CLAUDE_CODE_SESSION_ID`-based default state file in `convergence-tracker.sh` — replaces v1 plan's broken `-$$.json` default. Persists state across the multiple separate invocations the drift skill makes per session. 3 new bats tests.
- README §Security — documents the plugin's defense-in-depth `deny-guard.sh` and recommends a consumer-side `permissions.deny` block for projects that want a hard security boundary.

### Changed
- Auditor (`up-docs-audit-drift`) prompt: `evidence` is now a structured object `{command, expected_output_signature, source_tool_use_id?}` instead of a free-form string. New no-fabrication rule in `<verification_discipline>`: when `expected_output_signature` was not literally observed in tool output, the auditor MUST set `confidence: "unverifiable"` and `evidence: null` rather than inventing a signature. All 4 examples + the output_format JSON updated to the structured shape.
- `tests/run-bats.sh` honors explicit path arguments (single files, directories, multiple files), falling back to the top-level glob when called bare. Closes CR-004's wrapper-side gap.
- All five skill files now check for `python3` in PATH at Step 1 and exit with a clear ERROR message if missing.

### Fixed
- v1 plan's CR-001 through CR-008 audit findings — see [`docs/plans/2026-05-08-up-docs-hardening-plan-v1-audit.md`](../../docs/plans/2026-05-08-up-docs-hardening-plan-v1-audit.md) for the full list of structural defects this release closes.

### Notes
- Phase 2 hook-firing smoke test (Task 8) result: PASS (2026-05-08, claude 2.1.133). See `plugins/up-docs/docs/phase-2-smoke-result.txt`.

## [0.7.2] - 2026-05-08

### Fixed
- README "Known Issues" no longer claims drift analysis is "designed for Opus 4.6" — auditor runs Sonnet by frontmatter; Opus is opt-in via the escalation block.
- Stale Claude Code v2.1.92 MCP-loading mitigation note removed from Known Issues.
- Duplicate `## [0.3.0]` CHANGELOG entry merged into one block.
- `tests/link-audit.bats` no longer breaks on inputs containing single quotes; added a red-first regression test that exercises the `O'Reilly`-style failure case using the OLD pattern, then rewrites all 8 invocations to the safe `printf '%s\n' "$1"` form.

### Added
- README §Requirements now lists Python 3.x in `$PATH` as a hard prerequisite (used by all four helper scripts under `scripts/`).

## [0.7.1] - 2026-04-24

### Fixed

- `up-docs-propagate-repo` agent now audits **`AGENTS.md`** and **`AGENTS.reviews.md`** as mandatory targets on every run (same discipline as `CLAUDE.md`). These are Codex CLI's equivalent of `CLAUDE.md`; v0.7.0's mandatory-audit list omitted them, so a V2 migration could leave their "Session handoff: docs/handoff.md" pointers unchanged — Codex sessions would then try to read a deleted file. Discovered by the drift auditor on the homelab `/up-docs:all` run that ran immediately after v0.7.0 shipped. The auditor caught 4 findings; 2 of them were these two files.
- `up-docs-propagate-repo` V2 mandatory-audit block gains a **post-split self-reference check**: after Phase 1 has moved content from `docs/handoff.md` into `docs/state.md` (and siblings), grep the new files for literal `docs/handoff.md` strings. Pre-migration Session Instructions text frequently contained self-references like "Check `docs/handoff.md` (this file)" that became stale after the file was renamed to `state.md`. The check covers `state.md`, `deployed.md`, `architecture.md`, `credentials.md` — any of which may have inherited handoff.md references from their source sections. Fix in-place. Drift auditor caught this on homelab (`docs/state.md:11` was the offender).
- Stale-file-scan NEVER-flag list extended to include `AGENTS.reviews.md` (was only `AGENTS.md` in v0.7.0).

### Notes

Both fixes traced to the same root cause — v0.7.0's mandatory-audit list was modeled on Claude Code's file set (`CLAUDE.md` + `docs/`) and didn't account for Codex-specific files or self-reference drift from renames. Neither was caught in v0.7.0's example block, which kept the gaps invisible until a real-world `/up-docs:all` invocation exercised the full audit path.

## [0.7.0] - 2026-04-24

### Changed

- **Handoff-system-v2 adaptation.** `up-docs-propagate-repo`, `/up-docs:repo`, and `/up-docs:all` now target the post-2026-04-24 handoff layout (`docs/state.md` + `docs/deployed.md` + `docs/architecture.md` + `docs/credentials.md` + `docs/sessions/<YYYY-MM>.md` + `docs/bugs/<NNN>-*.md` + `docs/conventions.md` + `.claude/rules/*.md`) while preserving full backward compatibility with the legacy `docs/handoff.md` layout via probe-based detection. Rationale: 23 repos in the author's fleet migrated to v2 during the 2026-04-24 batch (pre/post reduction 91.1% aggregate); the plugin now matches.

  - **Layout detection:** agent probes `docs/state.md` first. If present → V2; if absent and `docs/handoff.md` present → V1 legacy; otherwise NONE. No CLI flag or user input required.
  - **V2 mandatory-audit rewrite:** `docs/state.md` (`**Last updated:**` + `🔴/🟡/🟢` active-incidents block under `## Session Instructions`, 2 KB hard cap), `docs/deployed.md` (deployment-truth rows + What Remains), `docs/architecture.md` (system graph, optional), `docs/credentials.md` (secret paths, optional), `docs/sessions/<current-month>.md` (append row with ≤20-word headline + commit SHAs + bug refs; update INDEX.md row count), `docs/bugs/<NNN>-<slug>.md` (create one per session-fixed bug with frontmatter; run `docs/bugs/_regen_index.py` after), `docs/conventions.md` (numbered skeleton; full rule body may live in `.claude/rules/` after Phase 5 of migration), `.claude/rules/<topic>.md` (path-scoped behavioral rules, ≤200 lines per file), `CLAUDE.md` (usually no-change post-migration — pure index).
  - **V1 legacy fallback:** repos that haven't run the v2 migration still work. Agent falls back to the pre-0.7.0 audit (`docs/handoff.md` + `docs/conventions.md`) and includes an advisory note in its output suggesting the migration.
  - **Handoff brief (Step 6/7 in skills) upgraded:** sources fields from the matching layout. V2 brief pulls Last-work from `docs/sessions/<current-month>.md`, deployed from `docs/deployed.md`, active incidents from `docs/state.md`, open bugs from `docs/bugs/INDEX.md` (rows with `status != fixed`). V1 brief unchanged. NONE skips the brief silently.
  - **Append-only bug KB rule codified:** creating a new bug file uses `max(existing_ids) + 1`; editing or renumbering prior bug files is forbidden. Supersession handled via `supersedes:` / `superseded_by:` frontmatter fields, both files kept.
  - **Stale-file scan NEVER-flag list** extended to include v2 files (`docs/state.md`, `docs/deployed.md`, `docs/architecture.md`, `docs/credentials.md`, `docs/specs-plans.md`), the `docs/sessions/` and `docs/bugs/` directories (persistent logs), and everything under `.claude/` (plugin-lifecycle-managed).
  - **`python3 docs/bugs/_regen_index.py`** is a sanctioned Bash call in the agent's guardrails (only destructive-adjacent operation allowed; rewrites `docs/bugs/INDEX.md` idempotently from frontmatter).

- `templates/drift-finding.md` example row updated: `docs/handoff.md` → `docs/deployed.md` to reflect the new layout's deployed-truth file.

### Notes

Rule-body migration decision per repo:

- **Phase 5 run (rule bodies in `.claude/rules/`):** extend the matching rules file; leave `docs/conventions.md` pointer unchanged.
- **Phase 5 deferred (real conventions.md still full-body):** append to `docs/conventions.md` using the six-field schema + Quick Reference row.
- **Template DOC-001/002/003 conventions.md:** extend `docs/conventions.md` for now; Phase 5 backfill will migrate to rules later.

The plugin does not enforce one or the other — it adapts to what exists.

## [0.6.1] - 2026-04-23

### Fixed

- `up-docs-propagate-notion` agent no longer fabricates version strings, identifiers, paths, or other load-bearing values when composing Notion prose. Added a dedicated `<verification_discipline>` block mirroring the pattern already applied to `up-docs-audit-drift` in 0.5.1: every fact written to Notion must come verbatim from the session-change summary or a just-retrieved `notion-fetch` result. Copy-paste discipline is mandatory; reconstruction from pattern or memory is forbidden. Includes sanctioned escape paths (omit missing detail, skip edit as "No change needed") when a value is not in the summary. Triggered by a 2026-04-23 `/up-docs:all` run that wrote three fabricated plugin version numbers (`2.3.0`, `2.2.0`, `3.1.0` instead of `2.2.7`, `1.4.0`, `1.1.0`) into the Claude Code Plugins page — drift auditor caught the discrepancy on the same run.

## [0.6.0] - 2026-04-20

### Added
- `up-docs-propagate-repo` agent now performs **handoff.md pruning** and **stale-file candidate detection** on every run as routine maintenance:
  - **Handoff pruning:** `docs/handoff.md` "Last Updated" section retains at most the 5 most recent entries — older entries are pruned (session outcomes live in git log + CHANGELOGs already). "Bugs Found And Fixed" is explicitly non-prunable (persistent log). Pruning rules for "What Is Deployed", "Architecture", "Gotchas" require demonstrable staleness, not age alone.
  - **Stale file scan:** globs `docs/superpowers/plans/`, `docs/superpowers/specs/`, `docs/plans/`, `docs/specs/`, and ISO-8601-prefixed files under `docs/` for candidates. A file is flagged only when ALL three hold: (a) contains a completion marker (`Status: ✅ Complete`, `DO NOT EXECUTE`, `superseded by`, etc.); (b) referenced work is shipped/abandoned per CHANGELOG evidence; (c) older than 60 days. Active plans, templates, handoff/conventions/CLAUDE/README/AGENTS, and persistent logs are never flagged.
  - **Permission-gated deletion:** agent surfaces candidates in a new `## Stale File Candidates` section of its output; it never executes `rm` or `git rm`. The `/up-docs:repo` and `/up-docs:all` skills pick up the list, present it via `AskUserQuestion` (multi-select), and run `git rm` only on explicitly-approved paths. No-op when zero candidates.
- `up-docs-propagate-repo` guardrails explicitly forbid destructive bash operations (`rm`, `git rm`, `mv` of delete-marked files, truncating redirects). Deletion remains a skill+user responsibility.
- `/up-docs:repo` and `/up-docs:all` gain `AskUserQuestion` in their `allowed-tools` list and a new Step 5/6 for stale-candidate review.

### Changed
- `up-docs-audit-drift` output-format block now explicitly enumerates the five required `stats` keys (`total_findings`, `by_layer`, `high_confidence`, `unverifiable`, `destructive_fixes_required`) and states that `unverifiable` must always be emitted, even when zero. Prior `<output_format>` listed the key in its example but a `/up-docs:all` run still emitted the legacy 4-key shape — the few-shot gradient from single-finding examples without stats blocks pulled the model toward pre-training defaults. Explicit enumeration pins the schema.


## [0.5.1] - 2026-04-20

### Fixed
- `up-docs-audit-drift` agent no longer fabricates verification evidence. The agent prompt now has a dedicated `<verification_discipline>` block defining two sanctioned responses when a verification command fails (omit the finding, or record with `"confidence": "unverifiable"` and put the literal error text in `evidence`). Added a worked example covering the "No such file or directory" case that previously led to invented findings (Hermes v0.8.0 → v1.0.0 fabrication reported 2026-04-20). Confidence enum extended to `"high" | "medium" | "low" | "unverifiable"`, and stats block gained an `unverifiable` counter.
- `templates/drift-finding.md` `evidence` field rule rewritten with explicit guard: verbatim output only, `"Command failed: <error>"` when verification fails, never fabricate. Confidence enum updated to match.


## [0.5.0] - 2026-04-20

### Added
- `up-docs-propagate-repo` agent now performs a **mandatory audit** of `docs/handoff.md` and `docs/conventions.md` on every run (when either file exists). The audit covers each `docs/handoff.md` schema section (Last Updated, What Is Deployed, What Remains, Bugs Found And Fixed, Architecture, Credentials, Gotchas) and extracts any session-durable pattern into `docs/conventions.md` using the six-field schema + Quick Reference row. Both files always appear in the propagator's output table as explicit rows — never silently omitted.
- `up-docs-propagate-repo` agent `<writing_style>` block codifies the repo-doc audience split: `README.md` files are human-facing prose; `CLAUDE.md`, `AGENTS.md`, and everything under `docs/` are LLM-facing (terse, scannable, tables over narrative). The agent preserves existing style when extending a file.
- `/up-docs:repo` and `/up-docs:all` skills now emit a **"Handoff for Next Session" brief** after the propagator table. The brief is a scannable read-only excerpt of the updated `docs/handoff.md` (Last Updated, Currently Deployed, Open Items, Open Bugs, Gotchas) meant to bridge session boundaries.

### Changed
- `up-docs-propagate-repo` guardrails explicitly allow the mandatory `docs/handoff.md` + `docs/conventions.md` audit as an exception to the "only act on items in the session-change summary" rule.


## [0.4.1] - 2026-04-20

### Fixed
- Orchestrator and wrapper skills now pass the plugin-namespaced `subagent_type` (`up-docs:up-docs-propagate-repo`, etc.) to the Agent tool. Previous bare-name strings (`up-docs-propagate-repo`) caused "Agent type not found" errors because Claude Code only addresses plugin-defined agents through their plugin namespace. Affected: `skills/all/SKILL.md`, `skills/repo/SKILL.md`, `skills/wiki/SKILL.md`, `skills/notion/SKILL.md`, `skills/drift/SKILL.md`.


## [0.4.0] - 2026-04-19

### Added
- Four sub-agents under `agents/`: `up-docs-propagate-repo`, `up-docs-propagate-wiki`, `up-docs-propagate-notion` (all Haiku), and `up-docs-audit-drift` (Sonnet). Each runs in its own context window with per-agent `model:` frontmatter overriding the caller's model tier.
- `templates/session-change-summary.md` — canonical format for the orchestrator's numbered change list; the single critical artifact consumed by every sub-agent.
- `templates/drift-finding.md` — dual-form (JSON + markdown) output contract for the drift auditor, including escalation triggers.

### Changed
- `/up-docs:all` orchestrates rather than executes: builds the session-change summary, dispatches three propagators in parallel via the Agent tool (formerly Task; renamed in Claude Code v2.1.63), then sequentially dispatches the drift auditor. Main-agent context stays slim — sub-agents read and edit pages in their own isolated contexts.
- `/up-docs:repo`, `/up-docs:wiki`, `/up-docs:notion`, `/up-docs:drift` are now thin wrappers that dispatch their single matching sub-agent. Layer guidelines and Notion content rules are inlined into sub-agent system prompts (no runtime `Read` on `references/notion-guidelines.md` from the propagator).
- Cost model: propagation runs on Haiku (≈ 1/10 the cost of Opus) while preserving Sonnet-quality drift detection. Parallel dispatch reduces wall time to `max(repo, wiki, notion)` instead of their sum.

### Fixed
- Opus escalation is now surfaced as an advisory block in the combined report rather than silently consuming Opus budget on routine drift passes. User decides whether to re-run with Opus.
- Agent prompts rewritten for Anthropic canonical patterns: XML tag structure (`<role>`, `<task>`, `<guardrails>`, `<examples>`, `<output_format>`), 5 worked few-shot examples per agent, canonical "Never speculate about X you have not read" grounding language, and commit-to-approach anti-flip-flop guidance. Particularly beneficial for the 3 Haiku propagators, which are more example-dependent than Sonnet.
- Drift auditor prompt now cross-checks propagator reports before emitting findings, preventing double-dispatch on a re-propagation pass.


## [0.3.0] - 2026-04-09

### Added
- `scripts/context-gather.sh` consolidating git context assessment for all 5 skills
- `scripts/server-inspect.sh` batching 5-15 SSH commands per host into a single session
- `scripts/link-audit.sh` for markdown link extraction and verification
- `scripts/convergence-tracker.sh` for managing iteration state across drift analysis phases

### Changed
- All 5 skill files (repo, wiki, notion, all, drift) now use context-gather.sh for session context
- `skills/drift/SKILL.md` Phase 1 uses server-inspect.sh and convergence-tracker.sh
- `skills/drift/SKILL.md` Phase 3 uses link-audit.sh for external link verification
- pass 3 — close remaining gaps, 293 total tests across 9 plugins
- close gap analysis findings, 247 total tests across 9 plugins
- add 166 bats tests across 9 plugins for new scripts

### Fixed
- add handoff to root README, fix up-docs skill names

## [0.2.0] - 2026-03-28

### Added

- `/up-docs:drift` command for comprehensive drift analysis: SSHes into live infrastructure, syncs Outline wiki across four convergence phases (infrastructure sync, wiki consistency, link integrity, Notion update)
- Server inspection reference with patterns for systemd, Docker, web servers, databases, DNS, VPN, monitoring, and backup services
- Convergence tracking reference with iteration mechanics, oscillation detection, and narrowing strategy

## [0.1.0] - 2026-03-28

### Added

- `/up-docs:repo` command to update repository documentation (README.md, docs/, CLAUDE.md)
- `/up-docs:wiki` command to update Outline wiki with implementation-level details
- `/up-docs:notion` command to update Notion with strategic and organizational context
- `/up-docs:all` command to update all three layers sequentially
- Summary report template for consistent output formatting across all commands
- Notion content guidelines reference document

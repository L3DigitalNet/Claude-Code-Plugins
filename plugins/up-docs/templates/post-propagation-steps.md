# Post-Propagation Steps

Shared orchestrator procedures that run after propagation completes. Single source of truth for both `/up-docs:repo` (single-layer) and `/up-docs:all` (combined run); `/up-docs:wiki` runs only the wiki-scoped variant of part (c). "Propagator output" below means the repo propagator's returned table — the repo propagator is **always dispatched** (even with zero routed items, for its mandatory live-state audit), so that table always exists in `/up-docs:repo` and `/up-docs:all` runs.

## Stale File Candidate Review (conditional)

If the repo propagator's output includes a `## Stale File Candidates` section, present the listed paths to the user via `AskUserQuestion` and execute deletions only on explicit approval:

1. Parse the candidate rows from the propagator output. Each row has a path, reason, and confidence.
2. Build an `AskUserQuestion` with `multiSelect: true`, one option per candidate (up to 4 — if more, batch in subsequent questions, or label the 4th "Delete these; rerun to review remaining").
3. Each option label is the filename basename (for readability); the description carries the reason + confidence verbatim from the agent.
4. For every path the user selects, run `git rm <path>` (never plain `rm` — staying inside git keeps history recoverable). Report what was deleted.
5. Paths the user does not select are left alone — no follow-up, no retry.
6. If the user cancels the question entirely, skip deletions and continue.

If the propagator emitted zero stale candidates (or omitted the section), skip this step silently. Deletion is the orchestrator's job, after consent — the propagator agent only surfaces candidates and never runs a destructive command, even for `high`-confidence rows.

## Handoff for Next Session

**(a) Update confirmation.** One or two lines summarizing the propagator table(s): files changed vs. audited-but-unchanged vs. deleted (if any). For `/up-docs:all`, one line per layer.

**(b) Handoff brief.** Detect the repo's handoff layout (probe-based, not flag-based) and source from the matching files:

- **V2 (handoff v3 layout; `docs/handoff/state.md` present):** `docs/handoff/state.md` exists. Read it + `docs/handoff/deployed.md` + `docs/handoff/bugs/INDEX.md`.
- **V1 (legacy):** `docs/handoff.md` exists (and no `docs/handoff/state.md`). Read it.
- **NONE:** neither file exists. Skip this subsection silently.

Emit using this structure (fields sourced per layout):

```markdown
## 📋 Handoff for Next Session

**Last work:** <V2: top row of docs/handoff/sessions/<current-month>.md | V1: top Last Updated line>

**Currently deployed:**

- <V2: docs/handoff/deployed.md rows, one per row, name + version + state>
- <V1: docs/handoff.md What Is Deployed bullets>

**Open items — what remains:**

- <V2: docs/handoff/deployed.md ## What Remains bullets | V1: docs/handoff.md What Remains bullets>

**Active incidents:** <V2: docs/handoff/state.md Session Instructions 🔴/🟡/🟢 block | V1: skip>

**Open bugs:** <V2: docs/handoff/bugs/INDEX.md rows with status != fixed | V1: docs/handoff.md Bugs table with unresolved items. "None" if all are fixed.>
```

Keep it scannable — no narrative prose, no full-file dump. The brief is a READ-only excerpt of the already-updated state files; do not re-edit them.

**(c) Commit offer (consent-gated, baseline-safe, no push).**

Prereq — **baseline**: the orchestrator must have captured, BEFORE propagation, a dirty-path snapshot per committable repo via `bash ${CLAUDE_PLUGIN_ROOT}/scripts/commit-candidates.sh snapshot <repo> > <baseline-file>` for the **local project repo**. The **wiki repo is REMOTE** (CT 103, `/srv/workspaces/llm-wiki`) — capture its baseline by piping the same helper to the CT: `ssh llm-wiki 'bash -s' snapshot /srv/workspaces/llm-wiki < ${CLAUDE_PLUGIN_ROOT}/scripts/commit-candidates.sh > <baseline-file>` (when the wiki layer was in scope). If no baseline was captured (the baseline variable is unset / the snapshot step never ran — note an EMPTY baseline file is a VALID baseline meaning the tree was clean at start, NOT a missing one), do NOT commit — report dirty trees and stop.

> **Local vs remote runner.** Below, every `commit-candidates.sh … <repo>` and `git -C <repo> …` for the **project repo** runs locally. For the **wiki repo** the identical commands run inside CT 103 over SSH — wrap the helper as `ssh llm-wiki 'bash -s' <subcommand> /srv/workspaces/llm-wiki [args] < ${CLAUDE_PLUGIN_ROOT}/scripts/commit-candidates.sh`, and raw git as `ssh llm-wiki 'git -C /srv/workspaces/llm-wiki …'`. The wiki commit is **commit-only, never push** — it stays on CT 103, which `vzdump`/restic back up; the operator pushes to GitHub separately.

1. For each committable repo, compute candidates: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/commit-candidates.sh candidates <repo> <baseline-file>`. These are paths **changed since baseline** — a candidate _surface_, NOT proof the run wrote them (a hook/editor/other process could have dirtied a clean-baseline path). Ownership is established by your per-path diff disclosure below, not by git.
2. If every repo's candidate set is empty, skip silently.
3. **Disclose + fingerprint**: show each candidate path's actual content so the user sees exactly what would be staged — `git -C <repo> --literal-pathspecs diff -- <path>` for tracked modifications, and `git -C <repo> --literal-pathspecs diff --no-index -- /dev/null <path>` for **untracked** candidates (plain `git diff` shows NOTHING for untracked files, so an untracked candidate's content would otherwise be approved unseen — CR-001). AND capture that path's content fingerprint now: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/commit-candidates.sh fingerprint <repo> <path>` — record it next to the diff you showed. Baseline-dirty paths are already excluded by the helper; surface them separately as "pre-existing local changes in `<repo>` — left for you to handle manually."
4. **Non-interactive guard**: if you cannot ask the user (headless `-p`, no `AskUserQuestion`), **commit nothing** — report the candidate paths and stop. No consent → no commit.
5. Otherwise present ONE `AskUserQuestion` (`multiSelect` over candidate paths/repos).
6. On approval, per selected repo: **late re-check (content, not just path — CR-001)** — immediately before staging, recompute each approved path's fingerprint (`commit-candidates.sh fingerprint <repo> <path>`) and compare to the value captured at disclosure, AND re-run `commit-candidates.sh candidates` to catch added/removed paths. If any approved path's fingerprint **differs** from what was shown, or a path is gone, or unexpected new paths appeared, **re-disclose and re-confirm** (a fresh `AskUserQuestion` over only the changed/new/missing paths; still-matching approved paths may proceed) rather than staging blindly — never stage content the user did not see. Then stage only the approved, fingerprint-matched paths by explicit literal pathspec (`git -C <repo> --literal-pathspecs add -- <path>` — so a name with pathspec magic stages only itself, CR-NEW-004; for the **remote wiki repo** wrap as `ssh llm-wiki 'git -C /srv/workspaces/llm-wiki --literal-pathspecs add -- <path>'`), commit under that repo's convention (project repo: signed `docs(handoff): …` via local `git -C`; the **remote wiki repo**: its draft-contract message via `ssh llm-wiki 'git -C /srv/workspaces/llm-wiki commit …'`, page stays `status: draft`), and **never push**. Report the commit SHA(s) and that nothing was pushed.

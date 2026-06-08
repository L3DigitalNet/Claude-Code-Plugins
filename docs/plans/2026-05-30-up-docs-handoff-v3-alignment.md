# up-docs ↔ Handoff System v3 Alignment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring the `up-docs` plugin's repo-layer propagator and drift auditor into conformance with Agent Handoff System **v3.0**, so up-docs neither emits v3-non-conformant artifacts nor leaves v3 layout violations undetected.

**Architecture:** up-docs reimplements a _subset_ of the handoff contract inline (state.md byte cap, bug-index regen) instead of calling the canonical validator. v3.0 kept v2.0's layout but changed the implementation (hash-pinned hook, byte-exact truncation, exact `AGENTS.md` block, a `validate-layout.sh` that checks them). This plan (a) fixes the two propagator outputs that would now fail `validate-layout.sh`, (b) closes enforcement gaps, and (c) replaces inline rule-duplication with a call to the canonical validator where one exists. No new layer is added — edits are confined to `propagate-repo`, `audit-drift`, one shared template, and release metadata.

**Tech Stack:** Markdown agent prompts (`agents/*.md`), shared templates, bash helper scripts, bats + pytest test suites, Keep-a-Changelog + SemVer release metadata.

**Canonical references (read before starting):**

- Spec: `~/projects/agent-configs/docs/handoff/agent-handoff-system.md` (v3.0, 2026-05-29)
- Validator: `~/projects/agent-configs/scripts/validate-layout.sh`
- Provenance of these findings: this repo `docs/handoff/bugs/006-up-docs-propagate-repo-emits-handoff-v3-nonconformant-artifacts.md`

**Target release:** up-docs **v0.9.0** (current: v0.8.4).

**Decision context (2026-05-30):** Audit identified 12 divergences (2 🔴, 6 🟡, 4 🟢). User elected to capture them as this plan + a bug row for a later dedicated pass — _no code changes were made at audit time_. This document is that capture.

---

## Divergence → Task Map

| # | Sev | Divergence | Task |
| --- | --- | --- | --- |
| 1 | 🔴 | `AGENTS.md` remediation writes only a `Session state:` line; omits the two other v3-mandated lines (validator fails) | T1 |
| 2 | 🔴 | New bug files omit `## Lesson` (v3 mandates Cause/Fix/Lesson) | T2 |
| 3 | 🟡 | No `CLAUDE.md`/`AGENTS.md` byte-cap enforcement (only `state.md`) | T3 |
| 4 | 🟡 | `docs/handoff/specs-plans.md` not in the mandatory audit | T4 |
| 5 | 🟡 | state.md over-cap handling is delete-first, not route-first | T5 |
| 6 | 🟡 | Bug-index regen lacks the `git diff --exit-code` verify step | T6 |
| 7 | 🟡 | No awareness of the hash-pinned hook / no call to `validate-layout.sh` (drift auditor has no conformance phase) | T7 |
| 8 | 🟢 | "v2" labels throughout; stale `/mnt/share/` migration pointer; superseded "Phase 5 / §9.2 / 200-line cap" refs; V1 framed as maintainable | T8 |
| 9 | — | Version bump + CHANGELOG | T9 |
| 10 | — | Run suites, flip bug 006 → fixed, update `specs-plans.md` status, session row | T10 |

> **8 rows, 12 divergences:** rows 1–6 are one audit divergence each; **row 7 (T7)** bundles the two hook-related 🟡 items (no hash-pinned-hook awareness + no `validate-layout.sh` conformance phase); **row 8 (T8)** bundles the four 🟢 items (v2 labels, stale `/mnt/share/` pointer, superseded Phase-5/§9.2/200-line refs, V1-as-maintainable). 6 + 2 + 4 = 12.

---

## File Structure

- **Modify** `plugins/up-docs/agents/up-docs-propagate-repo.md` — T1–T6, T8. The repo-layer writer; all output-conformance fixes land here.
- **Modify** `plugins/up-docs/agents/up-docs-audit-drift.md` — T7. Add a conditional handoff-conformance phase that shells out to `validate-layout.sh`.
- **Modify** `plugins/up-docs/templates/post-propagation-steps.md` — T8. Relabel V2→v3 in the handoff-brief layout detection.
- **Modify** `plugins/up-docs/.claude-plugin/plugin.json` + `plugins/up-docs/CHANGELOG.md` — T9.
- **Modify** `plugins/up-docs/tests/*` only if a grep-assertion test is added (T1/T2 verification); otherwise verification is grep + suite run.
- **Modify** (this session, already created) `docs/handoff/bugs/006-*.md`, `docs/handoff/specs-plans.md`, `docs/handoff/bugs/INDEX.md` — T10 status flip.

**Note on test design:** these divergences are agent-_prompt_ instructions, not code paths, so most are verified by `grep` assertions against the prompt markdown plus the existing `tests/validate_output.py` schema checks — not by new unit tests of runtime behavior. Where a divergence touches a schema (T2 bug body), add a fixture assertion. Where it only changes prose guidance (T5, T8), the "test" is a grep that the new wording is present and the old wording is gone.

---

### Task 1: 🔴 Fix `AGENTS.md` remediation to emit the v3 three-line block

**Files:**

- Modify: `plugins/up-docs/agents/up-docs-propagate-repo.md:117` and `:119` (the `AGENTS.md` / `AGENTS.reviews.md` mandatory-audit bullets)

**Why:** v3 §"Repo File Rules" mandates `AGENTS.md` carry three exact lines near the top, and `validate-layout.sh`'s Codex block checks for all three substrings (`Session state:`, `Full conventions reference:`, `Detailed review workflows:`). The current remediation writes only a `Session state: detect layout first…` line, so a propagator-touched `AGENTS.md` fails validation and drops two required lines.

- [ ] **Step 1: Write the failing assertion**

Add to `plugins/up-docs/tests/manifest.bats` (or a new `tests/prompt-conformance.bats`):

```bash
@test "propagate-repo AGENTS.md remediation cites all three v3-required lines" {
  run grep -F 'Full conventions reference:' "$REPO/agents/up-docs-propagate-repo.md"
  [ "$status" -eq 0 ]
  run grep -F 'Detailed review workflows:' "$REPO/agents/up-docs-propagate-repo.md"
  [ "$status" -eq 0 ]
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash plugins/up-docs/tests/run-bats.sh plugins/up-docs/tests/manifest.bats` Expected: FAIL — neither substring is currently present in the agent prompt.

- [ ] **Step 3: Replace the remediation text**

Replace the `:117` bullet (`- **AGENTS.md** (if exists) …`) with:

````markdown
- **`AGENTS.md`** (if exists) — Codex CLI equivalent of CLAUDE.md. Per handoff v3 §"Repo File Rules", AGENTS.md MUST carry these three lines near the top. Audit that all three are present and current; add/repair any that are missing:

  ```markdown
  **Session state:** read `docs/handoff/state.md`, then this file, then `docs/handoff/conventions.md`.

  **Full conventions reference:** [`docs/handoff/conventions.md`](docs/handoff/conventions.md) - LLM-targeted pattern library. Check it before adding persistent patterns.

  **Detailed review workflows:** [AGENTS.reviews.md](AGENTS.reviews.md) - read this only for review-related tasks when present.
  ```

  If `AGENTS.reviews.md` does not exist, the third line MUST instead read exactly: `**Detailed review workflows:** not configured for this repo.` Common drift: the `Session state:` line still points at the retired `docs/handoff.md`, or the other two lines are absent entirely (validator fails the Codex block). On a legacy V1 repo (docs/handoff.md present, no docs/handoff/state.md), the `Session state:` line points at `docs/handoff.md` instead — but flag the repo for migration per step 3's V1 note.
````

Then replace the `:119` `AGENTS.reviews.md` bullet with this exact text (the V1/V2 detection fallback is removed):

```markdown
- **`AGENTS.reviews.md`** (if exists) — Codex review-specific instructions. Audit for any `docs/handoff.md` reference; on a v3 repo (`docs/handoff/state.md` present) it MUST cite `docs/handoff/state.md` instead. The "or add V1/V2 detection guidance" fallback is removed — v3 treats V1 as a migration target, not a maintained alternative.
```

- [ ] **Step 4: Run the assertion to verify it passes**

Run: `bash plugins/up-docs/tests/run-bats.sh plugins/up-docs/tests/manifest.bats` Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add plugins/up-docs/agents/up-docs-propagate-repo.md plugins/up-docs/tests/manifest.bats
git commit -m "fix(up-docs): propagate-repo emits v3 three-line AGENTS.md block"
```

---

### Task 2: 🔴 Add `## Lesson` to the bug-file body template

**Files:**

- Modify: `plugins/up-docs/agents/up-docs-propagate-repo.md:93-99` (the `docs/handoff/bugs/<NNN>-<slug>.md` creation template)

**Why:** v3 §"Repo File Rules" requires bug bodies to be **Cause / Fix / Lesson**. This repo's live KB (`001`–`004`, `006`) and commit `f627ad7` ("reformat Summary-style bodies to Cause/Fix/Lesson") set that standard (bug `005` was created before the standard was enforced and also lacks `## Lesson`), but the propagator template emits only `## Cause` + `## Fix`, so every new bug it creates regresses the standard.

- [ ] **Step 1: Write the failing assertion**

```bash
@test "propagate-repo bug template includes Cause, Fix, and Lesson" {
  for h in '## Cause' '## Fix' '## Lesson'; do
    run grep -F "$h" "$REPO/agents/up-docs-propagate-repo.md"
    [ "$status" -eq 0 ]
  done
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash plugins/up-docs/tests/run-bats.sh plugins/up-docs/tests/manifest.bats` Expected: FAIL on `## Lesson`.

- [ ] **Step 3: Edit the template body**

In the fenced bug template, after the `## Fix` paragraph, append:

```markdown
       ## Lesson
       <one paragraph — the durable, reusable takeaway; what to do or check next time>
```

Also update step-3 prose: "create a new file with frontmatter … and a **Cause / Fix / Lesson** body".

- [ ] **Step 4: Run the assertion to verify it passes**

Run: `bash plugins/up-docs/tests/run-bats.sh plugins/up-docs/tests/manifest.bats` Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add plugins/up-docs/agents/up-docs-propagate-repo.md plugins/up-docs/tests/manifest.bats
git commit -m "fix(up-docs): bug-body template includes ## Lesson (handoff v3 Cause/Fix/Lesson)"
```

---

### Task 3: 🟡 Enforce `CLAUDE.md` (≤2048) and `AGENTS.md` (≤4096) byte caps

**Files:**

- Modify: `plugins/up-docs/agents/up-docs-propagate-repo.md:115` (the `CLAUDE.md` audit bullet) and `:117` (the `AGENTS.md` bullet)

**Why:** v3 §"Context Budgets" caps repo `CLAUDE.md` at ≤2048 bytes (target ≤1024) and `AGENTS.md` at ≤4096; `validate-layout.sh` checks `CLAUDE.md`. The propagator enforces the cap on `state.md` only, so a pointer addition that pushes `CLAUDE.md` over 2 KiB goes uncaught until the validator fails.

- [ ] **Step 1: Edit the `CLAUDE.md` audit bullet**

Append to the `:115` bullet:

```markdown
     After any edit to CLAUDE.md, enforce the handoff v3 byte cap: `wc -c CLAUDE.md` must be ≤2048 (target ≤1024). If over, the fix is NOT to delete pointers but to confirm the file is a pure index — move any non-index prose to the doc it points at — then re-check `wc -c`. Record the byte count in the output row when you edit CLAUDE.md.
```

- [ ] **Step 2: Edit the `AGENTS.md` bullet (from Task 1)**

Add: "After editing, `wc -c AGENTS.md` must be ≤4096 (handoff v3 budget)."

- [ ] **Step 3: Verify the guidance is present**

Run: `grep -nF 'wc -c CLAUDE.md' plugins/up-docs/agents/up-docs-propagate-repo.md` Expected: one match.

- [ ] **Step 4: Commit**

```bash
git add plugins/up-docs/agents/up-docs-propagate-repo.md
git commit -m "feat(up-docs): propagate-repo enforces CLAUDE.md/AGENTS.md byte caps (handoff v3)"
```

---

### Task 4: 🟡 Add `docs/handoff/specs-plans.md` to the mandatory audit

**Files:**

- Modify: `plugins/up-docs/agents/up-docs-propagate-repo.md` — add a bullet to the step-3 mandatory-audit list (alongside `docs/handoff/conventions.md`)

**Why:** v3 §"Session End" item 8 requires updating `docs/handoff/specs-plans.md` when a spec/plan changes. The propagator's stale-scan globs the spec/plan dirs for _deletion candidates_ only; it never maintains the pointer table, so a session that adds a spec/plan leaves `specs-plans.md` stale.

- [ ] **Step 1: Add the audit bullet**

```markdown
- **`docs/handoff/specs-plans.md`** — specs/plans pointer table (audit when the session added, moved, froze, or superseded a spec or plan). Add a row for any new artifact (Date | relative path | Status | ≤12-word summary); update the Status of an artifact the session advanced or froze. The actual spec/plan location is whatever this table records — default `docs/superpowers/{specs,plans}/`, but a repo may use `docs/{specs,plans}/` (this is recorded here, not assumed). If the session touched no spec/plan, record "No change needed".
```

- [ ] **Step 2: Add an output-table example row** in the `<examples>` block — the example tables are 4-column (`| # | File | Action | Summary of Changes |`). Extend the CLI-flag example (its rows end at 8) with: `| 9 | docs/handoff/specs-plans.md | No change needed | No spec/plan touched this session |`.

- [ ] **Step 3: Verify**

Run: `grep -nF 'docs/handoff/specs-plans.md' plugins/up-docs/agents/up-docs-propagate-repo.md` Expected: ≥2 matches (audit bullet + example).

- [ ] **Step 4: Commit**

```bash
git add plugins/up-docs/agents/up-docs-propagate-repo.md
git commit -m "feat(up-docs): propagate-repo audits docs/handoff/specs-plans.md (handoff v3 session-end item 8)"
```

---

### Task 5: 🟡 Reframe state.md over-cap handling as route-first

**Files:**

- Modify: `plugins/up-docs/agents/up-docs-propagate-repo.md:60` (the `docs/handoff/state.md` Hard-cap bullet)

**Why:** v3 §`docs/handoff/state.md` is explicit: an over-cap file is _"a symptom of longer-lifetime content leaking into live state,"_ and the fix is to **route** content to its home (session narrative→`sessions/`, deployment readouts→`deployed.md`, standing backlog→`architecture.md`), _"not to delete it."_ The current instruction deletes oldest "Recently closed" blocks (assuming they're already in `sessions/`) and routes nothing else — risking deletion of un-routed content.

- [ ] **Step 1: Replace the trim procedure**

Replace the "To trim: …" sentence with:

```markdown
This cap is state-conditioned, not transition-conditioned: enforce it whenever the file is over 2048 bytes _after_ your edit, even if a prior session left it bloated. Per handoff v3, the fix is to **route long-lived content to its home, then delete the now-duplicated lines** — never bare-delete: 1. Confirm each prior "Recently closed" block already has a one-line row in `docs/handoff/sessions/<YYYY-MM>.md`. If a block is NOT yet captured there, append its row first, THEN delete the block. (Append happens in the sessions sub-step above.) 2. Route any deployment readouts to `docs/handoff/deployed.md` and any standing-backlog prose to `docs/handoff/architecture.md` before deleting them from state.md. 3. Condense the Session Instructions preamble last, only if still over. Never drop a 🔴 active incident to fit budget. Re-check `wc -c` after trimming.
```

- [ ] **Step 2: Verify**

Run: `grep -nF 'route long-lived content to its home' plugins/up-docs/agents/up-docs-propagate-repo.md` Expected: one match.

- [ ] **Step 3: Commit**

```bash
git add plugins/up-docs/agents/up-docs-propagate-repo.md
git commit -m "fix(up-docs): state.md over-cap trim is route-first per handoff v3"
```

---

### Task 6: 🟡 Add the bug-index verify step

**Files:**

- Modify: `plugins/up-docs/agents/up-docs-propagate-repo.md:102` (the `_regen_index.py` instruction) and the `<guardrails>` allowed-command note at `:207`

**Why:** v3 pairs the regen with `&& git diff --exit-code docs/handoff/bugs/INDEX.md` to confirm the regenerator output is committed/idempotent.

- [ ] **Step 1: Edit the regen instruction**

Change "After creating, regenerate the index: `python3 docs/handoff/bugs/_regen_index.py`." to:

```markdown
     - After creating, regenerate and verify the index: `python3 docs/handoff/bugs/_regen_index.py && git diff --exit-code docs/handoff/bugs/INDEX.md` (a non-empty diff means the index was stale and is now fixed — stage it; a clean exit means already current).
```

- [ ] **Step 2: Extend the guardrails allowed-command exception** at `:207` to name `git diff --exit-code docs/handoff/bugs/INDEX.md` as read-only-verification (it does not modify content).

- [ ] **Step 3: Verify**

Run: `grep -nF 'git diff --exit-code docs/handoff/bugs/INDEX.md' plugins/up-docs/agents/up-docs-propagate-repo.md` Expected: ≥1 match.

- [ ] **Step 4: Commit**

```bash
git add plugins/up-docs/agents/up-docs-propagate-repo.md
git commit -m "feat(up-docs): bug-index regen verifies with git diff --exit-code (handoff v3)"
```

---

### Task 7: 🟡 Add a conditional handoff-conformance phase to the drift auditor

**Files:**

- Modify: `plugins/up-docs/agents/up-docs-audit-drift.md` — add a new `<task>` step and a `layer: "layout"` finding shape; correct the `.claude/` owner label in `propagate-repo.md:157`

**Why:** v3's headline change is that the SessionStart hook is a tracked, hash-pinned artifact (`agent-configs/global/claude/hooks/session_start.py`, installed by `install-globals.sh`, hash-checked by `validate-layout.sh`); per-repo hand-editing is forbidden. up-docs has zero awareness of this. The drift auditor's entire job is doc-vs-reality drift, yet it has no phase that checks layout conformance — exactly the drift v3 added the validator to catch (hook hash, settings `${CLAUDE_PROJECT_DIR}` anchor, byte caps, AGENTS.md lines). Because up-docs is portable, the phase MUST be conditional on the validator existing.

- [ ] **Step 1: Add the conformance task step**

Insert after the auditor's step 3 (live-state cross-reference):

````markdown
3b. **Handoff-layout conformance (conditional, read-only).** If `~/projects/agent-configs/scripts/validate-layout.sh` exists, run it against the active project root:

    ```bash
    AGC="${HOME}/projects/agent-configs/scripts/validate-layout.sh"
    [ -x "$AGC" ] && bash "$AGC" "${CLAUDE_PROJECT_DIR:-$PWD}" || echo "validator absent — skipping conformance phase"
    ```

    For each failed check the validator reports, emit a finding with `"layer": "layout"`, `confidence: "high"`, `evidence` = the validator's command + the failing line it printed. Do NOT fix — surface only (the propagators fix on a follow-up pass). If the validator is absent (portable install, no agent-configs clone), skip this phase and note "handoff conformance not checked — canonical validator not installed" in the context line. Never fabricate a conformance result when the validator is absent.
````

- [ ] **Step 2: Correct the `.claude/` owner label in propagate-repo**

In `propagate-repo.md:157`, change "Anything under `.claude/` (hooks, rules, settings — lifecycle-managed by the plugin system)." to "Anything under `.claude/` — the SessionStart hook is a hash-pinned copy owned by `agent-configs/install-globals.sh` (never hand-edit or delete it); rules/settings are lifecycle-managed. Never flag any `.claude/` file stale."

- [ ] **Step 3: Add a `"layout"` value to the auditor's `by_layer` stats and confidence/layer enums** in `<output_format>`, and update `tests/validate_output.py` to accept `layer: "layout"`:
  - In the `Finding.layer` enum (line 152), add `"layout"`.
  - In `StatsByLayer` (line 180, which uses Pydantic `extra="forbid"`), add `layout: int = 0`. Without this, emitting `"layout": 0` in the `by_layer` stats block raises `ValidationError` at `AuditorReport` parse time — _before_ the `Finding.layer` enum is ever checked.

- [ ] **Step 4: Run the schema self-tests**

Run: `cd plugins/up-docs/tests && python3 -m pytest test_validate_output.py -q` Expected: PASS (after the enum addition).

- [ ] **Step 5: Commit**

```bash
git add plugins/up-docs/agents/up-docs-audit-drift.md plugins/up-docs/agents/up-docs-propagate-repo.md plugins/up-docs/tests/validate_output.py plugins/up-docs/tests/test_validate_output.py
git commit -m "feat(up-docs): drift auditor runs validate-layout.sh when present; layout findings"
```

---

### Task 8: 🟢 Relabel v2→v3, fix stale pointers, drop superseded plan refs

**Files:**

- Modify: `plugins/up-docs/agents/up-docs-propagate-repo.md` (`:47`, `:107`, `:113`, `:123`, `:133`, `:294`, and the `<example>` `<scenario>` labels carrying "V2 layout" at `:218`, `:253`, `:284`, `:345`)
- Modify: `plugins/up-docs/templates/post-propagation-steps.md:34`

**Why:** All handoff references say `handoff-system-v2 (post-2026-04-24)`. v3 (2026-05-29) is canonical; the layout is unchanged so probe detection still works, but the labels are a release behind. Three concrete stale items: (a) the V1 note points to _"plan in /mnt/share/ or equivalent"_ — wrong; (b) `:113` and `:294` cite a superseded migration plan's "Phase 5" / "§9.2 / ≤200-line `.claude/rules/` cap" that v3 does not define (the 200-line cap is an up-docs invention, not canonical); (c) V1/`docs/handoff.md` is framed as a maintainable layout, but v3 **retires** it ("a migration target, not a pattern to preserve").

- [ ] **Step 1: Relabel** "handoff-system-v2" → "handoff system v3" everywhere it tags the _current_ layout; keep "V2 layout" as the internal probe-state name (state.md present) OR rename the probe states to `CURRENT`/`LEGACY`/`NONE` for clarity (pick one; if renaming, update `post-propagation-steps.md` and all examples in lockstep).

- [ ] **Step 2: Fix the V1 migration pointer** (`:133`) to: `*"Repo uses legacy handoff.md layout (retired in handoff v3) — migrate per ~/projects/agent-configs/docs/handoff/agent-handoff-system.md §Migration Trigger."*`

- [ ] **Step 3: Remove the invented cap.** Replace the `:113` "Keep each file ≤200 lines per the plan §9.2 adherence note" with "Keep each rules file focused; split by topic when it sprawls (no canonical hard cap in handoff v3)." Replace "`V2 layout with Phase 5 done`" at `:294` with "current layout with `.claude/rules/` present".

- [ ] **Step 4: Soften V1 framing** — in the V1 fallback intro (`:123`), state that v3 treats `docs/handoff.md` as retired and the propagator maintains it only for back-compat while flagging migration.

- [ ] **Step 5: Verify no stale tokens remain**

Run: `grep -rnE '/mnt/share|Phase 5|§9\.2|≤200 lines|200-line' plugins/up-docs/agents plugins/up-docs/templates` Expected: no matches.

- [ ] **Step 6: Commit**

```bash
git add plugins/up-docs/agents/up-docs-propagate-repo.md plugins/up-docs/templates/post-propagation-steps.md
git commit -m "docs(up-docs): relabel handoff v2→v3, drop stale /mnt/share + Phase-5/200-line refs"
```

---

### Task 9: Version bump + CHANGELOG

**Files:**

- Modify: `plugins/up-docs/.claude-plugin/plugin.json:3` (`0.8.4` → `0.9.0`)
- Modify: `plugins/up-docs/CHANGELOG.md` (new top entry)

- [ ] **Step 1: Bump the manifest version** to `0.9.0`.

- [ ] **Step 2: Add the CHANGELOG entry**

```markdown
## [0.9.0] - 2026-05-30

### Fixed

- propagate-repo: `AGENTS.md` remediation now emits the handoff v3 three-line block (`Session state:` / `Full conventions reference:` / `Detailed review workflows:`) — prior output failed `validate-layout.sh`'s Codex block. (Bug #6)
- propagate-repo: new bug files include `## Lesson` (handoff v3 Cause/Fix/Lesson body). (Bug #6)
- propagate-repo: state.md over-cap trim is route-first (route to sessions/deployed/architecture before deleting), per handoff v3.

### Added

- propagate-repo: enforces `CLAUDE.md` (≤2048) and `AGENTS.md` (≤4096) byte caps; audits `docs/handoff/specs-plans.md`; verifies bug-index regen with `git diff --exit-code`.
- audit-drift: conditional handoff-layout conformance phase — runs `~/projects/agent-configs/scripts/validate-layout.sh` against the project root when present and surfaces failures as `layer: "layout"` findings (read-only; never fixes).

### Changed

- Relabeled handoff "v2" → "v3"; removed stale `/mnt/share/` migration pointer and superseded "Phase 5 / §9.2 / ≤200-line rules cap" references (not part of the v3 contract).
```

- [ ] **Step 3: Commit**

```bash
git add plugins/up-docs/.claude-plugin/plugin.json plugins/up-docs/CHANGELOG.md
git commit -m "chore(up-docs): release v0.9.0 — handoff v3 alignment"
```

---

### Task 10: Run suites, flip bug 006 → fixed, update indexes, session row

**Files:**

- Modify: `docs/handoff/bugs/006-up-docs-propagate-repo-emits-handoff-v3-nonconformant-artifacts.md` (`status: open` → `fixed`; add commit SHA in Fix)
- Modify: `docs/handoff/bugs/INDEX.md` (regen), `docs/handoff/specs-plans.md` (this plan's row Status → Done), `docs/handoff/sessions/2026-05.md` (session row)

- [ ] **Step 1: Run the full up-docs suite**

Run: `bash plugins/up-docs/tests/run-bats.sh` then `cd plugins/up-docs/tests && python3 -m pytest -q` Expected: all green (48 bats + 26 pytest baseline, plus the new assertions from T1/T2/T7).

- [ ] **Step 2: Validate this repo's layout** (dogfood the validator the auditor now calls)

Run: `~/projects/agent-configs/scripts/validate-layout.sh ~/projects/Claude-Code-Plugins` Expected: PASS (or only pre-existing unrelated findings).

- [ ] **Step 3: Flip bug 006 to fixed**, set the Fix commit SHA(s), regen the index:

Run: `python3 docs/handoff/bugs/_regen_index.py && git diff --exit-code docs/handoff/bugs/INDEX.md`

- [ ] **Step 4: Update `docs/handoff/specs-plans.md`** — this plan's row Status `Planned` → `Done`.

- [ ] **Step 5: Append the session row** to `docs/handoff/sessions/2026-05.md`.

- [ ] **Step 6: Commit**

```bash
git add docs/handoff/bugs/006-*.md docs/handoff/bugs/INDEX.md docs/handoff/specs-plans.md docs/handoff/sessions/2026-05.md
git commit -m "docs: close up-docs handoff-v3 alignment (Bug #6 fixed, plan Done)"
```

---

## Self-Review

**Spec coverage:** All 12 audit divergences map to a task (table above): 🔴 #1→T1, #2→T2; 🟡 #3→T3, #4→T4, #5→T5, #6→T6, #7→T7; 🟢 #8 (four sub-items)→T8. Release hygiene → T9–T10. No divergence is unassigned.

**Out of scope (intentional):** The wiki/Notion propagators are untouched — the handoff contract governs only repo `docs/`. The hook source itself is not edited by up-docs (it is agent-configs-owned); T7 only _reads_ it via the validator.

**Placeholder scan:** Exact file:line targets and full replacement text are given for every edit. The only deliberately open choice is T8 Step 1 (keep "V2/V1" probe-state names vs. rename to CURRENT/LEGACY) — both branches name the lockstep files to update.

**Type/term consistency:** "v3", `layer: "layout"`, and the three AGENTS.md substrings are used identically across T1, T7, T9. The validator path `~/projects/agent-configs/scripts/validate-layout.sh` is identical in T7 and T10.

**Open risk:** prompt-instruction conformance can be grep-verified but not behavior-tested without an eval harness; T1/T2/T7 add grep/schema assertions, but a real `/up-docs:repo` smoke run on a scratch repo (like the v0.8.0 Phase-2 smoke test) is the only end-to-end check. Add it as a release pre-flight note, not a blocking unit test.

# up-docs Orchestration Improvements — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `/up-docs:all` cheaper and self-contained without losing thoroughness — narrow the drift auditor's re-passes, skip propagators for empty layers, and offer a consent-gated, baseline-safe commit at the end.

**Architecture:** Three independent changes to the `plugins/up-docs/` instruction-file plugin. (A) a new per-iteration `touched_pages` path contract in `scripts/convergence-tracker.sh` drives auditor-prompt narrowing; (B) a routing matrix in `skills/all/SKILL.md` gates propagator dispatch; (C) a new `scripts/commit-candidates.sh` git-ground-truth helper + a consent-gated part (c) in `templates/post-propagation-steps.md`. Real code (tracker, commit-candidates) is TDD with bats; instruction changes are guarded test-first with `prompt-conformance.bats` grep assertions.

**Tech Stack:** Bash + Python 3 (scripts), bats-core (shell tests), pytest (output-schema tests), Markdown (agent/skill/template prompts). Spec: `docs/plans/2026-06-07-up-docs-orchestration-improvements-design.md` (Codex-converged, 4 rounds).

---

## Conventions for every task

- Run the bats suite **only** through the hardened wrapper, which forces GNU coreutils (this workstation shims `find`→fd / `grep`→ugrep, which otherwise false-greens bats):
  `PATH="/usr/bin:/bin:$PATH" bash plugins/up-docs/tests/run-bats.sh <file.bats>`
- Commit with a plain signed commit (global hook enforces author email + GPG). Never `git add -A`; stage by explicit name.
- All paths below are relative to the repo root `/home/chris/projects/Claude-Code-Plugins`.

## File structure (created / modified)

| File | Responsibility | Task |
|---|---|---|
| `plugins/up-docs/scripts/convergence-tracker.sh` | + per-iteration `touched_pages` path list; `pages_touched` = `len`; `touched-pages` subcommand | 1 |
| `plugins/up-docs/tests/convergence-tracker.bats` | path round-trip + new-semantics tests (replaces the old "max" test) | 1 |
| `plugins/up-docs/agents/up-docs-audit-drift.md` | pass-1-full / pass-N-narrow task step keyed to `touched_pages` + one-hop `related` | 2 |
| `plugins/up-docs/skills/drift/references/convergence-tracking.md` | defer narrowing rule to the auditor task step | 2 |
| `plugins/up-docs/skills/all/SKILL.md` | routing matrix (Step 2) + conditional dispatch (Step 3) + skipped-layer line; baseline-capture ref (Step 6) | 3, 5 |
| `plugins/up-docs/templates/summary-report.md` | document the presentation-only skipped-layer line | 3 |
| `plugins/up-docs/scripts/commit-candidates.sh` | git-ground-truth: `snapshot` + `candidates` (changed-since-baseline) + `fingerprint` (content guard, CR-001); `--no-optional-locks` (CR-004) | 4 |
| `plugins/up-docs/tests/commit-candidates.bats` | commit-safety scenarios incl. fingerprint mutation (CR-001) | 4 |
| `plugins/up-docs/tests/fixtures/routing-cases.md` | worked routing cases incl. system-of-record edges (CR-002/003) | 3 |
| `plugins/up-docs/templates/post-propagation-steps.md` | part (c): baseline + per-path diff approval + late re-check + no-push + headless report-only | 5 |
| `plugins/up-docs/skills/repo/SKILL.md` | baseline-capture ref (shares the template) | 5 |
| `plugins/up-docs/tests/prompt-conformance.bats` | grep guards for the prompt/template changes (Tasks 2,3,5) | 2,3,5 |
| `plugins/up-docs/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `plugins/up-docs/CHANGELOG.md` | version 0.11.0 | 6 |
| `docs/handoff/specs-plans.md` | row status → plan executed | 7 |

---

### Task 0: Baseline — confirm green starting point

**Files:** none (read-only).

- [ ] **Step 1: Confirm no TRACKED changes + current version**

Run: `git status --porcelain && grep '"version"' plugins/up-docs/.claude-plugin/plugin.json`
Expected: `"version": "0.10.1"`. The tree may contain **pre-existing user-owned untracked files** (e.g. `?? TODO.md`) — these are OUT OF SCOPE: never stage, move, or delete them. Require only that there are no *tracked* modifications (` M`/`A `/`D ` lines). Every task below stages only explicitly-named files, so untracked user files are never swept (CR-001/CR-004 missing-consideration).

- [ ] **Step 2: Confirm the existing suites are green before changing anything**

Run: `PATH="/usr/bin:/bin:$PATH" bash plugins/up-docs/tests/run-bats.sh && (cd plugins/up-docs/tests && .venv/bin/python -m pytest -q)`
Expected: all bats `ok`; pytest all pass. If anything fails here, STOP — the baseline is not green.

---

### Task 1: `touched_pages` path contract in the tracker (A1 data source, D6)

**Files:**
- Modify: `plugins/up-docs/scripts/convergence-tracker.sh` (init block ~line 60-65; `cmd_record_iteration` ~line 71-105; add `cmd_touched_pages`)
- Test: `plugins/up-docs/tests/convergence-tracker.bats`

- [ ] **Step 1: Write the failing tests**

Replace the existing `@test "record-iteration tracks pages_touched as max"` block (it encodes the old numeric-max semantics being removed) with these tests:

```bash
@test "record-iteration stores touched_pages as a path list (round-trip)" {
  bash "$SCRIPTS_DIR/convergence-tracker.sh" start-phase 1
  echo '{"fixes_applied":1,"touched_pages":["wiki/a.md","wiki/b.md"]}' \
    | bash "$SCRIPTS_DIR/convergence-tracker.sh" record-iteration 1
  run bash "$SCRIPTS_DIR/convergence-tracker.sh" status
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -c '.phases["1"].touched_pages')" = '["wiki/a.md","wiki/b.md"]' ]
  [ "$(echo "$output" | jq '.phases["1"].pages_touched')" = "2" ]
  [ "$(echo "$output" | jq '.phases["1"].changes_applied')" = "1" ]  # CR-005: not double-counted
}

@test "pages_touched is len of the latest touched_pages (not a running max)" {
  bash "$SCRIPTS_DIR/convergence-tracker.sh" start-phase 1
  echo '{"touched_pages":["wiki/a.md","wiki/b.md","wiki/c.md"]}' \
    | bash "$SCRIPTS_DIR/convergence-tracker.sh" record-iteration 1
  echo '{"touched_pages":["wiki/a.md"]}' \
    | bash "$SCRIPTS_DIR/convergence-tracker.sh" record-iteration 1
  run bash "$SCRIPTS_DIR/convergence-tracker.sh" status
  [ "$(echo "$output" | jq '.phases["1"].pages_touched')" = "1" ]
}

@test "record-iteration de-duplicates touched_pages preserving order" {
  bash "$SCRIPTS_DIR/convergence-tracker.sh" start-phase 1
  echo '{"touched_pages":["wiki/a.md","wiki/a.md","wiki/b.md"]}' \
    | bash "$SCRIPTS_DIR/convergence-tracker.sh" record-iteration 1
  run bash "$SCRIPTS_DIR/convergence-tracker.sh" status
  [ "$(echo "$output" | jq -c '.phases["1"].touched_pages')" = '["wiki/a.md","wiki/b.md"]' ]
}

@test "touched-pages subcommand emits the latest set for a phase" {
  bash "$SCRIPTS_DIR/convergence-tracker.sh" start-phase 2
  echo '{"touched_pages":["wiki/x.md"]}' \
    | bash "$SCRIPTS_DIR/convergence-tracker.sh" record-iteration 2
  run bash "$SCRIPTS_DIR/convergence-tracker.sh" touched-pages 2
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -c '.')" = '["wiki/x.md"]' ]
}
```

- [ ] **Step 2: Run them to verify they fail**

Run: `PATH="/usr/bin:/bin:$PATH" bash plugins/up-docs/tests/run-bats.sh plugins/up-docs/tests/convergence-tracker.bats`
Expected: the four new tests FAIL (`touched_pages` absent; `touched-pages` unknown subcommand).

- [ ] **Step 3: Add `touched_pages` to the phase template**

In `cmd_start_phase` (the python `state['phases'][phase] = {...}` initializer, ~line 60-65), add `'touched_pages': []` next to `'pages_touched': 0,`:

```python
    'iteration': 0,
    'max_iterations': 10,
    'history': [],
    'pages_touched': 0,
    'touched_pages': [],
    'changes_applied': 0,
```

- [ ] **Step 4: Rewrite the `pages_touched` handling in `cmd_record_iteration`**

Replace the **entire existing block** from `fixes = findings.get('fixes_applied', 0)` through the end of the `p['history'].append({...})` call (current lines 96–104). **CR-005:** `fixes`/`changes_applied` already live in that block — replace the whole block so they are not duplicated (a narrow replace that re-adds them double-counts `changes_applied`). The replacement block (containing each line exactly once):

```python
fixes = findings.get('fixes_applied', 0)
p['changes_applied'] += fixes

# touched_pages is the per-iteration PATH set that drives auditor narrowing (D6).
# De-dupe preserving first-seen order; pages_touched is now its length, not a max.
raw = findings.get('touched_pages', [])
seen = set()
touched = [x for x in raw if not (x in seen or seen.add(x))]
p['touched_pages'] = touched
p['pages_touched'] = len(touched)

p['history'].append({
    'iteration': p['iteration'],
    'findings': findings.get('findings', []),
    'fixes_applied': fixes,
    'touched_pages': touched,
})
```

- [ ] **Step 5: Add the `touched-pages` subcommand**

After `cmd_record_iteration` (before the dispatch `case`), add:

```bash
cmd_touched_pages() {
  local phase="${1:?Usage: touched-pages <phase>}"
  read_state | $PYTHON -c "
import json, sys
state = json.load(sys.stdin)
phase = sys.argv[1]
p = state['phases'].get(phase)
if p is None:
    print(json.dumps({'error': f'phase {phase} not started'}), file=sys.stderr)
    sys.exit(1)
print(json.dumps(p.get('touched_pages', [])))
" "$phase"
}
```

Then add `touched-pages) cmd_touched_pages "$@" ;;` to the dispatch `case` (alongside `record-iteration)` etc.), and add a `#   touched-pages <phase>   Emit the phase's latest touched_pages path list` line to the header usage comment.

- [ ] **Step 6: Run the tests to verify they pass**

Run: `PATH="/usr/bin:/bin:$PATH" bash plugins/up-docs/tests/run-bats.sh plugins/up-docs/tests/convergence-tracker.bats`
Expected: all PASS (including the unchanged init/start/convergence/oscillation tests).

- [ ] **Step 7: Lint + commit**

Run: `bash -n plugins/up-docs/scripts/convergence-tracker.sh && shellcheck -S warning plugins/up-docs/scripts/convergence-tracker.sh`
Expected: clean.

```bash
git add plugins/up-docs/scripts/convergence-tracker.sh plugins/up-docs/tests/convergence-tracker.bats
git commit -m "feat(up-docs): tracker persists per-iteration touched_pages path list (A1/D6)"
```

---

### Task 2: Auditor narrowing task step (A1 prompt)

**Files:**
- Modify: `plugins/up-docs/agents/up-docs-audit-drift.md` (task step "4. Iterate per phase under convergence")
- Modify: `plugins/up-docs/skills/drift/references/convergence-tracking.md` ("Narrowing on Re-pass" section)
- Test: `plugins/up-docs/tests/prompt-conformance.bats`

- [ ] **Step 1: Write the failing conformance assertions**

Append to `prompt-conformance.bats`:

```bash
AUDIT_DRIFT="$PLUGIN_ROOT/agents/up-docs-audit-drift.md"

@test "audit-drift narrows pass N+1 to prior-pass touched_pages + one-hop related" {
  run grep -iF 'touched_pages' "$AUDIT_DRIFT"
  [ "$status" -eq 0 ]
  run grep -iF 'one-hop' "$AUDIT_DRIFT"
  [ "$status" -eq 0 ]
  run grep -iF 'pass 1' "$AUDIT_DRIFT"
  [ "$status" -eq 0 ]
}

@test "convergence-tracking defers the narrowing rule to the auditor task step" {
  run grep -iF 'touched_pages' "$PLUGIN_ROOT/skills/drift/references/convergence-tracking.md"
  [ "$status" -eq 0 ]
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `PATH="/usr/bin:/bin:$PATH" bash plugins/up-docs/tests/run-bats.sh plugins/up-docs/tests/prompt-conformance.bats`
Expected: the two new tests FAIL.

- [ ] **Step 3: Rewrite the auditor's per-phase convergence step**

In `up-docs-audit-drift.md`, replace the body of task step `4. Iterate per phase under convergence` with (keep the surrounding numbering):

```markdown
4. Iterate per phase under convergence. Read `${CLAUDE_PLUGIN_ROOT}/skills/drift/references/convergence-tracking.md` for iteration mechanics and oscillation detection. **Narrowing (authoritative here):**
   - **Pass 1** of a phase: scan the full phase surface.
   - At the end of each pass, record the paths you examined-or-touched via `convergence-tracker.sh record-iteration <phase>` with a `touched_pages` array in the findings JSON.
   - **Pass N+1**: scan only the union of (i) the immediately prior pass's `touched_pages` (fetch with `bash ${CLAUDE_PLUGIN_ROOT}/scripts/convergence-tracker.sh touched-pages <phase>`) and (ii) pages whose frontmatter `related` references a page in that set (one-hop dependents). Pages outside that union are presumed stable for this phase.
   This narrowing keys off your OWN per-pass findings, so it applies identically in `/up-docs:all` and standalone `/up-docs:drift`. It never reduces pass-1 coverage.
```

- [ ] **Step 4: Point convergence-tracking.md at the task step**

In `convergence-tracking.md`, replace the "Narrowing on Re-pass" body with:

```markdown
## Narrowing on Re-pass

The narrowing rule is **owned by the auditor task step** (`agents/up-docs-audit-drift.md`, step 4): pass 1 is full; pass N+1 scans only the prior pass's `touched_pages` (from `convergence-tracker.sh touched-pages <phase>`) plus one-hop `related` dependents. This prevents O(n^2) re-scan growth. Do not restate the rule here — defer to the task step so the two cannot drift.
```

- [ ] **Step 5: Run conformance to verify pass**

Run: `PATH="/usr/bin:/bin:$PATH" bash plugins/up-docs/tests/run-bats.sh plugins/up-docs/tests/prompt-conformance.bats`
Expected: all PASS.

- [ ] **Step 6: Commit**

```bash
git add plugins/up-docs/agents/up-docs-audit-drift.md plugins/up-docs/skills/drift/references/convergence-tracking.md plugins/up-docs/tests/prompt-conformance.bats
git commit -m "feat(up-docs): auditor narrows pass N+1 to touched_pages + one-hop related (A1)"
```

---

### Task 3: Fast-path empty-layer skip + routing matrix (B, D1/D9/D11)

**Files:**
- Modify: `plugins/up-docs/skills/all/SKILL.md` (Step 2 add routing matrix; Step 3 conditional dispatch; Step 5 skipped-layer line)
- Modify: `plugins/up-docs/templates/summary-report.md` (document presentation-only skipped-layer line)
- Test: `plugins/up-docs/tests/prompt-conformance.bats`

- [ ] **Step 1: Write the failing conformance assertions**

Append to `prompt-conformance.bats`:

```bash
ALL_SKILL="$PLUGIN_ROOT/skills/all/SKILL.md"

@test "all-skill has a routing matrix with a fail-open ambiguous rule" {
  run grep -iF 'Routing matrix' "$ALL_SKILL"
  [ "$status" -eq 0 ]
  run grep -iF 'ambiguous' "$ALL_SKILL"
  [ "$status" -eq 0 ]
  run grep -iF 'all candidate layers' "$ALL_SKILL"
  [ "$status" -eq 0 ]
}

@test "all-skill dispatches only propagators with routed items and logs skips" {
  run grep -iF 'only the propagators with' "$ALL_SKILL"
  [ "$status" -eq 0 ]
  run grep -iF 'skipped (0 items routed' "$ALL_SKILL"
  [ "$status" -eq 0 ]
}

@test "audit still covers all layers even when a propagator is skipped" {
  run grep -iF 'audits all three layers' "$ALL_SKILL"
  [ "$status" -eq 0 ]
}

@test "routing fixtures cover the system-of-record edge cases (CR-002/003)" {
  F="$PLUGIN_ROOT/tests/fixtures/routing-cases.md"
  [ -f "$F" ]
  run grep -iF 'OpenBao listener rebind' "$F"; [ "$status" -eq 0 ]
  run grep -iF 'Secret VALUE' "$F"; [ "$status" -eq 0 ]
  run grep -iF 'Ambiguous' "$F"; [ "$status" -eq 0 ]
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `PATH="/usr/bin:/bin:$PATH" bash plugins/up-docs/tests/run-bats.sh plugins/up-docs/tests/prompt-conformance.bats`
Expected: three new tests FAIL.

- [ ] **Step 3: Add the routing matrix to Step 2 of `all/SKILL.md`**

At the end of `### 2. Build the Canonical Session-Change Summary`, add:

```markdown
**Routing matrix (tag each numbered item with target layer(s)).** Kept in sync with the agents' layer-boundary sections (`agents/up-docs-propagate-{repo,wiki,notion}.md`). Tag, do not drop:

| Item characteristic | Routes to |
|---|---|
| Project-repo artifact: README/docs/CLAUDE.md/AGENTS.md, handoff files, CLI flags, repo build/test config | `repo` |
| Credential **reference** added/rotated/removed (env-var name, OpenBao path — *not* the secret value) | `repo` (handoff/credentials.md) + `wiki` if a page cites it |
| Implementation reference: config values, env-var names, file paths, service procedures, troubleshooting, command usage, auth/networking wiring (incl. homelab implementation) | `wiki` |
| Strategic/organizational: new service in the stack, architecture decision, ownership/roadmap, personnel | `notion` |
| **Secret VALUE or live inventory RECORD only** (a secret's actual value in OpenBao; a device/IP/VLAN row in NetBox; an actual DNS/firewall entry) — owned by its system-of-record | none — no propagator |
| **Ambiguous / spans concerns** | **all candidate layers (fail-open)** |

**CR-002 — do not over-route to "none".** Only the *value/record itself* is system-of-record-owned. A change *about* such a thing (an OpenBao **listener rebind**, a **config path**, a **credential reference**, the **strategic fact** that a service was added) still routes to repo/wiki/notion. Worked cases live in `tests/fixtures/routing-cases.md` (created in the fixtures step below); consult them when classifying. An item may route to multiple layers; a layer is "routed-to" if ≥1 item carries its tag.
```

- [ ] **Step 3b: Create the routing fixtures (CR-003 behavioral coverage)**

Create `plugins/up-docs/tests/fixtures/routing-cases.md` — the canonical worked cases the matrix references. These double as the documented transcript-smoke checklist (LLM routing correctness is not unit-testable in bats; the conformance test in Step 1 only asserts the fixtures exist and cover the key rows):

```markdown
# Routing cases (up-docs fast-path) — expected layer tags

| # | Session item | Expected layers |
|---|---|---|
| 1 | CLI flag `--verbose` added to a repo tool | repo |
| 2 | Service procedure / config path / env-var name documented | wiki |
| 3 | New monitoring service added to the homelab stack (strategic) | notion |
| 4 | OpenBao listener rebind (`BAO_ADDR` 127.0.0.1 → 100.90.121.89) | wiki (+repo if credentials.md cites it) |
| 5 | Secret PATH rotation (OpenBao path moved) — reference only, not the value | repo (credentials.md) (+wiki if referenced) |
| 6 | DNS A-record value changed (record-only inventory) | none (Pi-hole/Porkbun is system-of-record) |
| 7 | Secret VALUE changed in OpenBao | none (OpenBao is system-of-record) |
| 8 | New service added: deploy steps + strategic note + repo README | all (repo + wiki + notion) |
| 9 | Ambiguous "updated the auth setup" with no detail | all (fail-open) |
```

- [ ] **Step 4: Make Step 3 dispatch conditional**

At the top of `### 3. Dispatch Propagators in Parallel`, before the dispatch table, add:

```markdown
Dispatch **only the propagators with ≥1 routed item** (from the Step 2 routing matrix), still in a single message with one Agent call each so they run concurrently. For every layer with zero routed items, do NOT dispatch its propagator; instead record a combined-report line `<Layer> — skipped (0 items routed to this layer)`. This never applies to the auditor — Step 4 still **audits all three layers** regardless of which propagators ran.
```

- [ ] **Step 5: Document the skipped-layer line in Step 5 and the template**

In `all/SKILL.md` `### 5. Collate and Emit Combined Report`, add a sentence: `For any layer skipped in Step 3, emit its "<Layer> — skipped (0 items routed)" line in place of that layer's table; it is presentation-only and carries no action-row totals.`

In `templates/summary-report.md`, add under the `/up-docs:all` format notes:

```markdown
- A propagation layer skipped because zero session items routed to it is rendered as a single orchestrator line `<Layer> — skipped (0 items routed to this layer)`, NOT a table row. It is presentation-only: it is not an agent `Action` value and does not pass through `validate_output.py`.
```

- [ ] **Step 6: Run conformance to verify pass**

Run: `PATH="/usr/bin:/bin:$PATH" bash plugins/up-docs/tests/run-bats.sh plugins/up-docs/tests/prompt-conformance.bats`
Expected: all PASS.

- [ ] **Step 7: Manual-acceptance note (behavioral, documented — not automated)**

Add a comment line to the top of the new conformance tests: `# Behavioral check (manual): a repo-only routed summary must dispatch NO wiki/notion Agent call while the auditor still covers all three layers. Verified by transcript inspection on the next /up-docs:all run.` (Transcript-level assertions are out of scope for bats; this records the acceptance criterion per spec §6.)

- [ ] **Step 8: Commit**

```bash
git add plugins/up-docs/skills/all/SKILL.md plugins/up-docs/templates/summary-report.md plugins/up-docs/tests/prompt-conformance.bats
git commit -m "feat(up-docs): fast-path empty-layer skip via routing matrix, fail-open (B)"
```

---

### Task 4: `commit-candidates.sh` git-ground-truth helper (C code, D8)

**Files:**
- Create: `plugins/up-docs/scripts/commit-candidates.sh`
- Test: `plugins/up-docs/tests/commit-candidates.bats`

- [ ] **Step 1: Write the failing tests**

Create `plugins/up-docs/tests/commit-candidates.bats`:

```bash
#!/usr/bin/env bats
# commit-candidates.bats — git-ground-truth candidate surfacing for the Step 6 commit offer.
bats_require_minimum_version 1.5.0
SCRIPTS_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../scripts" && pwd)"

setup() {
  REPO="$(mktemp -d)"
  git -C "$REPO" init -q
  git -C "$REPO" config user.email t@e.x
  git -C "$REPO" config user.name t
  echo base > "$REPO/tracked.md"
  git -C "$REPO" add tracked.md
  git -C "$REPO" commit -qm base
  BASE="$(mktemp)"
}
teardown() { rm -rf "$REPO" "$BASE"; }

@test "clean baseline: a newly written file is a candidate" {
  bash "$SCRIPTS_DIR/commit-candidates.sh" snapshot "$REPO" > "$BASE"   # empty
  echo new > "$REPO/written.md"
  run bash "$SCRIPTS_DIR/commit-candidates.sh" candidates "$REPO" "$BASE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"written.md"* ]]
}

@test "baseline-dirty different path is excluded from candidates" {
  echo pre > "$REPO/preexisting.md"                                     # dirty before baseline
  bash "$SCRIPTS_DIR/commit-candidates.sh" snapshot "$REPO" > "$BASE"
  echo new > "$REPO/written.md"
  run bash "$SCRIPTS_DIR/commit-candidates.sh" candidates "$REPO" "$BASE"
  [[ "$output" == *"written.md"* ]]
  [[ "$output" != *"preexisting.md"* ]]
}

@test "same-path collision (dirty at baseline AND written) is excluded" {
  echo pre >> "$REPO/tracked.md"                                        # tracked.md dirty at baseline
  bash "$SCRIPTS_DIR/commit-candidates.sh" snapshot "$REPO" > "$BASE"
  echo more >> "$REPO/tracked.md"                                       # written again this "run"
  run bash "$SCRIPTS_DIR/commit-candidates.sh" candidates "$REPO" "$BASE"
  [[ "$output" != *"tracked.md"* ]]
}

@test "path dirtied AFTER baseline is surfaced as a candidate (human approves)" {
  bash "$SCRIPTS_DIR/commit-candidates.sh" snapshot "$REPO" > "$BASE"
  echo a > "$REPO/written.md"
  echo z > "$REPO/unrelated.md"                                         # appeared post-baseline
  run bash "$SCRIPTS_DIR/commit-candidates.sh" candidates "$REPO" "$BASE"
  [[ "$output" == *"written.md"* ]]
  [[ "$output" == *"unrelated.md"* ]]   # surfaced; the template's per-path approval is the gate
}

@test "paths with spaces survive (NUL-safe parsing)" {
  bash "$SCRIPTS_DIR/commit-candidates.sh" snapshot "$REPO" > "$BASE"
  echo x > "$REPO/a b.md"
  run bash "$SCRIPTS_DIR/commit-candidates.sh" candidates "$REPO" "$BASE"
  [[ "$output" == *"a b.md"* ]]
}

@test "deleted and untracked files appear as candidates" {
  bash "$SCRIPTS_DIR/commit-candidates.sh" snapshot "$REPO" > "$BASE"
  rm "$REPO/tracked.md"                                                 # deletion
  echo u > "$REPO/untracked.md"                                         # untracked
  run bash "$SCRIPTS_DIR/commit-candidates.sh" candidates "$REPO" "$BASE"
  [[ "$output" == *"tracked.md"* ]]
  [[ "$output" == *"untracked.md"* ]]
}

@test "fingerprint changes when an approved path's content changes (CR-001)" {
  echo a > "$REPO/written.md"
  fp1=$(bash "$SCRIPTS_DIR/commit-candidates.sh" fingerprint "$REPO" written.md)
  echo b >> "$REPO/written.md"          # content mutated after "disclosure"
  fp2=$(bash "$SCRIPTS_DIR/commit-candidates.sh" fingerprint "$REPO" written.md)
  [ "$fp1" != "$fp2" ]
}

@test "fingerprint is stable when content is unchanged (CR-001)" {
  echo a > "$REPO/written.md"
  fp1=$(bash "$SCRIPTS_DIR/commit-candidates.sh" fingerprint "$REPO" written.md)
  fp2=$(bash "$SCRIPTS_DIR/commit-candidates.sh" fingerprint "$REPO" written.md)
  [ "$fp1" = "$fp2" ]
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `PATH="/usr/bin:/bin:$PATH" bash plugins/up-docs/tests/run-bats.sh plugins/up-docs/tests/commit-candidates.bats`
Expected: FAIL (script does not exist).

- [ ] **Step 3: Write the script**

Create `plugins/up-docs/scripts/commit-candidates.sh`:

```bash
#!/usr/bin/env bash
# commit-candidates.sh — git-ground-truth helper for the up-docs Step 6 commit offer.
# Surfaces paths CHANGED SINCE A BASELINE in a repo. It does NOT assert run-ownership
# (a hook/editor/other process could dirty a clean-baseline file too) — the orchestrator
# discloses each candidate's diff for explicit human approval (post-propagation-steps.md
# part (c)). git is the candidate surface; the human's diff review is the ownership guard.
#
# Subcommands:
#   snapshot   <repo>                  Print the repo's current dirty path set (one per line).
#   candidates <repo> <baseline-file>  Print (dirty now) − (baseline paths) = changed since baseline.
set -euo pipefail
PYTHON=$(command -v python3 2>/dev/null || command -v python 2>/dev/null) \
  || { echo "python3 not found" >&2; exit 1; }

# Emit NUL-safe dirty paths for the repo, one per line. Rename/copy records (R/C) carry
# the OLD path in the following NUL field; we keep the NEW path and skip the old one.
# --no-optional-locks: `git status` may otherwise refresh/write the index; a read-only
# candidate-surfacing helper must not mutate git metadata before user consent (CR-004).
dirty_paths() {
  git --no-optional-locks -C "$1" status --porcelain=v1 -z | "$PYTHON" -c '
import sys
data = sys.stdin.buffer.read().split(b"\0")
i = 0
while i < len(data):
    rec = data[i]
    if not rec:
        i += 1; continue
    xy, path = rec[:2], rec[3:]
    i += 2 if xy[:1] in (b"R", b"C") else 1
    sys.stdout.write(path.decode("utf-8", "surrogateescape") + "\n")
'
}

case "${1:-}" in
  snapshot)
    dirty_paths "${2:?usage: snapshot <repo>}"
    ;;
  candidates)
    repo="${2:?usage: candidates <repo> <baseline-file>}"
    baseline="${3:?usage: candidates <repo> <baseline-file>}"
    # set difference on exact path lines (doc paths do not contain newlines in practice)
    comm -23 <(dirty_paths "$repo" | sort -u) <(sort -u "$baseline")
    ;;
  fingerprint)
    repo="${2:?usage: fingerprint <repo> <path>}"
    path="${3:?usage: fingerprint <repo> <path>}"
    # Stable content+status fingerprint for ONE candidate path. Captured at disclosure and
    # re-checked immediately before staging (CR-001): if the worktree content changes after
    # the user approved the shown diff — even under the same path/status — the fingerprint
    # differs, and the offer must re-disclose instead of staging undisclosed content.
    xy=$(git --no-optional-locks -C "$repo" status --porcelain=v1 -- "$path" | cut -c1-2)
    if [ -e "$repo/$path" ]; then blob=$(git -C "$repo" hash-object -- "$path"); else blob="DELETED"; fi
    printf '%s:%s\n' "${xy:-??}" "$blob"
    ;;
  *)
    echo "usage: commit-candidates.sh {snapshot <repo> | candidates <repo> <baseline-file> | fingerprint <repo> <path>}" >&2
    exit 2
    ;;
esac
```

- [ ] **Step 4: Make it executable**

Run: `chmod +x plugins/up-docs/scripts/commit-candidates.sh`

- [ ] **Step 5: Run tests to verify they pass**

Run: `PATH="/usr/bin:/bin:$PATH" bash plugins/up-docs/tests/run-bats.sh plugins/up-docs/tests/commit-candidates.bats`
Expected: all 6 PASS.

- [ ] **Step 6: Lint + commit**

Run: `bash -n plugins/up-docs/scripts/commit-candidates.sh && shellcheck -S warning plugins/up-docs/scripts/commit-candidates.sh`
Expected: clean.

```bash
git add plugins/up-docs/scripts/commit-candidates.sh plugins/up-docs/tests/commit-candidates.bats
git commit -m "feat(up-docs): commit-candidates.sh surfaces changed-since-baseline paths (C/D8)"
```

---

### Task 5: Step 6 commit offer — part (c) (C prompt, D2/D8/D10)

**Files:**
- Modify: `plugins/up-docs/templates/post-propagation-steps.md` (add baseline + part (c))
- Modify: `plugins/up-docs/skills/all/SKILL.md` and `plugins/up-docs/skills/repo/SKILL.md` (capture baseline before propagation)
- Test: `plugins/up-docs/tests/prompt-conformance.bats`

- [ ] **Step 1: Write the failing conformance assertions**

Append to `prompt-conformance.bats`:

```bash
POST_PROP="$PLUGIN_ROOT/templates/post-propagation-steps.md"

@test "post-propagation part (c) is consent-gated, baseline-safe, no-push" {
  run grep -iF 'commit-candidates.sh' "$POST_PROP"
  [ "$status" -eq 0 ]
  run grep -iF 'changed since baseline' "$POST_PROP"
  [ "$status" -eq 0 ]
  run grep -iF 'per-path' "$POST_PROP"
  [ "$status" -eq 0 ]
  run grep -iF 're-check' "$POST_PROP"
  [ "$status" -eq 0 ]
  run grep -iF 'fingerprint' "$POST_PROP"
  [ "$status" -eq 0 ]
  run grep -iF 'never push' "$POST_PROP"
  [ "$status" -eq 0 ]
}

@test "post-propagation commit offer degrades to report-only when non-interactive" {
  run grep -iF 'non-interactive' "$POST_PROP"
  [ "$status" -eq 0 ]
  run grep -iF 'commit nothing' "$POST_PROP"
  [ "$status" -eq 0 ]
}

@test "all-skill captures a pre-propagation baseline for committable repos" {
  run grep -iF 'commit-candidates.sh snapshot' "$PLUGIN_ROOT/skills/all/SKILL.md"
  [ "$status" -eq 0 ]
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `PATH="/usr/bin:/bin:$PATH" bash plugins/up-docs/tests/run-bats.sh plugins/up-docs/tests/prompt-conformance.bats`
Expected: the three new tests FAIL.

- [ ] **Step 3: Add part (c) to `post-propagation-steps.md`**

After the "**(b) Handoff brief.**" subsection (end of the "Handoff for Next Session" section), append:

```markdown
**(c) Commit offer (consent-gated, baseline-safe, no push).**

Prereq — **baseline**: the orchestrator must have captured, BEFORE propagation, a dirty-path
snapshot per committable repo via `bash ${CLAUDE_PLUGIN_ROOT}/scripts/commit-candidates.sh
snapshot <repo> > <baseline-file>` (project repo; and `~/projects/llm-wiki` when the wiki
layer was in scope). If no baseline was captured (e.g. a code path that skipped it), do NOT
commit — report dirty trees and stop.

1. For each committable repo, compute candidates:
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/commit-candidates.sh candidates <repo> <baseline-file>`.
   These are paths **changed since baseline** — a candidate *surface*, NOT proof the run wrote
   them (a hook/editor/other process could have dirtied a clean-baseline path). Ownership is
   established by your per-path diff disclosure below, not by git.
2. If every repo's candidate set is empty, skip silently.
3. **Disclose + fingerprint**: for each candidate path, show its `git -C <repo> diff -- <path>`
   (or a tight summary) so the user sees exactly what would be staged, AND capture that path's
   content fingerprint now: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/commit-candidates.sh fingerprint
   <repo> <path>` — record it next to the diff you showed (CR-001). Baseline-dirty paths are
   already excluded by the helper; surface them separately as "pre-existing local changes in
   <repo> — left for you to handle manually."
4. **Non-interactive guard**: if you cannot ask the user (headless `-p`, no `AskUserQuestion`),
   **commit nothing** — report the candidate paths and stop. No consent → no commit.
5. Otherwise present ONE `AskUserQuestion` (`multiSelect` over candidate paths/repos).
6. On approval, per selected repo: **late re-check (content, not just path — CR-001)** —
   immediately before staging, recompute each approved path's fingerprint
   (`commit-candidates.sh fingerprint <repo> <path>`) and compare to the value captured at
   disclosure, AND re-run `commit-candidates.sh candidates` to catch added/removed paths. If any
   approved path's fingerprint **differs** from what was shown, or a path is gone, or unexpected
   new paths appeared, **re-disclose and re-confirm** rather than staging blindly — never stage
   content the user did not see. Then stage only the approved, fingerprint-matched paths by
   explicit literal name (`git -C <repo> add -- <path>`), commit under that repo's convention
   (project repo: signed `docs(handoff): …`; `~/projects/llm-wiki`: its draft-contract message,
   page stays `status: draft`), and **never push**. Report the commit SHA(s) and that nothing
   was pushed.
```

- [ ] **Step 4: Capture the baseline in the skills**

In `skills/all/SKILL.md`, in `### 0. Pre-flight` (after the dirty-tree guard passes), add:

```markdown
**Capture commit baselines** (for the Step 6 commit offer): BEFORE any propagation, snapshot
each committable repo's dirty set into a freshly **`mktemp`'d** file (NOT a fixed path —
concurrent runs would collide, CR-004) and remember the generated paths:
`BASELINE_REPO=$(mktemp); bash ${CLAUDE_PLUGIN_ROOT}/scripts/commit-candidates.sh snapshot . > "$BASELINE_REPO"`
and, when the wiki layer is in scope,
`BASELINE_WIKI=$(mktemp); bash ${CLAUDE_PLUGIN_ROOT}/scripts/commit-candidates.sh snapshot ~/projects/llm-wiki > "$BASELINE_WIKI"`.
Thread `$BASELINE_REPO` / `$BASELINE_WIKI` to Step 6 — do not hardcode baseline filenames there.
```

In `skills/repo/SKILL.md`, add the same project-repo snapshot line in its pre-flight (it has no wiki layer, so only the repo baseline).

- [ ] **Step 5: Run conformance to verify pass**

Run: `PATH="/usr/bin:/bin:$PATH" bash plugins/up-docs/tests/run-bats.sh plugins/up-docs/tests/prompt-conformance.bats`
Expected: all PASS.

- [ ] **Step 6: Commit**

```bash
git add plugins/up-docs/templates/post-propagation-steps.md plugins/up-docs/skills/all/SKILL.md plugins/up-docs/skills/repo/SKILL.md plugins/up-docs/tests/prompt-conformance.bats
git commit -m "feat(up-docs): Step 6 consent-gated baseline-safe commit offer, no push (C)"
```

---

### Task 6: Version bump → 0.11.0

**Files:**
- Modify: `plugins/up-docs/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json` (up-docs entry), `plugins/up-docs/CHANGELOG.md`

- [ ] **Step 1: Bump both manifests**

Set `"version"` to `0.11.0` in `plugins/up-docs/.claude-plugin/plugin.json` and in the up-docs entry of `.claude-plugin/marketplace.json`.

- [ ] **Step 2: Add the changelog entry**

Prepend under the top of `plugins/up-docs/CHANGELOG.md`:

```markdown
## [0.11.0] - 2026-06-07

### Added
- Auditor narrowing: `convergence-tracker.sh` persists a per-iteration `touched_pages` path list; the drift auditor scans pass 1 in full and narrows pass N+1 to the prior pass's touched pages + one-hop `related` dependents.
- Fast-path empty-layer skip: `/up-docs:all` routes each session item via a routing matrix and dispatches only propagators with routed items (fail-open on ambiguity); the auditor still covers all three layers.
- Step 6 commit offer: consent-gated, baseline-safe (`commit-candidates.sh` surfaces changed-since-baseline paths for per-path diff approval + a late re-check), never pushes; degrades to report-only when non-interactive.

### Changed
- `pages_touched` is now `len(touched_pages)` (was a running max).
```

- [ ] **Step 3: Validate the marketplace**

Run: `./scripts/validate-marketplace.sh`
Expected: PASS (versions consistent).

- [ ] **Step 4: Commit**

```bash
git add plugins/up-docs/.claude-plugin/plugin.json .claude-plugin/marketplace.json plugins/up-docs/CHANGELOG.md
git commit -m "chore(up-docs): bump to 0.11.0 — orchestration improvements"
```

---

### Task 7: Full green + index status

**Files:**
- Modify: `docs/handoff/specs-plans.md` (row status)

- [ ] **Step 1: Run the entire up-docs suite**

Run: `PATH="/usr/bin:/bin:$PATH" bash plugins/up-docs/tests/run-bats.sh && (cd plugins/up-docs/tests && .venv/bin/python -m pytest -q) && ./scripts/validate-marketplace.sh`
Expected: all bats `ok`, pytest all pass, marketplace PASS.

- [ ] **Step 2: Update the specs-plans index row**

In `docs/handoff/specs-plans.md`, change the design row's status to: `Executed — 0.11.0 implemented (all gates green); tagged release pending` and update the plan row likewise (add a plan row if not present, pointing at this file).

- [ ] **Step 3: Commit**

```bash
git add docs/handoff/specs-plans.md
git commit -m "docs(handoff): mark up-docs 0.11.0 orchestration plan executed"
```

- [ ] **Step 4: Release (separate, user-initiated)**

Release is a separate `/release-pipeline:release` step (plugin release, scoped tag `up-docs/v0.11.0`). Note in the release: a marketplace **cache refresh** is required for the new behavior to take effect.

---

## Self-Review

**Spec coverage:** A1 → Tasks 1–2; A2 dropped (D7), no task (correct); B → Task 3; C → Tasks 4–5; `Skipped` presentation-only → Task 3 Steps 5; non-interactive D10 → Task 5 Step 3; version/rollout → Tasks 6–7; specs-plans indexing → Task 7. Behavioral tests: A1 tracker round-trip (Task 1) + narrowing assertion (Task 2); B routing conformance + documented manual transcript check (Task 3); C six commit-safety scenarios incl. post-baseline-unrelated, spaces, deleted, untracked (Task 4). All spec §6 items covered.

**Placeholder scan:** every code step shows complete code; every test step shows real assertions and exact run commands with expected results. No TBD/TODO.

**Type/name consistency:** subcommand `touched-pages` (Task 1 Step 5) matches its use in the auditor step (Task 2 Step 3) and the `touched-pages <phase>` test (Task 1 Step 1). `commit-candidates.sh {snapshot|candidates|fingerprint}` (Task 4) matches the calls in `post-propagation-steps.md` and the skills (Task 5) and the baseline-capture (Task 5 Step 4). `touched_pages` (findings-JSON key + state field) is consistent across Tasks 1–2.

**Codex plan-review ledger (round 1 → applied):** CR-001 (late re-check missed content) → `fingerprint` subcommand + disclose/recompare flow + bats mutation test; CR-002 (routing over-routed to "none") → split system-of-record row + worked cases; CR-003 (grep-only validation) → `tests/fixtures/routing-cases.md` + fixtures-coverage conformance + concrete transcript-smoke note; CR-004 (fixed temp paths + git locks) → `mktemp` baselines + `git --no-optional-locks`; CR-005 (double-count) → Task 1 Step 4 replaces the whole `fixes…history` block + `changes_applied` assertion. Pre-existing untracked `TODO.md` flagged out-of-scope in Task 0.

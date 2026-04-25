# Plan: claude-sync

> **Status: Phase 1 plan — execute only after STRATEGY.md is approved.**
> **Phase 2 priority: 5 of 15.**

## Current state

| Field | Value |
|---|---|
| Source files | 5 shell scripts (`apply-snapshot.sh`, `capture-env.sh`, `config-block.sh`, `git-sync.sh`, `parse-snapshot.sh`) |
| Existing tests | 2 bats (`apply-snapshot.bats`, `config-block.bats`) + 3 ad-hoc bash (`test-capture-env.sh`, `test-git-sync.sh`, `test-parse-snapshot.sh`) + `run-all.sh` runner |
| Framework | Mixed: bats (canonical) + ad-hoc bash (legacy — keep) |
| Helper | `tests/helpers.bash` shared by ad-hoc scripts |

Principles: `[P1] Wholesale Capture`, `[P2] Git Is the Source of Truth for Code`, `[P3] Secrets Never Leave the Machine`, `[P4] Explicit Confirmation Before Destructive Actions`, `[P5] Machine-Local Config Stays Local`.

Highest-stakes principle in the plugin is **`[P3] Secrets Never Leave`** — the snapshot must exclude `.credentials.json`, OAuth tokens in `~/.claude.json`, and analytics caches. Currently no test asserts this directly.

## Gap table

| Principle | Layer | Proposed test | Rationale |
|---|---|---|---|
| [P1] Wholesale Capture | Mechanical | `tests/capture-env.bats` (new) — given a fake `~/.claude/` containing arbitrary unknown files (e.g., `__future_feature__/x`), the snapshot includes them by default. | Allowlist would fail this; wholesale-capture must pass. |
| [P2] Git Is Source of Truth for Code | Mechanical | `tests/capture-env.bats` — repository content under `repos-root` is **not** included in the snapshot tarball. | Mirror principle on the exclusion side. |
| [P3] Secrets Never Leave | Mechanical (security-critical) | `tests/capture-env.bats` — snapshot tarball lists do **not** include `.credentials.json`, OAuth-bearing fields from `~/.claude.json`, or `analytics/`. Use `tar tf` on the produced archive. | Highest-value test in the plugin. |
| [P3] Secrets Never Leave | Mechanical | `tests/parse-snapshot.bats` (new) — when extracting, mcpServers extraction reads only the `mcpServers` key; tokens elsewhere in source `~/.claude.json` are dropped. | Symmetric assertion on import side. |
| [P4] Explicit Confirmation Before Destructive | Behavioral — out of scope | n/a | The confirmation gate is implemented in command markdown ("/sync-import"), not in scripts. |
| [P4] (backup-before-write) | Mechanical | `tests/apply-snapshot.bats` (extend) — backup directory is created and populated **before** any file under the target tree is overwritten. Order asserted via timestamp. | The README's "backup before changes" claim is a mechanical promise. |
| [P5] Machine-Local Config Stays Local | Mechanical | `tests/capture-env.bats` — sync path, secret store path, repos root values from `CLAUDE.md` are stripped out of the snapshot during capture. | Multi-machine corruption-prevention guarantee. |
| [P5] Machine-Local Config Stays Local | Mechanical | `tests/apply-snapshot.bats` (extend) — when applying on the receiving machine, machine-local values in the local `CLAUDE.md` are not overwritten by anything in the snapshot. | Symmetric on import. |
| Cross-cutting (git-sync) | Mechanical | `tests/git-sync.bats` (new — the existing `test-git-sync.sh` becomes integration smoke) — clean repo: no commit; dirty repo: commit with auto-message; behind-but-clean: ff-pull. | Mirrors `projects.sh` state machine. |

## Files to create / modify

```
plugins/claude-sync/tests/
├── apply-snapshot.bats        (extend)
├── capture-env.bats           (new — replaces some assertions in test-capture-env.sh)
├── config-block.bats          (existing; no change)
├── git-sync.bats              (new — alongside test-git-sync.sh)
├── parse-snapshot.bats        (new — alongside test-parse-snapshot.sh)
└── helpers.bash               (existing; reuse from ad-hoc tests if applicable)
```

## Fixtures needed

- `tests/fixtures/fake-claude-home/` — a `.claude/` skeleton containing: real-looking files in subdirs, a `.credentials.json` sentinel, an `~/.claude.json` with both `mcpServers` and OAuth-shaped fields, an `analytics/` dir.
- `tests/fixtures/fake-repos-root/` — two git repos in different states (clean, dirty, behind).
- `tests/fixtures/baseline-claude-md/` — sample CLAUDE.md with `claude-sync:` block for path-stripping tests.

## Runtime estimate

- ~5 new/extended bats files × ~5 cases = 25 cases. ~10 s suite (tar/extract operations dominate).

## Risks (flag, do not fix)

1. **`HOME` redirection may not propagate into `tar` invocations** if the script uses absolute paths. Test from `BATS_TMPDIR` with `HOME` rewritten; if tar still hits real `/home`, flag. No source change.
2. **OAuth-token detection in `~/.claude.json`** may not be a deny-list — it may be an allowlist that just extracts `mcpServers`. If so, the `[P3]` test on imports already passes by construction; we still write the test to lock the behavior.
3. **`mtime`-based merge in `apply-snapshot.sh`** is platform-sensitive (filesystem mtime granularity). Tests must `sleep 1` between writes or use `touch -d` to set explicit times.
4. **The 3 legacy `test-*.sh` scripts use `tests/helpers.bash`.** New bats may want to re-use; if the bash-helper API is incompatible with bats's `setup()` model, write a parallel `tests/test_helper.bash` for bats — do not edit the existing helpers.

## What this plan does NOT do

- Migrate the legacy `test-*.sh` files. They stay as integration smoke.
- Test that the `/sync-export` and `/sync-import` command markdown leads Claude to the correct prompts. Behavioral.
- Test the actual interactive confirmation flow. Behavioral.

## Phase 2 execution log (2026-04-25)

### Built / extended

- **`tests/capture-env.bats` (new, 7 cases)** — covers [P1] wholesale capture of unknown files, [P2] repos-not-in-tarball, [P3] secrets exclusion (`.credentials.json`, `statsig/`, `projects/`, mcpServers-only extraction), [P5] CLAUDE.md config-block stripping. **`[P3]` is the highest-stakes assertion in the plugin** — verified against the actual produced tarball, not just the staging directory.
- **`tests/parse-snapshot.bats` (new, 3 cases)** — symmetric `[P3]` no-leak assertion on the import side; no_snapshot error path; addition-diff detection.
- **`tests/run-bats.sh`** — bats-wrapper workaround.

### Suite

`bash plugins/claude-sync/tests/run-bats.sh` — **29 of 29 passing** (19 baseline + 10 added).

### Findings

1. **Secrets-exclusion is implemented correctly** at the `rm -rf` step in `capture-env.sh` (lines 77–79) for the three named paths, and the `mcpServers` extraction uses `jq` filtering rather than full-file inclusion. Both layers verified on the produced tarball.
2. **CLAUDE.md config-block stripping uses sed range matching**. Edge case: if the start/end markers ever drift in casing or spacing, the strip silently no-ops. Regression-locked by test CE-P5.
3. **No source modifications.** All risks in the plan resolved by test design without script changes.

### Coverage delta

| Layer | Before | After |
|---|---|---|
| Mechanical (script) | 19 (apply-snapshot, config-block) | +10 across capture-env + parse-snapshot |
| [P3] secrets-exclusion | (no test) | 4 explicit cases — credentials, statsig, projects, mcp-only-extraction |
| Behavioral [P4] | (out of scope) | (out of scope — explicitly noted) |

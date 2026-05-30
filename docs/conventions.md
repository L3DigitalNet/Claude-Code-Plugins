# Conventions

Short, scannable pattern library for future LLM sessions. Check this file before introducing a new persistent repo pattern. Add new conventions in the same schema below.

## Quick Reference

| ID | Title | Applies when |
| --- | --- | --- |
| ARCH-001 | Thin command + fat agent | a plugin command needs to invoke expensive operations (file I/O, web research, iterative loops) |
| BRANCH-001 | Direct commit to `main` | committing or releasing in this repo |
| DOC-001 | Doc audience split | editing any repo doc — determines prose style vs LLM-first style |
| DOC-002 | Session start | starting work in this repo |
| DOC-003 | Convention changes | adding or revising a repo convention |
| PLUGIN-001 | Plugin-namespaced `subagent_type` | a plugin skill dispatches a plugin-defined agent via the Agent tool |
| TEST-001 | Canonical test frameworks by language | implementing unit tests for a plugin |
| TEST-002 | Bats wrapper for gnu env compatibility | running bats-core tests on Fedora 44+ with gnu env |
| TEST-003 | Tmpdir test repos disable git hooks | a test creates a tmpdir git repo and runs `git commit` against it |

## DOC-001. Doc audience split

**Applies when:** editing any markdown documentation in this repo.
**Rule:** Write for the file's audience — `README.md` files are human-facing prose; everything else is LLM-facing and must be terse, scannable, and optimized for future Claude Code sessions.

```md
Human-facing (prose OK):
- README.md (root + per-plugin)

LLM-facing (terse, scannable, tables > prose, no narrative framing):
- CLAUDE.md, AGENTS.md
- docs/state.md, docs/deployed.md, docs/architecture.md, docs/credentials.md, docs/conventions.md (v3 handoff layout — `docs/handoff.md` was renamed during the 2026-04-24 migration)
- docs/specs/*.md, docs/plans/*.md
- any other file under docs/
```

**Why:** All non-README documentation in this repo exists to give future Claude Code sessions reference and instruction, not to be read linearly by a human. LLM-facing prose wastes tokens and hides structure. README.md is the one file that may end up on a human's screen (GitHub page, plugin listing), so it gets conventional English prose. Mixing the two styles degrades both audiences.

**Sources:**
- `CLAUDE.md` (Repo Documentation Standard section)
- `plugins/up-docs/agents/up-docs-propagate-repo.md` `<writing_style>` block

**Related:** DOC-002, DOC-003

## ARCH-001. Thin command + fat agent

**Applies when:** a plugin command needs to invoke expensive operations — file I/O, multi-source web research, iterative convergence loops, or pattern-matching across many files.

**Rule:** Implement the command as a thin dispatcher (30-50 lines) that calls an Agent via the Agent tool, passing session context and user input; implement the actual work in a sibling agent with explicit `model:` (haiku for mechanical, sonnet for reasoning). Commands own user interaction only; agents own all data access and iteration.

```yaml
# commands/qdev-review.md — thin dispatcher (30 lines)
/qdev:quality-review target.py
├─ Call Agent: qdev:qdev-quality-reviewer
│  (receives: user input, prior findings, iteration count)
│  (returns: findings JSON + convergence status)
└─ AskUserQuestion: approve/revise/skip per finding

# agents/qdev-quality-reviewer.md — fat agent (200+ lines, explicit model: sonnet)
- Does all the work: file reads, pattern matching, multi-pass iteration
- No AskUserQuestion calls; returns structured findings only
- Model set explicitly per workload (haiku = mechanical, sonnet = reasoning)
```

**Why:** Commands that held research results, file contents, and iteration state in Opus context burned 15-22K tokens per invocation. Splitting separates concerns: commands handle user interaction (trivial) while agents handle work (and can run cheaper). Agents are stateless (no persistent context pressure); iteration state flows as JSON between Agent returns. For convergence-loop work, agents need the model tier for consistency/reasoning — sonnet over haiku for multi-pass quality audits. Mechanical work (manifest parsing, CVE lookups, docstring generation) downgrades to haiku. Pattern established across qdev and repo-hygiene (and previously python-dev before its 2026-05-08 removal); generalizes to any research-heavy or iterative plugin command.

**Sources:**
- `plugins/qdev/commands/deps-audit.md` (thin orchestrator, 40 lines)
- `plugins/qdev/agents/qdev-deps-auditor.md` (haiku agent, 180 lines)
- `plugins/repo-hygiene/commands/hygiene.md` (Step 1 inline; Step 2 dispatches agent)
- Session summary: plugin delegation migration (2026-04-23). The `plugins/python-dev/` exemplars referenced in earlier revisions were deleted 2026-05-08 along with the plugin.

**Related:** PLUGIN-001, DOC-001

## DOC-002. Session start

**Applies when:** starting any session in this repo.
**Rule:** Read `docs/state.md` before making changes (v3 handoff layout — the old `docs/handoff.md` was split into `state.md` + `deployed.md` + `architecture.md` + `credentials.md` during the 2026-04-24 migration).

```md
Open `docs/state.md`, confirm current state + active incidents, then proceed.
```

**Why:** `state.md` is the continuity layer between sessions and is auto-injected by the SessionStart hook. Older docs may still reference `docs/handoff.md` — that file no longer exists.

**Sources:**
- `AGENTS.md`

**Related:** DOC-001

## DOC-003. Convention changes

**Applies when:** adding or revising a persistent repo convention.
**Rule:** Record the convention here using the same six-field schema and add it to the quick-reference table.

```md
Update the Quick Reference table and add a new numbered convention section below it.
```

**Why:** A stable schema makes convention lookup deterministic for future sessions.

**Sources:**
- `AGENTS.md`

**Related:** DOC-001, DOC-002

## PLUGIN-001. Plugin-namespaced `subagent_type`

**Applies when:** a plugin skill dispatches a plugin-defined agent via the Agent tool.
**Rule:** Pass the fully-qualified `<plugin-name>:<agent-name>` as `subagent_type` — the bare agent filename is not resolvable from outside the plugin's namespace.

```md
Invoke via the Agent tool with `subagent_type: "up-docs:up-docs-propagate-repo"`.
NOT `subagent_type: "up-docs-propagate-repo"` — returns "Agent type not found".
```

**Why:** Claude Code resolves plugin-defined agents only through their plugin namespace. Bare-name dispatches compile but fail at runtime with "Agent type not found", and the failure does not block the skill from continuing — broken plugin flows silently no-op. Every plugin skill that dispatches an agent is affected.

**Sources:**
- `plugins/up-docs/CHANGELOG.md` (0.4.1 Fixed entry)
- Agent not-found error output lists available agents in the namespaced form.

**Related:** DOC-003

## TEST-001. Canonical test frameworks by language

**Applies when:** implementing unit tests for a plugin.
**Rule:** Use the canonical framework per language: bats-core for bash scripts, pytest for Python, Jest for TypeScript. See `testing/STRATEGY.md` §3 for rationale and per-language conventions.

```md
Bash:       bats (test files: tests/<script-name>.bats)
Python:     pytest (test files: tests/test_<module>.py)
TypeScript: Jest (test files: test/unit/<path-mirror>/<module>.test.ts)
```

**Why:** Consistency across the marketplace reduces context-switching cost for sessions that work on multiple plugins. Each framework dominates its language (bats = 9 existing bash plugins; pytest = HA and Qt already use it; Jest = HA/MCP and PTH established it for TypeScript). Ad-hoc bash runners are preserved but not extended.

**Sources:**
- `testing/STRATEGY.md` §3–4 (framework rationale + naming conventions)
- Existing test coverage (post-2026-05-25 batch release, 11 in-scope plugins): github-repo-manager 40 bats, handoff 22 bats, home-assistant-dev 207 pytest + 31 Jest, nominal 79 bats, opus-context 10 bats, plugin-test-harness 68 Jest, qt-suite 6 bats + 54 pytest, release-pipeline 76 bats, repo-hygiene 40 bats, test-driver 57 bats, up-docs 48 bats + 26 pytest (was 34 bats pre-v0.8.0; +27 bats from deny-guard/capture-transcript/convergence-tracker tests and +1 from a v0.8.1 deny-guard regression test, then −14 bats when the deny-guard PreToolUse hook was removed after v0.8.1; +26 pytest from validate_output and verify_evidence_grounded suites).

**Related:** TEST-002, DOC-001

## TEST-002. Bats wrapper for gnu env compatibility

**Applies when:** running bats-core tests on Fedora 44+ with gnu env.
**Rule:** Provide a `tests/run-bats.sh` wrapper that re-exports `bats_readlinkf` and invokes `$BATS_ROOT/libexec/bats-core/bats` directly instead of relying on the npm-installed `~/.local/bin/bats` wrapper.

```bash
#!/usr/bin/env bash
# Fedora 44 + bash 5.3.9 + gnu env workaround: env strips exported bash functions
# causing BATS_LIBEXEC to be empty and bats_readlinkf undefined.
set -euo pipefail

export BATS_ROOT="${BATS_ROOT:-$(npx bats --version 2>&1 | grep -o '/.*' | head -c-9)}"
export bats_readlinkf='...' # re-export the function
exec bash "$BATS_ROOT/libexec/bats-core/bats" "$@"
```

**Why:** On this environment, the standard `bats` invocation silently drops all test output (file size 0 bytes) because `exec env BATS_ROOT=...` strips the bash function export. The workaround bypasses the wrapper and calls the executable directly with the function pre-loaded. Fallback to plain `bats` when `BATS_ROOT` is unavailable.

**Sources:**
- Issue: reproducer `bats /tmp/minimal.bats > out.txt 2>&1; ls -la out.txt` shows 0 bytes via wrapper, populated via direct call
- Discovered during release-pipeline Phase 2 (2026-04-25)
- Affects 9 plugins (post-2026-05-08 cleanup): release-pipeline, opus-context, handoff, up-docs, repo-hygiene, github-repo-manager, nominal, test-driver, qt-suite

**Related:** TEST-001, DOC-001

## BRANCH-001. Direct commit to `main`

**Applies when:** committing or releasing in this repo.
**Rule:** Direct commit to `main`. There is no `testing` branch and no merge step. Local pre-commit hooks (noreply email enforcement, `scripts/validate-marketplace.sh`) provide the guardrails server-side branch protection used to provide. For tagged plugin releases (with version bump + changelog + GitHub release), use `/release-pipeline:release`.

```bash
# Routine commit
git pull origin main
# (edit)
git add <specific files>
git commit -m "..."
git push origin main

# Tagged release
/release-pipeline:release   # → pick "Plugin Release" or "Batch Release"
```

**Why:** Single-developer repo. The previous `testing` → `main` merge convention was retired 2026-05-07 along with deletion of the `testing` branch (local + remote) and removal of GitHub `lock_branch` protection on `main`. The release pipeline orchestrates the version-bump / changelog / tag / GitHub-release ceremony when a plugin is ready to ship; routine edits don't need that ceremony.

**Sources:**
- `BRANCH_PROTECTION.md` (canonical statement of the new rule)
- `CLAUDE.md` (Branch workflow line)
- `AGENTS.md` (Codex parallel)
- session 2026-05-07 (testing-branch retirement + release-pipeline v2.2.0 adaptation)

**Related:** ARCH-001, DOC-002

## TEST-003. Tmpdir test repos disable git hooks

**Applies when:** a test creates a temporary git repo (e.g., via `os.tmpdir()` + `git init`) and runs real `git commit` against it.
**Rule:** After `git init`, set `core.hooksPath` to `/dev/null` in the tmpdir repo's local config so workstation-level pre-commit/commit-msg hooks don't fire on test commits.

```typescript
// in beforeEach (TypeScript / Jest example)
await execa('git', ['init'], { cwd: tmpDir });
await execa('git', ['config', 'core.hooksPath', '/dev/null'], { cwd: tmpDir });
await execa('git', ['config', 'user.email', 'test@example.com'], { cwd: tmpDir });
await execa('git', ['config', 'user.name', 'Test'], { cwd: tmpDir });
```

```bash
# in setUp (bash / bats equivalent — per-tmpdir variant)
git init "$tmpdir"
git -C "$tmpdir" config core.hooksPath /dev/null
git -C "$tmpdir" config user.email 'test@example.com'
git -C "$tmpdir" config user.name 'Test'
```

```bash
# Preferred for bats: file-level variant at top of helpers.bash / test_helper.bash.
# Applied marketplace-wide on 2026-05-25 — covers all subsequent tmpdir repos
# without per-test boilerplate, and also neutralizes commit.gpgsign + tag.gpgsign
# which the per-repo core.hooksPath variant doesn't.
export GIT_CONFIG_GLOBAL=/dev/null
export GIT_CONFIG_NOSYSTEM=1
```

**Why:** Workstations may have global pre-commit hooks (e.g., noreply email enforcement) configured via global `core.hooksPath`, plus global `commit.gpgsign=true` and `tag.gpgsign=true` requiring signing keys. Tests using fake author emails for fixture commits will be rejected by those hooks before the test logic runs; tests creating tags will silently fail without a signing key. Setting `core.hooksPath=/dev/null` in the tmpdir's local config covers only the hook case; setting `GIT_CONFIG_GLOBAL=/dev/null` + `GIT_CONFIG_NOSYSTEM=1` as exports at the top of the bats helper covers all global-config interference (hooks, signing, default branch, anything else the workstation might inherit) for every test that loads the helper. Contributor-agnostic — works regardless of which workstation config the developer has. Prefer this over `--no-verify` because it covers all subsequent git operations in the test (including ones added later) without needing to retrofit every command.

**Sources:**
- Bug 005 (workstation pre-commit hook + tmpdir test repos) — includes the 2026-05-25 marketplace-wide canonicalization table
- plugin-test-harness commit `cf9aa1b` (per-tmpdir TypeScript/Jest reference)
- release-pipeline `tests/test_helper.bash::make_git_repo` (per-tmpdir bash reference at lines 19-34)
- up-docs commit `bacf529` (file-level bash reference, helpers.bash lines 8-15)

**Related:** TEST-001, TEST-002

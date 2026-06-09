# up-docs llm-wiki Local → Remote-SSH Migration — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Retarget the `up-docs` plugin's wiki layer from the now-deleted local `~/projects/llm-wiki` directory to the canonical repo on GMK **CT 103** (`/srv/workspaces/llm-wiki`), reachable only over SSH (alias `llm-wiki`), and ship it as up-docs **0.12.0**.

**Architecture:** The 2026-06-07 migration (v0.10.0) moved the wiki layer from the Outline MCP server to a **local filesystem** repo, with the propagator/auditor using `Read`/`Edit`/`Write`/`rg` against `${LLM_WIKI_ROOT:-$HOME/projects/llm-wiki}`. On 2026-06-08 the repo was moved off the workstation into CT 103, so that local path no longer exists and the wiki layer is **broken** (operates on a missing directory). This plan introduces a single indirection — `LLM_WIKI_SSH` (ssh alias) + `LLM_WIKI_ROOT` (remote path, default `/srv/workspaces/llm-wiki`) — and converts every wiki read/search/write/validate/commit operation to run **inside the LXC over SSH** (`ssh "$LLM_WIKI_SSH" 'cd "$LLM_WIKI_ROOT" && …'`). The local-filesystem tool model (Read/Edit/Write/Glob/Grep on the wiki path) is replaced by Bash+SSH exclusively, mirroring the `llm-wiki-remote` skill contract. The Notion and repo layers are untouched.

**Tech Stack:** Markdown agent/skill prompts, JSON plugin manifests, `bats` (prompt/manifest/script conformance), `pytest` (auditor JSON schema), `scripts/validate-marketplace.sh`, an `ssh` test stub (`tests/fixtures/stubs/ssh`). Remote validators: `ssh llm-wiki 'cd /srv/workspaces/llm-wiki && uvx … validate-frontmatter && uv run python -m llm_wiki_tools.lint.{resolve_links,frontmatter_ids}'`.

**Precedent:** [`docs/plans/2026-06-07-up-docs-llm-wiki-migration-plan.md`](2026-06-07-up-docs-llm-wiki-migration-plan.md) (the Outline → local-FS migration, v0.10.0) — this plan is the structural sequel; reuse its File Structure table, swapping "local FS verbs" for "SSH verbs."

**Reference contract:** `~/.agents/skills/llm-wiki-remote/SKILL.md` — the canonical HOW for remote access (session start/end, edit idioms, validation over SSH). The propagator/auditor prompts should align with it.

---

## Hard Prerequisite (verify before Task 1)

The remote validator gate depends on `uv`/`uvx` being on the **non-interactive** SSH PATH inside CT 103. This was broken (PATH prepend sat below the `.bashrc` interactive guard) and fixed 2026-06-08 in homelab commit `9664d7f`. Confirm it still holds:

```bash
ssh llm-wiki 'command -v uv uvx' && \
ssh llm-wiki 'cd /srv/workspaces/llm-wiki && uv run python -m llm_wiki_tools.lint.resolve_links' | tail -1
```

Expected: two `~/.local/bin/...` paths, then `all links resolve — N files checked`. If `uv: command not found`, stop and re-apply the homelab `9664d7f` bashrc fix (PATH export above the `[[ $- != *i* ]] && return` guard; `~/.bashrc` is root-owned, edit via `ssh gmk 'pct exec 103 -- …'`).

---

## Open Decisions (resolve at execution start — defaults chosen, flag to operator)

1. **Push policy for the remote wiki commit.** The local-repo model is **commit, never push** (the operator pushes from their working tree). The CT 103 repo's working tree is _not_ where the operator sits, and GitHub is its off-machine backup. **Default:** keep "commit-only, never push" to preserve the cautious contract — note that the CT's weekly `vzdump` + restic already back up the commit even unpushed, so durability is not at risk. **Alternative:** add a second gated "push?" prompt. Recommendation: ship the default in 0.12.0; treat push-offer as a follow-up if the operator wants it.
2. **Propagator `tools:` field.** After migration, `Read`/`Edit`/`Write`/`Glob`/`Grep` cannot reach the remote path (and the contract docs `AGENTS.md`/`conventions.md`/schemas are also remote). **Default:** narrow `tools:` to `Bash` only, so the agent never reaches for a local FS tool that would silently target the wrong (nonexistent) path. Keep `Read` only if there remain _local_ files it must read (there are none on the wiki path). Recommendation: `tools: Bash`.

---

## File Structure

| File | Responsibility | Change |
| --- | --- | --- |
| `plugins/up-docs/agents/up-docs-propagate-wiki.md` | Wiki-layer propagator prompt | **Major rewrite** — all repo I/O (read/search/edit/write/validate) → SSH; pre-flight reachability probe; `tools: Bash`; access constants `LLM_WIKI_SSH`+`LLM_WIKI_ROOT` |
| `plugins/up-docs/agents/up-docs-audit-drift.md` | Drift auditor (wiki phase) | **Moderate** — wiki-phase read/search → SSH; reachability skip replaces directory-exists skip |
| `plugins/up-docs/agents/up-docs-propagate-repo.md` | Repo propagator (one cross-ref) | **Minor** — the "Verifiable against: rg over ~/projects/llm-wiki/wiki/" example → `ssh llm-wiki 'cd … && rg …'` |
| `plugins/up-docs/skills/wiki/SKILL.md` | `/up-docs:wiki` entrypoint | **Minor** — description + body path/prereq refs |
| `plugins/up-docs/skills/all/SKILL.md` | `/up-docs:all` orchestrator | **Moderate** — wiki baseline snapshot now runs on the CT via SSH; prereq wording |
| `plugins/up-docs/templates/post-propagation-steps.md` | Step-6 commit offer | **Moderate** — wiki snapshot/fingerprint/stage/commit → SSH; push-policy note |
| `plugins/up-docs/scripts/commit-candidates.sh` | git-ground-truth helper | **Minor/none** — invoked on the CT via `ssh 'bash -s'`; verify it is remote-safe (pure git+sh) |
| `plugins/up-docs/README.md` | Human prereqs/surface | **Minor** — lines ~23/~205: "local repo on disk" → "SSH access to `llm-wiki`" |
| `plugins/up-docs/CHANGELOG.md` | Release notes | **Add** 0.12.0 entry |
| `plugins/up-docs/.claude-plugin/plugin.json` | Plugin manifest | **Bump** 0.11.0 → 0.12.0 |
| `.claude-plugin/marketplace.json` | Marketplace manifest | **Verify** (version lives in plugin.json; update up-docs description if it names the local path) |
| `plugins/up-docs/tests/fixtures/stubs/ssh` | SSH test stub | **Extend** — stub wiki `rg`/`cat`/`git`/`uv` ops |
| `plugins/up-docs/tests/prompt-conformance.bats` | Prompt assertions | **Add** wiki-SSH conformance assertions; **remove** local-FS-on-wiki assertions |
| `plugins/up-docs/tests/manifest.bats` | Version/manifest assertions | **Update** to 0.12.0 |
| `plugins/up-docs/tests/commit-candidates.bats` | Helper tests | **Add** remote-invocation case (if wrapper added) |
| `plugins/up-docs/docs/handoff/*` (deployed.md, specs-plans.md) | Repo handoff | **Update** llm-wiki path references |

---

## Task 1: Define the remote-access constants + pre-flight reachability (propagator)

**Files:**

- Modify: `plugins/up-docs/agents/up-docs-propagate-wiki.md` (header `tools:` line; the operating-context block ~lines 17–18, 38; pre-flight step ~line 44; paths&cwd ~line 73)
- Test: `plugins/up-docs/tests/prompt-conformance.bats`

- [ ] **Step 1: Write the failing conformance test**

Add to `prompt-conformance.bats`:

```bash
@test "propagate-wiki: declares LLM_WIKI_SSH + remote root, no local wiki path" {
  run cat "$REPO_ROOT/plugins/up-docs/agents/up-docs-propagate-wiki.md"
  [ "$status" -eq 0 ]
  # remote indirection present
  [[ "$output" == *'LLM_WIKI_SSH'* ]]
  [[ "$output" == *'/srv/workspaces/llm-wiki'* ]]
  # the old local default is gone
  [[ "$output" != *'$HOME/projects/llm-wiki'* ]]
  [[ "$output" != *'~/projects/llm-wiki'* ]]
}

@test "propagate-wiki: pre-flight probes reachability over ssh, not a local directory" {
  run cat "$REPO_ROOT/plugins/up-docs/agents/up-docs-propagate-wiki.md"
  [[ "$output" == *'ssh'*'test -d'* ]] || [[ "$output" == *'ConnectTimeout'* ]]
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd plugins/up-docs && ./tests/run.sh tests/prompt-conformance.bats` (or `bats tests/prompt-conformance.bats`) Expected: the two new tests FAIL (old prompt still says `$HOME/projects/llm-wiki`).

- [ ] **Step 3: Edit the prompt — access constants + pre-flight**

Replace the operating-context definition (the block that currently reads `${LLM_WIKI_ROOT:-$HOME/projects/llm-wiki}` … "There is NO MCP server") with:

```markdown
The wiki is a git-backed Markdown knowledge base hosted in a remote Debian 13 LXC (GMK CT 103), reachable over SSH as `${LLM_WIKI_SSH:-llm-wiki}` with the repo at `${LLM_WIKI_ROOT:-/srv/workspaces/llm-wiki}`. It is NOT on the local filesystem and there is NO MCP server. EVERY repo operation — search, read, edit, write, validate, git — runs inside the LXC over SSH:

    ssh "${LLM_WIKI_SSH:-llm-wiki}" 'cd '"${LLM_WIKI_ROOT:-/srv/workspaces/llm-wiki}"' && <command>'

Do NOT use Read/Edit/Write/Glob/Grep against the wiki — those tools target the local filesystem, where the repo does not exist.
```

Replace the pre-flight step (currently "Resolve `LLM_WIKI_ROOT` … If the directory is absent … graceful skip") with:

```markdown
1.  Pre-flight. Probe reachability — do NOT test for a local directory:

        ssh -o BatchMode=yes -o ConnectTimeout=5 "${LLM_WIKI_SSH:-llm-wiki}" \
          'test -d '"${LLM_WIKI_ROOT:-/srv/workspaces/llm-wiki}"'/.git'

    If this exits non-zero (host unreachable, key/auth failure, or repo absent), emit the single-row "wiki not checked (llm-wiki unreachable)" table from `<output_format>` and stop — a graceful skip, never a failed run.
```

- [ ] **Step 4: Update the `tools:` frontmatter line**

Change `tools: Read, Glob, Grep, Bash, Edit, Write` → `tools: Bash` (per Open Decision 2).

- [ ] **Step 5: Run to verify the two new tests pass**

Run: `bats tests/prompt-conformance.bats` Expected: the two Task-1 tests PASS. (Other wiki tests may still fail until Task 2 — that's expected.)

- [ ] **Step 6: Commit**

```bash
git add plugins/up-docs/agents/up-docs-propagate-wiki.md plugins/up-docs/tests/prompt-conformance.bats
git commit -m "feat(up-docs): wiki propagator pre-flight + access constants for remote SSH (0.12.0 wip)"
```

---

## Task 2: Convert propagator I/O (search/read/edit/write/validate) to SSH

**Files:**

- Modify: `plugins/up-docs/agents/up-docs-propagate-wiki.md` (operating model ~line 18, 38, 51–55; paths&cwd ~line 73; validator gate; worked examples ~lines 130–199)
- Test: `plugins/up-docs/tests/prompt-conformance.bats`, `plugins/up-docs/tests/fixtures/stubs/ssh`

- [ ] **Step 1: Write the failing conformance test**

```bash
@test "propagate-wiki: search/read/write/validate all go through ssh" {
  run cat "$REPO_ROOT/plugins/up-docs/agents/up-docs-propagate-wiki.md"
  # search idiom
  [[ "$output" == *"ssh"*"rg "* ]]
  # write idiom (heredoc to remote cat OR python3 - over stdin)
  [[ "$output" == *"python3 -"* ]] || [[ "$output" == *"cat >"* ]]
  # validators over ssh
  [[ "$output" == *"validate-frontmatter"* ]]
  [[ "$output" == *"resolve_links"* ]]
  # no bare local Edit/Write verbs against the wiki remain
  [[ "$output" != *'Edit "$LLM_WIKI_ROOT'* ]]
  [[ "$output" != *'Read "$LLM_WIKI_ROOT'* ]]
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `bats tests/prompt-conformance.bats` Expected: FAIL — prompt still uses `Read "$LLM_WIKI_ROOT/..."` / `Edit "$LLM_WIKI_ROOT/..."`.

- [ ] **Step 3: Rewrite the operating-model + per-item-action text**

Replace the local-FS verbs with the SSH idioms from `llm-wiki-remote/SKILL.md`:

- **Search/locate** (was `rg` over `$LLM_WIKI_ROOT/wiki/`):
  ```bash
  ssh "$LLM_WIKI_SSH" 'cd "$LLM_WIKI_ROOT" && rg -n -i "<pattern>" wiki/'
  ```
- **Read a page** (was `Read "$LLM_WIKI_ROOT/wiki/...md"`):
  ```bash
  ssh "$LLM_WIKI_SSH" 'cat "$LLM_WIKI_ROOT/wiki/<path>.md"'
  ```
- **Edit an existing page** (was `Edit`): structured edit via local-heredoc piped to remote `python3 -` (no nested-quote escaping; `$VARS` stay literal):
  ```bash
  ssh "$LLM_WIKI_SSH" 'cd "$LLM_WIKI_ROOT" && python3 -' <<'PY'
  from pathlib import Path
  p = Path("wiki/<path>.md")
  s = p.read_text()
  s = s.replace("<old>", "<new>")        # targeted, smallest-coherent-change
  p.write_text(s)
  PY
  ```
- **Write a new draft page** (was `Write`): heredoc to remote file:
  ```bash
  ssh "$LLM_WIKI_SSH" 'cat > "$LLM_WIKI_ROOT/wiki/<path>.md"' <<'EOF'
  ---
  # v1.1 frontmatter (minted id, status: 'draft', tags: ['wiki'], …)
  ---
  …body…
  EOF
  ```
- **Contract docs** (was "`Read` AGENTS.md / conventions.md / schemas"): read them over SSH too —
  ```bash
  ssh "$LLM_WIKI_SSH" 'cd "$LLM_WIKI_ROOT" && cat AGENTS.md docs/handoff/conventions.md'
  ```
- **id minting** runs on the CT: `ssh "$LLM_WIKI_SSH" 'cd "$LLM_WIKI_ROOT" && uv run python -m llm_wiki_tools.<id-mint-cmd>'` (use the exact command named in the repo's AGENTS.md).

- [ ] **Step 4: Rewrite the validator gate block**

Replace the "validate before claiming clean" block with the SSH form (copy the version-pinned commands from the repo's `AGENTS.md`, run each over SSH):

```bash
ssh "$LLM_WIKI_SSH" 'cd "$LLM_WIKI_ROOT" && uvx --from "git+https://github.com/L3DigitalNet/project-standards@v2.0.0" validate-frontmatter --config .project-standards.yml'
ssh "$LLM_WIKI_SSH" 'cd "$LLM_WIKI_ROOT" && uv run python -m llm_wiki_tools.lint.resolve_links'
ssh "$LLM_WIKI_SSH" 'cd "$LLM_WIKI_ROOT" && uv run python -m llm_wiki_tools.lint.frontmatter_ids check'
```

Add a note: this requires `~/.local/bin` on the non-interactive SSH PATH (homelab `9664d7f`).

- [ ] **Step 5: Convert the worked examples**

In the worked examples (~lines 130–199), change each `rg -n … "$LLM_WIKI_ROOT/wiki/"`, `Read "$LLM_WIKI_ROOT/…"`, `Edit "$LLM_WIKI_ROOT/…"`, `Write "$LLM_WIKI_ROOT/…"` to its SSH equivalent above. Keep the prose semantics (smallest-coherent-change, preserve `id`/`created`, bump `updated`, no self-promote, `confidence: 'unknown'` for operator-asserted facts).

- [ ] **Step 6: Extend the ssh stub for the new ops**

In `tests/fixtures/stubs/ssh`, add canned responses for `cd … && rg …` (return a fixture hit), `cat …` (return fixture page), `python3 -` (consume stdin, exit 0), `uvx … validate-frontmatter` / `uv run … resolve_links` / `frontmatter_ids check` (exit 0 with a clean line), and the pre-flight `test -d …/.git` (exit 0). Mirror the existing stub's dispatch style.

- [ ] **Step 7: Run conformance + stub-driven tests**

Run: `bats tests/prompt-conformance.bats tests/commit-candidates.bats` Expected: Task-2 test PASSES; existing tests still green.

- [ ] **Step 8: Commit**

```bash
git add plugins/up-docs/agents/up-docs-propagate-wiki.md plugins/up-docs/tests/prompt-conformance.bats plugins/up-docs/tests/fixtures/stubs/ssh
git commit -m "feat(up-docs): wiki propagator I/O + validators run over SSH (0.12.0 wip)"
```

---

## Task 3: Convert the drift auditor's wiki phase to SSH

**Files:**

- Modify: `plugins/up-docs/agents/up-docs-audit-drift.md` (wiki-phase resolve ~line 48 + its read/search steps)
- Test: `plugins/up-docs/tests/prompt-conformance.bats`, `pytest` auditor schema test

- [ ] **Step 1: Write the failing conformance test**

```bash
@test "audit-drift: wiki phase reads over ssh, skips on unreachable host" {
  run cat "$REPO_ROOT/plugins/up-docs/agents/up-docs-audit-drift.md"
  [[ "$output" == *'LLM_WIKI_SSH'* ]]
  [[ "$output" == *'/srv/workspaces/llm-wiki'* ]]
  [[ "$output" != *'$HOME/projects/llm-wiki'* ]]
  [[ "$output" == *'unreachable'* ]]
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `bats tests/prompt-conformance.bats` Expected: FAIL.

- [ ] **Step 3: Edit the wiki-phase resolve + read steps**

Replace the "Resolve `LLM_WIKI_ROOT` … If that directory is missing, skip" block with the reachability-probe skip from Task 1, and convert the wiki-phase reads/searches to `ssh "$LLM_WIKI_SSH" 'cd "$LLM_WIKI_ROOT" && rg/cat …'`. Keep the "never fabricate a wiki result when absent" rule (now: when **unreachable**). The auditor already uses `ssh gmk 'pct exec …'` for server inspection, so the SSH idiom is consistent with the rest of the prompt.

- [ ] **Step 4: Run conformance + pytest schema**

Run: `bats tests/prompt-conformance.bats && pytest -q` Expected: PASS (auditor JSON output schema unchanged — only the read mechanism changed).

- [ ] **Step 5: Commit**

```bash
git add plugins/up-docs/agents/up-docs-audit-drift.md plugins/up-docs/tests/prompt-conformance.bats
git commit -m "feat(up-docs): drift auditor wiki phase reads over SSH (0.12.0 wip)"
```

---

## Task 4: Remote-safe commit offer (Step 6) for the wiki repo

**Files:**

- Modify: `plugins/up-docs/templates/post-propagation-steps.md` (baseline ~line 53; staging/commit ~line 60)
- Modify: `plugins/up-docs/skills/all/SKILL.md` (baseline snapshot ~line 47; commit-offer hand-off ~line 125)
- Verify/none: `plugins/up-docs/scripts/commit-candidates.sh` (run on the CT via `ssh 'bash -s'`)
- Test: `plugins/up-docs/tests/commit-candidates.bats`

- [ ] **Step 1: Write the failing test (remote invocation of the helper)**

```bash
@test "commit-candidates: snapshot runs against the remote wiki repo over ssh" {
  # ssh stub returns a fixed dirty set for the remote repo
  run bash -c 'ssh llm-wiki "bash -s" snapshot /srv/workspaces/llm-wiki < "'"$REPO_ROOT"'/plugins/up-docs/scripts/commit-candidates.sh"'
  [ "$status" -eq 0 ]
  [[ "$output" == *"wiki/"* ]]
}
```

(Drive it with the `tests/fixtures/stubs/ssh` stub returning a canned `git status` for the remote path.)

- [ ] **Step 2: Run to verify it fails**

Run: `bats tests/commit-candidates.bats` Expected: FAIL until the ssh stub handles `bash -s … snapshot /srv/workspaces/llm-wiki`.

- [ ] **Step 3: Decide invocation — pipe the existing script to the CT**

`commit-candidates.sh` is pure `git -C "$repo"` + sh, so it runs unchanged on the CT. Invoke it remotely by piping the local script to a remote bash with the **remote** repo path as arg:

```bash
ssh "$LLM_WIKI_SSH" 'bash -s' snapshot "$LLM_WIKI_ROOT" \
  < "${CLAUDE_PLUGIN_ROOT}/scripts/commit-candidates.sh"
```

No new file lands on the CT. `fingerprint`/`candidates` follow the same pattern. Add a 1-line header comment to `commit-candidates.sh` noting it is invoked locally for the project repo and via `ssh 'bash -s'` for the remote wiki repo.

- [ ] **Step 4: Update `templates/post-propagation-steps.md`**

- Baseline prereq (~line 53): the wiki baseline snapshot is captured on the CT —
  ```bash
  BASELINE_WIKI=$(mktemp)
  ssh "$LLM_WIKI_SSH" 'bash -s' snapshot "$LLM_WIKI_ROOT" \
    < "${CLAUDE_PLUGIN_ROOT}/scripts/commit-candidates.sh" > "$BASELINE_WIKI"
  ```
- Staging/commit (~line 60): for the wiki repo, fingerprint/stage/commit run **on the CT**:

  ```bash
  ssh "$LLM_WIKI_SSH" 'git -C "$LLM_WIKI_ROOT" --literal-pathspecs add -- <path> \
    && git -C "$LLM_WIKI_ROOT" commit -m "<draft-contract message>"'
  ```

  Pages stay `status: draft`. **Push policy:** per Open Decision 1, **do not push** by default; add a one-line note that the CT vzdump/restic backs up the commit even unpushed.

- [ ] **Step 5: Update `skills/all/SKILL.md`**

- Pre-flight baseline (~line 47): replace the local `commit-candidates.sh snapshot ~/projects/llm-wiki` with the `ssh "$LLM_WIKI_SSH" 'bash -s' snapshot "$LLM_WIKI_ROOT" < …` form above.
- Commit-offer hand-off (~line 125): replace the `~/projects/llm-wiki` reference with "the remote wiki repo on `llm-wiki` (`/srv/workspaces/llm-wiki`)".

- [ ] **Step 6: Run helper + all-skill conformance**

Run: `bats tests/commit-candidates.bats tests/prompt-conformance.bats` Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add plugins/up-docs/templates/post-propagation-steps.md plugins/up-docs/skills/all/SKILL.md plugins/up-docs/scripts/commit-candidates.sh plugins/up-docs/tests/commit-candidates.bats plugins/up-docs/tests/fixtures/stubs/ssh
git commit -m "feat(up-docs): remote-safe wiki commit offer over SSH (0.12.0 wip)"
```

---

## Task 5: Minor cross-references (wiki skill, repo agent)

**Files:**

- Modify: `plugins/up-docs/skills/wiki/SKILL.md` (description line 3 + body)
- Modify: `plugins/up-docs/agents/up-docs-propagate-repo.md` (the "Verifiable against: rg over ~/projects/llm-wiki/wiki/" example ~line 365)

- [ ] **Step 1: Update the wiki skill description + body**

`skills/wiki/SKILL.md` line 3: change `Update the llm-wiki knowledge base (~/projects/llm-wiki) …` → `Update the llm-wiki knowledge base (remote LXC CT 103, /srv/workspaces/llm-wiki over SSH) …`. Update any body prereq line from "local repo on disk" to "SSH access to `llm-wiki`."

- [ ] **Step 2: Update the repo agent's verification example**

`up-docs-propagate-repo.md` ~line 365: `rg over ~/projects/llm-wiki/wiki/` → `ssh llm-wiki 'cd /srv/workspaces/llm-wiki && rg … wiki/'`.

- [ ] **Step 3: Conformance sweep — no local wiki path remains in any prompt/skill**

```bash
! rg -n "projects/llm-wiki" plugins/up-docs/agents plugins/up-docs/skills plugins/up-docs/templates
```

Expected: no matches (exit 0 from the negation).

- [ ] **Step 4: Commit**

```bash
git add plugins/up-docs/skills/wiki/SKILL.md plugins/up-docs/agents/up-docs-propagate-repo.md
git commit -m "docs(up-docs): retarget wiki skill + repo-agent ref to remote llm-wiki (0.12.0 wip)"
```

---

## Task 6: Version bump, README, CHANGELOG, manifest, handoff docs

**Files:**

- Modify: `plugins/up-docs/.claude-plugin/plugin.json` (version)
- Modify: `plugins/up-docs/README.md` (prereqs ~lines 23, 205)
- Modify: `plugins/up-docs/CHANGELOG.md`
- Verify: `.claude-plugin/marketplace.json`
- Modify: `plugins/up-docs/docs/handoff/deployed.md`, `docs/handoff/specs-plans.md`
- Test: `plugins/up-docs/tests/manifest.bats`

- [ ] **Step 1: Update manifest test to 0.12.0**

In `tests/manifest.bats`, change the asserted version `0.11.0` → `0.12.0`.

- [ ] **Step 2: Run to verify it fails**

Run: `bats tests/manifest.bats` Expected: FAIL (plugin.json still 0.11.0).

- [ ] **Step 3: Bump `plugin.json`**

`"version": "0.11.0"` → `"version": "0.12.0"`.

- [ ] **Step 4: README prereqs**

Lines ~23 and ~205: replace "The local `~/projects/llm-wiki` repo present on disk, plus `uv`/`uvx` …" with "SSH access to the `llm-wiki` host (alias resolves, key auth); the wiki repo and its `uv`/`uvx` validators live in CT 103 (`/srv/workspaces/llm-wiki`) — nothing is required on the workstation's disk."

- [ ] **Step 5: CHANGELOG 0.12.0 entry**

```markdown
## 0.12.0

- Wiki layer retargeted from the local `~/projects/llm-wiki` directory to the canonical repo on GMK CT 103 (`/srv/workspaces/llm-wiki`), reachable only over SSH (alias `llm-wiki`). The wiki propagator and the drift auditor's wiki phase now run every read/search/edit/write/validate/git operation inside the LXC over SSH (`LLM_WIKI_SSH`+`LLM_WIKI_ROOT` indirection) instead of local Read/Edit/Write/rg. Pre-flight switched from "local directory exists" to an SSH reachability probe; graceful-skip on unreachable host. `up-docs-propagate-wiki` `tools:` narrowed to `Bash`. Step-6 commit offer runs the git-ground-truth helper on the CT via `ssh 'bash -s'`; wiki commit stays draft, commit-only (no push). Requires `~/.local/bin` on the CT's non-interactive SSH PATH.
```

- [ ] **Step 6: Verify marketplace manifest**

```bash
rg -n "up-docs" .claude-plugin/marketplace.json
```

If the up-docs block carries a `description` naming the local path, update it; the version is sourced from `plugin.json`, so no version edit there. Run `scripts/validate-marketplace.sh`.

- [ ] **Step 7: Update the plugin's handoff docs**

In `docs/handoff/deployed.md` + `docs/handoff/specs-plans.md`, update llm-wiki references from `~/projects/llm-wiki` to "CT 103 `/srv/workspaces/llm-wiki` (SSH)", and add a specs-plans row pointing at this plan.

- [ ] **Step 8: Run the full manifest + marketplace gate**

Run: `bats tests/manifest.bats && bash ../../scripts/validate-marketplace.sh` (adjust path to the repo-root validator) Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add plugins/up-docs/.claude-plugin/plugin.json plugins/up-docs/README.md plugins/up-docs/CHANGELOG.md plugins/up-docs/docs/handoff/deployed.md plugins/up-docs/docs/handoff/specs-plans.md plugins/up-docs/tests/manifest.bats .claude-plugin/marketplace.json
git commit -m "release(up-docs): 0.12.0 — remote-SSH wiki layer (docs, version, manifest)"
```

---

## Task 7: Full gate + live acceptance sweep

**Files:** none (verification only)

- [ ] **Step 1: Run the entire test suite**

Run (from `plugins/up-docs/`): `bats tests/ && pytest -q` Expected: all green (the precedent run was bats 52 / pytest 29 — count will rise with the new cases).

- [ ] **Step 2: Marketplace validator**

Run: `bash scripts/validate-marketplace.sh` (repo root) Expected: PASS.

- [ ] **Step 3: No-residual-local-path sweep**

Run: `! rg -n "projects/llm-wiki" plugins/up-docs --glob '!CHANGELOG.md' --glob '!docs/0.11.0-acceptance.md'` Expected: no matches outside the historical CHANGELOG/acceptance record.

- [ ] **Step 4: Live smoke (real SSH, read-only)**

Confirm the new idioms work against the real CT (read-only — do not write):

```bash
ssh llm-wiki 'cd /srv/workspaces/llm-wiki && rg -l -i "openbao" wiki/ | head'
ssh llm-wiki 'cd /srv/workspaces/llm-wiki && uv run python -m llm_wiki_tools.lint.resolve_links | tail -1'
```

Expected: page hits; `all links resolve — N files checked`.

- [ ] **Step 5: Optional end-to-end dry-run of `/up-docs:wiki`**

With a trivial session-change summary, run the wiki layer and confirm it reaches the CT, proposes a draft edit, runs the validator gate over SSH, and (commit offer) stages on the CT without pushing. Abort before committing if only smoke-testing.

- [ ] **Step 6: Tag the release (pending operator)**

Per the repo convention (the 2026-06-07 plan notes `/release-pipeline:release`), cut `up-docs/v0.12.0` after operator sign-off. Leave untagged until then.

---

## Self-Review (completed by plan author)

- **Spec coverage:** every `projects/llm-wiki` touchpoint found in the source tree (propagate-wiki, audit-drift, propagate-repo, skills/all, skills/wiki, templates/post-propagation-steps, README, CHANGELOG, handoff docs) has a task. The commit-offer helper's local-`git -C` assumption is addressed (Task 4). The PATH dependency is called out as a hard prerequisite.
- **Open decisions surfaced:** push policy + `tools:` narrowing — both defaulted with rationale, flagged for operator confirmation at execution start.
- **Type/name consistency:** `LLM_WIKI_SSH` (alias, default `llm-wiki`) and `LLM_WIKI_ROOT` (remote path, default `/srv/workspaces/llm-wiki`) used identically across all tasks.
- **Known soft spots to resolve at execution:** exact bats runner invocation (`tests/run.sh` vs `bats`), the precise id-minting command name (read from the repo's live `AGENTS.md`), and the exact line numbers (may drift — match on the described block, not the number).

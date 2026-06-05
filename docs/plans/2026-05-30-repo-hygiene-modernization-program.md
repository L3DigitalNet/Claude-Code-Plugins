# Repo-Hygiene Modernization Program — Session Handoff & Plan

**Status:** Brainstorm in progress (design not yet written/approved). Resume-ready handoff.
**Created:** 2026-05-30
**Owner harness:** Claude Code (Opus)
**Plugin baseline at handoff:** `repo-hygiene` **v1.4.3** (committed `3ca0d10`, local `main`, **unpushed**).
**Supersedes/extends:** [`docs/plans/2026-02-20-repo-hygiene-design.md`](2026-02-20-repo-hygiene-design.md) + [`...-implementation.md`](2026-02-20-repo-hygiene-implementation.md).

---

## 0. How to use this document (next-session pickup)

1. Read §1 (goals), §4 (locked decisions), §11 (process state) first — that's the minimum to resume.
2. The immediate next action is **§6: write the Phase 0 spec** (skills migration), then run `superpowers:writing-plans`.
3. §7 captures the Phase 1 detection design already explored — do **not** re-brainstorm it from scratch; refine from there when Phase 0 is done.
4. §12 + Appendix A hold the verified source material (doc URLs, frontmatter facts, the verbatim deep-audit prompt that Phase 3 is built from).
5. This file is the **living program record**. Update it at each phase boundary (decisions, status, new open questions). Keep `docs/handoff/specs-plans.md` pointing at it.

---

## 1. Goals (three user objectives for this initiative)

1. **Modernize plugin structure to current Claude Code conventions** — custom commands have merged into skills; `skills/<name>/SKILL.md` is the recommended form (`commands/*.md` still works but is legacy). Adopt skill frontmatter (invocation control, `allowed-tools`, supporting-file dirs) and the Agent Skills open standard.
2. **Comprehensive review + v3-handoff alignment** — every action the plugin takes must align with the v3 agent-handoff system and function in part as handoff-doc maintenance/cleanup. (Boundary preserved — see §4 row "Handoff scope".)
3. **Two tiers of depth:**
   - **Light:** quick, token-efficient general once-over, safe to run often.
   - **Deep:** read-only top-to-bottom cleanup audit producing a categorized, risk-tiered, confidence-tagged report (based on the prompt in **Appendix A**). Remediation is a separate, later, gated capability.

---

## 2. Current plugin state (v1.4.3 baseline — what exists today)

- **One command:** `commands/hygiene.md` → `/repo-hygiene:hygiene`. 8-step sweep (setup → 7 parallel mechanical scripts → semantic subagent → classify → auto-fix → approval → apply → summary → commit/push).
- **One agent:** `agents/hygiene-semantic-auditor.md` (Haiku, read-only) — semantic README/docs pass. As of v1.4.3 it does **only** what scripts can't: table-semantic cross-refs, Known-Issues staleness, Principles contradictions, em-dash overuse, root-README coverage (2b), docs/ accuracy (2c).
- **Seven mechanical scripts** (`scripts/`): `check-gitignore.sh`, `check-manifests.sh`, `check-orphans.sh`, `check-stale-commits.sh`, `check-readme-structure.sh`, `check-readme-placeholders.sh`, `check-readme-refs.sh`. All bash-wrapping-python3 (stdlib only), emit findings JSON `{check, severity, path, detail, auto_fix, fix_cmd}`.
- **Tests:** `tests/*.bats` via `tests/run-bats.sh` — **40/40 passing** at handoff.
- **Five conceptual checks** (README table): 1 gitignore · 2 manifests · 3 README/docs · 4 orphans · 5 stale-commits. (Script comment headers say "Check N of 5" — this is correct; 5 checks / 7 scripts.)
- **Conformance boundary today:** the semantic auditor is handoff-v3-aware (never flags canonical `docs/` files; `docs/handoff.md` = `info`) and **explicitly defers** byte-cap/hook-hash/AGENTS.md-block conformance to `agent-configs/scripts/validate-layout.sh` + up-docs. **This boundary is preserved** (see §4).

---

## 3. Research findings (verified this session)

Sources: `code.claude.com/docs/en/skills`, `/plugins`, `/plugins-reference`; `agentskills.io`; `~/projects/agent-configs/docs/handoff/agent-handoff-system.md`. (Full URLs in §12.)

### 3.1 Commands → skills convergence (current, official)
- "**Custom commands have been merged into skills.** `.claude/commands/deploy.md` and `.claude/skills/deploy/SKILL.md` both create `/deploy`." Existing `commands/` keep working.
- Plugin dir table: `commands/` = "Skills as flat Markdown files. **Use `skills/` for new plugins**." → `skills/` is the modern form.
- Skills add: a supporting-files directory, invocation-control frontmatter, auto-load-when-relevant.

### 3.2 Skill `SKILL.md` frontmatter (verified field set)
| Field | Meaning |
|---|---|
| `name` | Display label in listings. For a plugin-root `SKILL.md` it sets the command; otherwise the **directory name** sets the command, not `name`. |
| `description` | When Claude should load it (matched during discovery). |
| `disable-model-invocation: true` | **Only the user** can invoke (`/name`). Description kept out of context until invoked. Also blocks preload into subagents. Default `false`. |
| `user-invocable: false` | **Only Claude** can invoke; hidden from `/` menu. |
| `allowed-tools` | Tools usable without per-use approval while active (space/comma list or YAML list). Does **not** restrict the pool. Honored after workspace-trust for project skills. |
| `disallowed-tools` | Tools removed from pool while active (e.g. block `AskUserQuestion` in a background loop). |
| `context: fork` | Run the skill in a forked subagent; SKILL.md becomes the task prompt; no conversation history. Pair with `agent:` type. |
| `model` | Model to use while the skill is active. |
| `arguments` / `$ARGUMENTS` / `$N` / `$name` | Argument passing. `$ARGUMENTS` = all; `$0/$1…` or `$ARGUMENTS[N]` positional; named via `arguments:` list. |
- Invocation matrix: default = both can invoke (description always in context). `disable-model-invocation:true` = user-only. `user-invocable:false` = Claude-only.
- **Skill content lifecycle:** invoked SKILL.md enters the conversation once and persists; not re-read each turn. Re-attached after compaction (first 5k tokens each, 25k combined budget). → write standing instructions, not one-time steps.
- `skillOverrides` in settings can control visibility without editing SKILL.md.

### 3.3 Plugin structure (verified)
- Plugin root dirs: `.claude-plugin/plugin.json` (manifest ONLY), `skills/`, `commands/` (legacy), `agents/`, `hooks/hooks.json`, `.mcp.json`, `.lsp.json`, `monitors/monitors.json`, `bin/` (PATH while enabled), `settings.json` (only `agent` + `subagentStatusLine` keys honored). **Never** nest component dirs inside `.claude-plugin/`.
- Plugin skills are always namespaced `/<plugin-name>:<skill>`.
- `plugin.json` fields seen: `name`, `description`, `version` (optional; omit → commit SHA used), `author`, plus `homepage`/`repository`/`license` per full schema. (NB local memory: our marketplace validator is Zod-strict — confirm field validity before adding.)
- `${CLAUDE_PLUGIN_ROOT}` = plugin install dir. `/reload-plugins` to hot-reload. `--plugin-dir ./path` to dev-test.

### 3.4 Agent Skills open standard (`agentskills.io`)
- A skill = a folder with `SKILL.md` (metadata `name`+`description` minimum) + optional `scripts/`, `references/`, `assets/`.
- Progressive disclosure: discovery (name+desc) → activation (full SKILL.md) → execution (bundled files on demand).
- Broadly adopted (Cursor, Codex, Gemini CLI, Copilot, Roo, etc.) — relevant to Phase 1 multi-harness detection.

### 3.5 v3 agent-handoff system (key facts + ownership boundary)
- Canonical spec: `~/projects/agent-configs/docs/handoff/agent-handoff-system.md` (Schema 3.0, 2026-05-29).
- Layout: `docs/{state,deployed,architecture,credentials,conventions,specs-plans}.md` + `docs/handoff/sessions/<YYYY-MM>.md` + `docs/handoff/bugs/<NNN>-<slug>.md` + `docs/superpowers/{specs,plans}/` (repos may record another location in `docs/handoff/specs-plans.md` — **this repo uses `docs/specs/` + `docs/plans/`**).
- Byte caps: repo `CLAUDE.md` ≤2048 (target ≤1024); `docs/handoff/state.md` ≤2048; Claude hook output ≤4096; `AGENTS.md` ≤4096.
- `docs/handoff.md` is **retired** — its presence = migration target.
- SessionStart hook is a tracked, hash-verified installed copy (`global/claude/hooks/session_start.py`); `${CLAUDE_PROJECT_DIR}`-anchored.
- **Ownership boundary (critical):** conformance validation (byte caps, hook hash, AGENTS.md three-line block, required files) is owned by `scripts/validate-layout.sh` + the up-docs drift auditor. **repo-hygiene must NOT re-implement this** — it aligns, cleans up, and (deep tier) *calls* the canonical script. See §4.

---

## 4. Locked decisions (with rationale)

| # | Decision | Choice | Rationale |
|---|---|---|---|
| D1 | Decompose work | **5 dependency-ordered phases**, each its own spec→plan→build | Keeps each spec focused/reviewable; bounds blast radius. |
| D2 | **First spec to write** | **Phase 0 — skills migration** | Structural foundation; low-risk; everything new lands as skills. (An earlier batch briefly leaned Phase 1; the consolidated pick is Phase 0. If ambiguous next session, confirm before writing.) |
| D3 | Handoff scope | **Align + cleanup; deep tier *calls* `validate-layout.sh` and folds results in** | Preserves the existing defer-to-canonical boundary; **no parallel reimplementation** to drift. Plugin stays self-contained but compatible — never *depends* on agent-configs (script absent ⇒ skip that check). |
| D4 | Tier shape | **Two skills:** `hygiene` (light) + `audit` (deep) | Each tier sets its own invocation control + tool perms. |
| D5 | Invocation control | **Both skills `disable-model-invocation: true` (manual-only)** | User controls timing; deep audit is expensive, light sweep should not auto-fire. Deep audit is also read-only, so doubly safe. |
| D6 | Audit report location | **Repo root `CLEANUP-AUDIT.md`, git-ignored** | Matches the Appendix-A prompt verbatim; easy to find; never committed. Overwrite-in-place ⇒ only ever one. (Cleanup lifecycle: §9.) |
| D7 | Remediation | **Build a gated remediation capability (Phase 4)** | User wants eventual cleaning, but read-only audit ships first. |
| D7a | Remediation R-tier scope | **Decide at Phase 4** | Candidate: R1+R3 first, defer R2/R4. **Caveat to honor:** some R1/R3 actions may depend on an R2 move — flag and handle inter-tier dependencies explicitly; never silently skip. |
| D8 | Conformance checks | **Opt-in via repo detection** | Run handoff/agentic checks only when a harness/v3 layout is detected; silent elsewhere. Detection must be reliable across many harnesses (Cursor, Codex, Gemini, Roo, Copilot, …) and multiple coexisting configs — see §7. |
| D9 | Phase 1 detector scope | **Unified repo profile** (harnesses + repo-type/conventions) in one primitive | Both tiers need both; one detector avoids two overlapping ones. |
| D10 | Phase 1 deliverable | **Detect + declarative registry + check** (findings in existing JSON schema, gated on detection) | Self-contained, drop-in for both tiers. |
| D11 | Baseline depth | **Pragmatic** (README, LICENSE, sane .gitignore, no committed secrets, no tracked cruft, agentic-standard presence when a harness is detected) | Mirrors Appendix-A protected-set + Agent Skills std; avoids small/private-repo false positives. |
| D12 | Registry format | **JSON + per-entry `notes` + `references/registry-schema.md`** | Zero-dependency (stdlib `json`), runs identically anywhere (install does not pip-install; PyYAML/TOML add reliability risk); modular data-vs-logic split. Python-module alt was offered and not selected. |

---

## 5. Phased decomposition (dependency-ordered)

```
Phase 0  Skills migration / structure modernization      (foundation; low risk)
   └─> Phase 1  Unified detection primitive + registry    (foundational; the risky/novel piece)
          ├─> Phase 2  Light tier upgrade (/hygiene)       (consumes profile+registry)
          └─> Phase 3  Deep audit (/audit, read-only)      (consumes profile; Step 0 = detection)
                 └─> Phase 4  Gated remediation (/remediate) (consumes CLEANUP-AUDIT.md contract)
```

- **Phase 0 — Skills migration:** `commands/hygiene.md` → `skills/hygiene/SKILL.md` (modern form); both target skills `disable-model-invocation: true`; update manifest/README/marketplace/tests; **behavior unchanged**. (Detail in §6.)
- **Phase 1 — Detection primitive:** unified repo-profile detector + declarative JSON registry + conformance check script (gated). (Design in §7.)
- **Phase 2 — Light tier upgrade:** `/repo-hygiene:hygiene` slimmed + handoff/agentic-conformance via detection + stale-`CLEANUP-AUDIT.md` reaping; keeps existing approval/commit safety (P1–P4).
- **Phase 3 — Deep audit:** new read-only skill `/repo-hygiene:audit` + a dedicated auditor subagent; implements Appendix A; Step 0 = Phase 1 detection; deep tier *calls* `validate-layout.sh` when present.
- **Phase 4 — Gated remediation:** `/repo-hygiene:remediate` consumes the audit report; plan/apply with re-validation + tiered gating (§9).

---

## 6. Phase 0 spec scope (the next thing to write)

Write `docs/plans/2026-05-30-repo-hygiene-phase0-skills-migration-{design,plan}.md` (or `docs/specs/` + `docs/plans/` per repo convention). Scope:

1. **Migrate** `commands/hygiene.md` → `skills/hygiene/SKILL.md` (directory form; folder name `hygiene` ⇒ `/repo-hygiene:hygiene` unchanged). Move body verbatim; add frontmatter.
2. **Frontmatter** for `skills/hygiene/SKILL.md`: `description`, `disable-model-invocation: true`, `allowed-tools` (the current `allowed-tools: Bash, Read, Write, Edit, Glob, Grep, AskUserQuestion, Agent` set), preserve `$ARGUMENTS`/`--dry-run` handling.
3. **Decide:** remove the legacy `commands/hygiene.md` or keep as a thin shim? (Recommend: remove after skill verified, to avoid duplicate-definition ambiguity — docs say plugin version takes precedence but two definitions are confusing.)
4. **Update** `README.md` (Commands→Skills table + structure), `.claude-plugin/plugin.json` + root `marketplace.json` (version bump, kept in sync), `CHANGELOG.md`.
5. **Tests:** ensure `tests/run-bats.sh` still green; add a check that the skill is discoverable / structure valid.
6. **Verify** with `--plugin-dir` + `/reload-plugins` that `/repo-hygiene:hygiene` still resolves and behavior is identical.
7. **Non-goal:** any behavior change, the new `audit` skill, or detection — those are later phases. Phase 0 is pure structural modernization.

**Open Phase-0 question to resolve when speccing:** does the marketplace Zod validator accept the new `skills/` layout + frontmatter fields (`disable-model-invocation`, `allowed-tools`)? Verify against the validator before shipping (local memory notes strict-mode rejections).

---

## 7. Phase 1 design notes (captured — refine, don't re-derive)

**Goal:** one reliable, standalone, zero-dependency primitive that profiles a repo (which agent harnesses are present + repo type/conventions) and emits conformance findings, consumed identically by the light tier and the deep audit.

**Proposed layout (new under `plugins/repo-hygiene/`):**
```
registry/
  harnesses.json     # marker → harness identity + per-harness conformance rules (+ notes)
  baseline.json      # harness-agnostic pragmatic best-practice rules
  repo-types.json    # language/build/monorepo signatures
scripts/
  lib/profile.py     # shared reader: load registry, walk repo, build profile + helpers
  detect-profile.sh  # → emits repo-profile JSON (debug / tier input)
  check-conformance.sh # → emits findings JSON (standard schema), gated on detection
references/registry-schema.md  # how to add/adjust/remove a harness (modularity contract)
tests/  detect-profile.bats, check-conformance.bats, fixtures/<per-harness|multi|bare|v3|nonconformant>
```

**Repo-profile contract (v1):**
```json
{ "schema":"repo-profile/v1", "repo_root":"...",
  "harnesses":[{"id":"claude-code","name":"Claude Code","confidence":"high","markers_found":[...]}],
  "repo_type":{"languages":["python"],"build":["uv"],"monorepo":false},
  "profiles_active":["claude-code","codex","agent-skills-std","v3-handoff"] }
```

**Registry entry shape (harnesses.json):** `{id, name, notes, markers:{any:[...], strong:[...]}, conformance:[{id,type,path,severity,detail,notes}]}`.

**Detection reliability (user's core worry):**
- **Presence-based, not heuristic** — detected iff marker files/dirs exist.
- **Multi-valued** — returns a SET; many harnesses can coexist.
- **Confidence** — `high` if a `strong` marker present, else `medium` (ambiguous markers like a bare `AGENTS.md` shared by several tools).
- **Conflict-free** — all output advisory/read-only; if `validate-layout.sh` exists, profile notes it so a tier can defer; never depends on it.
- **Extensible** — add a harness = add one JSON entry + a fixture; no logic change.
- **Harness signature seeds:** Claude Code (`CLAUDE.md`, `.claude/`, `.claude-plugin/`), Codex (`AGENTS.md`, `.codex/`), Cursor (`.cursor/`, `.cursorrules`), Roo (`.roo/`, `.roomodes`), Kilo (`.kilocode*`), Gemini (`GEMINI.md`, `.gemini/`), Qwen (`QWEN.md`), Windsurf (`.windsurf*`), Cline (`.clinerules`), Copilot (`.github/copilot-instructions.md`), Agent Skills std (`skills/*/SKILL.md`, `AGENTS.md`), v3-handoff (the `docs/` split + retired `docs/handoff.md` + SessionStart hook).
- **Baseline (pragmatic, D11):** README, LICENSE, sane `.gitignore`, committed-secret scan (path+type only, exclude `*.example|template|sample`), tracked-cruft, agentic-standard presence when a harness is detected.
- **Error handling:** malformed registry ⇒ hard error exit (plugin's own data broken); missing target files ⇒ normal (no detection); python3 stdlib only.

---

## 8. Phases 2–4 outline (placeholders to expand at their spec time)

- **Phase 2 (light `/hygiene`):** fold `check-conformance.sh` into the parallel mechanical batch (gated ⇒ empty when nothing detected); add stale-`CLEANUP-AUDIT.md` awareness; keep P1–P4 safety + commit/push.
- **Phase 3 (deep `/audit`):** read-only; new auditor subagent (model TBD — Haiku for mechanical sweep / Sonnet for judgment?); implements Appendix A exactly (coverage ledger, risk tiers R1–R4, confidence, protected/off-limits sets, keep-reason, PLAN rules); writes `CLEANUP-AUDIT.md` + a machine-readable findings sidecar (for Phase 4); auto-append `CLEANUP-AUDIT.md` to `.gitignore`; calls `validate-layout.sh` when present.
- **Phase 4 (gated `/remediate`):** consumes the report contract; see §9.

---

## 9. Professional guidance captured (for later phases)

**Audit ↔ remediation coupling (plan/apply pattern):**
- Audit emits human `CLEANUP-AUDIT.md` **and** a machine-readable findings block/sidecar (stable schema: type, path, action, risk-tier, confidence, evidence refs).
- Remediation **re-validates every precondition at apply time** (file still exists, still unreferenced, hash matches what the audit saw) — never blindly trusts a possibly-stale audit. This is the key safety property.
- **Staleness guard:** audit stamps commit SHA + timestamp; remediation refuses / requires re-confirm if HEAD moved or report is old.
- **Tier gating:** R1 (safe delete) + R3 (untrack/gitignore/content) per-item approved first; R2 (move/rename) needs approval + reference re-scan; **R4 (history rewrite / secrets) NEVER automated** — print instructions only.
- **Inter-tier dependencies (D7a caveat):** detect when an R1/R3 action depends on an R2 (e.g., move-then-delete); surface the dependency, don't silently drop.
- Bound complexity: ship remediation as a thin, conservative consumer (R1/R3 first).

**`CLEANUP-AUDIT.md` lifecycle (answers "when is it cleaned up?"):** overwrite-in-place (only one ever) + auto-added to `.gitignore` (never committed) + light tier flags a stale report (age-based) for removal / remediation deletes it when done. Closes the loop self-hostedly (the plugin cleans up after its own audit).

---

## 10. Open / deferred decisions

- **D2 ambiguity:** confirm Phase 0-first (vs Phase 1-first) at next session start if unsure — batched answers conflicted once.
- **Phase 0:** remove legacy `commands/hygiene.md` vs keep a shim (recommend remove post-verify).
- **Marketplace validator** acceptance of `skills/` + new frontmatter fields — verify before shipping Phase 0.
- **Phase 3 auditor model** (Haiku vs Sonnet vs split).
- **Phase 4 R-tier scope** (D7a) — decide when speccing Phase 4.
- **Em-dash check** — mechanical; could migrate from the semantic auditor into a script later (not in current scope).
- **Registry comments** — JSON chosen; if `notes` fields prove insufficient, the Python-module format is the fallback.

---

## 11. Process state (where we are)

- Skill in use: `superpowers:brainstorming`. We completed: explore-context, clarifying questions, approach selection. We were at the **"present design / approve"** step for Phase 1 when the user chose to pause and write this handoff.
- **Not yet done:** write the (Phase 0) spec, spec self-review, user review, then `superpowers:writing-plans`.
- **Correction logged this session:** earlier interleaved/delayed tool results caused me to act briefly on mis-attributed answers (handoff "reimplement" and "Phase 1 first" and "light-auto"); the **authoritative** answers are in §4 (handoff = align/defer/call-canonical; first spec = Phase 0; both skills manual-only).
- **Repo state:** `repo-hygiene` v1.4.3 committed locally (`3ca0d10`), **main is 1 ahead of origin, unpushed**.

**Next-session first actions:** (1) confirm §4 still reflects intent; (2) `superpowers:brainstorming` → present Phase 0 design → on approval write the Phase 0 spec; (3) `superpowers:writing-plans`.

---

## 12. References

- Skills: https://code.claude.com/docs/en/skills (incl. `#control-who-invokes-a-skill`)
- Plugins guide: https://code.claude.com/docs/en/plugins
- Plugins reference: https://code.claude.com/docs/en/plugins-reference
- Agent Skills open standard: https://agentskills.io
- v3 handoff spec: `~/projects/agent-configs/docs/handoff/agent-handoff-system.md`
- Local memory: marketplace Zod-strict validation; plugin install does not pip/npm-install; `.mcp.json`/hooks gotchas (see session MEMORY.md).
- Prior repo-hygiene artifacts: `docs/plans/2026-02-20-repo-hygiene-{design,implementation}.md`.

---

## Appendix A — Deep-audit prompt (verbatim basis for Phase 3)

> The following is the user-provided prompt that Phase 3's read-only audit is built from "as reasonable." Preserved verbatim so Phase 3 can be specced without context loss.

```markdown
## Objective
Conduct a read-only, full-repo cleanup audit and produce a single categorized, risk-tiered, confidence-tagged recommendation report. Make no changes to any existing file.

## Context
- Repo: `[REPO_PATH]` (run from repo root). Local working copy.
- This is the audit-and-recommend pass only. Remediation (deletes, moves, renames, untracking, gitignore edits, history rewrites) happens in a separate later pass after you review the report — change nothing now.
- "Cleanup" means file- and structure-level hygiene: superseded docs, cruft, naming, layout, `.gitignore`, committed secrets, and git bloat. It does not include dead-code analysis or dependency work.

## Step 0 — Detect repo type before judging anything
Inspect manifests (`pyproject.toml`, `package.json`, `Cargo.toml`, `go.mod`, Terraform/Ansible files, etc.), the README, and the layout to determine the repo's language(s), purpose, and dominant conventions. If no manifest exists (e.g. an IaC, homelab, or docs repo), infer type from the file mix and layout instead. If the repo is a monorepo, detect sub-packages and evaluate naming, structure, and ignore conventions per package. Every structure/naming/`.gitignore` judgment below is relative to the conventions for the detected type. State the detected type and conventions at the top of the report.

## Keep-reason definition (governs DELETE recommendations for deprecated/superseded material)
A deprecated or superseded document is deleted by default. Recommend KEEP only if at least one real reason applies: referenced by current code, config, docs, or CI; required for license/compliance/legal reasons; an architecture decision record (ADR) or rationale still governing the current design; or explicitly marked as intentionally retained. Historical or archival interest alone is not sufficient. This default applies to deprecated/superseded material only — completed plans are governed by the PLAN rule below and are retained.

## Protected set — never recommend deletion
`LICENSE`/`COPYING`/`NOTICE`, `SECURITY.md`, `CONTRIBUTING.md`, `CHANGELOG.md`, `CODEOWNERS`, `CITATION*`, `.github/` (workflows, issue/PR templates), CI/CD config, `.gitignore`, `.gitattributes`, `.pre-commit-config.yaml`, build runners (`Makefile`/`justfile`/`Taskfile`), container files (`Dockerfile`/`compose.yaml`/`docker-compose.yml`), dependency lockfiles, language package markers (`__init__.py`, `py.typed`, `MANIFEST.in`), and example/template env files (`*.example`, `*.template`, `*.sample`, `.env.example`). List any of these only if they would otherwise be mistaken for cruft.

## Off-limits & role-aware exclusions
Do not recommend deleting, renaming, moving, or untracking files whose presence is explained by their role. Note them only if genuinely problematic, and say why the role does not excuse it:
- Test assets — files under `test/`, `tests/`, `fixtures/`, `__fixtures__/`, `golden/`, `testdata/`, or sample-data paths are not CRUFT/DUPLICATE/BLOAT merely for looking redundant, large, or "old".
- Vendored code — `vendor/`, `third_party/`, bundled libraries.
- Generated-by-convention files — protobuf outputs (`*_pb2.py`), generated API clients, files with a "generated by" / "do not edit" header, a committed built site for GitHub Pages.
- Submodules — any path under `.gitmodules`; treat as off-limits and never descend into or recommend changes to submodule contents.

## Findings taxonomy
A file may have more than one issue. Record one primary finding chosen by action precedence — delete > untrack > move > rename > update > keep — and note any additional issues inline in the rationale. A file recommended for deletion is not also flagged for a cosmetic rename or move. Types:
- SUPERSEDED-DOC — deprecated or superseded doc, including a spec for a feature/service no longer implemented or in service; delete unless a keep-reason applies.
- PLAN — a planning/roadmap/design-plan doc; action follows its spec:
  - completed → keep; record the spec it implemented when one exists (pair them). Completed is not the same as superseded. If no separate spec exists, keep as a standalone completed record.
  - completed, but the spec/feature it produced is itself being deleted → delete alongside that spec.
  - active or in-progress → keep.
  - superseded by a newer plan for the same work, or abandoned/stale (never completed, no longer relevant) → delete.
- RESEARCH — keep for future reference. If not already under `docs/research/`, recommend moving it there.
- CRUFT — disposable artifact: backups (`*.bak`, `*~`, `*.orig`), editor swap/temp files, empty directories, stale generated/output files; delete.
- DUPLICATE — duplicate or near-duplicate of another file; consolidate to one.
- MISNAMED — deviates from the dominant naming convention for its file class; rename.
- MISPLACED — wrong location for the repo type/structure; move.
- TRACKED-IGNORABLE — committed file a reasonable ignore policy should exclude (`__pycache__/`, `.venv/`, `node_modules/`, `dist/`, build output, logs, `.DS_Store`); untrack via `git rm --cached` and add the pattern. Record an ignorable directory as one finding, not per-file.
- GITIGNORE — additions or removals to make `.gitignore` reasonable for the repo type.
- SECRET — likely committed credential/secret (key files, high-entropy values in tracked config). Exclude `*.example`/`*.template`/`*.sample`/example env files. Report path and secret type only — never print the value. Remediation is rotate + purge from history, never a plain delete.
- BLOAT — large binary/dataset/archive bloating the repo. Distinguish working-tree size from git-history (pack) size: a file may be small or absent in the working tree yet bloat history. Working-tree-only bloat → move/untrack (R2/R3); history bloat → R4 rewrite. Flag for LFS/external storage; never delete-only for history bloat.
- STALE-DOC — doc whose content is now inaccurate (drift, dead links, removed features); update, not delete.
- STRUCTURE — directory-structure issue (missing or extra standard dirs for the repo type).

## Actions, risk tiers, and confidence
Valid actions: delete, untrack, move, rename, consolidate, edit-gitignore, update, rotate+purge, keep, flag-for-decision.
Risk tiers: R1 — safe delete, recoverable via git history. R2 — move/rename/consolidate; may break references. R3 — untrack, `.gitignore` edit, or content update; in-repo, reversible. R4 — history rewrite (secrets, history bloat); dangerous, requires rotation/coordination, never automatic. `keep` and `flag-for-decision` carry no tier (`—`).
Confidence on every finding: high — direct evidence (explicit marker, missing live config, git-confirmed completion); medium — strong but circumstantial; low — judgment call worth a second look. When confidence is low, use `flag-for-decision` rather than a destructive action.

## Constraints
- Read-only on every existing file: no edits, moves, renames, deletions, untracking, or history operations this pass. The only permitted write is the audit report. If a `CLEANUP-AUDIT.md` from a prior run exists, overwrite it; never flag the report itself. Do not `git add`, `git commit`, or stage anything.
- Read any file you make a finding about before describing it; never assert a file is superseded, deprecated, unused, completed, generated, or duplicate without opening it and citing evidence. For files you are not flagging, a stat and quick scan to confirm no issue is enough — you need not read every byte of every file.
- Before recommending any delete, untrack, move, rename, or consolidate, search the repo for inbound references (other docs, README, code imports, CI paths) and record what you find. In-repo reference search establishes repo-local linkage only — a doc may be linked from an external wiki (Outline), Notion, or deploy scripts outside this repo. Treat in-repo absence as raising confidence, not proof; for any doc plausibly referenced externally, cap confidence at medium and prefer `flag-for-decision` over delete.
- For MISNAMED/MISPLACED findings, detect the dominant existing convention/layout and flag deviations from the majority. If there is no clear majority, recommend a single convention and say so — do not impose an external standard over an established internal one.
- When multiple tool calls are independent (e.g. reading several files, running several searches), issue them in parallel. Call tools sequentially only when one depends on another's output. You may spawn parallel subagents to read and classify independent files.
- If the repo is large, audit directory-by-directory and append to the report as you go, so progress persists if context compacts.
- When in doubt, use `flag-for-decision` rather than recommending a destructive or reference-breaking action.

## Steps
1. Detect repo type and conventions (Step 0).
2. Enumerate files: `git ls-files` for tracked, plus untracked-but-not-ignored (`git ls-files --others --exclude-standard`). Do not descend into ignored or dependency directories (`.git/`, `node_modules/`, `.venv/`, `dist/`, `build/`, `target/`); if such a directory is itself tracked, record it as one TRACKED-IGNORABLE finding. Always exclude `.git/`.
3. For each file you flag, gather evidence: read it; `git log` for last-modified date and supersession/deprecation/completion commit messages; scan for in-file markers (deprecated, superseded, archived, completed, generated, "old", TODO); find newer files on the same topic; `git grep`/search for inbound references; cross-reference specs/docs against current code and config for in-service status. For plans, determine completion state and the spec they implemented.
4. Run targeted sweeps: secrets (tracked/untracked text files, excluding template/example env files; path + type only); history bloat (`git rev-list --all --objects` + `git cat-file --batch-check` for the largest objects); tracked-ignorable files; duplicates.
5. Classify each finding (primary type by action precedence), assign action, risk tier, and confidence.
6. Build the coverage ledger and write the report.

## Tools
- Filesystem + git (`git ls-files`, `git log`, `git grep`, `git cat-file`, `git rev-list --all --objects`) are the primary toolset.
- If a dedicated secret scanner (`gitleaks`, `trufflehog`) is already available, it is more reliable than manual entropy scanning — use it; otherwise scan by pattern. Do not install tooling.
- No GitHub MCP, web search, or browser automation needed. If remediation would require `git-filter-repo`/BFG (R4 items), note it in the report — do not run it.

## Report format
Write to `[REPO_PATH]/CLEANUP-AUDIT.md`. Open with: (a) detected repo type + conventions (per-package for a monorepo); (b) a coverage ledger — total files scanned, count of findings by type, and per top-level directory an "N files evaluated, no action" line so completeness is verifiable without a row per clean file; (c) counts by risk tier; (d) a "handle with care" callout listing every R4 item. Then group entries by finding type. Only files with a finding or a deliberate-keep decision (retained research, retained completed plans) get an entry. One entry per file:
`type · path · action · risk-tier · confidence · rationale · evidence · inbound-references`

<example>
SUPERSEDED-DOC · `docs/old-deploy-guide.md` · delete · R1 · high · replaced by current guide, no keep-reason · git mod 2024-09; `docs/deploy.md` (2025-11) supersedes; no in-repo refs found
SUPERSEDED-DOC · `docs/architecture-notes.md` · flag-for-decision · — · low · overlaps `docs/handoff/architecture.md` but not a clean duplicate; may be linked externally · no in-repo refs; check Outline wiki before removal
PLAN · `plans/2025-03-add-auth.md` · keep (paired with `specs/auth.md`) · — · high · completed plan for an in-service spec; completed ≠ superseded · completion commit 2025-04; `specs/auth.md` live, referenced by `src/auth/`
RESEARCH · `notes/latency-benchmarks.md` · move to `docs/research/` · R2 · high · reference material outside research dir (also non-standard name; rename to kebab-case on move) · linked from `docs/handoff/architecture.md` — update link
TRACKED-IGNORABLE · `app/__pycache__/` · untrack + add `__pycache__/` · R3 · high · build artifacts committed (directory-level) · matches standard Python ignore policy
SECRET · `config/secrets.yaml` · rotate + purge from history · R4 · high · committed credentials · value redacted; rotate keys before any removal
BLOAT · `assets/demo.mov` (history) · flag for LFS + history rewrite · R4 · medium · ~180 MB object in pack, absent from working tree · found via `git rev-list`; confirm before rewrite
</example>

## Success criteria
- Detected repo type and conventions stated at the top (per-package for a monorepo).
- Coverage ledger accounts for all scanned files; every file with a finding or deliberate-keep decision is listed, with no per-file row for clean files.
- Every entry carries type, action, risk tier (or `—`), and confidence.
- Every delete/untrack/move/rename/consolidate/rotate entry cites evidence and records inbound-reference results.
- Low-confidence items use `flag-for-decision` rather than a destructive action; uncertain items are surfaced, never force-fit or silently dropped.
- A keep-reason is named for any deprecated/superseded doc recommended for KEEP; every completed plan kept names its paired spec when one exists; every plan deleted states which case applies (superseded, abandoned, or spec-removed).
- All R4 items are called out separately at the top; no secret values are printed; template/example env files are not flagged as secrets.
- No protected, vendored, generated, submodule, or test-asset path is recommended for deletion, rename, move, or untracking.
- No existing file is modified, moved, deleted, or untracked; the report file is written and left uncommitted.
- Chat output is a brief summary only: ledger headline counts, the R4 callout, and notable judgment calls — pointing to the report for detail.

## Mode
Read-only audit. Produce the report and stop for review. No deletions, moves, untracking, edits, commits, or history operations.

## Out of scope
Executing any change; deep dead-code or static analysis; dependency upgrades; branch/tag cleanup; running history rewrites or `git-filter-repo`/BFG.
```

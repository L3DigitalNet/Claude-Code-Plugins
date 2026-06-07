# up-docs Outline → llm-wiki Migration — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Retarget the `up-docs` plugin's wiki layer from the retired Outline MCP server to the local `~/projects/llm-wiki` git repo, and ship it as up-docs `0.10.0`.

**Architecture:** Two agent rewrites (`propagate-wiki` full; `audit-drift` wiki-phase) swap `mcp-outline` MCP verbs for filesystem `Read`/`Edit`/`Write` + `rg` under the llm-wiki governance contract (layer model, frontmatter v1.1, path-links, validators, no self-promote). The remaining surfaces (two minor agents, three skills, two templates, READMEs, manifests, CHANGELOG, one repo handoff doc) change naming + the wiki-propagator model tier (Haiku → Sonnet; repo/notion stay Haiku). Manifest **and** marketplace version/description move together.

**Tech Stack:** Markdown agent/skill prompts, JSON plugin manifests, `bats` (prompt/manifest conformance), `pytest` (auditor JSON schema), `scripts/validate-marketplace.sh`, `rg` acceptance sweeps. llm-wiki validators: `uvx … validate-frontmatter`, `uv run python -m llm_wiki_tools.lint.{resolve_links,frontmatter_ids}`.

**Authoritative spec:** [`docs/plans/2026-06-07-up-docs-llm-wiki-migration-design.md`](2026-06-07-up-docs-llm-wiki-migration-design.md) (Codex-converged, §13 ledger). Section refs below (§4, §5, …) point into it.

**Plan status:** Reviewed — Codex `$plan-review` converged in 2 rounds (round-2 verdict: _No significant findings remain_; CR-NEW-001 hardening applied). Ready for execution. See the Plan audit ledger at the end.

---

## File Structure

| File | Change |
| --- | --- |
| `plugins/up-docs/agents/up-docs-propagate-wiki.md` | **Full rewrite** — MCP→filesystem, model `sonnet`, llm-wiki contract (§5) |
| `plugins/up-docs/agents/up-docs-audit-drift.md` | **Wiki-phase rewrite** — drop mcp-outline reads, add validator-backed wiki drift (§6) |
| `plugins/up-docs/agents/up-docs-propagate-repo.md` | Naming only (preserve bats-guarded strings) |
| `plugins/up-docs/agents/up-docs-propagate-notion.md` | Naming only (Notion↔wiki boundary prose) |
| `plugins/up-docs/skills/wiki/SKILL.md` | Rename + `description:` + model note |
| `plugins/up-docs/skills/all/SKILL.md` | Wiki cell rename + wiki "(Haiku)"→"(Sonnet)" |
| `plugins/up-docs/skills/drift/SKILL.md` | Outline-collection wording + Haiku-cost nuance |
| `plugins/up-docs/templates/summary-report.md` | `Wiki (Outline)` → `Wiki (llm-wiki)` |
| `plugins/up-docs/templates/drift-finding.md` | `page_id` wording (KEEP literal `"layout"`) |
| `plugins/up-docs/templates/session-change-summary.md` | line 5 "Haiku propagators" → "the propagators" (CR-001) |
| `plugins/up-docs/README.md` | Layer prose, prereqs, model-surface inventory |
| `README.md` (root) | up-docs row + summary (Outline→llm-wiki; model tiers) |
| `plugins/up-docs/.claude-plugin/plugin.json` | `version` 0.10.0 + description |
| `.claude-plugin/marketplace.json` | up-docs entry version + description (must match) |
| `plugins/up-docs/CHANGELOG.md` | New `0.10.0` entry (history preserved) |
| `docs/handoff/deployed.md` | up-docs version + description |

**Branch:** direct commit to `main` (repo convention; no `testing` branch). Plain `git commit` (global hook signs + sets author).

---

## Task 0: Baseline — confirm green before touching anything

**Files:** none (verification only)

- [ ] **Step 1: Confirm the llm-wiki target repo exists**

Run: `ls -d "${LLM_WIKI_ROOT:-$HOME/projects/llm-wiki}"/wiki && cat "${LLM_WIKI_ROOT:-$HOME/projects/llm-wiki}/AGENTS.md" | sed -n '45,55p'`
Expected: the `wiki/` dir lists and the "Validate before claiming clean" block prints (the three validator commands). If absent, STOP — the migration target is missing.

- [ ] **Step 2: Run the bats suite (must already pass)**

Run: `bash plugins/up-docs/tests/run-bats.sh`
Expected: all tests PASS (4 in `prompt-conformance.bats`, 2 in `manifest.bats`, plus the script suites).

- [ ] **Step 3: Run the pytest suite (must already pass)**

Run: `cd plugins/up-docs/tests && (.venv/bin/python -m pytest -q 2>/dev/null || python3 -m pytest -q); cd -`
Expected: `test_validate_output.py` + `test_verify_evidence_grounded.py` PASS. (If no venv, the plan's later pytest steps use the same fallback.)

- [ ] **Step 4: Run the marketplace validator (must already pass)**

Run: `./scripts/validate-marketplace.sh`
Expected: PASS (no errors). Records the pre-change baseline so a later failure is attributable to this work.

- [ ] **Step 5: Capture the pre-change Outline/Haiku surface (reference snapshot)**

Run: `rg -n -i 'outline|mcp-outline' plugins/up-docs README.md .claude-plugin/marketplace.json | tee /tmp/up-docs-outline-before.txt | wc -l`
Expected: a non-zero count; the file is the worklist. The `/tmp/...` snapshot is an intentional scratch artifact **outside git** — Task 0 changes no tracked files (verification only, no commit).

---

## Task 1: Rewrite `up-docs-propagate-wiki` (MCP → llm-wiki filesystem)

**Files:**
- Modify (full rewrite of body; preserve block scaffolding): `plugins/up-docs/agents/up-docs-propagate-wiki.md`
- Reference (read, do not edit): `${LLM_WIKI_ROOT:-$HOME/projects/llm-wiki}/AGENTS.md`, spec §4 + §5

This agent is **not** guarded by `prompt-conformance.bats`, so correctness here is enforced by the rg acceptance checks in Steps 5–6, not bats.

- [ ] **Step 1: Replace the YAML frontmatter exactly**

Set the frontmatter to (drops all six `mcp-outline` verbs; adds `Edit, Write`; bumps model):

```yaml
---
name: up-docs-propagate-wiki
description: Propagates named session changes into the llm-wiki knowledge base (~/projects/llm-wiki) at the implementation-reference layer. Writes status:draft pages under the llm-wiki contract; never self-promotes. Never performs drift detection. Never edits pages outside the session change summary.
tools: Read, Glob, Grep, Bash, Edit, Write
model: sonnet
---
```

- [ ] **Step 2: Rewrite the routing comment + `<role>`**

Keep the leading `<!-- … -->` routing comment block and `<role>`, but replace every "Outline" with "llm-wiki" and restate the mechanism: the agent reads/searches `${LLM_WIKI_ROOT:-$HOME/projects/llm-wiki}/wiki/` with `rg`/`Read` and writes with `Edit`/`Write`. Update the "Model: haiku — mechanical…" line to "Model: sonnet — frontmatter v1.1, id-minting, citations, and validator runs exceed mechanical edits." Keep the "Output contract" + "Hard rule" lines (retarget Outline→llm-wiki).

- [ ] **Step 3: Rewrite `<task>` to the llm-wiki contract (spec §4)**

The `<task>` steps become:
1. **Pre-flight (D4).** `Read` `$LLM_WIKI_ROOT/AGENTS.md`, `$LLM_WIKI_ROOT/docs/handoff/conventions.md` (rules C-1..C-12), and `$LLM_WIKI_ROOT/docs/schemas/frontmatter.schema.md`. These are authoritative; the runtime AGENTS.md validation block wins on any version disagreement. Resolve `LLM_WIKI_ROOT` (default `$HOME/projects/llm-wiki`); if the dir is absent, emit the one-row "wiki not checked" table from Step 4's output format and stop (graceful skip — never fail the run).
2. **Locate targets** with `rg` over `$LLM_WIKI_ROOT/wiki/` (title/aliases/tags/`related`), not `search_documents`.
3. **Read** each candidate page with `Read` (absolute path under `$LLM_WIKI_ROOT`).
4. **Per session item**, apply a targeted `Edit` to an existing page or `Write` a new draft page (Step-4 contract). Skip items that are strategy (→ Notion), live operational facts (→ system-of-record), or homelab **execution-state** (→ the homelab repo's own docs); **homelab implementation-reference is in-scope**. Record skips as "No change needed — out of llm-wiki domain".
5. **Validate** (Step 6).
6. **Report** every page examined.

- [ ] **Step 4: Inline the page-write contract (spec §4.2–4.6)**

Add a `<llm_wiki_contract>` block stating, verbatim intent:
- Writes touch `wiki/` only; never normalize `raw/` (immutable, C-4); never cite `capture/` (ADR-0007).
- **Session changes are operator testimony** — do NOT fabricate a `raw/` source. Record the claim in the `wiki/` page as operator-asserted, set `confidence: 'unknown'`, keep the page `status: 'draft'`, and flag the missing citation. Never self-promote `draft`→`active`.
- New pages: `status: 'draft'`, carry the `wiki` tag, and an `id` minted with `(cd "$LLM_WIKI_ROOT" && uv run python -m llm_wiki_tools.lint.frontmatter_ids mint --title "<page title>")` — `--title` is **required** (Typer `...`; see llm-wiki conventions C-11); never hand-authored. Field set / key order from the `markdown-frontmatter` skill + `docs/schemas/`.
- Links: v1.1 path-links, never `[[wikilinks]]` (frontmatter relations no-slash+`.md`; body links leading-slash Markdown).
- Smallest coherent change; on edit preserve `id`/`created`, bump `updated` only for a meaningful change.
- **All Bash runs `(cd "$LLM_WIKI_ROOT" && …)`; all `Read`/`Edit`/`Write` use absolute paths under `$LLM_WIKI_ROOT`** (SA-004).
- No secrets — credential references only.

- [ ] **Step 5: Rewrite `<layer_boundary>`, `<guardrails>`, `<examples>`, `<output_format>`**

- `<layer_boundary>`: llm-wiki `wiki/` synthesized implementation-reference (**incl. homelab infra**); exclusions: strategy (→ Notion), live facts (→ system-of-record), execution-state (→ repo docs).
- `<guardrails>`: keep the existing discipline (only act on summary items; read before write; commit to an approach; no invented values; retry-once-then-FAILED; ground-truth=live server). Replace the "Outline pages change between sessions" line with "llm-wiki pages change between sessions — re-`Read` before any `Edit`."
- `<examples>`: provide **≥1 explicit "update" and ≥1 explicit "skip"** plus one creation (SA-001). Concretely: (a) UPDATE an existing homelab page — e.g. a config value on `wiki/systems/homelab-overview.md` via `Edit`, bump `updated`; (b) CREATE a new draft for a non-homelab repo's build procedure via `Write` (minted id, `status: draft`, `confidence: unknown`, flagged citation); (c) SKIP a strategy-only item → "No change needed — out of llm-wiki domain (→ Notion)". Use `rg`/`Read`/`Edit`/`Write` in `<your_actions>`, never MCP verbs.
- `<output_format>`: header `## Documentation Update: Wiki (llm-wiki)`; same table columns + `**Totals:**` line; Action enum unchanged (`Created, Updated, No change needed, FAILED`); add a "wiki not checked (LLM_WIKI_ROOT absent)" single-row variant.

- [ ] **Step 6: Append the validator gate to the run (spec §4.8)**

The agent, after writing, runs (copied from AGENTS.md at runtime; do not hardcode versions):

```bash
(cd "$LLM_WIKI_ROOT" && uvx --from 'git+https://github.com/L3DigitalNet/project-standards@v2.0.0' validate-frontmatter --config .project-standards.yml \
  && uv run python -m llm_wiki_tools.lint.resolve_links \
  && uv run python -m llm_wiki_tools.lint.frontmatter_ids check)
```

Plus Prettier + markdownlint for changed `md` (never reformat `raw/`/`capture/`/`.claude/`). If the gate fails, report failure — never claim clean.

- [ ] **Step 7: Verify no MCP residue + required elements (acceptance)**

Run: `rg -n -i 'mcp-outline|outline|read_document|create_document|update_document|search_documents' plugins/up-docs/agents/up-docs-propagate-wiki.md`
Expected: **no matches.**
Run (per-pattern, so a single hit can't mask a miss — CR-005):

```bash
F=plugins/up-docs/agents/up-docs-propagate-wiki.md
for p in 'model: sonnet' 'Edit, Write' 'frontmatter_ids mint --title' 'LLM_WIKI_ROOT' 'Wiki (llm-wiki)'; do
  rg -qF "$p" "$F" || { echo "MISSING: $p"; exit 1; }
done; echo "all required elements present"
```

Expected: `all required elements present` (each literal found; exits non-zero naming the first missing one).

- [ ] **Step 8: Confirm no bats regression + commit**

Run: `bash plugins/up-docs/tests/run-bats.sh`
Expected: all PASS (this file isn't asserted, so this confirms no collateral breakage).

```bash
git add plugins/up-docs/agents/up-docs-propagate-wiki.md
git commit -m "feat(up-docs): rewrite propagate-wiki for llm-wiki filesystem backend (Sonnet)"
```

---

## Task 2: Rewrite `up-docs-audit-drift` wiki phase

**Files:**
- Modify: `plugins/up-docs/agents/up-docs-audit-drift.md`
- Test: `plugins/up-docs/tests/test_validate_output.py`, `plugins/up-docs/tests/test_verify_evidence_grounded.py` (must stay green — schema unchanged)

- [ ] **Step 1: Edit the frontmatter `tools:` line**

Replace the six `mcp-outline` read verbs; keep the Notion verbs. New `tools:`:

```yaml
tools: Read, Glob, Grep, Bash, WebFetch, mcp__plugin_Notion_notion__notion-search, mcp__plugin_Notion_notion__notion-fetch
```

Leave `model: sonnet` unchanged.

- [ ] **Step 2: Retarget the wiki layer in `<role>`/`<task>`**

Everywhere the prompt says "Outline" for the wiki layer, say "llm-wiki". In `<task>` step 2's Wiki bullet, replace `search_documents`/`read_document` with: "Wiki: `rg` over `$LLM_WIKI_ROOT/wiki/` for each extracted term; `Read` candidate pages fully (absolute paths; run any Bash as `(cd "$LLM_WIKI_ROOT" && …)`)." Resolve `LLM_WIKI_ROOT` with the same default + graceful-skip note ("wiki not checked — LLM_WIKI_ROOT absent") as Task 1.

- [ ] **Step 3: Add llm-wiki-native wiki drift checks (spec §6)**

In the wiki phase, instruct the auditor to run llm-wiki's **full** validator gate (all three, per design §6 + AGENTS.md — CR-004) as live-state verification and emit `layer: "wiki"` findings for failures:

```bash
(cd "$LLM_WIKI_ROOT" \
  && uvx --from 'git+https://github.com/L3DigitalNet/project-standards@v2.0.0' validate-frontmatter --config .project-standards.yml; \
  uv run python -m llm_wiki_tools.lint.resolve_links; \
  uv run python -m llm_wiki_tools.lint.frontmatter_ids check)
```

A failed `validate-frontmatter` (bad `status`/`doc_type`/schema drift), a broken path-link (`resolve_links`), or a malformed id (`frontmatter_ids check`) is a high-confidence `wiki` finding — capture each validator's literal failing line as the `expected_output_signature` (per the existing structured-evidence schema). Also flag a `status: draft` page treated as authoritative. All three are read-only and fit the allowed-verbs list. Keep `<verification_discipline>`, `<forbidden_commands>`, escalation thresholds, and the `layer` enum (`repo|wiki|notion|layout`) **unchanged**.

- [ ] **Step 4: De-Outline the examples**

In `<examples>`, change wiki-layer example actions from `search_documents`/`read_document` to `rg`/`Read` over `$LLM_WIKI_ROOT/wiki/`. Homelab-citing examples stay (in-scope per SA-001); only the read mechanism + "wiki = llm-wiki" framing change. Leave the repo/notion/layout examples alone.

- [ ] **Step 5: Verify no MCP residue + acceptance**

Run: `rg -n -i 'mcp-outline|read_document|search_documents|get_collection_structure|get_document_backlinks|get_document_id_from_title' plugins/up-docs/agents/up-docs-audit-drift.md`
Expected: **no matches.**
Run (per-pattern — CR-005):

```bash
F=plugins/up-docs/agents/up-docs-audit-drift.md
for p in 'notion-search' 'notion-fetch' 'LLM_WIKI_ROOT' 'resolve_links' 'validate-frontmatter' 'frontmatter_ids check'; do
  rg -qF "$p" "$F" || { echo "MISSING: $p"; exit 1; }
done; echo "all required elements present"
```

Expected: `all required elements present` (Notion retained; wiki retargeted with the full validator set).

- [ ] **Step 6: Run pytest + bats, then commit**

Run: `cd plugins/up-docs/tests && (.venv/bin/python -m pytest -q 2>/dev/null || python3 -m pytest -q); cd -`
Expected: PASS (schema untouched).
Run: `bash plugins/up-docs/tests/run-bats.sh`
Expected: PASS.

```bash
git add plugins/up-docs/agents/up-docs-audit-drift.md
git commit -m "feat(up-docs): retarget audit-drift wiki phase to llm-wiki + validator-backed drift checks"
```

---

## Task 3: Minor agents — naming only (preserve bats-guarded strings)

**Files:**
- Modify: `plugins/up-docs/agents/up-docs-propagate-repo.md`, `plugins/up-docs/agents/up-docs-propagate-notion.md`
- Guarded by: `prompt-conformance.bats` (propagate-repo)

- [ ] **Step 1: propagate-repo — retarget the two Outline references**

Edit line ~212 `- Implementation depth beyond what a local contributor needs (→ Outline wiki)` → `(→ llm-wiki)`. Edit the example item (~lines 351–356): `New Outline wiki page created` → `New llm-wiki page created`; `Affected area: Outline wiki` → `Affected area: llm-wiki`; `Verifiable against: Outline search` → `Verifiable against: rg over ~/projects/llm-wiki/wiki/`.
**Do NOT touch** these bats-asserted strings: `Full conventions reference:`, `Detailed review workflows:`, `## Cause`, `## Fix`, `## Lesson`, `retired V1/V2 layout-detection`, `retired handoff-version label`.

- [ ] **Step 2: propagate-notion — retarget the Notion↔wiki boundary**

Replace "Outline" with "llm-wiki" in the boundary prose + example pointers (grep lines 97, 116, 119–120, 147–148, 151, 153, 169, 172, 252). Keep the homelab examples (domain-correct). Example: line 119–120 "Boundary with Outline:" → "Boundary with llm-wiki:" and "Outline says …/links to Outline" → "llm-wiki says …/links to llm-wiki". Line 148/151/153/172/252 "see Outline"/"linked to Outline" → "see llm-wiki"/"linked to llm-wiki".

- [ ] **Step 3: Acceptance + bats + commit**

Run: `rg -n -i 'outline' plugins/up-docs/agents/up-docs-propagate-repo.md plugins/up-docs/agents/up-docs-propagate-notion.md`
Expected: **no matches.**
Run: `bash plugins/up-docs/tests/run-bats.sh`
Expected: PASS (propagate-repo guards intact).

```bash
git add plugins/up-docs/agents/up-docs-propagate-repo.md plugins/up-docs/agents/up-docs-propagate-notion.md
git commit -m "docs(up-docs): retarget propagate-repo/notion Outline references to llm-wiki"
```

---

## Task 4: Skills — wiki, all, drift

**Files:** `plugins/up-docs/skills/wiki/SKILL.md`, `plugins/up-docs/skills/all/SKILL.md`, `plugins/up-docs/skills/drift/SKILL.md`

- [ ] **Step 1: skills/wiki/SKILL.md**

Frontmatter `description:` (line 3) → "Update the llm-wiki knowledge base (~/projects/llm-wiki) with implementation-level details from the current session by dispatching the up-docs-propagate-wiki sub-agent. This skill should be used when the user runs /up-docs:wiki." Body: title/line 8–10 "Outline wiki via the `up-docs-propagate-wiki` sub-agent (Haiku)" → "llm-wiki via … sub-agent (**Sonnet**)". Line ~35 "single-layer 'Wiki (Outline)' format" → "(llm-wiki)". Drop any "no longer reads pages…" Outline-specific note or retarget to llm-wiki.

- [ ] **Step 2: skills/all/SKILL.md**

Line 10 (CR-001): `dispatch three propagator sub-agents in parallel (Haiku), then run the drift auditor (Sonnet)` → `dispatch three propagator sub-agents in parallel — repo + Notion on Haiku, wiki on Sonnet — then run the drift auditor (Sonnet)`. Line 21 dispatch tree: `up-docs-propagate-wiki     (Haiku, parallel)` → `(Sonnet, parallel)` (leave lines 20/22 repo/notion Haiku). Line 73 table cell `Updates Outline pages at implementation-reference level` → `Updates llm-wiki wiki/ pages at implementation-reference level`.

- [ ] **Step 3: skills/drift/SKILL.md**

Line 12 "scope the analysis to that Outline collection … analyze all collections" → "scope to that llm-wiki `wiki/` subtree or tag … otherwise analyze the whole `wiki/`". Line 68 "no write tools for Outline or Notion" → "no write tools for llm-wiki or Notion". Line 58 "fixes them at Haiku cost" → "fixes them at propagator cost (wiki on Sonnet, repo/notion on Haiku)".

- [ ] **Step 4: Acceptance + commit**

Run: `rg -n -i 'outline' plugins/up-docs/skills`
Expected: **no matches.**

```bash
git add plugins/up-docs/skills
git commit -m "docs(up-docs): retarget skills (wiki/all/drift) to llm-wiki + wiki=Sonnet"
```

---

## Task 5: Templates

**Files:** `plugins/up-docs/templates/summary-report.md`, `plugins/up-docs/templates/drift-finding.md`

- [ ] **Step 1: summary-report.md**

Line ~47 `### Wiki (Outline)` → `### Wiki (llm-wiki)`. Any other "Outline" → "llm-wiki".

- [ ] **Step 2: drift-finding.md (KEEP `"layout"`)**

Line ~14 `"page_id": "<Outline/Notion page ID, or null for repo>"` → `"page_id": "<wiki page path or Notion page id; null for repo>"`. Line ~46 `Human-readable page title (Outline, Notion) or file path (repo).` → `… (llm-wiki path, Notion title) or file path (repo).` **Do NOT remove the literal `"layout"`** (asserted by `prompt-conformance.bats`).

- [ ] **Step 3: session-change-summary.md model wording (CR-001)**

Line 5 `… the Haiku propagators will miss changes or over-edit.` → `… the propagators will miss changes or over-edit.` (drop the now-inaccurate "Haiku" — repo/Notion are Haiku but wiki is Sonnet, so generic "the propagators" is correct).

- [ ] **Step 4: Acceptance + bats + commit**

Run: `rg -n -i 'outline' plugins/up-docs/templates; rg -n '"layout"' plugins/up-docs/templates/drift-finding.md; rg -n 'Haiku propagators' plugins/up-docs/templates/session-change-summary.md`
Expected: first **no matches**; second **matches** (layout enum preserved); third **no matches** (stale "Haiku propagators" gone).
Run: `bash plugins/up-docs/tests/run-bats.sh`
Expected: PASS (the layout-enum test stays green).

```bash
git add plugins/up-docs/templates
git commit -m "docs(up-docs): retarget templates to llm-wiki + drop stale Haiku-propagator wording"
```

---

## Task 6: Plugin README — prose, prerequisites, model-surface inventory

**Files:** `plugins/up-docs/README.md`

- [ ] **Step 1: Layer prose + principles**

Lines 3, 7, 11, 17: replace "Outline wiki"/"Outline" with "llm-wiki". Line 7 "Haiku for propagation … Sonnet for drift detection" → "Haiku for the repo/Notion propagators and Sonnet for the wiki propagator and drift detection". Lines 147/171 command/mapping: `Update Outline wiki only` → `Update llm-wiki only`; the CLAUDE.md `## Documentation` mapping example `Outline: "Homelab" collection` → `llm-wiki: wiki/ paths (e.g. wiki/systems/, wiki/services/)`.

- [ ] **Step 2: Prerequisites rewrite (capability upgrade)**

Replace the prereq lines (≈23, 205, 207) that say "Outline wiki accessible via MCP (mcp-outline server configured)" / "Requires both Outline and Notion MCP servers" / "Air-gapped systems can only use `/up-docs:repo`" with: the wiki layer requires the local `~/projects/llm-wiki` repo present + `uv`/`uvx` (no MCP). Only the Notion layer needs network; the repo and wiki layers' read/write work offline (the pinned `validate-frontmatter` tool fetches from git on first use, cached after). Roadmap line ~201 "without pushing to Outline or Notion" → "without pushing to llm-wiki or Notion".

- [ ] **Step 3: Model-surface inventory (SA-003) — wiki propagator → Sonnet only**

Mermaid line 108 `Wiki[up-docs-propagate-wiki<br/>Haiku]` → `…<br/>Sonnet`. Agent table line 193 `| up-docs-propagate-wiki | Haiku | Mechanical edits to Outline pages …|` → `| up-docs-propagate-wiki | Sonnet | Edits/creates llm-wiki wiki/ pages at implementation-reference level |`. Line 121 generic node `Single propagator sub-agent<br/>Haiku` → add "(wiki on Sonnet)" or split. Line 197 cost note "propagation runs on Haiku (≈ 1/10 Opus cost)" → "repo/Notion propagation runs on Haiku; the wiki propagator runs on Sonnet". **Leave lines 107/109 (`propagate-repo`/`propagate-notion` Haiku) unchanged.**

- [ ] **Step 4: Acceptance + commit**

Run: `rg -n -i 'outline' plugins/up-docs/README.md; rg -n 'propagate-wiki.*Haiku|Outline' plugins/up-docs/README.md`
Expected: **no matches** for either.

```bash
git add plugins/up-docs/README.md
git commit -m "docs(up-docs): README — llm-wiki prose/prereqs + wiki-propagator Sonnet"
```

---

## Task 7: Root README + handoff deployed.md

**Files:** `README.md` (root), `docs/handoff/deployed.md`

- [ ] **Step 1: Root README up-docs surfaces**

Line 57 `… (Haiku propagators + Sonnet drift auditor) …` → `… (Haiku repo/Notion propagators + Sonnet wiki propagator & drift auditor) …`; same line "three layers" wording stays. Line 267 "updates repo docs, Outline wiki, and Notion" → "… llm-wiki, and Notion". Line 271 "three Haiku propagators (repo, wiki, notion)" → "two Haiku propagators (repo, notion) + one Sonnet (wiki)". Line 273 "syncs the Outline wiki" → "syncs llm-wiki".

- [ ] **Step 2: deployed.md up-docs row**

Update the up-docs entry: version → `0.10.0`; description "Outline wiki" → "llm-wiki"; note the Outline→llm-wiki backend swap. Mark released/pending per the file's deployed-truth convention (this lands as a tagged release via `/release-pipeline:release` later, so flag accordingly).

- [ ] **Step 3: Acceptance + commit**

Run: `rg -n -i 'outline' README.md docs/handoff/deployed.md`
Expected: **no matches.**

```bash
git add README.md docs/handoff/deployed.md
git commit -m "docs: retarget root README + deployed.md up-docs entry to llm-wiki (0.10.0)"
```

---

## Task 8: Manifests + marketplace + CHANGELOG (version moves together)

**Files:** `plugins/up-docs/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `plugins/up-docs/CHANGELOG.md`
**Guarded by:** `manifest.bats`, `scripts/validate-marketplace.sh`

- [ ] **Step 1: plugin.json**

Set `"version": "0.10.0"`. Set `"description"` to: `Update documentation across three layers (repo, llm-wiki, Notion) via sub-agent propagation (Haiku repo/Notion + Sonnet wiki) plus drift audit (Sonnet). Five commands for targeted updates and comprehensive drift analysis with four-phase convergence.` (Only `name, version, description, author, homepage` keys — Zod allow-list.)

- [ ] **Step 2: marketplace.json up-docs entry (must match)**

In the up-docs object (line ~88): set `"version": "0.10.0"` and the **identical** description string from Step 1. Leave `source`, `author`, `homepage` unchanged.

- [ ] **Step 3: CHANGELOG.md — new entry (history preserved)**

Prepend a `## [0.10.0] - 2026-06-07` block (Keep a Changelog format). Changed: wiki layer retargeted from the retired Outline MCP server to local `~/projects/llm-wiki` (filesystem writes under the llm-wiki contract); `propagate-wiki` model Haiku → Sonnet. Added: validator-backed wiki drift checks in the auditor (`resolve_links`/`frontmatter_ids`); offline wiki read/write (only Notion needs network). Do not alter the historical 213/222 entries.

- [ ] **Step 4: Version-match + validator + manifest bats**

Run: `jq -r '.version' plugins/up-docs/.claude-plugin/plugin.json; jq -r '.plugins[] | select(.name=="up-docs") | .version' .claude-plugin/marketplace.json`
Expected: both print `0.10.0` (identical).
Run: `./scripts/validate-marketplace.sh && bash plugins/up-docs/tests/run-bats.sh`
Expected: both PASS (no version-mismatch error; Zod allow-list intact).

- [ ] **Step 5: Commit**

```bash
git add plugins/up-docs/.claude-plugin/plugin.json .claude-plugin/marketplace.json plugins/up-docs/CHANGELOG.md
git commit -m "chore(up-docs): bump to 0.10.0 — llm-wiki backend (manifest + marketplace + changelog)"
```

---

## Task 9: Full acceptance gate (spec §10) + handoff close

**Files:** none (verification), then `docs/handoff/specs-plans.md` + `docs/plans/2026-06-07-up-docs-llm-wiki-migration-plan.md` status

- [ ] **Step 1: Outline retired from runtime surface (CHANGELOG excluded — CR-003)**

Run: `rg -i 'outline' plugins/up-docs .claude-plugin/marketplace.json README.md docs/handoff/deployed.md -g '!CHANGELOG.md'`
Expected: **no matches.** CHANGELOG.md is a release-note surface (not runtime): it legitimately names "Outline" in both the historical 213/222 entries **and** the new 0.10.0 entry describing the retirement, so it is excluded from this sweep.
Run (changelog sanity): `rg -c -i 'outline' plugins/up-docs/CHANGELOG.md`
Expected: a small count (historical entries + the new release-note line) — all legitimate; no other file matched Step 1's sweep.

- [ ] **Step 2: No mcp-outline tool anywhere**

Run: `rg -n 'mcp-outline|mcp__plugin_mcp-outline' plugins/up-docs`
Expected: **no matches.**

- [ ] **Step 3: Model tiers correct**

Run: `rg -n '^model:' plugins/up-docs/agents/up-docs-propagate-wiki.md plugins/up-docs/agents/up-docs-propagate-repo.md plugins/up-docs/agents/up-docs-propagate-notion.md`
Expected: propagate-wiki `sonnet`; propagate-repo + propagate-notion `haiku`.
Run (per-pattern absence, CHANGELOG excluded — CR-001/CR-005):

```bash
for p in 'Haiku propagators' 'propagate-wiki.*Haiku' 'three Haiku' 'all Haiku' 'three propagator sub-agents in parallel \(Haiku\)' 'Single propagator.*Haiku'; do
  hits=$(rg -n "$p" README.md plugins/up-docs -g '!CHANGELOG.md' || true)
  [ -z "$hits" ] || { echo "STALE ($p): $hits"; exit 1; }
done; echo "no stale Haiku model surfaces"
```

Expected: `no stale Haiku model surfaces` (SA-003/CR-001 clean — these patterns target the wiki propagator + collective framing; the standalone repo/Notion "(Haiku)" mentions are correct and intentionally not matched).

- [ ] **Step 4: Full suites green**

Run: `bash plugins/up-docs/tests/run-bats.sh`
Expected: ALL PASS.
Run: `cd plugins/up-docs/tests && (.venv/bin/python -m pytest -q 2>/dev/null || python3 -m pytest -q); cd -`
Expected: ALL PASS.
Run: `./scripts/validate-marketplace.sh`
Expected: PASS.

- [ ] **Step 5: Update the plan + index status, commit**

Mark this plan's status "Done — shipped up-docs 0.10.0 (pending tag)". Update the `docs/handoff/specs-plans.md` plan row likewise. If implementation materially changed session state, add a `docs/handoff/sessions/2026-06.md` row and refresh `docs/handoff/state.md` per the handoff ritual (CR-001 non-blocking).

```bash
git add docs/plans/2026-06-07-up-docs-llm-wiki-migration-plan.md docs/handoff/specs-plans.md docs/handoff/sessions/2026-06.md docs/handoff/state.md
git commit -m "docs(up-docs): mark llm-wiki migration plan complete + session handoff"
```

- [ ] **Step 6: Release (separate, user-initiated)**

The tagged release (`up-docs/v0.10.0` + GitHub release) is **not** part of this plan — run `/release-pipeline:release` afterward when ready. Note it in the session handoff.

---

## Out-of-repo follow-ups (NOT in this plan — flag in handoff)

Per spec §11: `~/.claude/CLAUDE.md` Source-of-Truth table ("Implementation reference → Outline wiki") and the "Before Any Infrastructure Work" step 3 ("Search and read Outline wiki FIRST") still name the retired system → should point at llm-wiki. These live outside this repo; surface them to the user, do not edit here.

---

## Plan audit ledger (Codex `$plan-review`, adversarial)

Read-only adversarial audits via `codex exec` (gpt-5.5, xhigh, `-s read-only`) against this plan. Raw output: `/tmp/codex-planreview/`. (Companion to the spec's `SA-*` ledger; this namespace is `CR-*`.)

### Round 1 — verdict: Needs major correction before execution (3 blocking, 2 non-blocking)

| ID | Sev | Title | Disposition |
| --- | --- | --- | --- |
| CR-001 | High | Model-tier cleanup omits `session-change-summary.md:5` + `skills/all/SKILL.md:10` | **Resolved** — added to File Structure + Task 5 Step 3 + Task 4 Step 2; Task 9 Step 3 adds the broad-prose absence check |
| CR-002 | High | `frontmatter_ids mint` missing required `--title` | **Resolved** — Task 1 Step 4 + acceptance now use `mint --title "<page title>"` (verified `[required]` in source + C-11) |
| CR-003 | High | Final Outline sweep contradicts the new CHANGELOG entry | **Resolved** — Task 9 Step 1 excludes `CHANGELOG.md` (`-g '!CHANGELOG.md'`) + separate changelog sanity check |
| CR-004 | Med | audit-drift validator set omits `validate-frontmatter` | **Resolved** — Task 2 Step 3 runs the full three-validator gate |
| CR-005 | Med | Alternation `rg` "each matches" can pass on one hit | **Resolved** — Task 1 Step 7 + Task 2 Step 5 + Task 9 Step 3 use per-pattern loops |
| nit | Low | Task 0 `/tmp` tee not literally "Files: none"; add session-handoff row | **Resolved** — Task 0 Step 5 notes the scratch artifact; Task 9 Step 5 adds the sessions/state handoff |

### Round 2 — verdict: No significant findings remain (loop stopped)

Follow-up audit (`codex exec resume`, same session) re-read rev 2 at commit `fac5d49` and retested every prior finding: CR-001..005 + the nit all **Resolved**, **0 regressions**. One new Low surfaced — **CR-NEW-001** (Task 9's stale-Haiku loop didn't include the `Single propagator…Haiku` README node; the edit itself was already covered by Task 6 Step 3). Marked optional by Codex; **applied anyway** (added `'Single propagator.*Haiku'` to the Task 9 Step 3 loop) so the gate is fully adversarial. Codex: _"the audit/fix loop can stop."_ Plan converged — ready for execution.

## Self-Review (writing-plans)

- **Spec coverage:** §3 scope → Tasks 1–8 (every in-scope file has a task; `session-change-summary.md` added per CR-001); §4 contract → Task 1 Steps 3–6 + Task 2 Step 3; §5 propagate-wiki → Task 1; §6 audit-drift → Task 2; §7 minor agents → Task 3; §8 skills/templates → Tasks 4–5; §9 README/manifest/marketplace/CHANGELOG/repo-docs → Tasks 6–8; §10 acceptance → Task 9; §11 follow-ups → final section. SA-001 (homelab in-scope) → Task 1 Steps 3/5; SA-002 (marketplace) → Task 8; SA-003 (model surfaces) → Tasks 4/5/6/7/8 + Task 9 Step 3; SA-004 (cwd) → Task 1 Step 4 + Task 2 Steps 2–3. No gaps.
- **Placeholder scan:** exact paths, commands, and frontmatter blocks given; the two prose rewrites specify exact frontmatter + block-by-block required content + concrete examples/commands (authored from the converged spec contract, not invented). No "TBD"/"add error handling"/"similar to Task N".
- **Type/string consistency:** `LLM_WIKI_ROOT` default, the three validator commands, `frontmatter_ids mint`/`check`, the output header `## Documentation Update: Wiki (llm-wiki)`, version `0.10.0`, and the identical plugin/marketplace description string are used consistently across tasks. bats-guarded strings (`"layout"`, the propagate-repo six) are explicitly preserved in Tasks 3/5.

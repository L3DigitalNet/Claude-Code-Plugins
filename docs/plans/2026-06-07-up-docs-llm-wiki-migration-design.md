# up-docs — Outline → llm-wiki Migration (Design)

**Date:** 2026-06-07
**Status:** Draft (rev 2) — round-1 Codex `$spec-review` applied (SA-001..004 + nits); awaiting round-2 re-audit
**Target version:** up-docs `0.9.1` → `0.10.0`
**Topic owner:** documentation-propagation plugin (`plugins/up-docs/`)

## 1. Context & problem

The Outline wiki is retired and replaced by **llm-wiki** — the user's local, git-backed
Markdown knowledge base at `~/projects/llm-wiki` (skill: `llm-wiki`). The `up-docs` plugin's
**wiki layer** is currently bound to Outline through MCP:

- `agents/up-docs-propagate-wiki.md` (Haiku) calls six `mcp-outline` verbs
  (`search_documents`, `read_document`, `update_document`, `create_document`,
  `list_collections`, `get_collection_structure`).
- `agents/up-docs-audit-drift.md` (Sonnet) calls six `mcp-outline` read verbs
  (`…__search_documents`, `…__read_document`, `…__list_collections`,
  `…__get_collection_structure`, `…__get_document_backlinks`,
  `…__get_document_id_from_title`).

The two integration shapes are **opposite**, so this is not a tool-name swap:

| | Outline (old) | llm-wiki (new) |
| --- | --- | --- |
| Transport | MCP verbs over a network server | Local files in a git repo |
| Read | `read_document(id)` | `rg` / `grep` / `Read` over `~/projects/llm-wiki/wiki/` |
| Write | `update_document` / `create_document` | `Edit` (existing) / `Write` (new) |
| Governance | none enforced by the tool | strict layer model (`raw/`,`wiki/`,`capture/`), frontmatter v1.1, path-links, `## Source` citations, validators, **draft→active promotion gate agents may not self-cross** |
| Prereq | `mcp-outline` MCP server configured + reachable | local `~/projects/llm-wiki` repo present + `uv`/`uvx`; **no MCP.** Read/write + repo-local validators are offline; the pinned `validate-frontmatter` tool is fetched from git on first use (cached after) |

**No up-docs MCP server definition lives in this repo.** up-docs has no `.mcp.json` (other plugins
— `home-assistant-dev`, `plugin-test-harness`, `qt-suite` — do); `mcp-outline` is a globally-defined
server, so the migration is entirely prompt / tool-list / doc surface.

## 2. Locked decisions (from brainstorming Q&A, 2026-06-07)

| # | Decision | Choice |
| --- | --- | --- |
| D1 | What the wiki layer DOES now | **Write `status: draft` pages directly into `~/projects/llm-wiki/wiki/`** — respecting the full llm-wiki contract; never self-promote. |
| D2 | Homelab infra docs | **llm-wiki owns homelab implementation-reference.** Homelab reference pages are in-scope propagation targets (ADR-0009; `homelab-wiki` skill retired; `wiki/systems/homelab-overview.md` + `wiki/services/monitoring.md` are `status: active`). _Revised from the original "homelab elsewhere" after round-1 Codex SA-001 + user confirmation — see §13._ |
| D3 | Blast radius | **up-docs plugin + this repo's live handoff docs + root README.** Historical `docs/plans/*` + `docs/research/*` untouched; global `~/.claude` files flagged as out-of-repo follow-ups. |
| D4 | Rule grounding | **Read canonical at runtime.** The rewritten propagator `Read`s `~/projects/llm-wiki/AGENTS.md` + `docs/handoff/conventions.md` (C-1..C-12) + the frontmatter schema each run — the llm-wiki repo's own docs are authoritative. No rule duplication in the prompt. |
| D5 | Version | **Minor → `0.10.0`** (unchanged command surface; one layer's backend replaced). |
| D6 | Process | Full **spec → plan → implement** with user review gates. |

## 3. Scope

**In scope (rewrite/edit):**

- `plugins/up-docs/agents/up-docs-propagate-wiki.md` — full rewrite (§5)
- `plugins/up-docs/agents/up-docs-audit-drift.md` — wiki-phase rewrite (§6)
- `plugins/up-docs/agents/up-docs-propagate-notion.md` — Outline→wiki naming only
- `plugins/up-docs/agents/up-docs-propagate-repo.md` — Outline→wiki naming only
- `plugins/up-docs/skills/{wiki,all,drift}/SKILL.md`
- `plugins/up-docs/templates/{summary-report.md,drift-finding.md}`
- `plugins/up-docs/README.md`, `plugins/up-docs/.claude-plugin/plugin.json`, `plugins/up-docs/CHANGELOG.md`
- `.claude-plugin/marketplace.json` — root marketplace up-docs entry; version + description must match `plugin.json` (SA-002)
- `plugins/up-docs/tests/*` — only where a structural assertion needs updating (verify in plan)
- Repo: root `README.md`; `docs/handoff/deployed.md` (version + description)

**Out of scope (this change):**

- Historical `docs/plans/*` and `docs/research/*` — dated point-in-time records.
- `CHANGELOG.md` lines 213/222 — historical entries kept verbatim; a NEW entry is added.
- The notion/repo agents' homelab _examples_ — they stay; only their Outline→wiki _naming_ changes.
  (Homelab is now in-scope, so the examples are domain-correct as written.)
- Global `~/.claude/CLAUDE.md` Source-of-Truth table + "infra work" step 3 — see §11 follow-up.

## 4. The new wiki-layer contract (applies to both agents)

The rewritten agents must honor the llm-wiki governance model. The **authoritative** source is
`~/projects/llm-wiki/AGENTS.md` + `docs/handoff/conventions.md` (rules C-1..C-12), read at
runtime (D4). Summarized here for design intent only — on any conflict the repo doc wins:

1. **Path, cwd & override (SA-004).** Root = `${LLM_WIKI_ROOT:-$HOME/projects/llm-wiki}`. Every
   llm-wiki Bash command (searches + validators) MUST run as `(cd "$LLM_WIKI_ROOT" && …)` — the gate
   uses repo-relative paths (`.project-standards.yml`, `uv run -m llm_wiki_tools…`) and silently
   validates the wrong tree if run from the caller's project. Every Read/Edit/Write targets an
   absolute path under that root. If the root is absent, the agent reports cleanly (one-row table /
   "wiki not checked" note) and exits its layer — it never fails the whole run. Mirrors the existing
   "validator absent" graceful-skip pattern in audit-drift.
2. **Layers never blur (C-2).** Writes go to `wiki/` only. `raw/` is immutable evidence (C-4);
   `capture/` is staging and is never cited (ADR-0007).
3. **Session changes are operator testimony, not external evidence.** Per the llm-wiki `†` rule:
   a session-change fact has no external `raw/` source, so the propagator does **not** fabricate a
   `raw/` file. It records the claim in the `wiki/` page as operator-asserted, sets
   `confidence: 'unknown'`, keeps the page `draft`, and flags the missing citation. (Promotion to
   `active` later requires a real cited source + operator review — out of the propagator's hands.)
4. **Frontmatter v1.1.** New pages start `status: 'draft'`, carry the `wiki` tag, and get an
   `id` of the form `llm-wiki-<base36-6>-<slug>` **minted with llm-wiki's id tool** (the command in
   AGENTS.md), never hand-authored. Field set / key order / controlled values come from the
   `markdown-frontmatter` skill + `docs/schemas/`. On edit: preserve `id`/`created`, bump `updated`
   only for a meaningful change.
5. **Path links, never `[[wikilinks]]` (C-5).** Frontmatter relations: no-slash + `.md`
   (`'wiki/systems/nginx.md'`). Body links: leading-slash Markdown (`[Nginx](/wiki/systems/nginx.md)`).
6. **Smallest coherent change (C-1/6/7).** No unsolicited tooling, folders, or fields; prefer
   `git mv`; search before creating; flag contradictions instead of smoothing them.
7. **No secrets** — credential references only (env var names, OpenBao paths), never values.
8. **Validate before claiming clean.** Run the gate block **copied from `~/projects/llm-wiki/AGENTS.md`
   at runtime** — that block is authoritative over any schema/convention text that disagrees on a
   validator version (do not hardcode versions; AGENTS.md is the single source). As of this writing:

   ```bash
   uvx --from 'git+https://github.com/L3DigitalNet/project-standards@v2.0.0' validate-frontmatter --config .project-standards.yml
   uv run python -m llm_wiki_tools.lint.resolve_links
   uv run python -m llm_wiki_tools.lint.frontmatter_ids check
   ```

   Plus Prettier + markdownlint for changed `md`/`json`/`yaml`. **Never reformat `raw/`,
   `capture/`, or `.claude/`.** If the gate fails, report the failure — never claim clean.

## 5. `up-docs-propagate-wiki` — full rewrite

| Aspect | Before | After |
| --- | --- | --- |
| `tools:` | `Read, Glob, Grep, Bash` + 6 `mcp-outline` verbs | `Read, Glob, Grep, Bash, Edit, Write` |
| `model:` | `haiku` | **`sonnet`** |
| Find targets | `search_documents` / `get_collection_structure` | `rg`/`grep` over `wiki/` titles, aliases, tags, `related` |
| Read | `read_document` | `Read` |
| Write existing | `update_document` | `Edit` (smallest coherent change; bump `updated`) |
| Create new | `create_document` | `Write` (draft page per §4.3–4.4) |
| Pre-flight | — | `Read` AGENTS.md + conventions + frontmatter schema (D4); locate `LLM_WIKI_ROOT` or graceful-skip |
| Post-flight | retry-once / FAILED row | retry-once / FAILED row **+ run validator gate (§4.8)** |
| Domain filter | (none) | Skip only: strategy (→ Notion), live operational facts (→ system-of-record), and homelab **execution-state** (→ the homelab repo's own `README`/`docs/handoff`). **Homelab implementation-reference is in-scope** (SA-001). Report skips as "No change needed — out of llm-wiki domain" |
| Examples | homelab (OpenBao CT 111, Kismet CT 105, AIDE GMK) | refreshed to the llm-wiki taxonomy, **homelab reference retained** (now in-scope) alongside a non-homelab case (e.g. a repo's build procedure) — include ≥1 explicit "update" and ≥1 explicit "skip" example (SA-001) |
| `<layer_boundary>` | "Outline implementer's shelf" | llm-wiki `wiki/` synthesized implementation-reference (**incl. homelab infra**); explicit exclusions: strategy (→ Notion), live facts (→ system-of-record), execution-state (→ repo docs) |
| Output | `## Documentation Update: Wiki (Outline)` | `## Documentation Update: Wiki (llm-wiki)` |

**Behavior note (honest reporting):** the propagator still reports "No change needed" plainly when an
item is genuinely out of domain (strategy / live fact / execution-state) rather than inventing a page
— the same anti-fabrication discipline the drift auditor enforces. But homelab
implementation-reference now DOES produce real wiki updates (SA-001), so this user's infra sessions
are expected to land llm-wiki edits, not routinely no-op.

**Preserved structure** (so `prompt-conformance.bats` stays green): keep the `<role>`, `<task>`,
`<layer_boundary>`, `<guardrails>`, `<examples>`, `<output_format>` blocks and the leading routing
comment. Only contents change.

## 6. `up-docs-audit-drift` — targeted rewrite

- `tools:` — drop the 6 `mcp-outline` read verbs; keep `Read, Glob, Grep, Bash, WebFetch` and the
  two Notion verbs (`notion-search`, `notion-fetch`). Wiki reads now via `rg`/`Read` over
  `LLM_WIKI_ROOT`.
- **Wiki phase** reads llm-wiki pages from disk. Add **llm-wiki-native drift checks**: run
  llm-wiki's own validators (`resolve_links`, `frontmatter_ids check`, `validate-frontmatter`) as
  live-state verification, and flag a `draft` page being treated as authoritative. Broken links /
  malformed ids become first-class, machine-checkable `layer: "wiki"` findings — a strengthening,
  not just a port. The step-3b handoff `layout` validator phase is unchanged.
- **Unchanged:** `<verification_discipline>`, `<forbidden_commands>`, escalation thresholds,
  structured-evidence schema (`{command, expected_output_signature, source_tool_use_id?}`), the
  `layer` enum (`repo|wiki|notion|layout` — `"wiki"` now denotes llm-wiki), the `stats` shape.
- Examples: homelab pages are valid llm-wiki targets (SA-001), so homelab-citing examples stay; only
  the read mechanism (disk vs MCP) and the "wiki = llm-wiki" framing change.

## 7. Minor agents — naming only

- `up-docs-propagate-notion.md` — change the Notion↔Outline boundary prose and `→ Outline wiki`
  pointers to llm-wiki / "the wiki." Homelab examples (OpenBao/Kismet) stay — domain-correct.
- `up-docs-propagate-repo.md` — change `(→ Outline wiki)` and the "New Outline wiki page created"
  example item to llm-wiki wording.

## 8. Skills & templates

- `skills/wiki/SKILL.md` — rename "Outline wiki" → "llm-wiki" in body + `description:` frontmatter
  (the `description` is what renders in the slash-command list); update the "single-layer Wiki
  (Outline)" output reference to "(llm-wiki)".
- `skills/all/SKILL.md` — line 73 table cell "Updates Outline pages…" → "Updates llm-wiki pages…".
- `skills/drift/SKILL.md` — lines 12/68: "Outline collection" → llm-wiki scoping (a `wiki/`
  subtree or tag, not a collection id); "no write tools for Outline" → "for llm-wiki".
- `templates/summary-report.md` — `### Wiki (Outline)` → `### Wiki (llm-wiki)`.
- `templates/drift-finding.md` — `page_id` note: "Outline/Notion page ID" → "wiki page path or
  Notion page id; null for repo"; `page` description likewise.

## 9. README, manifest, marketplace, CHANGELOG, repo docs

- `plugins/up-docs/README.md`:
  - Three-layer description + [P1]/[P4] principle text: "Outline" → "llm-wiki".
  - **Prerequisites rewrite (capability upgrade):** wiki layer needs the local `~/projects/llm-wiki`
    repo present + `uv`/`uvx` for validators — **no MCP**. Replace "Requires both Outline and Notion
    MCP servers" + "Air-gapped systems can only use `/up-docs:repo`" with: only Notion needs network;
    repo + wiki read/write work offline (the pinned `validate-frontmatter` tool fetches from git on
    first use, cached after).
  - CLAUDE.md `## Documentation` mapping example → an llm-wiki `wiki/` path mapping (not an Outline
    collection).
  - Roadmap line 201 "without pushing to Outline or Notion" → "llm-wiki or Notion".
- **Model-surface inventory (SA-003) — ONLY `propagate-wiki` changes; `propagate-repo` +
  `propagate-notion` stay Haiku.** The "three Haiku propagators" framing becomes "two Haiku
  (repo, notion) + one Sonnet (wiki)". Surfaces to update (verified via `rg -ni haiku`, excl.
  CHANGELOG):
  - `plugins/up-docs/README.md`: line 7 ("Haiku for propagation" → split tiers), mermaid line 108
    (`propagate-wiki<br/>Haiku` → Sonnet), line 121 (generic "Haiku" propagator node note), agent
    table line 193 (wiki → Sonnet), line 197 (cost-note nuance).
  - root `README.md`: line 57 ("Haiku propagators + Sonnet drift auditor" → "Haiku/Sonnet
    propagators…"), line 271 ("three Haiku propagators (repo, wiki, notion)" → "two Haiku (repo,
    notion) + one Sonnet (wiki)").
  - `skills/wiki/SKILL.md` line 10 ("(Haiku)" → "(Sonnet)"); `skills/all/SKILL.md` line 21 (wiki
    "(Haiku, parallel)" → Sonnet); `skills/drift/SKILL.md` line 58 ("at Haiku cost" nuance).
  - `templates/session-change-summary.md` line 5 ("Haiku propagators" → "the propagators").
- **Manifest + marketplace (SA-002) — both must change together (architecture.md "Updating a
  plugin"):**
  - `plugins/up-docs/.claude-plugin/plugin.json` — `version` → `0.10.0`; `description` "Outline wiki"
    → "llm-wiki" and "(Haiku)" → "(Haiku/Sonnet)".
  - `.claude-plugin/marketplace.json` up-docs entry (line ~88) — matching `version` `0.10.0` +
    identical description edit. `scripts/validate-marketplace.sh` errors on version mismatch.
- `CHANGELOG.md` — new `0.10.0` entry: Outline→llm-wiki backend swap, the wiki-propagator model bump,
  the offline-wiki capability, and the new validator-backed drift checks. Historical entries kept.
- Root `README.md` lines 267/273 — "Outline wiki" → "llm-wiki"; "SSHes into live infrastructure /
  syncs the Outline wiki" reworded for the llm-wiki phase.
- `docs/handoff/deployed.md` — up-docs version (→ 0.10.0) + description; mark released/pending per
  the deployed-truth convention.

## 10. Tests & verification

`tests/` contains **no** "Outline"/"mcp-outline" string, so assertions are structural. Plan must:

1. Inventory `prompt-conformance.bats` + `manifest.bats` assertions; confirm the rewrites preserve
   every asserted block/tool-presence. Update assertions only if one now checks for a dropped
   `mcp-outline` tool or an Outline-specific string (none found so far).
2. `validate_output.py` / `verify_evidence_grounded.py` — schema unchanged (`layer` enum keeps
   `wiki`); confirm green.
3. Run gates: `bash tests/run-bats.sh` + pytest; `scripts/validate-marketplace.sh` (plugin.json +
   marketplace.json fields valid + version match per marketplace strict-Zod rules).

**Acceptance criteria:**

- `rg -i 'outline' plugins/up-docs .claude-plugin/marketplace.json README.md` returns only
  `CHANGELOG.md` historical lines.
- No agent `tools:` line contains `mcp-outline`.
- `propagate-wiki` model is `sonnet`; tool list adds `Edit, Write`, drops all MCP verbs;
  `propagate-repo` + `propagate-notion` remain `haiku`.
- `jq` version match: `plugin.json` `0.10.0` == marketplace up-docs entry `0.10.0`;
  `scripts/validate-marketplace.sh` passes.
- `rg -n "Haiku propagators|propagate-wiki.*Haiku|three Haiku|all Haiku" README.md plugins/up-docs`
  returns nothing outside CHANGELOG (SA-003).
- All bats + pytest green.
- README prereqs no longer claim the wiki layer needs MCP / is air-gap-blocked.

## 11. Out-of-repo follow-ups (flagged, not done here)

- `~/.claude/CLAUDE.md` Source-of-Truth table row: "Implementation reference → **Outline wiki** +
  repo docs" is now stale → llm-wiki + repo docs.
- `~/.claude/CLAUDE.md` "Before Any Infrastructure Work" step 3 ("Search and read Outline wiki
  FIRST") references a retired system → should point at llm-wiki (`rg` over `~/projects/llm-wiki/wiki/`).
- _Resolved 2026-06-07 (was round-1 SA-001): the `llm-wiki` skill already reflects homelab ownership
  and the `homelab-wiki` skill is retired — no follow-up needed; D2 was flipped to match._

## 12. Open questions

None blocking. D2 was resolved against ground truth (homelab implementation-reference lives in
llm-wiki; see §13 SA-001). The §11 items are surfaced for the user to action outside this repo.

## 13. Audit ledger (Codex `$spec-review`, adversarial)

Read-only adversarial audits via `codex exec` (gpt-5.5, xhigh reasoning, `-s read-only`) against this
spec. Raw output kept under `/tmp/codex-specreview/`.

### Round 1 — verdict: Needs major specification correction (2 blocking, 2 non-blocking)

| ID | Sev | Title | Disposition |
| --- | --- | --- | --- |
| SA-001 | High | Homelab exclusion contradicts the active llm-wiki corpus (ADR-0009; `homelab-overview.md` + `monitoring.md` active) | **Resolved** — D2 flipped to "llm-wiki owns homelab reference" (user-confirmed); domain filter, examples, layer_boundary, §11 updated |
| SA-002 | High | Marketplace metadata omitted from version-bump scope | **Resolved** — `.claude-plugin/marketplace.json` added to §3 scope, §9, §10 acceptance |
| SA-003 | Med | Sonnet bump leaves stale "Haiku propagator" surfaces | **Resolved** — §9 model-surface inventory (13 surfaces; "two Haiku + one Sonnet"); §10 `rg` acceptance check |
| SA-004 | Med | llm-wiki command cwd unspecified | **Resolved** — §4.1 requires `(cd "$LLM_WIKI_ROOT" && …)` + absolute paths |
| nit | Low | "No MCP server in repo" too broad | **Resolved** — §1 reworded (other plugins carry `.mcp.json`) |
| ambiguity | — | llm-wiki validator-version drift across docs | **Resolved** — §4.8 makes runtime AGENTS.md authoritative |

Open issue IDs after round-1 fixes: none pending. Round 2 should confirm SA-001..004 resolved with no
regressions and no new findings, then the loop can stop on "No significant findings remain".

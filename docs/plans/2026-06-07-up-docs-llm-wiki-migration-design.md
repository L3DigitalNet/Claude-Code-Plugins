# up-docs — Outline → llm-wiki Migration (Design)

**Date:** 2026-06-07
**Status:** Draft — awaiting user review before `writing-plans`
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

**No MCP server definition lives in this repo.** up-docs has no `.mcp.json`; `mcp-outline`
is a globally-defined server, so the migration is entirely prompt / tool-list / doc surface.

## 2. Locked decisions (from brainstorming Q&A, 2026-06-07)

| # | Decision | Choice |
| --- | --- | --- |
| D1 | What the wiki layer DOES now | **Write `status: draft` pages directly into `~/projects/llm-wiki/wiki/`** — respecting the full llm-wiki contract; never self-promote. |
| D2 | Homelab infra docs | **Generic examples; homelab stays elsewhere.** llm-wiki holds cross-cutting synthesized reference, NOT homelab infra. The propagator must not imply homelab ownership. |
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
- `plugins/up-docs/tests/*` — only where a structural assertion needs updating (verify in plan)
- Repo: root `README.md`; `docs/handoff/deployed.md` (version + description)

**Out of scope (this change):**

- Historical `docs/plans/*` and `docs/research/*` — dated point-in-time records.
- `CHANGELOG.md` lines 213/222 — historical entries kept verbatim; a NEW entry is added.
- The notion/repo agents' homelab _examples_ — only their Outline→wiki _naming_ changes;
  de-homelab'ing those examples is a separate concern, not Outline retirement.
- Global `~/.claude/CLAUDE.md` Source-of-Truth table and the `llm-wiki` skill's stale homelab
  carve-out — see §11 follow-ups.

## 4. The new wiki-layer contract (applies to both agents)

The rewritten agents must honor the llm-wiki governance model. The **authoritative** source is
`~/projects/llm-wiki/AGENTS.md` + `docs/handoff/conventions.md` (rules C-1..C-12), read at
runtime (D4). Summarized here for design intent only — on any conflict the repo doc wins:

1. **Path & override.** Root = `${LLM_WIKI_ROOT:-$HOME/projects/llm-wiki}`. If absent, the agent
   reports cleanly (one-row table / "wiki not checked" note) and exits its layer — it never fails
   the whole run. Mirrors the existing "validator absent" graceful-skip pattern in audit-drift.
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
8. **Validate before claiming clean.** Run the gate block **copied from AGENTS.md at runtime**
   (do not hardcode validator versions). As of this writing:

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
| Domain filter | (none) | Skip items that are homelab infra (→ elsewhere), strategy (→ Notion), or live facts (→ system-of-record); report them as "No change needed — out of llm-wiki domain" |
| Examples | homelab (OpenBao CT 111, Kismet CT 105, AIDE GMK) | **generic** (e.g. a library's config reference, a repo's build procedure, a service integration note) |
| `<layer_boundary>` | "Outline implementer's shelf" | llm-wiki `wiki/` synthesized cross-cutting reference; explicit exclusions: homelab infra, strategy, live facts |
| Output | `## Documentation Update: Wiki (Outline)` | `## Documentation Update: Wiki (llm-wiki)` |

**Behavior note (honest under-delivery is correct):** with homelab excluded, many of this user's
sessions will yield "nothing for llm-wiki." The propagator must report that plainly rather than
invent a page — the same anti-fabrication discipline the drift auditor already enforces.

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
- Examples de-homelab'd to generic where they currently cite homelab pages.

## 7. Minor agents — naming only

- `up-docs-propagate-notion.md` — change the Notion↔Outline boundary prose and `→ Outline wiki`
  pointers to llm-wiki / "the wiki." Homelab examples (OpenBao/Kismet) stay (out of scope).
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

## 9. README, manifest, CHANGELOG, repo docs

- `plugins/up-docs/README.md`:
  - Three-layer description + [P1]/[P4] principle text: "Outline" → "llm-wiki".
  - **Prerequisites rewrite (capability upgrade):** wiki layer needs the local `~/projects/llm-wiki`
    repo present + `uv`/`uvx` for validators — **no MCP**. Replace "Requires both Outline and Notion
    MCP servers" + "Air-gapped systems can only use `/up-docs:repo`" with: only Notion needs network;
    repo + wiki layers work air-gapped.
  - Generic CLAUDE.md `## Documentation` mapping example (drop "Outline: 'Homelab' collection").
  - Roadmap line 201 "without pushing to Outline or Notion" → "llm-wiki or Notion".
  - Agent table line 193 model: `up-docs-propagate-wiki` Haiku → **Sonnet**.
- `plugin.json` — `version` → `0.10.0`; `description` "Outline wiki" → "llm-wiki".
- `CHANGELOG.md` — new `0.10.0` entry describing the Outline→llm-wiki backend swap, the model bump,
  the air-gapped-wiki capability, and the new validator-backed drift checks. Historical entries kept.
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
3. Run gates: `bash tests/run-bats.sh` + pytest; `scripts/validate-marketplace.sh` (plugin.json
   fields/version valid per marketplace strict-Zod rules).

**Acceptance criteria:**

- `rg -i 'outline' plugins/up-docs` returns only `CHANGELOG.md` historical lines.
- No agent `tools:` line contains `mcp-outline`.
- `propagate-wiki` model is `sonnet`; tool list adds `Edit, Write`, drops all MCP verbs.
- All bats + pytest green; marketplace validator passes.
- README prereqs no longer claim the wiki layer needs MCP / is air-gap-blocked.

## 11. Out-of-repo follow-ups (flagged, not done here)

- `~/.claude/CLAUDE.md` Source-of-Truth table row: "Implementation reference → **Outline wiki** +
  repo docs" is now stale → llm-wiki + repo docs.
- `~/.claude/CLAUDE.md` "Before Any Infrastructure Work" step 3 ("Search and read Outline wiki
  FIRST") references a retired system.
- The `llm-wiki` **skill's** "When NOT to use" + "Where does this belong?" still route homelab infra
  to "Outline / the homelab-wiki skill" — internally contradictory now that Outline is retired.
  Resolving where homelab infra docs live (D2 left it "elsewhere") is the user's call.

## 12. Open questions

None blocking. D2 deliberately leaves the homelab-docs destination unresolved; the plugin simply
stops claiming that domain. The §11 items are surfaced for the user to action outside this repo.

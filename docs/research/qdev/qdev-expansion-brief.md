# Brief: Expand the `qdev` plugin's web-research capability

**Goal.** Expand `qdev` in two ways:

1. **Refine the user-invoked `/qdev:research`** (command + `qdev-researcher` subagent).
2. **Add one auto-invoked grounding skill** that fires mid-task and escalates: a **light** inline path (no report) that climbs to a **medium** path (dispatch `qdev-researcher` + full reporting cycle) when it fails to resolve.

**One skill, not two — locked.** Skill selection in Claude Code is description-match with no runtime arbiter, so two auto-firing skills sharing a trigger space misfire. A single skill that escalates inside its own logic removes that ambiguity. Whether it is physically one skill with two branches or a thin light skill that invokes a separate medium skill on escalation is an implementation detail for the brainstorm — but only the entry skill ever carries an auto-trigger `description`, and the medium path must never self-trigger.

---

## Why this exists

Claude Code often fails to search when it should — it loops on broken approaches or trusts stale training data for fast-moving libraries/APIs. `/qdev:research` covers _deliberate_ research, but nothing fires _automatically_ mid-task. Deliverable 2 fills that gap cheaply (inline lookups that escalate only on failure); Deliverable 1 hardens the shared reporting machinery the medium path reuses.

---

## What exists today (read before changing anything)

| Artifact | Path | State |
| --- | --- | --- |
| User command | `plugins/qdev/commands/research.md` | Dispatches `qdev-researcher`; depth defaults to `standard`. Supports `quick`/`standard`/`thorough`. |
| Research agent | `plugins/qdev/agents/qdev-researcher.md` | Sonnet. Dual-source (brave+serper) parallel search, Tavily extract, Context7 routing, corroboration discipline, source grading, 1 follow-up pass. Persists `docs/research/<date>-<slug>.md`. |
| Report persistence | — | Per-report file only. **No README index, no dedup logic.** |

**Gaps to close:** (a) no README index, (b) no dedup against prior reports, (c) no auto-trigger path.

---

## Research inputs (read-only ground truth — read before the brainstorm)

Three commissioned reports back this brief. All reflect the post-fix Tavily naming and the actual installed servers, so they are trustworthy ground truth. They live in the `qdev` plugin repo under `docs/research/qdev/`.

- [`llm-coding-agent-search-tools.md`](docs/research/qdev/llm-coding-agent-search-tools.md) — built-ins vs MCP, per-provider tool surface, pricing, token-economics. Argues **Brave-first** for agent search (`brave_llm_context` is token-bounded).
- [`search-mcp-routing-strategy.md`](docs/research/qdev/search-mcp-routing-strategy.md) — deterministic routing rules, per-tool defaults, evidence-tier trust model. Argues **Tavily-first** search → Brave cross-check → Serper operators.
- [`search-mcp-routing-strategy-context7.md`](docs/research/qdev/search-mcp-routing-strategy-context7.md) — **most current; supersedes the prior routing doc where they overlap.** Adds **Context7 as a distinct documentation-context layer above the search stack**: the first routing question becomes "docs/API-usage task → Context7 first, else search stack." Also surfaces query-egress, Context7 freshness gaps, and a Context7 tool-name mismatch (all folded into this brief below).

---

## Locked decisions (do not re-litigate)

- **One auto-skill, escalating** — single auto-trigger; the medium path is reached only by escalation or the Category-A shortcut (see Goal).
- **Medium engine** — reuses `qdev-researcher` at `quick` depth; shares one report/README/dedup codepath with `/qdev:research`. No second research agent.
- **Light engine** — inline in the main agent's context; no subagent, no report, no dedup.
- **Escalation** — Category-C gaps start light; after **2 unsuccessful rounds** escalate to medium (handing over what light found). Category-A "already stuck" enters medium directly.
- **Trigger posture** — Categories **A + C only**; proactive B stays manual via `/qdev:research`.
- **Compatibility** — Claude Code only; stack is Serper + Tavily + Brave (+ Context7). Paid accounts — quality over quota.

---

## Deliverable 1 — Refine `/qdev:research` (user-invoked)

1. ~~Fix the Tavily tool-name bug~~ — ✅ done (`e49e4de`): `mcp__tavily__*` → `mcp__tavily-mcp__*` across three agents; logged under `[Unreleased]` in the qdev CHANGELOG.
2. **Add the shared reporting cycle** (README index + dedup — see Shared Infrastructure). Extend the agent's existing persist step.
3. **Reconcile the report format.** Keep the proven angle-structured `<output_format>` as the persisted format; _add_ the dedup header fields (`**Query:**`, `**Date:**`, `**Related reports:**`) and a `## Sources` table. Do not rewrite the structure wholesale.
4. **Fold in the Known Limitations** (Constraints) as guardrails where missing.

Keep `standard` as the default depth.

---

## Deliverable 2 — The escalating grounding skill

One skill, the only auto-trigger in the system. Fires on Categories A + C (detection signals: see Triggering reference).

### Routing at entry

- **Category A (already stuck)** → **medium path directly.** Being demonstrably stuck is worth a full sweep and a persisted report.
- **Category C (context gap)** → **light path**, escalating only on failure.

### Light path (inline — no subagent, no report)

For one-off, low-stakes lookups: a current version, an API signature, "is library X still maintained?"

- **First gate — docs or web?** If the lookup is _how to use_ a named library/framework/SDK/API/CLI (syntax, config, version behavior), go to **Context7 first**. Otherwise it's a web lookup → use the search stack below. Context7 self-promotes and over-triggers, so restrict it to named-library docs — never general concepts, comparisons, or news — and don't trust it for "latest version / what changed" (see Constraints).
- **Provisional web routing** (exact order is an Open Question — see Routing): for non-docs lookups, use our MCP stack, not raw `WebSearch` — Brave for grounding (`brave_web_search` / `brave_llm_context`) → Serper for Google-recall → `tavily_extract` only to read one specific page in full.
- **Minimum search:** ≥2 of {brave, serper} (never single-source a fact that will be acted on), prefer the freshest result, include the current year for version/changelog queries.
- **A round = one sweep meeting the minimum.** Round 1 is the initial sweep; round 2 is one refined retry (reworded/expanded queries, an added server, or a `tavily_extract` on the best page).

### Escalation (light → medium)

- **After 2 unsuccessful rounds** — "unsuccessful" = results thin/empty/conflicting, OR applied but the question/blocker persists.
- Hand the medium path what light found (queries tried, best links, why it stalled) so the subagent doesn't restart cold.
- Escalate early (before round 2) if scope turns substantial or the blocker is confirmed.

### Medium path (dispatch `qdev-researcher` + full report)

- `qdev-researcher` at `depth=quick`: 3–4 queries; skip the follow-up pass (or cap deep-reads at ~2); thin angles become Open Questions.
- Runs the full reporting cycle (Shared Infrastructure). "Medium" is _search breadth_, not skipping the report.
- Announce before firing (e.g. `Auto-research: <topic> (escalated after 2 light rounds)`); return a compact result and hand control back.

### Trigger `description` (the make-or-break field)

Encode A + C, exclude B. It must (a) fire reliably when the agent is stuck or missing current data, (b) **not** over-fire on routine work, (c) convey "starts cheap, escalates" so Claude invokes it freely without fearing a full research sweep every time.

---

## Shared Infrastructure (used by `/qdev:research` and the medium path — build once)

> The light path uses none of this — no report, no README index, no dedup.

### Report persistence

Path: `docs/research/<YYYY-MM-DD>-<slug>.md` (`<slug>` = kebab-case topic, ≤60 chars). The `qdev-researcher` `<output_format>` plus a dedup header and a `## Sources` table (`| URL | Title | Date | Relevance |`):

```markdown
**Query:** <exact query or task description> **Date:** <ISO date> **Tools used:** <MCP tools invoked> **Related reports:** <links to prior reports, or "none">
```

### `docs/research/README.md` index

Create if missing; append one line per report:

```markdown
- [YYYY-MM-DD — <topic>](<filename>.md) — <one-line summary>
```

### Deduplication algorithm (run before writing a new report)

1. Extract 3–5 keywords (nouns, library/tool names) from the query.
2. `grep -i` them against `docs/research/README.md`. If fewer than 2 match any entry, skip to step 5.
3. For each matching entry, read only its `**Query:**` and `**Date:**` fields.
4. Apply the decision table:

   | Condition | Action |
   | --- | --- |
   | ≥2 keywords match AND report <6 months old AND scope overlaps AND topic NOT fast-moving | Update existing report |
   | ≥2 keywords match AND report >6 months old AND topic IS fast-moving (library/API/tool/CVE) | Create new; link the old entry in `**Related reports:**` |
   | ≥2 keywords match AND current query is a different angle (e.g. existing = setup, current = debugging) | Create new; link the old entry in `**Related reports:**` |
   | <2 keywords match | Create new |

   **Fast-moving** = subject includes a library/API/CLI/service version or a security topic (CVE/auth/compliance); all else is stable. **When updating:** append a `## Update: YYYY-MM-DD` section — never rewrite existing content (preserves the audit trail, avoids a full re-read to merge).

5. Create the report and add its `README.md` entry.

---

## Triggering reference — Categories A & C

Detection signals for the single auto-trigger. **Category B is excluded.**

### Category A — reactive (already stuck)

- The same tool call, command, or API call failed or returned empty/wrong **twice in a row**.
- **≥2 different approaches** to the same subtask both failed.
- A command failed with an unrecognized error (unfamiliar exit code, deprecation warning, 4xx implying a changed API).
- A fix was written, verified, and the **same failure reappeared unchanged**.
- The agent is about to retry something it already tried this session.

### Category C — context gap (information not in context)

- The task needs the **current/latest version** of a dependency or tool.
- The task involves something possibly **after the training cutoff**.
- The agent must **verify a fact** it cannot confirm from in-context code/files.
- A recommendation is requested and **current ecosystem state matters** (e.g. "is library X still maintained?").

### Category B — proactive (out of scope)

Pre-emptively searching before _any_ external-library/API/date-sensitive work over-fires on routine tasks. Serve it via deliberate `/qdev:research`; document B in the skill as a "when to run `/qdev:research` instead" note — never auto-trigger on it.

---

## Quality control (apply in both paths)

- 🔒 **Query hygiene (egress):** every external search / Context7 query is sent to a third-party service and may be logged or reused (Context7 reranks and benchmarks on submitted queries). **Never** put secrets, tokens, credentials, proprietary code, customer data, or internal hostnames/paths in a query — sanitize to a generic task description. Sharpest on the **light path**: it auto-fires on Category-A errors, and raw error text is exactly where such data leaks. Enforces the global "don't upload secrets to external services" rule.
- **Corroboration:** footguns need 2+ independent sources OR one official source; single-source items are `[unverified]` and demoted/omitted.
- **Source grading:** every citation carries `[official]`/`[community]`/`[blog]`/`[unverified]`.
- **Triangulation:** prefer claims corroborated across ≥2 search services.
- **Freshness:** include the current year (`date +%Y`, not a literal) in stale-risk queries; prefer recent sources for fast-moving topics.

---

## Constraints & resources

**MCP servers:** Serper `serper-search-scrape-mcp-server` (the `scrape` tool is **not** in this package); Tavily `tavily-mcp`; Brave `brave-search`; Context7 (official plugin).

**Tool names (use exactly):**

- **Brave:** `mcp__brave-search__brave_web_search`, `brave_news_search`, `brave_local_search`, `brave_video_search`, `brave_image_search`, `brave_place_search`, `brave_summarizer`, `brave_llm_context`.
- **Tavily:** `mcp__tavily-mcp__tavily_search`, `tavily_extract`, `tavily_crawl`, `tavily_map`, `tavily_research`.
- **Serper:** `mcp__serper-search__google_search`.
- **Context7:** `mcp__plugin_context7_context7__resolve-library-id`, `mcp__plugin_context7_context7__query-docs`.

**Known limitations (carry as guardrails):**

- Tavily `search_depth=fast` returns empty — use `basic` (or `advanced` for high-stakes). Re-test annually.
- Serper `gl`/`hl` are required in code despite being documented as optional → always pass (`gl: us, hl: en`).
- `brave_llm_context` is token-bounded: `maximum_number_of_tokens` default 8192, max 32768.
- Tavily `topic` is restricted to `general` in the MCP schema (no news/finance via MCP) → route news to Brave.
- **Context7 tool name is install-dependent:** `query-docs` (current source / this env) vs `get-library-docs` (package README). Detect from the installed schema; don't hardcode blindly. Second instance of the Tavily naming-mismatch class.
- **Context7 is not authoritative for freshness:** it can serve stale docs during background refresh and its defaults often exclude changelogs/deprecated folders → route "latest version / what changed" lookups to Serper/Brave, not Context7 alone.
- **Context7 over-triggers:** its tool description self-promotes "prefer over web search." Constrain it to named-library/API docs; exclude refactoring, comparisons, business-logic debugging, and news.

---

## Open questions for the brainstorm (2026-06-03)

From the Research Inputs vs this brief. **None are resolved** — do not treat them as decided.

**Framing principle:** the two docs optimize different axes — Brave-first = token economy, Tavily-first = recall/quality — and those axes map onto the two paths. Light results land in the **main agent's** context (economize → Brave); medium runs in a **disposable subagent** context (maximize recall → Tavily). Same "context has a lifetime" principle as the repo's doc layout. Start there and most options below resolve.

### 🔴 Routing (decide first — also changes `qdev-researcher`, i.e. Deliverable 1)

1. **Medium search order** — per-path split (light = Brave token-bounded; medium = Tavily-first → Brave cross-check → Serper operators → Tavily extract) · keep current (brave+serper parallel, Tavily extract-only) · Tavily-first everywhere. Note: `tavily_search` is already granted-but-unused, so adopting Tavily-first is low-friction.
2. **Light primary tool** — make `brave_llm_context` the explicit primary over `brave_web_search`? Defaults: `maximum_number_of_urls: 5`, `context_threshold_mode: balanced`.
3. **Minimum-pair composition** — `{brave, serper}` vs **Tavily + Brave** (two genuinely independent indexes; Serper _is_ Google).

### 🟡 Guardrails to ratify (cheap, additive)

4. **Installed-schema-is-truth** — make both paths tolerate a missing/renamed tool instead of silently degrading. **Now two confirmed instances** of the bug class: the fixed Tavily server-key, and Context7's `query-docs` vs `get-library-docs`. Detect available tools at runtime; don't hardcode names.
5. **Enforce the search quirks** — promote Serper `gl`/`hl` and the Tavily `topic=general` → Brave-news routing (Constraints) from passive notes to enforced behavior.
6. **`tavily_research`** — schema-gated; optional only, verify per install if used.

### 🟢 Optional enhancements

7. `tavily_map` → `tavily_extract` for docs sites Context7 doesn't cover (medium path).
8. Lift the routing doc's paste-ready JSON defaults into the refined agent.

### ⚠ Meta — global vs qdev drift

9. Global `CLAUDE.md` routing says Brave-first; doc 2 says Tavily-first. Reconcile globally, or scope Tavily-first to qdev only. Touches the user's global config — confirm before editing anything outside this repo.

---

## Suggested process

1. `superpowers:brainstorming` — resolve the Open Questions (routing, light primary tool, guardrails, global drift) and settle the `description` wording, the "unsuccessful round" definition, the medium `quick`-depth knobs, and the report-format reconciliation. Read the Research Inputs first.
2. `superpowers:writing-plans` → a spec/plan under the qdev plugin docs.
3. Implement in order: Tavily bug (✅ done) → shared reporting cycle (Deliverable 1) → escalating skill (Deliverable 2). Test end-to-end: `/qdev:research` and the escalated medium path both write a report, update the README, and honor dedup on a repeat query; the light path writes nothing, uses ≥2 services, and escalates after 2 rounds; a Category-A entry skips light.

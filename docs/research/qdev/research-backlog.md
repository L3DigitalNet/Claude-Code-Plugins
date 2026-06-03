# Research Backlog — qdev web-research expansion

Topics to research before/while executing [`qdev-expansion-brief.md`](qdev-expansion-brief.md). These are **investigations** (go find external knowledge or run a measurement), distinct from the brief's **Open Questions** (design decisions the brainstorm must make). Several of these _feed_ those decisions; the mapping is noted per item.

**Method legend:** 🌐 web/docs research (dogfood through `/qdev:research`) · 📊 empirical benchmark/measurement · 📖 official-docs lookup (Context7 / docs.claude.com).

---

## 🔴 Foundational — verify the architecture's load-bearing assumptions

These can _invalidate_ the design. Do them first; a wrong assumption here reshapes Deliverable 2.

### 1. Claude Code skill auto-invocation: mechanism & reliability — 📖🌐

The brief asserts "skill selection is description-match with no runtime arbiter." **Verify it.** How does Claude Code actually decide to auto-trigger a skill from its `description`? Is it model-judged, keyword-weighted, embedding-matched? How reliably does an auto-trigger fire in practice, and what description patterns fire reliably vs. over-fire on routine work?

- **Unblocks:** the entire Deliverable 2 trigger design + the `description` wording (the make-or-break field).
- **Sources:** official skill-authoring docs, `superpowers:writing-skills` / `skill-creator` guidance, Anthropic skill docs, community reports of over/under-triggering.

### 2. Within-skill control flow: can a skill dispatch a subagent or invoke another skill mid-execution? — 📖🌐

The escalation ladder assumes the skill body can branch (Category A vs C), run inline searches, **then dispatch `qdev-researcher`** on escalation. Confirm a skill can programmatically invoke the `Agent` tool / another skill, and what the limits are.

- **Unblocks:** one-skill-vs-two (brief's locked-but-structurally-open point), and the escalation step itself.
- **Risk if false:** "light escalates to medium" may need to be two skills or a command, not internal branching.

### 3. Runtime MCP tool-availability detection — 📖🌐

Can a skill/agent introspect which MCP tools are **actually granted** at runtime (a programmatic equivalent of `/mcp`), so it can degrade gracefully when a server is missing or a tool is renamed?

- **Unblocks:** Open Question #4 (installed-schema-is-truth). The _general_ fix for the bug class with **two confirmed instances now** — the Tavily server-key misname (`e49e4de`) and Context7's `query-docs` vs `get-library-docs` tool-name drift. Two instances make this a structural hazard, not a one-off typo.

---

## 🟡 Evidence — replace routing assumptions with data

The provider reports are explicit that their routing recommendations are **architectural, not benchmark-derived**. These measurements turn Open Questions #1–3 from opinion into evidence.

### 4. Live provider benchmark: Brave vs Serper vs Tavily on a qdev-representative query set — 📊

Run the harness the research docs already sketch, on queries qdev actually faces: current library-version lookups, GitHub-issue discovery, changelog/CVE checks, docs-site discovery, "is X still maintained?". Measure p50/p95 latency, recall@k, precision@k, stale-result rate, serialized token footprint, cost/query.

- **Unblocks:** routing Open Questions #1 (medium search order) and #3 (minimum-pair composition).

### 5. `brave_llm_context` real-world behavior for coding-agent grounding — 📊🌐

The light path's proposed primary tool. Measure actual token footprint (vs. its 8192 default), answer quality, and latency against `brave_web_search` + manual read, on real grounding tasks.

- **Unblocks:** Open Question #2 (make `brave_llm_context` the light-path primary?).

### 6. Per-tool serialized token footprint — 📊

The light/medium split is justified entirely on **context economy** (light results land in the main agent's context). Measure the real token cost each tool's output adds, to confirm or refute that premise and to set the light-path's tool defaults.

- **Unblocks:** validates the core light-vs-medium rationale; informs min-search defaults.

### 7. Context7 coverage, freshness & the docs-vs-web gate — 📊🌐

The Context7 report (most current routing doc) puts Context7 _first_ for named-library/API docs. Validate that gate empirically: for the libraries qdev users actually touch, how complete is Context7's coverage, how stale can it be (background-refresh lag), and how often does its changelog/deprecated-folder exclusion make it the **wrong** first stop? Identify when to bypass straight to Serper/Tavily.

- **Unblocks:** the new "First gate — docs or web?" routing rule and the "Context7 not authoritative for freshness" constraint in the brief. Complements #4 (different metrics: coverage/freshness/snippet quality, not SERP recall).

---

## 🟢 Prior art & safety — learn from what exists, harden what's exposed

### 8. Existing auto-search / web-grounding skills or plugins for Claude Code — 🌐

Has anyone already built an auto-triggering research/grounding skill (community marketplaces, `superpowers`, the bundled `deep-research`/`research`/`search` skills)? Study their trigger `description` wording and escalation patterns.

- **Why:** don't reinvent; harvest proven self-trigger phrasing for the `description` field. Directly feeds topic #1.

### 9. How other coding agents handle "search when stuck" escalation — 🌐

Codex (`--search` / cached-vs-live), Cursor, Aider, etc.: do they auto-escalate to web search on repeated failure, and on what heuristics?

- **Why:** cross-pollinate the Category-A reactive heuristics and the "2 unsuccessful rounds" threshold.

### 10. Prompt-injection handling for agent-ingested web content (data **in**) — 🌐📖

Current best practices for treating fetched/searched content as untrusted. **Sharper for the LIGHT path:** it injects raw results into the **main agent's** context (larger blast radius than the sandboxed subagent the medium path uses).

- **Why:** the medium path already flags injection; the light path's exposure is new.

### 11. Provider data-handling & query-egress policies (data **out**) — 🌐📖

The inverse of #10. The brief now carries a query-hygiene/egress guardrail because Context7 reuses submitted queries for reranking/benchmarking. Research each provider's actual policy — retention, query reuse, logging, training use — for Tavily, Brave, Serper, **and** Context7. Determine whether any provider is materially safer for auto-fired queries, and what sanitization is genuinely sufficient.

- **Why:** turns the egress guardrail from a blanket "sanitize everything" into provider-specific rules; matters because the light path auto-fires on Category-A error text (a common secret-leak vector). Feeds the global "don't upload secrets to external services" rule.

### 12. Incremental research-KB patterns (dedup, indexing, staleness) — 🌐

Established approaches for an append-only LLM research corpus — keyword/embedding dedup, freshness scoring, index maintenance.

- **Why:** validates (or improves) the hand-rolled README-index + `grep`-keyword dedup algorithm in Shared Infrastructure.

---

## Notes

- **Dogfood opportunity:** the non-benchmark topics (1–3, 7's web half, 8–12) are web/docs research that `/qdev:research` can largely answer itself — running them is also a real-world test of the tool being improved.
- **Sequencing:** resolve 🔴 1–3 before the brainstorm commits to the single-skill escalation architecture. 🟡 4–7 can run in parallel and should land before Deliverable 1's routing changes to `qdev-researcher` (7 specifically gates the Context7-first routing rule). 🟢 8–12 are valuable but non-blocking — though #11 (egress) should inform the sanitization guardrail before the light path ships.
- **Persist findings** as reports in this folder (`docs/research/qdev/`) per the brief's reporting cycle, so the brainstorm and plan read from one place.

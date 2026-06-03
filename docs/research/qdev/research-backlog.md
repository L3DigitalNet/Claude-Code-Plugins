# Research Backlog — qdev web-research expansion

Topics to research before/while executing [`qdev-expansion-brief.md`](qdev-expansion-brief.md). These are **investigations** (go find external knowledge or run a measurement), distinct from the brief's **Open Questions** (design decisions the brainstorm must make). Several of these _feed_ those decisions; the mapping is noted per item.

**Method legend:** 🌐 web/docs research (dogfood through `/qdev:research`) · 📊 empirical benchmark/measurement · 📖 official-docs lookup (Context7 / docs.claude.com).

---

## Resolution status (updated 2026-06-03)

Two resolution passes have now closed every web/docs-answerable item.

- [`qdev-research-backlog-resolution.md`](qdev-research-backlog-resolution.md) (**pass 1**) closed 1, 2, 3, 8, 9, 10, 12.
- [`qdev-research-backlog-resolution-2.md`](qdev-research-backlog-resolution-2.md) (**pass 2**) closed all of 11, closed the web/docs half of 7 (live 3-library probe + freshness mechanics + revised docs-vs-web gate), and refined 4–6 into an implementable local benchmark-harness spec.

Status by topic number (this doc's numbering):

- ✅ **Resolved (web/docs):** 1, 2, 3, 8, 9, 10, 11, 12. Headlines — **#2:** the escalating skill must run **inline, not forked** (a forked skill is a subagent, and subagents can't use `Agent`, so it could never dispatch `qdev-researcher`); **#11:** provider-specific egress rules — Brave-with-enterprise-ZDR is the safest general channel, Tavily/Serper are high-risk for auto-fired queries, and Context7 reranks + anonymously stores submitted queries — plus a global egress sanitizer. All folded into the brief.
- 🟡 **Web half resolved, empirical half open:** 7 — Context7 refresh thresholds (Top 100 = 1 day → all-others = 45 days), request-triggered background-refresh mechanics, a 3-library live probe (FastAPI/Pydantic/MCP all "Strong"), and the revised docs-vs-web gate are done (pass 2 §1). Full closure still needs a local coverage matrix over the real qdev library set.
- 📊 **Empirical — need a local harness (spec refined in pass 2 §3):** 4, 5, 6, plus 7's coverage-matrix half. Pass 2 supplies the query set, tool matrix, captured-record schema, token-footprint method, and default decision thresholds — ready to hand to Claude Code/Codex.

Findings folded into the brief from both passes: inline-not-forked constraint, softened "description-match" claim, `qdev doctor` + fail-soft schema guardrail, light-path token caps, OWASP external-content safety policy, the KB-structure open question, the revised Context7 docs-vs-web gate, provider-specific query-egress rules, the global egress sanitizer, and the benchmark decision thresholds.

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
- 📊 **Status (pass 2 §3):** harness spec refined — concrete query set (§3.2), tool matrix (§3.3), captured-record schema (§3.4), and default decision thresholds (§3.7: light-path p95 < 5 s, footprint < 3,000 tokens, precision@5 > 0.60, stale < 20%). Still requires a live run against the installed MCP servers. Persist to `docs/research/qdev/benchmarks/`.

### 5. `brave_llm_context` real-world behavior for coding-agent grounding — 📊🌐

The light path's proposed primary tool. Measure actual token footprint (vs. its 8192 default), answer quality, and latency against `brave_web_search` + manual read, on real grounding tasks.

- **Unblocks:** Open Question #2 (make `brave_llm_context` the light-path primary?).
- 📊 **Status (pass 2 §3.6):** paired-workflow comparison defined (LLM-context vs Brave-web+read vs Tavily search+extract vs Serper+extract) with a decision rule — **if `brave_llm_context` exceeds ~5,000 serialized tokens on common light-path tasks, do not default to it** despite the 8,192 parameter default. Still needs a live run.

### 6. Per-tool serialized token footprint — 📊

The light/medium split is justified entirely on **context economy** (light results land in the main agent's context). Measure the real token cost each tool's output adds, to confirm or refute that premise and to set the light-path's tool defaults.

- **Unblocks:** validates the core light-vs-medium rationale; informs min-search defaults.
- 📊 **Status (pass 2 §3.5):** method fixed — measure at three layers (raw JSON bytes → minified bytes → `o200k_base` token count), and count **what actually lands in agent context**, not what the API theoretically returns. Captured per the §3.4 record schema. Still needs a live run.

### 7. Context7 coverage, freshness & the docs-vs-web gate — 📊🌐

The Context7 report (most current routing doc) puts Context7 _first_ for named-library/API docs. Validate that gate empirically: for the libraries qdev users actually touch, how complete is Context7's coverage, how stale can it be (background-refresh lag), and how often does its changelog/deprecated-folder exclusion make it the **wrong** first stop? Identify when to bypass straight to Serper/Tavily.

- **Unblocks:** the new "First gate — docs or web?" routing rule and the "Context7 not authoritative for freshness" constraint in the brief. Complements #4 (different metrics: coverage/freshness/snippet quality, not SERP recall).
- 🟡 **Status (pass 2 §1):** web/docs half **resolved** — refresh is request-triggered with popularity-based thresholds (Top 100 = 1 day, Top 1,000 = 15 days, Top 5,000 = 30 days, all others = 45 days; private libs never auto-refresh); a 3-library live probe (FastAPI, Pydantic, MCP) returned "Strong" coverage for all three; a match-scoring rubric (exact name · official vs community · reputation · snippet count · benchmark score · version match · task fit) and a bypass table (changelogs/CVEs/issues/maintainer-status/same-day-freshness → search stack) are folded into the brief. **Empirical half open:** the §1.7 coverage matrix over the full qdev library set (`context7-coverage-matrix.jsonl`).

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
- ✅ **Status (pass 2 §2):** **resolved.** Per-provider verdicts — **Brave** low risk _only with enterprise Zero Data Retention_ (otherwise low–medium); **Context7** medium (sends only a formulated docs query, but reranks via third-party LLMs incl. OpenAI/Gemini/Anthropic and anonymously stores queries for benchmarking, 30-day API logs); **Tavily** high (may reuse query data to improve responses and share with third-party indexes e.g. Google); **Serper** high/unknown (thin public disclosure, Google-scraper API). Output: a provider ranking for sensitive-but-allowed auto queries, per-provider allowed/disallowed query examples, and a global egress sanitizer (drop secrets → strip private identifiers → collapse stack traces → emit provider-specific `safe_query` + human-approval flag). All folded into the brief.

### 12. Incremental research-KB patterns (dedup, indexing, staleness) — 🌐

Established approaches for an append-only LLM research corpus — keyword/embedding dedup, freshness scoring, index maintenance.

- **Why:** validates (or improves) the hand-rolled README-index + `grep`-keyword dedup algorithm in Shared Infrastructure.

---

## Notes

- **Dogfood opportunity:** the non-benchmark topics (1–3, 7's web half, 8–12) are web/docs research that `/qdev:research` can largely answer itself — running them is also a real-world test of the tool being improved.
- **Sequencing (now):** every web/docs item (1–3, 7's web half, 8–12, and 11) is closed across the two resolution passes — the brainstorm has all the design inputs it needs and is unblocked. The only remaining work is the local benchmark harness (4, 5, 6, and 7's coverage matrix), which is an **implementation/measurement** task, not a brainstorm blocker: ship Deliverables 1–2 on the research-informed defaults, then run the harness to replace those defaults with measured thresholds. Pass 2 §3.7 supplies the starting thresholds to ship against.
- **Persist findings** as reports in this folder (`docs/research/qdev/`) per the brief's reporting cycle, so the brainstorm and plan read from one place.

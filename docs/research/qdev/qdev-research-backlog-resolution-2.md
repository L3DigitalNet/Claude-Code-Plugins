# qdev Research Backlog Resolution Update — Context7 Coverage, Provider Egress, and Benchmark Harness

**Prepared for:** Chris Purcell **Prepared on:** 2026-06-03 **Input:** `research-backlog.md` updated 2026-06-03 **Scope:** Complete what is reasonably answerable by web/docs research and convert remaining empirical items into an implementable local harness spec.

---

## Executive Summary

The updated backlog changes the work from a broad research pass into a targeted closeout:

- **Already resolved by prior report:** topics 1, 2, 3, 8, 9, 10, and 12.
- **Still empirical / local harness required:** topics 4, 5, and 6.
- **Still open and web/docs-answerable:** topic 7, Context7 coverage/freshness, and topic 11, provider data-handling/query-egress policy.

This update therefore does three things:

1. Resolves the **web/docs half of topic 7** and performs a limited live Context7 coverage probe against three representative qdev libraries.
2. Resolves **topic 11** into provider-specific query-egress rules for Tavily, Brave, Serper, and Context7.
3. Converts topics **4–6** into a concrete benchmark harness spec that can be handed to Claude Code/Codex.

Main decision impact:

- Keep the **Context7-first gate** for named-library/API documentation, but make it conditional. Context7 is a strong first stop for stable library docs and code examples. It is not authoritative for very recent releases, changelogs, CVEs, issue discovery, maintainer status, or anything where freshness is measured in hours/days.
- Treat **Brave Search API as the safest general web provider only if enterprise Zero Data Retention is enabled**. Without ZDR, it is still a strong privacy posture relative to scraper-dependent APIs, but not a “safe to send secrets” channel.
- Treat **Tavily, Context7, and Serper as external egress channels that require query minimization**. None should receive raw stack traces, environment dumps, proprietary source, credentials, `.env` contents, API keys, tokens, customer data, or pasted private repo text.
- The light path must not auto-fire using raw error text. It should first transform the error into a sanitized, provider-specific search query.

---

## Backlog Status After This Pass

| Topic | Status after this report | Reason |
| --- | --- | --- |
| 1. Claude Code skill auto-invocation | No change — already resolved as far as public docs allow | Public docs explain description/metadata usage but not internal matching algorithm. Empirical skill-trigger testing remains separate. |
| 2. Within-skill control flow | No change — already resolved | Prior result remains: forked subagents cannot use `Agent`; escalation must be inline/coordinator-owned. |
| 3. Runtime MCP tool availability | No change — already resolved as architecture rule | Installed schema remains authoritative; use `qdev doctor`/preflight rather than trusting docs. |
| 4. Live provider benchmark | **Harness spec refined** | Web research cannot measure your installed MCP latency/tokens/cost. |
| 5. `brave_llm_context` behavior | **Harness spec refined** | Requires live tool output from your MCP server and actual token accounting. |
| 6. Per-tool serialized token footprint | **Harness spec refined** | Requires capturing actual serialized MCP responses. |
| 7. Context7 coverage/freshness | **Partially resolved + harness spec** | Public refresh/coverage mechanics were researched; three representative live Context7 probes were performed. Full closure needs a local library matrix. |
| 8. Existing auto-search skills/plugins | No change — already resolved | Prior report closed the web-answerable portion. |
| 9. Search-when-stuck escalation | No change — already resolved | Prior report closed the web-answerable portion. |
| 10. Prompt injection, data in | No change — already resolved | Prior report closed the web-answerable portion. |
| 11. Provider data-handling/query egress | **Resolved from public policies** | Provider-specific policies were reviewed and converted into qdev routing/sanitization rules. |
| 12. Research-KB patterns | No change — already resolved | Prior report closed the web-answerable portion. |

---

## 1. Topic 7 — Context7 Coverage, Freshness, and Docs-vs-Web Gate

## 1.1 What public docs establish

Context7 positions itself as a provider of up-to-date, version-specific library documentation and code examples delivered into AI coding assistants. Its docs explicitly claim that Context7 pulls documentation and code examples “straight from the source” and places them into the prompt, reducing outdated APIs and hallucinated examples.[^context7-overview]

That supports the **Context7-first gate** for:

- Named library/framework/API questions.
- Version-specific usage examples.
- SDK syntax and migration questions.
- Common framework patterns.
- Documentation lookup where the task is “how do I use this library?”

It does **not** support Context7-first for every research task. Context7 is a docs retrieval system, not a general web search index, issue tracker, CVE database, package-release monitor, or maintainer-activity analyzer.

## 1.2 Freshness mechanics

Context7’s “Keeping Libraries Fresh” docs are load-bearing for qdev routing.

Public-library refresh is request-triggered:

- When a library is requested through MCP or REST API, Context7 checks when the docs were last updated.
- If the docs are older than the library’s popularity-based threshold, a background refresh is triggered.
- The current request still receives the existing documentation immediately; it does **not** wait for the refresh to complete.
- If a library has not been requested recently, it will not be refreshed.
- Private libraries are not refreshed automatically; they require manual refresh.[^context7-refresh]

Refresh thresholds:

| Context7 popularity rank | Refresh threshold |
| -----------------------: | ----------------: |
|                  Top 100 |             1 day |
|                Top 1,000 |           15 days |
|                Top 5,000 |           30 days |
|               All others |           45 days |

This means Context7 freshness is **bounded but not immediate**. For popular libraries, it may be very fresh. For less-used libraries, docs can be weeks old. For a release that happened today, Context7 can be stale even if it triggers a refresh in the background.

## 1.3 Coverage mechanics

Context7’s API guide shows that it can search libraries, get documentation context, refresh libraries, retrieve policies, and add repositories, OpenAPI specs, `llms.txt`, websites, and Confluence spaces.[^context7-api]

The same guide documents library ID shapes such as:

- `/owner/repo`
- `/websites/<source>`
- `/llmstxt/<source>`
- `/packages/<name>` or `/npm/<name>`
- `/docs/<name>`
- Version pins like `/vercel/next.js/v15.1.8` or `/vercel/next.js@v15.1.8`

Operationally, this matters because qdev should prefer **version-pinned Context7 IDs** when the user’s project pins a library version. Version pinning gives more stable results than asking for “latest” when code generation must match an existing repo.

## 1.4 Limited live Context7 probe

Because the backlog asks for “libraries qdev users actually touch” but no explicit qdev library matrix was included, I used three representative libraries from your stack and the qdev problem domain:

1. FastAPI — core Python web app framework in your projects.
2. Pydantic — Python data modeling/configuration standard in your project standards.
3. Model Context Protocol — directly relevant to qdev MCP routing and tool/schema drift.

### Probe results

| Library | Context7 result quality | Coverage signal | Practical interpretation |
| --- | --- | --: | --- |
| FastAPI | Strong | `/fastapi/fastapi` with 2,154 snippets; `/websites/fastapi_tiangolo` with 5,421 snippets; high reputation; benchmark scores 73.6–84.6 | Context7 is a good first stop for FastAPI docs. Prefer the official website source for broad docs and the repo source for implementation-adjacent examples. |
| Pydantic | Strong | `/pydantic/pydantic` with 2,110 snippets; `/websites/pydantic_dev_validation` with 1,839 snippets; `/pydantic/pydantic-settings` available; high reputation; benchmark scores 81.2–87.4 | Context7 is a good first stop for Pydantic v2 and pydantic-settings usage. Pin version when maintaining older code. |
| Model Context Protocol | Strong but ambiguous | `/modelcontextprotocol/modelcontextprotocol` with 1,710 snippets; `/websites/modelcontextprotocol` with 2,382 snippets; spec-specific source available; high reputation on key results | Context7 is useful for MCP spec/docs lookup, but exact tool availability must still come from installed MCP schema, not docs. |

### Probe interpretation

This limited probe supports Context7-first for qdev’s common docs questions. It does **not** close the empirical backlog item completely, because three libraries are not a coverage benchmark.

The important pattern is that Context7 can return multiple plausible sources for one library: repository docs, official website docs, package pages, old version docs, reference-only pages, tutorials, and third-party curricula. qdev must not blindly choose the first match; it should score matches by:

- exact name match;
- official source vs community/tutorial;
- source reputation;
- snippet count;
- benchmark score;
- version match;
- task fit.

## 1.5 When Context7 should be bypassed

Context7 should **not** be the first stop when the question is materially about:

| Bypass condition | Prefer |
| --- | --- |
| “Was this released today/yesterday/this week?” | Tavily + Brave + Serper |
| Changelog/release-note discovery | Serper `site:` / Tavily / official GitHub releases |
| CVEs/security advisories | GitHub Security Advisories, NVD/vendor security pages, Serper/Tavily |
| “Is this still maintained?” | GitHub repo metadata, release history, issues/PRs, package registry |
| GitHub issue discovery | Serper `site:github.com` or GitHub search |
| Forum/community workaround discovery | Serper/Brave/Tavily |
| Deprecated behavior in old code | Context7 only if pinned to old version; otherwise web/docs archive |
| Exact installed MCP tool names | Installed schema / `/mcp` / `qdev doctor` |
| Private repo code behavior | Local repo inspection, not Context7 public docs |
| Freshness window shorter than Context7 refresh threshold | Web/provider primary sources |

## 1.6 Revised docs-vs-web gate

Use this gate in qdev routing:

```md
First decide whether the question is a documentation lookup or a web research task.

Use Context7 first when all are true:

- The task names a library, framework, SDK, API, package, protocol, or CLI.
- The goal is usage, syntax, configuration, examples, migration guidance, or version-specific docs.
- The query can be expressed without sending proprietary source, secrets, credentials, customer data, or raw stack traces.
- Freshness does not require today's release/changelog/security state.

Bypass Context7 and use web/search first when:

- The task asks about latest releases, changelogs, CVEs, issue status, maintainer activity, roadmap, pricing, current incidents, or community reports.
- The task requires GitHub issues/PRs, forum threads, package registry data, or release notes.
- The library is missing, low-reputation, low-snippet, ambiguous, or unpinned when version matters.
- The answer depends on installed local tool schemas rather than public documentation.
```

## 1.7 Topic 7 still-open empirical closure

To fully close topic 7, qdev needs a local coverage/freshness matrix over the real library set.

Minimum library set:

```yaml
python:
  - FastAPI
  - Pydantic
  - pydantic-settings
  - pytest
  - uv
  - ruff
  - pyright
  - SQLAlchemy
  - Home Assistant
mcp_ai:
  - Model Context Protocol
  - Anthropic Claude Code
  - OpenAI Codex CLI
frontend:
  - HTMX
  - React
  - Astro
infra:
  - NetBox
  - Proxmox
  - Tailscale
```

Metrics:

- `resolve_success`: Context7 found an unambiguous library.
- `official_source_present`: official repo/site appears in top results.
- `snippet_count`: count from resolve result.
- `source_reputation`: High/Medium/Low/Unknown.
- `benchmark_score`: Context7 result score.
- `version_pin_available`: version list present or documented version ID works.
- `freshness_visible`: library page/API reports last update or equivalent.
- `latest_release_delta_days`: days between upstream latest release and Context7 visible update, if measurable.
- `answer_quality`: human-judged 0–3 for three fixed questions per library.
- `bypass_reason`: no coverage, stale docs, issue/changelog task, ambiguity, low trust.

---

## 2. Topic 11 — Provider Data Handling and Query Egress

## 2.1 Bottom line

No provider in this stack should receive raw, unsanitized agent context. The correct rule is **provider-specific minimization**, not “sanitize everything” as a vague slogan.

The safest general provider depends on the plan:

- **Brave Search API with enterprise Zero Data Retention enabled** is the strongest privacy posture for web search queries.
- **Context7** sends a smaller, docs-specific payload, but it stores MCP-formulated queries anonymously for benchmarking and uses third-party LLM providers for reranking.
- **Tavily** explicitly collects query data and documents, may use portions of query data to improve future responses unless contractually specified otherwise, and may share query data with third-party search index providers in limited situations.
- **Serper** has the least specific public disclosure about API query handling. Its privacy policy is generic and its terms say the service provides web-scraped data and is not affiliated with Google.

Therefore: do not use query egress as a place to leak raw tool errors, stack traces, full prompts, private code, URLs with tokens, customer data, `.env` values, or machine-local details.

## 2.2 Provider comparison

| Provider | What public policy says | Query reuse / retention signal | Third-party egress signal | qdev risk level for auto-fired raw errors | Recommended rule |
| --- | --- | --- | --- | --- | --- |
| Context7 | MCP sends formulated `query`, `libraryName`/`libraryId`, API key if provided, client info, transport, and encrypted HTTP IP for rate limiting. Full prompt, source code, and conversation stay with the assistant. | MCP-formulated queries are used for server-side LLM reranking and anonymously stored for benchmarking/quality improvement. API logs retained 30 days. Enterprise can disable query storage and use own LLM provider on-prem. | Reranking uses LLM providers including OpenAI, Google Gemini, and Anthropic. | Medium | Use for sanitized docs queries only. Never include proprietary code or raw stack traces. |
| Tavily | Collects query data and uploaded documents; uses them to retrieve relevant internet content. | Unless otherwise specified by contract, may use portions of query data to improve future responses. Retention is “as necessary” under policy. | May share query data with third-party search index providers, e.g. Google, in limited cases when its own index cannot retrieve requested content. | High | Use only sanitized task queries. Avoid raw errors and any sensitive or proprietary content. |
| Brave Search API | API is powered by Brave’s independent index. Brave advertises SOC 2 Type II and enterprise Zero Data Retention. API terms define Search Query Data and require safeguards. | ZDR is available on custom enterprise plans; public Brave Search says it does not collect personal information about searches, but API terms govern API usage. | Brave emphasizes independent index/no scrapers; no need to send queries to Big Tech search for normal API operation. | Low to Medium; Low only with ZDR | Prefer Brave for sensitive-but-allowed web queries if using enterprise ZDR; still sanitize. |
| Serper | Privacy policy says service normally should not lead to personal-data processing; account/system access logs and activity information may be collected. | Public docs do not clearly disclose API query retention/training use. | Terms say Serper is not affiliated with Google and provides web-scraped data from public sources. | High / Unknown | Use for sanitized Google-style operator queries only. Do not send raw errors or private text. |

## 2.3 Provider-specific query rules

### Context7 query hygiene

Allowed:

```text
FastAPI dependency override in pytest with async session
Pydantic v2 model_validator before mode example
MCP tool schema list_changed behavior
```

Disallowed:

```text
Raw traceback with absolute local paths
Private function/class names from unreleased repo
.env contents
JWT/API key/header/token snippets
Customer/project-specific business logic
```

Preferred transform:

```text
Raw: "Traceback ... /home/chris/projects/finances/app/auth.py ... plaid access token ..."
Query: "FastAPI dependency override for authentication in pytest"
```

### Tavily query hygiene

Allowed:

```text
"FastAPI 0.128 release notes dependency injection change"
"uv Python package manager cache behavior CI"
"Claude Code MCP tool schema list changed dynamic discovery"
```

Disallowed:

```text
raw stack traces
private repo file paths when not necessary
customer names
internal hostnames
API keys
tokens
URLs with signed query strings
```

Tavily can route to third-party search index providers in limited situations, so treat it as possibly broader egress than just Tavily.

### Brave query hygiene

Allowed:

```text
"current pytest pyright compatibility Python 3.13"
"brave search mcp server llm_context token limit"
"latest Model Context Protocol specification tools list_changed"
```

Disallowed:

```text
secrets
credential-bearing URLs
customer-specific data
private incident text
full local error logs
```

If enterprise ZDR is available and configured, Brave should be the default provider for sensitive-but-external-allowed web grounding. Without ZDR, still sanitize.

### Serper query hygiene

Allowed:

```text
site:github.com modelcontextprotocol list_changed issue
filetype:pdf FastAPI deployment guide
site:docs.anthropic.com Claude Code skill description
```

Disallowed:

```text
raw error output
anything containing secrets
private repo paths/source
user/customer data
internal hostnames unless intentionally searching them
```

Because Serper is a Google-style/scraper-like API and public policy detail on API query retention is thin, it should be used only for heavily reduced operator-style searches.

## 2.4 Global qdev egress sanitizer

Before any auto-fired external query, run this conceptual sanitizer:

```text
Input: user prompt, tool error, compiler output, logs, traceback, source excerpt.

1. Drop all lines matching likely secrets:
   - API keys, tokens, passwords, bearer headers, cookies, JWTs
   - .env assignments
   - SSH keys or PEM blocks
   - signed URLs or query strings with credential-bearing parameters

2. Drop private identifiers unless needed:
   - absolute local paths
   - internal hostnames
   - private repo names
   - customer/person names
   - account IDs, tenant IDs, database names

3. Collapse stack traces to library/task terms:
   - keep package/framework names
   - keep public error class names
   - keep version numbers
   - keep generic symptom
   - remove project-specific call frames

4. Convert to provider-specific query:
   - Context7: "<library> <API/concept> <task>"
   - Brave/Tavily: "<public technology> <symptom> <current/version/issue>"
   - Serper: add only useful operators (`site:`, `filetype:`, exact phrase, date)
```

Recommended implementation output:

```json
{
	"safe_query": "...",
	"dropped_fields": ["raw_path", "token_like_string", "private_hostname"],
	"provider_allowed": {
		"context7": true,
		"brave": true,
		"tavily": true,
		"serper": false
	},
	"requires_human_approval": false
}
```

Human approval should be required if the sanitizer detects secrets, regulated data, customer data, legal/financial/health context, or proprietary code longer than a tiny symbolic excerpt.

---

## 3. Topics 4–6 — Local Benchmark Harness Spec

Topics 4–6 cannot be completed honestly by web research. They require your installed MCP servers and actual serialized outputs.

The correct deliverable is a local harness that captures the real behavior of your stack.

## 3.1 Harness goals

Measure:

- p50/p95 latency;
- result recall@k;
- precision@k;
- stale-result rate;
- serialized byte size;
- token footprint;
- per-query cost estimate;
- answer quality after grounding;
- failure/error rate.

## 3.2 Query set

Use qdev-representative tasks:

```yaml
library_version_lookup:
  - id: fastapi_latest_dependency_override
    query: 'FastAPI latest docs dependency override pytest async session'
    gold_sources:
      - 'https://fastapi.tiangolo.com/'
  - id: pydantic_v2_settings_env
    query: 'Pydantic v2 settings environment variables nested model'
    gold_sources:
      - 'https://docs.pydantic.dev/'

github_issue_discovery:
  - id: mcp_tool_schema_drift
    query: 'Model Context Protocol MCP tool schema list_changed tool availability issue'
    gold_sources:
      - 'https://github.com/modelcontextprotocol'

changelog_cve:
  - id: ruff_latest_breaking_change
    query: 'ruff latest release breaking changes configuration'
    gold_sources:
      - 'https://github.com/astral-sh/ruff/releases'
      - 'https://docs.astral.sh/ruff/'

docs_site_discovery:
  - id: claude_code_skills_docs
    query: 'Claude Code skills description auto invocation official docs'
    gold_sources:
      - 'https://docs.anthropic.com/'

maintenance_status:
  - id: serper_mcp_maintained
    query: 'marcopesani mcp-server-serper maintained releases commits'
    gold_sources:
      - 'https://github.com/marcopesani/mcp-server-serper'
```

## 3.3 Tool matrix

Run each applicable query through:

```yaml
context7:
  - resolve-library-id
  - query-docs
brave:
  - brave_web_search
  - brave_llm_context
serper:
  - google_search
tavily:
  - tavily_search
  - tavily_extract
```

Do not force tools into domains they are not built for. For example, do not run Context7 for “is this repo maintained?” except as a negative-control test.

## 3.4 Captured record schema

```json
{
	"run_id": "uuid",
	"timestamp_utc": "2026-06-03T00:00:00Z",
	"query_id": "fastapi_latest_dependency_override",
	"provider": "brave",
	"tool": "brave_llm_context",
	"arguments": {},
	"latency_ms": 1234,
	"status": "ok",
	"serialized_bytes": 42000,
	"token_count_o200k": 9800,
	"result_count": 5,
	"urls": [],
	"matched_gold_sources": [],
	"freshness_observations": [],
	"estimated_cost_usd": null,
	"notes": ""
}
```

## 3.5 Token footprint measurement

Measure at three layers:

1. Raw JSON response bytes.
2. Minified JSON bytes.
3. Token count using the same tokenizer you use for planning, preferably `o200k_base` or model-specific equivalent.

For MCP tool output, measure what actually lands in the agent context, not what the API theoretically returns.

## 3.6 `brave_llm_context` comparison

For topic 5, compare these paired workflows:

| Workflow | Steps |
| --- | --- |
| Brave LLM Context | `brave_llm_context(query, maximum_number_of_tokens=8192)` |
| Brave Web + manual read | `brave_web_search(query, count=10)` then extract/open top 3 sources |
| Tavily Search + Extract | `tavily_search(query)` then `tavily_extract(top_urls)` |
| Serper + Extract | `google_search(query)` then `tavily_extract` or `scrape` |

Score:

- completeness;
- factual accuracy;
- citations/source traceability;
- token footprint;
- latency;
- whether prompt-injection exposure is main-context or subagent-contained.

## 3.7 Default benchmark decision thresholds

Initial qdev decision thresholds:

| Metric | Light path target | Medium path target |
| --- | --: | --: |
| p95 latency | < 5 seconds | < 20 seconds |
| serialized token footprint | < 3,000 tokens | any, if isolated in subagent |
| precision@5 | > 0.60 | > 0.75 |
| stale-result rate | < 20% | < 10% |
| source traceability | must include URLs | must include URLs + extracted source text |
| prompt-injection risk | low, summarized output | acceptable if sandboxed/subagent-contained |

If `brave_llm_context` exceeds 5,000 actual serialized tokens in common light-path tasks, it should not be the default light path despite its 8,192-token parameter default.

---

## 4. Updated qdev Routing Decisions

## 4.1 Recommended routing order

```md
1. If named-library/API/SDK/CLI docs question:
   - Use Context7 first, with sanitized query and version pin when available.
   - Bypass Context7 for changelogs, CVEs, issues, maintainer status, or same-day freshness.

2. If general research/current facts:
   - Use Tavily first for source discovery and extraction.
   - Cross-check with Brave.

3. If independent index or vertical search is needed:
   - Use Brave web/news/local/place/image/video/LLM context as appropriate.

4. If Google-like precision or advanced operators matter:
   - Use Serper with `site`, `filetype`, `intitle`, `inurl`, date bounds, exact phrases, and exclusions.

5. If any query is auto-fired from an error:
   - Sanitize first.
   - If sanitizer cannot confidently remove sensitive material, require human approval.
```

## 4.2 Provider ranking for sensitive-but-allowed auto queries

| Rank | Provider | Condition |
| --: | --- | --- |
| 1 | Brave Search API | Only if enterprise ZDR is enabled; otherwise rank lower. |
| 2 | Context7 | Only for sanitized library docs queries; smaller query payload but reranking/storage still applies. |
| 3 | Brave Search API without ZDR | Independent index and strong privacy posture, but still external egress. |
| 4 | Tavily | Useful but policy permits query reuse for response improvement and possible third-party index sharing. |
| 5 | Serper | Least specific query-retention disclosure; use only sanitized operator queries. |

## 4.3 Explicit qdev safety rule

```md
Never send raw Category-A error text directly to external search/docs providers.

Before external lookup:

- redact secrets and credentials;
- remove private paths and hostnames unless they are intentionally searched;
- collapse stack traces into public package names, public error names, and generic symptoms;
- use provider-specific query minimization;
- require human approval when sensitive data is detected.
```

---

## 5. Open Work Remaining

## 5.1 Required local measurements

Still not closable by web research:

- Topic 4: live provider benchmark.
- Topic 5: `brave_llm_context` behavior.
- Topic 6: serialized token footprint.
- Full empirical closure of topic 7 across the complete qdev library set.

## 5.2 Suggested artifact outputs

Persist benchmark outputs under:

```text
docs/research/qdev/benchmarks/
  provider-query-set.yaml
  provider-benchmark-results.jsonl
  token-footprint-results.jsonl
  context7-coverage-matrix.jsonl
  benchmark-summary.md
```

## 5.3 Stop condition

Do not keep researching this abstractly. The architecture is now research-informed enough to implement the harness. Further confidence requires measurements from your actual MCP installation.

---

## Sources

[^context7-overview]: Context7 Docs, “Intro.” <https://context7.com/docs/overview>

[^context7-refresh]: Context7 Docs, “Keeping Libraries Fresh.” <https://context7.com/docs/library-updates>

[^context7-api]: Context7 Docs, “API Guide.” <https://context7.com/docs/api-guide>

# Search MCP Routing Strategy: Serper, Tavily, and Brave

**Prepared for:** Chris Purcell **Prepared on:** 2026-06-03 **Status:** Final merged report after correction, gap analysis, and additional research **Scope:** This report covers only the three MCP servers currently in use:

- `marcopesani/mcp-server-serper`
- `tavily-ai/tavily-mcp`
- `brave/brave-search-mcp-server`

This document merges the two prior reports, removes claims that were unsupported or overstated, and closes the identified gaps with current upstream research. The goal is not to pick one universal winner. The right architecture is a multi-provider search stack with deterministic routing rules so Claude Code, Codex, and other agents choose the correct search domain on the first pass.

---

## Executive Summary

Use the three servers as complementary tools:

1. **Tavily** should be the default **agentic research, extraction, mapping, and crawling** server.
2. **Brave** should be the default **independent-index, vertical-search, news/local/media, LLM-context, and summarization** server.
3. **Serper** should be the default **Google-style SERP and advanced-operator** server.

The stack is strong because the services fail differently. Tavily is optimized for LLM-oriented search and downstream retrieval. Brave provides a separate independent web index plus dedicated vertical tools. Serper provides Google-shaped results, Google-style query operators, and a lightweight scrape tool.

Recommended default policy:

- Start with **Tavily** for general research and known-URL extraction.
- Cross-check with **Brave** for important factual claims, freshness, source diversity, news, local/place, images, video, and LLM-ready context.
- Use **Serper** when Google-like ranking, `site`, `filetype`, `intitle`, `inurl`, exact phrase matching, date bounds, PDF/manual discovery, or long-tail technical discovery matter.
- For important factual answers, use **at least two independent providers** before finalizing. The default pair should be Tavily + Brave. Add Serper when the query is operator-heavy, Google-ranking-sensitive, or long-tail.

---

## What Was Wrong or Incomplete in the Prior Reports

The two prior drafts had useful material, but also several issues that needed correction.

| Issue | Prior problem | Resolution in this final report |
| --- | --- | --- |
| Tavily `tavily_research` | The first report elevated `tavily_research` into normal routing. The corrected report demoted it too far in some places. | Final stance: `tavily_research` is present in the current `main` source and Tavily has a public Research API endpoint, but Tavily's README still summarizes the MCP server as search/extract/map/crawl and the docs feature text emphasizes search/extract. Use it only when your installed MCP schema exposes it. |
| Tavily docs/source mismatch | The reports did not fully explain that Tavily's README, MCP docs page, API docs, and current source are not perfectly aligned. | Added an evidence-tier model: public README, MCP docs page, current source, and API docs. Durable routing should rely on confirmed installed tool schema. |
| Brave image output | The earlier reports noted the contradiction but did not make it operational enough. | Final stance: the v2 migration note controls for v2.x installs: v2 removed base64 image payloads. Treat the lower README text saying automatic base64 fetching as stale. |
| Serper source comment | The raw source contains an outdated comment saying it exposes a single `webSearch` tool. | Final stance: ignore the stale comment; the actual `ListTools` schema exposes `google_search` and `scrape`. |
| Serper verticals | The earlier stronger report correctly noted that Serper's platform has many verticals, but the linked MCP wrapper exposes only two tools. | Final stance: do not assume Serper Images/News/Shopping/Scholar/Patents are available through `marcopesani/mcp-server-serper`; they are not exposed by this wrapper. |
| Package/install identity | Tavily docs mention `@tavily/mcp`, while the GitHub README and package JSON show `tavily-mcp`. | Final stance: use the installation method already working in your environment; for durable docs, record both the repo and the actual installed command/package. Verify with `/mcp` or MCP Inspector. |
| Evidence vs generated summaries | The prior reports mentioned this but did not integrate it into routing. | Final stance: generated summaries and research tools are orientation tools. Final answers should be grounded in source-level search/extract results for load-bearing claims. |

---

## Evidence Tiers and Trust Model

Because MCP projects move quickly, treat the exposed tool schema as the source of truth for a given installation.

**Tier 1: Installed MCP schema** The live tools shown by Claude Code `/mcp`, MCP Inspector, or the client tool registry are authoritative for the local environment.

**Tier 2: Current upstream source** Useful for detecting newly added tools and parameters, but not always equivalent to the deployed remote server or published package.

**Tier 3: README and provider docs** Good for intended use and public behavior, but can lag behind source or contain stale sections.

**Tier 4: Provider platform docs** Useful for understanding the underlying API, but not every platform endpoint is exposed by a specific MCP wrapper.

This matters most for Tavily and Brave. Tavily's current source exposes `tavily_research`, but public README/tool summary emphasizes search/extract/map/crawl. Brave's README has both a v2 migration note saying base64 image payloads were removed and a lower tool section still saying image search performs automatic base64 fetching.

---

## Current Server Inventory

| Server | Package / install identity | Primary transport notes | Current visible maturity signals | Primary job |
| --- | --- | --- | --- | --- |
| `marcopesani/mcp-server-serper` | README config uses NPM package `serper-search-scrape-mcp-server`; source server name is `Serper MCP Server` version `0.1.0`.[^serper-readme][^serper-source] | STDIO server; Docker instructions are also present.[^serper-readme] | GitHub page showed 154 stars, 22 forks, 23 commits, and no releases at time of review.[^serper-repo] | Google-like SERP search and lightweight webpage scrape. |
| `tavily-ai/tavily-mcp` | GitHub README uses `npx -y tavily-mcp@latest`; package JSON name is `tavily-mcp` version `0.2.20`; Tavily docs page labels NPM as `@tavily/mcp`, creating an install-identity mismatch to verify locally.[^tavily-readme][^tavily-package][^tavily-docs] | Remote MCP URL supported; local STDIO via NPX also supported; OAuth is supported for compatible remote MCP clients.[^tavily-docs] | GitHub page showed 2.1k stars; current source lists `tavily_search`, `tavily_extract`, `tavily_crawl`, `tavily_map`, and `tavily_research`.[^tavily-readme][^tavily-source] | Agentic search, URL extraction, site mapping, bounded crawling, and optional research synthesis if exposed. |
| `brave/brave-search-mcp-server` | Package JSON name is `@brave/brave-search-mcp-server`, version `2.0.82`; GitHub release panel showed `v2.0.83` as latest on 2026-06-01.[^brave-package][^brave-repo] | STDIO is the default in v2.x; HTTP remains available via environment variable or CLI transport flag.[^brave-readme] | GitHub page showed 1.1k stars, 169 forks, 564 commits, 95 releases, and latest `v2.0.83` on 2026-06-01.[^brave-repo] | Independent-index search plus web/local/place/image/video/news/LLM-context/summarization. |

---

## Tool Catalog and Preferred Use

### 1. Serper MCP: `marcopesani/mcp-server-serper`

#### Tool surface

The linked Serper MCP wrapper exposes two tools:

- `google_search`
- `scrape`

The README lists those same two tools, and the current source's `ListTools` schema confirms `google_search` and `scrape` even though an older nearby code comment says "single webSearch tool." Treat the schema and README as authoritative, not the stale comment.[^serper-readme][^serper-source]

#### `google_search`

**Primary purpose:** Google-style web search through Serper.

The README describes `google_search` as returning rich search results, including organic results, knowledge graph, "People Also Ask," and related searches. It supports region/language targeting, optional location, pagination, time filters, autocorrection, and advanced search operators including `site`, `filetype`, `inurl`, `intitle`, `related`, `cache`, `before`, `after`, `exact`, `exclude`, and `or`.[^serper-readme]

The source schema requires `q`, `gl`, and `hl`, so agent instructions should always specify region and language explicitly rather than relying on implied defaults.[^serper-source]

Use `google_search` when:

- Google-like result ordering matters.
- You need precise search syntax.
- You need `site`, `filetype`, `intitle`, `inurl`, `before`, `after`, exact phrase, exclusion, or OR-style terms.
- You are hunting PDFs, manuals, standards, vendor docs, GitHub issues, forum threads, changelogs, old docs, or obscure long-tail pages.
- Tavily or Brave misses an expected result.

Avoid using it as the default when:

- The task needs multi-page extraction or crawling.
- The user asks for local/place/media/news-specific results and Brave has a dedicated tool.
- You already know the URLs and only need structured extraction; use Tavily Extract first.

Practical defaults:

```json
{ "gl": "us", "hl": "en", "num": 10, "autocorrect": true }
```

Operator-heavy examples:

```json
{
	"q": "equipment breakdown risk control guide",
	"gl": "us",
	"hl": "en",
	"filetype": "pdf",
	"after": "2022-01-01"
}
```

```json
{
	"q": "netbox nautobot plugin lifecycle",
	"gl": "us",
	"hl": "en",
	"site": "github.com"
}
```

#### `scrape`

**Primary purpose:** Lightweight extraction from a known URL.

The README says `scrape` retrieves text and optional markdown content, includes JSON-LD and head metadata, and preserves document structure.[^serper-readme] The source schema requires `url` and optionally accepts `includeMarkdown`.[^serper-source]

Use `scrape` when:

- A URL came directly from Serper and a quick extraction is enough.
- Metadata such as JSON-LD/head data is useful.
- Tavily Extract is unavailable or excessive for the task.

Prefer Tavily Extract when:

- Multiple URLs must be processed.
- You need stronger extraction-depth controls.
- You need markdown/text choice, image inclusion, favicon inclusion, or query-reranked extraction.
- The answer requires source-level confidence.

#### Serper platform vs this MCP wrapper

Serper's platform advertises Search, Images, News, Maps, Places, Videos, Shopping, Scholar, Patents, and Autocomplete endpoints.[^serper-platform] The linked `marcopesani` MCP wrapper does **not** expose those vertical endpoints. Do not write agent instructions that assume Serper image/news/shopping/scholar/patent tools are available unless you switch to a broader Serper MCP wrapper.

---

### 2. Tavily MCP: `tavily-ai/tavily-mcp`

#### Tool surface: evidence-tiered view

Tavily is the trickiest server because the evidence layers differ:

- Tavily's GitHub README says the MCP server provides **search, extract, map, crawl** tools.[^tavily-readme]
- Tavily's MCP docs page identifies the GitHub repo and NPM identity, describes remote/local setup, and its feature summary emphasizes `tavily-search` and `tavily-extract`.[^tavily-docs]
- Current `main` source exposes five tools: `tavily_search`, `tavily_extract`, `tavily_crawl`, `tavily_map`, and `tavily_research`.[^tavily-source]
- Tavily's public API docs document separate Search, Extract, Map, Crawl, and Research endpoints.[^tavily-search-api][^tavily-extract-api][^tavily-map-api][^tavily-crawl-api][^tavily-research-api]

**Operational rule:** Use `tavily_search`, `tavily_extract`, `tavily_map`, and `tavily_crawl` in durable instructions. Add `tavily_research` only if your installed MCP client actually lists it.

#### `tavily_search`

**Primary purpose:** Default LLM-oriented web research and source discovery.

Current source exposes parameters including `query`, `search_depth`, `topic`, `time_range`, `start_date`, `end_date`, `max_results`, `include_images`, `include_image_descriptions`, `include_raw_content`, `include_domains`, `exclude_domains`, `country`, `include_favicon`, and `exact_match`.[^tavily-source]

Tavily API docs describe `search_depth` and usage behavior, including the note that explicitly setting `search_depth` to `basic` avoids the extra cost of automatic selection.[^tavily-search-depth] The API docs show `auto_parameters` containing `topic` and `search_depth` in responses.[^tavily-search-depth] Current MCP source enumerates only `topic: general`, so do not depend on `topic: news` or `topic: finance` via MCP unless your installed schema confirms it.[^tavily-source]

Use it when:

- The task is general research.
- You need current web facts but not Google-specific ranking.
- You want good snippets and URLs for follow-up extraction.
- You need include/exclude domain controls.
- You want a first pass before independent validation through Brave.

Default parameters:

```json
{
	"search_depth": "basic",
	"max_results": 5,
	"include_raw_content": false,
	"include_images": false,
	"include_favicon": true
}
```

Escalate when:

- Use `search_depth: advanced` for niche, technical, or low-recall searches.
- Use `max_results: 10` when comparing sources or building a source set.
- Use `include_raw_content: true` only when snippets are insufficient and you intentionally want search to retrieve page content without a separate extraction call.

#### `tavily_extract`

**Primary purpose:** Extract content from known URLs.

The MCP source exposes `urls`, `extract_depth`, `include_images`, `format`, `include_favicon`, and `query`.[^tavily-source] Tavily's Extract API docs describe `extract_depth`, chunk behavior when `query` is provided, and timeout behavior based on extraction depth.[^tavily-extract-api]

Use it when:

- You already have one or more URLs.
- Search snippets are not enough.
- You need article/docs content in markdown or text.
- You want to rerank extracted content by a query.
- You need source-level extraction for citations or final claims.

Preferred pattern:

1. Use Tavily Search, Brave Web Search, Brave News Search, or Serper Search to discover URLs.
2. Use Tavily Extract on the URLs that look authoritative.
3. Cite or summarize from extracted page content, not just snippets.

#### `tavily_map`

**Primary purpose:** Discover a website's URL structure.

The MCP source exposes `url`, `max_depth`, `max_breadth`, `limit`, `instructions`, `select_paths`, `select_domains`, and `allow_external`.[^tavily-source] Tavily's Map API docs describe `url` as the required root URL and note `max_depth` defaults to 1.[^tavily-map-api]

Use it when:

- You need to understand a docs site.
- You are looking for API reference, guides, changelogs, installation docs, or examples.
- You want to select relevant URLs before extracting content.
- A site has poor search or poor navigation.

Preferred pattern:

1. `tavily_map` the docs root with a low `limit`.
2. Filter for useful paths such as `/docs/`, `/api/`, `/reference/`, `/guides/`, `/changelog/`.
3. Use `tavily_extract` on selected URLs.
4. Use `tavily_crawl` only if too many relevant pages need extraction.

#### `tavily_crawl`

**Primary purpose:** Bounded multi-page crawl and extraction.

The MCP source exposes `url`, `max_depth`, `max_breadth`, `limit`, `instructions`, `select_paths`, `select_domains`, `allow_external`, `extract_depth`, `format`, and `include_favicon`.[^tavily-source] Tavily's Crawl API docs describe `max_depth` with default 1 and chunk controls when instructions are provided.[^tavily-crawl-api]

Use it when:

- The task is explicitly site-wide.
- You need content from many pages under a bounded area.
- You need to ingest a docs section, guide set, or small knowledge base.

Avoid it when:

- You only need one known page.
- You only need URL discovery; use `tavily_map`.
- The site is large and the task is not bounded by path/domain instructions.

Safe defaults:

```json
{
	"max_depth": 1,
	"max_breadth": 10,
	"limit": 20,
	"allow_external": false,
	"extract_depth": "basic",
	"format": "markdown"
}
```

#### `tavily_research`

**Primary purpose:** Optional long-form research synthesis if exposed by the installed MCP schema.

Current `main` source defines `tavily_research` with `input` and `model` values of `mini`, `pro`, or `auto`.[^tavily-source] Tavily's Research API docs describe a research task endpoint where the `input` is required and `model` defaults to `auto`, with `mini` intended for narrower targeted research and `pro` for comprehensive multi-angle research.[^tavily-research-api]

Use it when:

- Your installed MCP schema lists it.
- The task is broad and exploratory.
- You want a fast first-pass research brief.
- You need help identifying subtopics before doing source-level verification.

Do **not** use it as final evidence when:

- Exact wording matters.
- The answer is technical, legal, medical, financial, or high-stakes.
- The final deliverable needs source-by-source support.

Operational caveat:

- Durable project instructions should say: "Use `tavily_research` only if the installed MCP client lists it; verify load-bearing claims with source-level search/extract results."

---

### 3. Brave Search MCP: `brave/brave-search-mcp-server`

The Brave README describes the server as integrating Brave Search API capabilities including web search, local business search, place search, image search, video search, news search, LLM context, and AI-powered summarization. It supports STDIO and HTTP transports, with STDIO as the default mode in v2.x.[^brave-readme]

Brave's Search API page describes the API as powered by Brave's own independent web index and says the API is used for search products, AI search engines, AI training, and agentic search.[^brave-api-independent]

#### `brave_web_search`

**Primary purpose:** Independent-index web search and cross-checking.

The README describes `brave_web_search` as comprehensive web search with rich result types and advanced filtering. Parameters include query, country, search language, UI language, count, offset, SafeSearch, freshness, text decorations, spellcheck, result filters, Goggles, units, extra snippets, and summary key generation.[^brave-web]

Use it when:

- You need an independent index to check Tavily or Serper.
- You need general current web search.
- You want freshness controls.
- You want to generate a summary key for `brave_summarizer`.
- You want Brave Goggles/custom reranking.
- You want to avoid relying only on Tavily's agentic search result selection.

Default cross-check parameters:

```json
{
	"count": 10,
	"country": "US",
	"search_lang": "en",
	"ui_lang": "en-US",
	"safesearch": "moderate",
	"spellcheck": true
}
```

#### `brave_local_search`

**Primary purpose:** Local business search.

The README says local search finds local businesses and places with detailed information including ratings, hours, and AI-generated descriptions, but notes that full local search capabilities require a Pro plan and otherwise fall back to web search.[^brave-local]

Use it when:

- The user asks for businesses, services, restaurants, stores, contractors, or local entities.
- Location is part of the query but exact coordinates are not available.
- Broad local/web blending is acceptable.

Caveat:

- Verify critical details such as hours, safety issues, pricing, and availability on the business's own site when possible.

#### `brave_place_search`

**Primary purpose:** Structured point-of-interest search.

The README describes this as searching POIs in a specified geographic area and returning structured data such as name, address, opening hours, contact info, ratings, photos, categories, and timezone.[^brave-place]

Use it when:

- Latitude/longitude or a clear location string is available.
- Structured place data matters.
- The question is about POIs rather than general local web results.

Prefer it over `brave_local_search` when the search is explicitly geographic or POI-oriented.

#### `brave_news_search`

**Primary purpose:** Current news search.

The README describes news search as returning current news articles with freshness controls and breaking-news indicators. The tool section lists `freshness` with default `pd`, meaning last 24 hours.[^brave-news]

Use it when:

- The user asks for latest/current/recent news.
- Publish date matters.
- The answer needs multiple current sources.
- The query is news-native rather than general web research.

Preferred news pattern:

1. `brave_news_search` for recent article discovery.
2. `tavily_search` for broader context or non-news sources.
3. `google_search` with `after`/`before` if Google-like ranking or exact operators matter.
4. Compare event date, publish date, and update date before finalizing.

#### `brave_image_search`

**Primary purpose:** Visual search.

There is an important README conflict. The v2 migration note says version 1.x returned base64 image data and version 2.x removed base64 data to reduce latency and context consumption.[^brave-readme] A lower image-search section still says `brave_image_search` performs automatic fetching and base64 encoding.[^brave-image-stale]

For v2.x installs, treat the v2 migration note as controlling.

Use it when:

- Visual confirmation matters.
- You need photos, diagrams, screenshots, logos, maps, UI references, product imagery, or visual examples.
- The search domain is visual rather than text-first.

Caveat:

- Image search results do not grant reuse rights. Check source/licensing before using images in published materials.

#### `brave_video_search`

**Primary purpose:** Video discovery.

The README describes video search as returning videos with comprehensive metadata and thumbnail information and supports freshness controls.[^brave-video]

Use it when:

- The likely best source is a tutorial, demo, conference talk, walkthrough, interview, or review.
- The user asks for video resources.
- A tool demonstration is better shown than described.

Caveat:

- For technical instructions, treat video as discovery. Verify details against primary docs, transcripts, or source text before treating the answer as authoritative.

#### `brave_llm_context`

**Primary purpose:** LLM-grounding context and RAG-style snippets.

The README describes this tool as retrieving pre-extracted web content optimized for AI agents, LLM grounding, and RAG pipelines.[^brave-llm]

Use it when:

- You need LLM-ready context quickly.
- You want multiple source snippets without manually extracting each page.
- You are building a grounded answer or RAG-style context set.
- You need breadth more than exact page reproduction.

Avoid it when:

- Exact wording matters.
- You need tables, code blocks, legal language, or primary-source quotes.
- You need full-page extraction; use `tavily_extract` instead.

#### `brave_summarizer`

**Primary purpose:** Brave-generated answer from a web search summary key.

The README says this requires a summary key from `brave_web_search` with `summary: true`, then calls Brave's summarization API. It can include entity information and inline references.[^brave-summarizer]

Use it when:

- You want a quick Brave-generated first-pass summary.
- You already performed `brave_web_search` with `summary: true`.
- You want to compare Brave's answer against your own synthesis.

Avoid it when:

- The answer is high-stakes.
- You have not inspected the underlying sources.
- You need exact source text.

---

## Search Domain Comparison

| Search domain / task | Preferred server/tool | Secondary server/tool | Avoid / caution | Rationale |
| --- | --- | --- | --- | --- |
| General current web research | Tavily `tavily_search` | Brave `brave_web_search` | Serper as default | Tavily is optimized around agentic web search and downstream extraction. Brave is the best independent-index cross-check. |
| Independent cross-check | Brave `brave_web_search` | Serper `google_search` | Tavily-only finalization | Brave uses an independent web index, which is valuable for provider diversity. |
| Google-like SERP behavior | Serper `google_search` | Brave `brave_web_search` | Tavily | Serper is explicitly a Google Search API provider; this wrapper exposes Google-style search and SERP fields. |
| Advanced search operators | Serper `google_search` | Brave web where supported | Tavily | Serper exposes operator parameters directly in the MCP schema. |
| PDF/manual/standards discovery | Serper `google_search` | Brave `brave_web_search` | Tavily as first choice | `filetype` and `site` controls are the clearest fit. |
| Domain-bounded research | Tavily `tavily_search` include/exclude domains | Serper `site` | Brave if exact domain operators matter | Tavily handles include/exclude domains; Serper is better for Google-style `site` search. |
| Known URL extraction | Tavily `tavily_extract` | Serper `scrape` | Brave LLM context if exact content matters | Tavily Extract is a first-class extraction endpoint; Serper scrape is lightweight. |
| Website structure discovery | Tavily `tavily_map` | Serper `site` search | Brave/Serper as crawlers | Tavily Map is purpose-built to discover URLs from a root site. |
| Multi-page site crawl | Tavily `tavily_crawl` | Tavily Map + Extract | Brave/Serper | Tavily Crawl is purpose-built for bounded crawl/extract workflows. |
| News/current events | Brave `brave_news_search` | Tavily `tavily_search` | Serper as only source | Brave has a dedicated news endpoint with freshness controls. |
| Local businesses | Brave `brave_local_search` | Brave `brave_place_search` | Tavily | Brave has a local-business tool; full local capability is plan-dependent. |
| POI/geospatial | Brave `brave_place_search` | Brave `brave_local_search` | Tavily | Place search returns structured POI-style data. |
| Images | Brave `brave_image_search` | Tavily search with images | Current Serper wrapper | Brave has the dedicated image endpoint. Current linked Serper MCP does not expose Serper Images. |
| Video | Brave `brave_video_search` | Brave web search | Tavily | Brave has the dedicated video endpoint. |
| LLM/RAG context | Brave `brave_llm_context` | Tavily Search + Extract | Serper scrape alone | Brave LLM Context is designed for AI grounding and RAG-style context. |
| AI summary | Brave `brave_summarizer` | Tavily Research if exposed | Summarizer as sole evidence | Summaries accelerate orientation but should not replace source-level verification. |
| Long-form exploratory brief | Tavily `tavily_research` if exposed | Tavily Search + Extract | Durable dependency without schema check | Research is in current source and API docs, but not the README's stable tool summary. |

---

## Preferred Routing Policy

### Default route: Tavily first

Use Tavily first when the request is broad, research-oriented, or needs source discovery.

Use `tavily_search` for:

- "Research this."
- "Find current information."
- "Compare these technologies."
- "Find documentation."
- "What are people doing today?"
- "Find sources about this topic."

Then use `tavily_extract` for the most relevant URLs.

### Cross-check route: Brave second

Use Brave as the normal second provider for important claims.

Use `brave_web_search` when:

- Tavily results seem narrow.
- The topic is current or contested.
- You need a second independent index.
- You want source diversity before finalizing.
- The final answer would be fragile if based on one provider.

Use Brave vertical tools directly when the domain is clear:

- News: `brave_news_search`
- Local businesses: `brave_local_search`
- POIs: `brave_place_search`
- Images: `brave_image_search`
- Videos: `brave_video_search`
- LLM-ready grounding: `brave_llm_context`
- AI summary after web search: `brave_summarizer`

### Operator route: Serper when query shape matters

Use Serper when the task depends on precise search syntax or Google-like ranking.

Use `google_search` when:

- The task needs `site`, `filetype`, `inurl`, `intitle`, `before`, `after`, exact phrase, exclusion, or OR-style terms.
- You are searching PDFs/manuals/docs/standards.
- You are hunting GitHub issues, forum posts, changelogs, or old docs.
- You expect Google-like ranking to matter.
- You need to verify whether a source appears in Google-shaped results.

Use `scrape` after Serper only when simple extraction is enough; otherwise pass the found URL to Tavily Extract.

---

## Tool Use Strategies

### Strategy 1: Normal technical research

Use this for most technical or current factual research.

1. `tavily_search` with `search_depth: basic` and `max_results: 5`.
2. `tavily_extract` on the most relevant primary sources.
3. `brave_web_search` to cross-check independent index coverage.
4. `google_search` only if the result set is incomplete, long-tail, or operator-heavy.

### Strategy 2: Exact-source discovery

Use this when the likely answer is buried in docs, PDFs, GitHub, changelogs, forums, or standards.

1. `google_search` with only the needed operators.
2. `tavily_extract` selected URLs for content.
3. `brave_web_search` to check whether Brave surfaces better or newer sources.

### Strategy 3: Current news/event validation

Use this when publish dates matter.

1. `brave_news_search` with freshness controls.
2. `tavily_search` with explicit date range or time range if useful.
3. `google_search` with `after`/`before` when necessary.
4. Compare event date, publish date, and update date before writing the final answer.

### Strategy 4: Documentation site analysis

Use this when an agent needs to understand a docs site.

1. `tavily_map` the docs root.
2. Select pages matching `/docs/`, `/api/`, `/reference/`, `/guides/`, `/changelog/`, or project-specific patterns.
3. `tavily_extract` selected pages.
4. Use `tavily_crawl` only if mapping reveals too many relevant pages to extract manually.
5. Use `google_search site:docs.example.com` when the docs site's navigation is poor.

### Strategy 5: Local/place search

Use this for contractors, restaurants, stores, services, POIs, and local research.

1. `brave_place_search` if coordinates/geographic area are known.
2. `brave_local_search` if the task is business/service oriented but coordinates are not known.
3. `brave_web_search` or Serper `google_search` to verify the entity's own website.
4. Do not rely on search snippets alone for hours, pricing, availability, or safety-critical details.

### Strategy 6: Visual/video discovery

Use this for diagrams, photos, UI screenshots, product images, logos, and historical/location/animal/person visual references.

1. `brave_image_search` or `brave_video_search` depending on media type.
2. `brave_web_search` for source pages and context.
3. `google_search` if exact source discovery needs Google-like ranking.
4. Check usage rights before reusing any image.

### Strategy 7: Long-form exploratory research

Use this only if `tavily_research` is exposed by the installed schema.

1. `tavily_research` with `model: mini` for narrow questions or `model: pro` for broad multi-angle topics.
2. Extract the load-bearing URLs or claims from the synthesis.
3. Verify those claims with `tavily_search`/`tavily_extract`, `brave_web_search`, or `google_search`.
4. Do not cite the generated synthesis itself as final evidence unless the workflow explicitly allows generated summaries as sources.

---

## Practical Defaults

### Tavily defaults

```json
{
	"search_depth": "basic",
	"max_results": 5,
	"include_raw_content": false,
	"include_images": false,
	"include_favicon": true
}
```

Escalate to:

```json
{ "search_depth": "advanced", "max_results": 10, "include_raw_content": false }
```

Use `include_raw_content: true` only when you need page content and do not want a separate extract call.

### Tavily Map/Crawl defaults

```json
{ "max_depth": 1, "max_breadth": 10, "limit": 20, "allow_external": false }
```

Use `instructions`, `select_paths`, and `select_domains` whenever possible to constrain the crawl.

### Brave defaults

For general cross-checking:

```json
{
	"count": 10,
	"country": "US",
	"search_lang": "en",
	"ui_lang": "en-US",
	"safesearch": "moderate",
	"spellcheck": true
}
```

For news:

```json
{ "count": 10, "country": "US", "search_lang": "en", "freshness": "pd" }
```

For LLM grounding:

```json
{
	"count": 10,
	"maximum_number_of_urls": 5,
	"maximum_number_of_tokens": 8192,
	"context_threshold_mode": "balanced"
}
```

### Serper defaults

Always specify region and language explicitly.

```json
{ "gl": "us", "hl": "en", "num": 10, "autocorrect": true }
```

For precise discovery, add only the operator controls needed. Avoid stacking too many operators at once unless intentionally narrowing a large result set.

---

## Comprehensive Gap Analysis

| Gap | Why it matters | Research finding | Status | Operational action |
| --- | --- | --- | --- | --- |
| Tavily `tavily_research` availability | Incorrect routing could tell agents to call a tool not exposed in a given install. | Current source exposes `tavily_research`; README summarizes search/extract/map/crawl; Tavily API docs document a Research endpoint. | Partially closed | Include as optional and schema-dependent. Confirm with `/mcp` before using in durable instructions. |
| Tavily docs vs package identity | Install instructions may drift or differ between remote/local setups. | GitHub README uses `tavily-mcp@latest`; package JSON name is `tavily-mcp`; Tavily docs page labels NPM as `@tavily/mcp` while also showing `tavily-mcp` local commands. | Partially closed | Document the actually installed command in your project. Do not assume docs labels equal package name. |
| Tavily API vs MCP parameter mismatch | API docs may list parameters not exposed by MCP. | API docs show broader topic concepts; current MCP source enumerates only `topic: general`. | Closed for routing | Do not route Tavily MCP by `topic: news` or `topic: finance` unless installed schema confirms support. |
| Serper platform verticals vs wrapper surface | Agents might assume Serper Images/News/Scholar are available. | Serper platform advertises many verticals; `marcopesani` MCP exposes only `google_search` and `scrape`. | Closed | Route images/news/local/video to Brave; use Serper only for Google-style web search and scrape. |
| Serper stale source comment | Could mislead an audit into thinking only one tool exists. | Actual ListTools schema exposes `google_search` and `scrape`; README agrees. | Closed | Ignore stale "single webSearch" comment. |
| Serper required `gl`/`hl` | Agents may omit region/language and fail. | Source marks `q`, `gl`, and `hl` as required. | Closed | Always include `gl: us`, `hl: en` unless another locale is intended. |
| Serper release hygiene | Lack of releases affects pinning strategy. | GitHub page shows no releases. | Closed | Pin the NPM package version/lockfile rather than relying on GitHub releases. |
| Brave image output conflict | A model could expect base64 image payloads and waste context or handle output incorrectly. | v2 migration note says base64 removed; lower README image section still says automatic base64 fetching. | Closed | For v2.x, treat base64 as removed. |
| Brave local-search plan dependency | Agents may rely on local output quality without the right plan. | README says full local search requires Pro plan and falls back to web search otherwise. | Closed | Treat local results as plan-dependent; verify with primary sites. |
| Brave package version vs latest release | Can confuse upgrade/pinning. | Package JSON shows `2.0.82`; GitHub release panel showed `v2.0.83` latest. | Closed | Pin via package manager; check installed version separately from GitHub release panel. |
| Summarizer/research evidence quality | Generated answers can hide source selection errors. | Brave summarizer depends on a summary key from web search; Tavily Research is a synthesis endpoint. | Closed | Use summaries for orientation; verify load-bearing claims with source-level search/extract. |
| Search freshness vs fact freshness | Recent search results can describe old facts. | Brave offers freshness controls and recent-event coverage; still, result freshness is not event freshness. | Closed | For news/current events, compare event date, publish date, update date, and source reliability. |
| Agent determinism | Without routing rules, agents may randomly pick a provider. | Three servers overlap but optimize different domains. | Closed | Use the agent instruction block below. |

---

## Recommended Agent Instructions

```md
## Web Search MCP Routing

Use Tavily as the default research MCP. Prefer `tavily_search` for general web research, current facts, technical research, and source discovery. Use `tavily_extract` for known URLs that need full content. Use `tavily_map` before `tavily_crawl` when exploring documentation or website structure. Use `tavily_crawl` only for bounded multi-page extraction.

Use `tavily_research` only if the installed MCP client lists it as available. If available, use it for broad exploratory briefs, not final evidence. Verify important claims with source-level search and extraction before finalizing.

Use Brave as the independent-index and vertical-search MCP. Prefer `brave_web_search` as the second opinion for important factual claims. Use `brave_news_search` for news/current events, `brave_place_search` or `brave_local_search` for places and businesses, `brave_image_search` for visual discovery, `brave_video_search` for video discovery, `brave_llm_context` for RAG-style grounding, and `brave_summarizer` only after a web search has produced a summary key.

Use Serper as the Google-style SERP and advanced-operator MCP. Prefer `google_search` when Google-like ranking matters or when using `site`, `filetype`, `intitle`, `inurl`, `before`, `after`, exact phrase, exclusion, or OR-style terms. Use Serper for PDFs, manuals, standards, GitHub issue discovery, forum threads, changelogs, and obscure long-tail pages. Always pass `gl` and `hl`; default to `gl: us` and `hl: en` unless another locale is intended. Use Serper `scrape` only for lightweight extraction of known URLs; prefer `tavily_extract` for richer extraction.

For important factual answers, use at least two independent providers before finalizing. Default to Tavily + Brave. Add Serper when the query is operator-heavy, long-tail, technical, or likely to depend on Google-style indexing.

Do not treat snippets as final evidence when exact wording matters. Extract or open the source page. For news, compare publish date, update date, and event date. For local/place results, verify critical details on the entity's own website when possible.
```

---

## Final Recommendation

Keep all three MCP servers. The stack is well-balanced as long as agents have explicit routing rules.

- **Tavily:** default research, extraction, mapping, crawling, and optional broad synthesis when `tavily_research` is installed.
- **Brave:** independent-index validation, news, local/place, images, video, LLM-context, and summarization.
- **Serper:** Google-like SERP behavior, exact/operator-heavy search, PDFs/manuals/docs/GitHub/forum discovery, and lightweight scrape.

The main improvement is not adding another MCP server. It is making the routing deterministic enough that Claude Code and Codex choose the right search domain on the first pass and know when to cross-check.

---

## Sources

[^serper-repo]: GitHub, `marcopesani/mcp-server-serper`, repository metadata showing stars, forks, commits, and no releases. https://github.com/marcopesani/mcp-server-serper

[^serper-readme]: GitHub README, `marcopesani/mcp-server-serper`, tools and installation sections. https://github.com/marcopesani/mcp-server-serper

[^serper-source]: GitHub raw source, `marcopesani/mcp-server-serper/src/index.ts`, tool schemas for `google_search` and `scrape`. https://raw.githubusercontent.com/marcopesani/mcp-server-serper/main/src/index.ts

[^serper-platform]: Serper homepage, advertised Google Search API and endpoint categories. https://serper.dev/

[^tavily-readme]: GitHub README, `tavily-ai/tavily-mcp`, tool summary and remote/local setup. https://github.com/tavily-ai/tavily-mcp

[^tavily-docs]: Tavily Docs, Tavily MCP Server documentation, remote/local setup, OAuth, defaults, and local examples. https://docs.tavily.com/documentation/mcp

[^tavily-package]: GitHub raw source, `tavily-ai/tavily-mcp/package.json`, package metadata. https://raw.githubusercontent.com/tavily-ai/tavily-mcp/main/package.json

[^tavily-source]: GitHub raw source, `tavily-ai/tavily-mcp/src/index.ts`, current MCP tool definitions and schemas. https://raw.githubusercontent.com/tavily-ai/tavily-mcp/main/src/index.ts

[^tavily-search-api]: Tavily Search API docs. https://docs.tavily.com/documentation/api-reference/endpoint/search

[^tavily-search-depth]: Tavily Search API docs, `search_depth`, auto parameters, and usage behavior. https://docs.tavily.com/documentation/api-reference/endpoint/search

[^tavily-extract-api]: Tavily Extract API docs, URL extraction endpoint and parameters. https://docs.tavily.com/documentation/api-reference/endpoint/extract

[^tavily-map-api]: Tavily Map API docs, mapping root URL and crawl controls. https://docs.tavily.com/documentation/api-reference/endpoint/map

[^tavily-crawl-api]: Tavily Crawl API docs, crawl controls including max depth and chunks. https://docs.tavily.com/documentation/api-reference/endpoint/crawl

[^tavily-research-api]: Tavily Research API docs, research task endpoint and model options. https://docs.tavily.com/documentation/api-reference/endpoint/research

[^brave-repo]: GitHub, `brave/brave-search-mcp-server`, repository metadata and release panel. https://github.com/brave/brave-search-mcp-server

[^brave-readme]: GitHub README, `brave/brave-search-mcp-server`, project description, migration notes, transport defaults, and tools list. https://github.com/brave/brave-search-mcp-server

[^brave-package]: GitHub raw source, `brave/brave-search-mcp-server/package.json`, package metadata. https://raw.githubusercontent.com/brave/brave-search-mcp-server/main/package.json

[^brave-api-independent]: Brave Search API product page, independent index and API FAQ. https://brave.com/search/api/

[^brave-web]: GitHub README, Brave `brave_web_search` tool section. https://github.com/brave/brave-search-mcp-server

[^brave-local]: GitHub README, Brave `brave_local_search` tool section and Pro-plan note. https://github.com/brave/brave-search-mcp-server

[^brave-place]: GitHub README, Brave `brave_place_search` tool section. https://github.com/brave/brave-search-mcp-server

[^brave-news]: GitHub README, Brave `brave_news_search` tool section and freshness parameter. https://github.com/brave/brave-search-mcp-server

[^brave-image-stale]: GitHub README, Brave `brave_image_search` section and v2 image-output migration note. https://github.com/brave/brave-search-mcp-server

[^brave-video]: GitHub README, Brave `brave_video_search` tool section. https://github.com/brave/brave-search-mcp-server

[^brave-llm]: GitHub README, Brave `brave_llm_context` section. https://github.com/brave/brave-search-mcp-server

[^brave-summarizer]: GitHub README, Brave `brave_summarizer` section. https://github.com/brave/brave-search-mcp-server

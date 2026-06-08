# Search and Documentation MCP Routing Strategy: Context7, Tavily, Brave, and Serper

**Prepared for:** Chris Purcell **Prepared on:** 2026-06-03 **Status:** Updated report after adding Context7, correcting prior issues, and closing newly identified gaps **Scope:** This report covers the four MCP/documentation layers now relevant to the stack:

- `upstash/context7` / `@upstash/context7-mcp`
- `tavily-ai/tavily-mcp`
- `brave/brave-search-mcp-server`
- `marcopesani/mcp-server-serper`

The conclusion changes with Context7: **Context7 should sit in front of the search stack for library, framework, SDK, CLI, and API documentation tasks.** It should not replace Tavily, Brave, or Serper. It solves a different problem: current, version-aware code documentation retrieval.

---

## Executive Summary

Use the stack as four complementary retrieval domains:

1. **Context7** is the default **library/API documentation context layer**.
2. **Tavily** is the default **agentic web research, extraction, mapping, and crawling layer**.
3. **Brave** is the default **independent-index, vertical-search, news/local/media, LLM-context, and summarization layer**.
4. **Serper** is the default **Google-style SERP, advanced-operator, and long-tail precision-search layer**.

The corrected routing principle is:

> If the task is about how to use a specific library, framework, SDK, API, package, cloud service, or CLI, start with **Context7**. If the task is about discovering sources, comparing products/projects, researching news/current events, validating facts across the web, finding PDFs/manuals/changelogs/issues, or crawling/extracting arbitrary websites, use the search stack.

Context7 should reduce hallucinated APIs and stale code examples because its stated purpose is to pull up-to-date, version-specific docs and code examples into the coding assistant’s prompt.[^context7-overview] But Context7 is not a full web search engine, not a primary-source browser, and not a replacement for extraction/cross-checking. For important implementation decisions, use Context7 for API syntax and then verify critical claims through source-level documentation, release notes, or vendor docs when necessary.

---

## What Context7 Adds

The previous report treated the stack as a three-provider web-search system:

- Tavily: agentic research/extraction/crawl
- Brave: independent index and vertical search
- Serper: Google-style SERP/operators

Context7 adds a **documentation retrieval layer**. It changes the first routing decision from “which search engine?” to “is this actually a documentation task?”

Context7 fits best when the task includes:

- code generation using a named library or framework;
- API syntax, SDK usage, options, parameters, setup, and configuration;
- version-specific behavior;
- migration between library versions;
- library-specific debugging;
- CLI command usage;
- cloud provider or developer-platform documentation where Context7 has indexed material.

Context7 fits poorly when the task includes:

- open-ended web research;
- recent news or events;
- comparing vendors, communities, benchmarks, or alternatives;
- finding unknown sources;
- discovering PDFs, standards, manuals, GitHub issues, forum threads, or release notes;
- extracting arbitrary websites;
- local/place/image/video search;
- business logic debugging or code review that does not require external library docs.

The current upstream MCP source describes Context7’s role in almost exactly this way: use it for current documentation whenever the user asks about libraries, frameworks, SDKs, APIs, CLI tools, or cloud services, and prefer it over web search for library docs; do not use it for refactoring, scripts from scratch, business-logic debugging, code review, or general programming concepts.[^context7-source]

---

## Evidence Tiers and Trust Model

Because MCP projects move quickly and documentation often lags source, use this evidence order:

**Tier 1: Installed MCP schema** The live tools shown by Claude Code `/mcp`, Codex MCP config/inspection, MCP Inspector, or the client’s tool registry are authoritative for the local environment.

**Tier 2: Current upstream source** Useful for detecting current implementation, but not always equivalent to a hosted remote server or an older installed package.

**Tier 3: README and official docs** Good for intended public behavior, but may lag or contain stale naming.

**Tier 4: Provider platform/API docs** Useful for understanding the underlying service, but not every provider endpoint is exposed by a specific MCP wrapper.

This matters for Context7. There is a real naming/schema mismatch:

- The current `packages/mcp/src/index.ts` source registers `resolve-library-id` and `query-docs`.[^context7-source]
- The package README currently lists `resolve-library-id` and `get-library-docs`.[^context7-mcp-readme-tools]
- Some client/connector environments expose `query-docs` with additional deployment-specific options.

Operational rule: **write agent instructions around the conceptual two-step flow, but name the tools exactly as your installed MCP client exposes them.**

---

## Updated Server Inventory

| Server | Package / install identity | Primary transport notes | Current visible maturity signals | Primary job |
| --- | --- | --- | --- | --- |
| `upstash/context7` / `@upstash/context7-mcp` | NPM package `@upstash/context7-mcp`; package source currently shows version `3.1.0`; MCP registry `server.json` currently lists package version `2.0.2`, which indicates metadata drift that should be verified against the installed package.[^context7-package][^context7-serverjson] | Remote Streamable HTTP at `https://mcp.context7.com/mcp`; local stdio via `npx -y @upstash/context7-mcp --api-key ...`; API key optional for public docs but recommended for higher limits/private repos.[^context7-mcp-readme-install] | GitHub page showed 56.6k stars, 2.7k forks, 835 commits, and 81 releases; latest release panel showed `ctx7@0.4.5` on 2026-06-02.[^context7-github] | Up-to-date, version-aware library/API/SDK/CLI documentation context. |
| `tavily-ai/tavily-mcp` | GitHub README uses `npx -y tavily-mcp@latest`; package JSON name is `tavily-mcp`; Tavily docs have at times used different package labeling, so verify the installed command locally.[^tavily-readme][^tavily-package][^tavily-docs] | Remote MCP URL supported; local stdio via NPX also supported; OAuth is supported for compatible remote MCP clients.[^tavily-docs] | GitHub page showed strong adoption/activity; current source lists `tavily_search`, `tavily_extract`, `tavily_crawl`, `tavily_map`, and `tavily_research`.[^tavily-readme][^tavily-source] | Agentic search, URL extraction, site mapping, bounded crawling, optional research synthesis if exposed. |
| `brave/brave-search-mcp-server` | Package JSON name is `@brave/brave-search-mcp-server`; package source showed version `2.0.82`, while GitHub release panel showed `v2.0.83` on 2026-06-01.[^brave-package][^brave-repo] | STDIO is default in v2.x; HTTP remains available via environment variable or CLI transport flag.[^brave-readme] | GitHub page showed 1.1k stars, 169 forks, 564 commits, 95 releases, and latest `v2.0.83` on 2026-06-01.[^brave-repo] | Independent-index search plus web/local/place/image/video/news/LLM-context/summarization. |
| `marcopesani/mcp-server-serper` | README config uses NPM package `serper-search-scrape-mcp-server`; source server name is `Serper MCP Server` version `0.1.0`.[^serper-readme][^serper-source] | STDIO server; Docker instructions are also present.[^serper-readme] | GitHub page showed 154 stars, 22 forks, 23 commits, and no releases at time of review.[^serper-repo] | Google-like SERP search and lightweight webpage scrape. |

---

## Tool Catalog and Preferred Use

### 1. Context7 MCP: documentation context layer

#### Conceptual workflow

Context7 has a two-step documentation workflow:

1. Resolve the library/package/product name to a Context7-compatible library ID.
2. Query documentation for that exact library ID.

The CLI docs describe the same pattern: `ctx7 library` first resolves a library name to an ID, then `ctx7 docs` uses the ID and a natural-language question to retrieve relevant code snippets and explanations.[^context7-cli]

#### Tool naming caveat

Depending on installed version/client, the second tool may appear as `query-docs` or `get-library-docs`.

- Current source: `query-docs` with `libraryId` and `query`.[^context7-source]
- Current package README: `get-library-docs` with `context7CompatibleLibraryID`, optional `topic`, and optional `page`.[^context7-mcp-readme-tools]

Treat this as an installed-schema issue, not a conceptual difference. The routing strategy is the same either way.

#### `resolve-library-id`

**Primary purpose:** Resolve an ambiguous library/package/product name into a Context7-compatible library ID.

Use it when:

- the user names a library without a Context7 ID;
- the package name is ambiguous;
- several similarly named packages exist;
- a specific version might matter;
- you need to compare snippet count, source reputation, benchmark score, and available versions before selecting docs.

The CLI docs state that library search results include the library ID, code-snippet count, source reputation, benchmark score, and version-specific IDs when available.[^context7-cli]

Avoid repeated resolution when:

- the user already gives a slash-style Context7 ID such as `/vercel/next.js`;
- the agent already resolved the ID earlier in the same task;
- a project-level rule pins a known library ID.

#### `query-docs` / `get-library-docs`

**Primary purpose:** Retrieve relevant documentation snippets and code examples for a resolved Context7 library ID.

Use it when:

- implementing code against a named framework, SDK, API, CLI, or cloud service;
- checking current API syntax;
- writing setup/configuration steps;
- resolving version-specific behavior;
- producing migration guidance;
- fixing library-specific errors where docs likely explain the behavior.

Use specific natural-language queries. Context7’s API guide explicitly recommends detailed task-oriented queries over short keywords, because a query like “How to implement authentication with middleware” is more useful than “auth.”[^context7-api-best-practices]

Prefer exact library IDs and versions where possible. Context7 supports library IDs such as `/vercel/next.js`, website IDs such as `/websites/uploadcare_com`, npm/package IDs, uploaded-doc IDs, and version-pinned IDs using either `/owner/repo/version` or `/owner/repo@version` syntax.[^context7-api-guide]

#### What Context7 is not

Do not use Context7 as a substitute for:

- Tavily Search for broad research;
- Tavily Extract for exact page extraction from arbitrary URLs;
- Tavily Map/Crawl for website structure and bounded crawl ingestion;
- Brave News/Local/Image/Video for vertical search;
- Serper for Google-like `site`, `filetype`, `intitle`, `inurl`, `before`, `after`, exact-phrase, PDF/manual, GitHub issue, and forum discovery;
- official release notes/changelogs when migration timing matters.

Context7’s own library-owner docs show that default exclusions can omit changelog/license/code-of-conduct files and old/deprecated/legacy folders unless project owners configure otherwise.[^context7-library-owners] That is reasonable for code-generation context, but it means Context7 is not always the right tool for historical release-note research.

---

### 2. Tavily MCP: search, extraction, mapping, crawling, optional research

Tavily remains the default research/extraction workhorse after Context7. Use it when the task is not strictly a known-library documentation lookup, or when Context7 needs fallback verification.

#### `tavily_search`

Use for:

- first-pass web research;
- current but non-news-specific facts;
- finding authoritative URLs;
- domain include/exclude research;
- broader context after Context7 retrieves library snippets.

Tavily’s API docs describe `search_depth` as a latency/relevance control. `advanced` is positioned for higher relevance and detailed queries; `basic` is balanced; `fast` is lower-latency.[^tavily-search-depth]

#### `tavily_extract`

Use for:

- full content from known URLs;
- source-level verification after search;
- official docs pages not indexed or not sufficiently covered by Context7;
- extracting release notes, migration guides, API docs, or vendor pages.

#### `tavily_map`

Use for:

- documentation-site structure discovery;
- finding relevant pages before extraction;
- docs sites where Context7 has no coverage or the exact version/page is unclear.

#### `tavily_crawl`

Use for:

- bounded multi-page extraction;
- docs sections or guide sets;
- small knowledge-base ingestion.

Use Map before Crawl unless the task is explicitly site-wide.

#### `tavily_research`

Use only if the installed MCP schema exposes it. Tavily’s current source includes it, and Tavily has a public Research API endpoint, but durable routing should still rely on installed tool inspection.[^tavily-source][^tavily-research]

Treat it as a synthesis helper, not final evidence.

---

### 3. Brave Search MCP: independent index and vertical search

Brave remains the second independent search layer and the first choice for vertical domains.

Use Brave when:

- checking Tavily or Serper against an independent index;
- searching news/current events;
- finding local businesses or structured place results;
- image or video search matters;
- you need LLM-ready grounding snippets;
- you want Brave’s summarizer after a web search.

Brave’s API page describes Brave Search API as powered by an independent web index and lists endpoint categories including web, images, videos, news, autosuggest, spellcheck, AI summaries, local, and local POI.[^brave-api]

Important caveat: Brave’s README has a known internal contradiction. A v2 migration note says base64 image data was removed in v2.x to reduce latency/context bloat, while a lower image-search section still refers to automatic base64 fetching. For v2.x installs, follow the migration note.[^brave-readme]

---

### 4. Serper MCP: Google-style precision search

Serper remains the Google-shaped fallback and precision-search tool.

Use `google_search` when:

- Google-like ranking matters;
- advanced operators are useful;
- searching PDFs, manuals, standards, GitHub issues, changelogs, old docs, forums, or obscure pages;
- Context7 returns weak/no coverage and exact docs/source discovery is required;
- Tavily/Brave miss expected results.

Use `scrape` only for lightweight extraction of known URLs. Prefer Tavily Extract for richer extraction.

The linked `marcopesani` wrapper exposes only `google_search` and `scrape`. Serper’s platform advertises additional Google verticals such as Images, News, Maps, Places, Videos, Shopping, Scholar, Patents, and Autocomplete, but those verticals are not exposed by this specific MCP wrapper.[^serper-api][^serper-readme]

---

## Updated Routing Matrix

| Task / search domain | First tool | Second tool | Fallback / verification | Rationale |
| --- | --- | --- | --- | --- |
| Library/API/SDK syntax | Context7 | Tavily Extract on official docs | Serper `site:` search | Context7 is built for current docs; Tavily/Serper verify source pages when exactness matters. |
| Code generation using known framework | Context7 | Tavily Extract | Brave Web / Serper | Start with version-aware docs before generating code. |
| Setup/configuration steps | Context7 | Tavily Search/Extract | Serper | Avoid stale package/config examples from model memory. |
| Version-specific migration | Context7 with version-pinned ID or version in query | Official release notes via Tavily/Serper | Brave Web | Context7 can version-pin, but release notes/changelog history may require direct source search. |
| Library-specific debugging | Context7 | Tavily Search/Extract | Serper exact error search | Use docs first; use search for GitHub issues, Stack Overflow, and bug reports. |
| Choosing between libraries/vendors | Tavily Search | Brave Web | Serper | Context7 can describe docs for a known library, but it is not an ecosystem-comparison tool. |
| Current news/events | Brave News | Tavily Search | Serper date-bounded search | Context7 is not a news tool. |
| Official docs site discovery | Context7 if known library | Tavily Map | Serper `site:` search | Use Context7 for indexed docs; Map/Search for missing or arbitrary docs sites. |
| Known URL extraction | Tavily Extract | Serper Scrape | Brave LLM Context only for snippets | Context7 retrieves indexed docs, not arbitrary page extraction. |
| Multi-page docs ingestion | Tavily Map → Tavily Crawl | Context7 for targeted library answers | Serper `site:` for missing pages | Context7 answers questions; Tavily maps/crawls sites. |
| PDF/manual/standards discovery | Serper `filetype` / `site` | Brave Web | Tavily Extract if web-readable | Serper has the best operator surface. |
| GitHub issue/forum/changelog discovery | Serper | Brave Web | Tavily Search | Context7 may omit changelogs and is not designed for issue/forum discovery. |
| Local/place search | Brave Local/Place | Brave Web | Serper with location | Context7/Tavily are wrong first choices. |
| Image/video search | Brave Image/Video | Brave Web | Serper only if using another wrapper | Brave exposes dedicated media tools. |
| LLM/RAG grounding snippets | Brave LLM Context | Tavily Search/Extract | Context7 for docs-only context | Brave is optimized for multi-source context; Context7 is docs-specific. |
| AI-generated summary | Brave Summarizer / Tavily Research | Source-level extract | Serper/Brave cross-check | Generated summaries orient; source extraction proves. |

---

## Preferred Routing Policy

### Step 1: Decide whether the task is documentation-bound

Ask first: “Is the user asking how to use a named library, framework, SDK, API, CLI, package, cloud service, or developer tool?”

If yes, use **Context7 first**.

Examples:

- “How do I configure Next.js middleware?”
- “Show the current Supabase auth API for email/password sign-up.”
- “How do I use Pydantic v2 validators?”
- “What is the current FastAPI lifespan pattern?”
- “How do I configure Ruff and pyright?”
- “What changed in Tailwind v4 config?”

If no, use the search routing from the prior report.

### Step 2: Use Context7 as a precise docs retriever, not a generic research agent

Recommended Context7 workflow:

1. If the Context7 library ID is known, skip resolution.
2. Otherwise, call the resolve tool with the official library name and a specific task query.
3. Select the best match using name match, source reputation, snippet count, benchmark score, and version list.
4. Query docs with a specific task-oriented query.
5. If the answer is insufficient, retry with a narrower query, version-pinned library ID, topic/page if exposed by the installed schema, or fallback to Tavily/Serper.

### Step 3: Fall back deliberately

Use fallback search when Context7 is weak, missing, stale, ambiguous, or too abstract.

Fallback rules:

- Use **Tavily Extract** for exact official documentation pages.
- Use **Tavily Map** to discover a docs site structure.
- Use **Serper** for `site:docs.vendor.com`, `filetype:pdf`, exact error strings, release notes, old versions, GitHub issues, and changelogs.
- Use **Brave Web** as an independent validation layer.

### Step 4: Do not leak sensitive context

Context7’s privacy docs state that the MCP client sends formulated documentation queries and library names/IDs to Context7, along with API key if provided, client metadata, transport type, and encrypted client IP for HTTP rate limiting. Context7 says full prompts, source code, and conversation history are not sent, but the query is still sent and used for LLM-based reranking and anonymous benchmarking/quality improvement.[^context7-privacy]

Agent rule: **never include secrets, proprietary code, customer data, credentials, or full internal snippets in Context7 queries.** Use generic, sanitized task descriptions.

---

## Tool Use Strategies

### Strategy 1: Normal code-generation task

Use when the user asks for code against a known library/framework.

1. Context7 resolve library ID, unless the ID is known.
2. Context7 query docs with a specific implementation task.
3. Generate code using the retrieved docs.
4. If the code relies on subtle behavior, verify with Tavily Extract against the official docs page.

Example task:

```txt
Implement FastAPI lifespan startup/shutdown with Pydantic v2 settings.
```

Preferred route:

```txt
Context7: resolve FastAPI → query docs for lifespan
Context7: resolve Pydantic → query docs for settings/model config
Tavily Extract: official docs only if exact behavior is load-bearing
```

### Strategy 2: Version-specific migration

Use when version matters.

1. Mention the version explicitly in the Context7 query or use a version-pinned library ID.
2. Query Context7 for the migration target.
3. Use Serper or Tavily to locate release notes/changelog if the migration is version-sensitive.
4. Verify breaking changes against official release docs.

Why: Context7 supports version-pinned library IDs, but its indexing defaults may not be optimized for changelog/history research.[^context7-api-guide][^context7-library-owners]

### Strategy 3: Unknown or ambiguous library

Use when the name is ambiguous or there are similarly named packages.

1. Context7 resolve with the official package/product name and task query.
2. Prefer high source reputation, strong name match, high snippet count, high benchmark score, and relevant description.
3. If still ambiguous, use Tavily/Brave to identify the canonical project/package.
4. Then return to Context7 with the chosen ID.

### Strategy 4: Documentation coverage gap

Use when Context7 returns no result or weak context.

1. Tavily Search for the official docs.
2. Tavily Map the docs root if structure is unclear.
3. Tavily Extract relevant docs pages.
4. Serper `site:` search if navigation/search is poor.
5. If the library should be in Context7, consider adding or refreshing the library.

Context7 supports adding libraries from repositories, websites, OpenAPI specs, llms.txt, uploaded docs, and Confluence through API endpoints or the web flow, depending on source and plan.[^context7-api-guide][^context7-library-owners]

### Strategy 5: Bug/error investigation

Use when there is an error message or unexpected behavior.

1. Context7 for the documented API and intended usage.
2. Serper exact-phrase search for the error message, GitHub issues, and forum posts.
3. Brave Web as an independent cross-check.
4. Tavily Extract authoritative pages or issue threads.

Context7 tells you what the library says should work. Search tells you what users hit in the field.

### Strategy 6: Private or internal docs

Use Context7 only if private sources are configured and the data-sharing model is acceptable.

Context7 pricing/docs say private repositories are available on Pro/Enterprise, not Free; private repository parsing is separately billed, and Enterprise can support self-hosted/on-premise deployment.[^context7-pricing]

For sensitive internal code/docs, do not assume Context7 is acceptable just because it is an MCP server. Confirm private-source configuration, retention, query storage, and teamspace policies first.

---

## Comprehensive Gap Analysis After Adding Context7

| Gap | Why it matters | Closure / routing rule |
| --- | --- | --- |
| Context7 is not a web search provider | It retrieves indexed docs; it does not replace Tavily/Brave/Serper for web discovery. | Put Context7 before search only for named library/API docs. Use Tavily/Brave/Serper for discovery, news, web research, and validation. |
| Tool name mismatch: `query-docs` vs `get-library-docs` | Public docs/source/package README are not perfectly aligned. Agents may call the wrong tool name if instructions are too literal. | Use the installed MCP schema as source of truth. In shared instructions, describe the conceptual flow and then map to the actual installed tool names. |
| Possible deployment-specific schema differences | Some environments expose additional options not in upstream README/source. | Inspect `/mcp` or MCP Inspector before relying on parameters such as `topic`, `page`, or `researchMode`. |
| Freshness is not instantaneous | Context7 may return existing docs while a background refresh runs. | For very recent releases, verify with official docs/release notes using Tavily/Serper. Context7’s freshness docs say refresh can be triggered in the background while the current request receives existing docs.[^context7-freshness] |
| Library coverage is not universal | Context7 depends on indexed libraries/sources. | If no high-quality match exists, use Tavily/Serper to find official docs, then optionally add/refresh the library. |
| Changelog/release-note gaps | Context7 owner config defaults can exclude changelog files and deprecated/old folders. | Use Serper/Tavily for release notes, changelogs, deprecations, and historical migrations. |
| Documentation accuracy/security is not guaranteed | Context7 projects are community-contributed and Context7 disclaims guarantees of accuracy, completeness, and security. | Treat Context7 as high-quality context, not unquestioned authority. Verify high-impact claims against official source docs/release notes/source code.[^context7-mcp-readme-disclaimer] |
| Managed backend is private | The repo hosts the MCP server; backend/parsing/crawling engines are private. | Treat Context7 as a managed service unless Enterprise self-hosting is negotiated. Do not assume full local/on-prem control from the open-source MCP package alone.[^context7-mcp-readme-disclaimer] |
| Privacy/query handling | Queries and library IDs are sent to Context7; queries are used for reranking and benchmarking/quality improvement. | Sanitize queries. Never send secrets, proprietary code, customer details, credentials, or full internal snippets. Use Enterprise controls/on-prem for stricter environments.[^context7-privacy] |
| Rate limits and cost | Free/API-keyless use has lower limits; Pro/Enterprise/private parsing has costs. | Use an API key, cache repeated docs lookups, avoid tight loops, and monitor usage. Context7 API docs recommend caching responses and handling 429 rate limits.[^context7-api-best-practices] |
| Context7 cannot choose the best library for a product decision | It can resolve docs for a named library but does not evaluate ecosystem health, benchmarks, or user feedback. | Use Tavily/Brave/Serper for library/vendor comparison; use Context7 only after candidates are selected. |
| Context7 answers can be too snippet-oriented | Snippets may omit surrounding context, caveats, or full examples. | Use Tavily Extract on official docs when exact wording, full context, tables, or edge cases matter. |
| Tool descriptions influence agent behavior | Context7’s source includes strong instructions to prefer it over web search for library docs. This is useful but can over-trigger. | Add your own routing rules limiting Context7 to library/API docs and excluding refactoring/business-logic/code-review tasks. |

---

## Updated Agent Instructions

Use this in `CLAUDE.md`, `AGENTS.md`, or a tool-routing spec. Adjust tool names to the actual installed schema.

```md
## Retrieval and Search MCP Routing

Use Context7 before web search when the task requires current documentation for a named library, framework, SDK, API, CLI tool, package, or cloud developer service. This includes code generation, setup/configuration, API syntax, version migration, library-specific debugging, and CLI usage.

Context7 workflow:

1. If the user provides a Context7 library ID like `/org/project` or `/org/project/version`, skip resolution.
2. Otherwise, resolve the library ID using the installed Context7 resolve tool.
3. Query docs using the installed Context7 documentation tool.
4. Keep queries specific and sanitized. Do not include API keys, credentials, proprietary code, customer data, full prompts, or sensitive internal details.
5. If the docs are insufficient, retry once with a narrower query or version-pinned ID. Then fall back to Tavily/Serper/Brave.

Do not use Context7 for general programming concepts, refactoring, business-logic debugging, code review, broad web research, news, product/vendor comparisons, local/place/media search, GitHub issue discovery, forum research, PDFs/manuals/standards discovery, or arbitrary website extraction.

Use Tavily as the default web research and extraction MCP. Prefer `tavily_search` for general web research and source discovery, `tavily_extract` for known URLs, `tavily_map` before `tavily_crawl` when exploring documentation or website structure, and `tavily_crawl` only for bounded multi-page extraction. Use `tavily_research` only if the installed schema exposes it, and treat it as exploratory synthesis rather than final evidence.

Use Brave as the independent-index and vertical-search MCP. Prefer `brave_web_search` as the second opinion for important factual claims. Use `brave_news_search` for news/current events, `brave_place_search` or `brave_local_search` for places and businesses, `brave_image_search` for visual discovery, `brave_video_search` for video discovery, `brave_llm_context` for RAG-style grounding, and `brave_summarizer` only after a web search has produced a summary key.

Use Serper as the Google-style SERP and advanced-operator MCP. Prefer `google_search` when Google-like ranking matters or when using `site`, `filetype`, `intitle`, `inurl`, `before`, `after`, exact phrase, exclusion, or OR-style terms. Use Serper for PDFs, manuals, standards, GitHub issue discovery, forum threads, changelogs, release notes, obscure long-tail pages, and search-result gaps. Use Serper `scrape` only for lightweight known-URL extraction; prefer Tavily Extract for richer extraction.

For important factual or implementation-critical answers, use source-level verification. Context7 docs are strong implementation context, but generated summaries and snippets are not final evidence when exact wording, legal/security implications, migrations, or breaking changes matter.
```

---

## Practical Defaults

### Context7 defaults

Prefer exact IDs and specific queries:

```json
{
	"libraryName": "FastAPI",
	"query": "How to use lifespan startup and shutdown handlers with current FastAPI patterns"
}
```

Then query docs with the resolved ID:

```json
{
	"libraryId": "/tiangolo/fastapi",
	"query": "How to use lifespan startup and shutdown handlers with current FastAPI patterns"
}
```

If your installed schema exposes `topic`/`page`, use `topic` to narrow and `page` only when the first page is insufficient. If your installed schema exposes `researchMode`, use it only after normal docs retrieval fails and verify its synthesis through source-level docs.

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

### Serper defaults

Always specify region and language explicitly:

```json
{ "gl": "us", "hl": "en", "num": 10, "autocorrect": true }
```

Add only the operators needed. Over-constraining the query is a common way to hide the right answer.

---

## Decision Rules

### Use Context7 first when the answer depends on current docs

Use Context7 first for:

- “How do I use X library?”
- “Generate code using X.”
- “Configure X with Y.”
- “What is the current API for X?”
- “How did X change in version N?”
- “Fix this library-specific error.”

### Use Tavily first when the answer depends on web research

Use Tavily first for:

- broad research;
- source discovery;
- extracting known URLs;
- mapping/crawling docs sites;
- comparing technologies/vendors;
- building a source set.

### Use Brave first when the answer depends on independent index or vertical search

Use Brave first for:

- news;
- local/place;
- image/video;
- independent validation;
- LLM-ready multi-source context.

### Use Serper first when the answer depends on Google-like precision

Use Serper first for:

- `site:` and `filetype:` searches;
- PDFs/manuals/standards;
- exact phrase/error search;
- GitHub issues and forums;
- changelogs/release notes;
- long-tail discovery.

---

## Final Recommendation

Add Context7, but do not mentally group it with Tavily, Brave, and Serper as “another search MCP.” It is a **documentation-context MCP**.

The best four-layer stack is:

1. **Context7:** first stop for named library/API/SDK/CLI documentation and code-generation grounding.
2. **Tavily:** first stop for general web research, extraction, mapping, and crawling.
3. **Brave:** first stop for independent-index validation and vertical search.
4. **Serper:** first stop for Google-style precision, operators, PDFs/manuals, GitHub/forum/changelog discovery.

The biggest operational improvement is to make the first routing question explicit:

> “Is this a docs/API usage problem or a web-research problem?”

If docs/API usage: Context7 first. If web research: Tavily/Brave/Serper according to domain. If implementation-critical: Context7 for syntax, then source-level verification through Tavily/Serper/Brave.

---

## Sources

[^context7-overview]: Context7 Docs, Intro, “Context7 brings up-to-date, version-specific documentation and code examples directly into your AI coding assistant.” <https://context7.com/docs/overview>

[^context7-github]: GitHub, `upstash/context7`, repository metadata, README, stars/forks/commits/releases, and project description. <https://github.com/upstash/context7>

[^context7-source]: GitHub raw source, `upstash/context7/packages/mcp/src/index.ts`, MCP server instructions and registered tools `resolve-library-id` and `query-docs`. <https://raw.githubusercontent.com/upstash/context7/master/packages/mcp/src/index.ts>

[^context7-package]: GitHub raw source, `upstash/context7/packages/mcp/package.json`, package metadata for `@upstash/context7-mcp`. <https://raw.githubusercontent.com/upstash/context7/master/packages/mcp/package.json>

[^context7-serverjson]: GitHub raw source, `upstash/context7/server.json`, MCP registry metadata, package/remotes, and environment variables. <https://raw.githubusercontent.com/upstash/context7/master/server.json>

[^context7-mcp-readme-install]: GitHub raw README, `upstash/context7/packages/mcp/README.md`, installation, Claude Code, Codex, remote/local, CLI flags, and API key notes. <https://raw.githubusercontent.com/upstash/context7/master/packages/mcp/README.md>

[^context7-mcp-readme-tools]: GitHub raw README, `upstash/context7/packages/mcp/README.md`, Available Tools section listing `resolve-library-id` and `get-library-docs`. <https://raw.githubusercontent.com/upstash/context7/master/packages/mcp/README.md>

[^context7-mcp-readme-disclaimer]: GitHub raw README, `upstash/context7/packages/mcp/README.md`, disclaimer that projects are community-contributed and supporting backend/parsing/crawling engines are private. <https://raw.githubusercontent.com/upstash/context7/master/packages/mcp/README.md>

[^context7-cli]: Context7 Docs, CLI page, `ctx7 library` and `ctx7 docs` two-step workflow, result fields, version IDs, setup modes, authentication, and telemetry. <https://context7.com/docs/clients/cli>

[^context7-api-guide]: Context7 Docs, API Guide, authentication, API methods, library ID formats, version pinning, workflow example, rate limits, and error handling. <https://context7.com/docs/api-guide>

[^context7-api-best-practices]: Context7 Docs, API Guide, best practices for specific natural-language queries, caching, rate-limit handling, and version pinning. <https://context7.com/docs/api-guide>

[^context7-library-owners]: Context7 Docs, Library Owners, `context7.json`, configuration fields, defaults, exclusions, previous versions, and source submission. <https://context7.com/docs/adding-libraries>

[^context7-freshness]: Context7 Docs, Keeping Libraries Fresh, automatic refresh thresholds and behavior. <https://context7.com/docs/library-updates>

[^context7-privacy]: Context7 Docs, Data Privacy, query privacy, what is sent to Context7, query use for reranking/benchmarking, enterprise controls, retrieval scope, and data storage. <https://context7.com/docs/security/data-privacy>

[^context7-pricing]: Context7 Pricing & Plans, Free/Pro/Enterprise limits, private repo parsing costs, privacy FAQ, and enterprise/self-hosting notes. <https://context7.com/plans>

[^tavily-readme]: GitHub README, `tavily-ai/tavily-mcp`, tool summary and setup sections. <https://github.com/tavily-ai/tavily-mcp>

[^tavily-docs]: Tavily Docs, Tavily MCP Server documentation, remote/local setup, OAuth, defaults, and examples. <https://docs.tavily.com/documentation/mcp>

[^tavily-source]: GitHub raw source, `tavily-ai/tavily-mcp/src/index.ts`, current MCP tool definitions. <https://raw.githubusercontent.com/tavily-ai/tavily-mcp/main/src/index.ts>

[^tavily-package]: GitHub raw source, `tavily-ai/tavily-mcp/package.json`, package metadata. <https://raw.githubusercontent.com/tavily-ai/tavily-mcp/main/package.json>

[^tavily-search-depth]: Tavily Search API docs, `search_depth` behavior. <https://docs.tavily.com/documentation/api-reference/endpoint/search>

[^tavily-research]: Tavily Research API docs, research task endpoint and model options. <https://docs.tavily.com/documentation/api-reference/endpoint/research>

[^brave-repo]: GitHub, `brave/brave-search-mcp-server`, repository metadata and release panel. <https://github.com/brave/brave-search-mcp-server>

[^brave-readme]: GitHub README, `brave/brave-search-mcp-server`, project description, migration notes, transport defaults, and tools list. <https://github.com/brave/brave-search-mcp-server>

[^brave-package]: GitHub raw source, `brave/brave-search-mcp-server/package.json`, package metadata. <https://raw.githubusercontent.com/brave/brave-search-mcp-server/main/package.json>

[^brave-api]: Brave Search API product page, independent index, plans, endpoint categories, index size/freshness, and special features. <https://brave.com/search/api/>

[^serper-repo]: GitHub, `marcopesani/mcp-server-serper`, repository metadata showing stars, forks, commits, and no releases. <https://github.com/marcopesani/mcp-server-serper>

[^serper-readme]: GitHub README, `marcopesani/mcp-server-serper`, tools and installation sections. <https://github.com/marcopesani/mcp-server-serper>

[^serper-source]: GitHub raw source, `marcopesani/mcp-server-serper/src/index.ts`, tool schemas for `google_search` and `scrape`. <https://raw.githubusercontent.com/marcopesani/mcp-server-serper/main/src/index.ts>

[^serper-api]: Serper homepage, advertised Google Search API speed and endpoint categories. <https://serper.dev/>

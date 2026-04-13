---
name: research
description: Dual-source internet research on a topic, task, or technology before designing or building. Covers official docs, community best practices, footguns, and existing tools.
argument-hint: "<topic, task, or technology to research>"
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
  - AskUserQuestion
  - WebFetch
  - mcp__brave-search__brave_web_search
  - mcp__serper-search__google_search
---

# /qdev:research

Research a topic or technology space before designing, planning, or building.

## Step 1: Establish Topic

If `$ARGUMENTS` is provided, use it as the research topic.

Otherwise, gather context to infer the topic:

```bash
git log --oneline -5 2>/dev/null || true
```

Scan for project-level docs that reveal the current focus:

```bash
find . -maxdepth 3 -name "*.md" -not -path "*/.git/*" | head -15
```

Read `CLAUDE.md` at the project root if present. From git history, project files, and conversation context, infer the current focus area.

If the topic still cannot be determined with reasonable confidence, use `AskUserQuestion`:
- header: `"Research topic"`
- question: `"I could not determine the research topic from context. What should I research?"`
- options:
  1. label: `"Describe it now"`, description: `"I'll type the topic in the next message"`
  2. label: `"Cancel"`, description: `"Stop"`

If `"Describe it now"` is chosen: ask `"What should I research? Describe the topic, task, or technology."` as a follow-up open-ended question, then use the response as the topic before proceeding.
If `"Cancel"` is chosen: emit `No topic provided.` and stop.

Announce: `Research topic: <topic>`

## Step 2: Plan Research Queries

Based on the topic, generate 6-8 targeted search queries covering these angles:

1. **Official docs**: primary documentation, API reference, getting-started guide
2. **Best practices**: established patterns, current community recommendations
3. **Footguns and gotchas**: common mistakes, version traps, known pain points
4. **Existing tools**: alternatives and prior art; what already solves this problem
5. **Security**: CVEs, known vulnerabilities, advisories relevant to the topic
6. **Recent changes**: deprecations, breaking changes, ecosystem shifts

Use specific queries. Include the year (e.g., `"Redis pub/sub Python gotchas 2024"`) to surface current results over stale archived answers. Prefer the technology's own name plus a specific angle over a single broad query.

## Step 3: Execute Research

For each query, run both search tools in the same response turn (parallel tool calls):
- `mcp__brave-search__brave_web_search` with 10 results
- `mcp__serper-search__google_search` with 10 results

After collecting all search results, identify 3-5 pages that are most relevant across all queries:
- Official documentation pages or changelogs
- Canonical "production guide" or "best practices" references
- Security advisories or CVE records
- Well-maintained reference repositories or cookbooks

Use `WebFetch` to read these pages in full. Deduplicate overlapping results across the two search tools.

## Step 4: Synthesize and Report

Synthesize all findings into a structured Markdown report. Include only sections where relevant findings exist.

Report header:

```
Research Report: <topic>
Queries: N  |  Results: N  |  Full reads: N pages
```

Sections (as H3 headings in the response):

- **Official Documentation**: current docs links, API surface, recent changes or version status
- **Best Practices**: what official sources and the community recommend; patterns that have replaced older approaches
- **Footguns and Gotchas**: known pitfalls, common mistakes, patterns that look correct but produce subtle failures
- **Existing Tools**: tools already solving this or related problems, with links and maintenance status
- **Security and Compatibility**: CVEs, deprecation notices, compatibility warnings
- **Open Questions**: decisions or unknowns surfaced by research that need answering before proceeding

If **Existing Tools** contains a tool that appears to cover the use case being researched, surface it as a callout before the report body:

```
⚠ Existing solution: <tool name> (<link>) — appears to cover this use case. Review before building.
```

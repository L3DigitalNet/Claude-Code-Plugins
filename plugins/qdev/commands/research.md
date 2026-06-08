---
name: research
description: Dual-source web research via the qdev-researcher subagent (Sonnet). Covers docs, best practices, footguns, existing tools, security, and recent changes. Routes library questions through Context7. Persists a structured report under docs/research/.
argument-hint: '[optional: <topic> — omit to infer from session context]'
allowed-tools:
  - Agent
  - AskUserQuestion
  - Read
  - Bash
---

# /qdev:research

Research a topic, task, or technology before designing or building, by dispatching the `qdev-researcher` subagent.

## Why this is a subagent

The research workflow performs 6-8 queries through a Tavily-first recall path, Brave/Serper cross-checks, 3-5 full-page Tavily extracts, and per-library Context7 round-trips. Running it in Opus context burns ~25K tokens per sweep on raw search results alone. The Sonnet subagent consolidates research + corroboration + synthesis into one dispatch and returns a compact structured report. This is the v1.3.0 subagent-extraction pattern: the orchestrator stays out of raw search results and receives only the compact structured report.

## How to run it

1. **Establish topic.**
   - If `$ARGUMENTS` is provided, use it as the topic.
   - Otherwise, gather context with one bash call:

     ```bash
     git log --oneline -5 2>/dev/null || true
     ```

     Read `CLAUDE.md` at the project root if present. From git history, project files, and conversation context, infer the focus area with reasonable confidence.

   - If the topic still cannot be inferred, use `AskUserQuestion` with a single bounded question (no two-step pattern):
     - header: `"Research topic"`
     - question: `"What should I research? (Pick a recent context or use Other to type a topic.)"`
     - options: up to 3 inferred candidates from git/CLAUDE.md context. The implicit "Other" entry lets the user type a free-text topic.

     If no candidates can be inferred at all and the user does not provide one, emit `No topic provided.` and stop.

   Announce: `Research topic: <topic>`

2. **Dispatch `qdev-researcher`** with the topic.

   Use the `Agent` tool with `subagent_type: qdev:qdev-researcher` and a prompt like:

   > Research `<topic>`. Default depth=standard. The research-KB scripts live in `${CLAUDE_PLUGIN_ROOT}/scripts/`; pass that absolute path to the agent as `SCRIPTS` so it can invoke `uv run "$SCRIPTS/build_research_index.py"`, `"$SCRIPTS/validate_research_frontmatter.py"`, and `"$SCRIPTS/dedup.py"`. Run the Tavily-first search path, route library docs through the Context7 gate, corroborate footguns across 2+ sources, run at most one follow-up pass for thin angles, run the reporting cycle (preflight index → dedup → write report with frontmatter → self-validate → regenerate index), and return the structured report per your output format.

   Do **not** run search tools, `find`, or read manifests in this session. The whole point of the delegation is to keep raw search results out of the orchestrator context.

## After the agent returns

1. **Present the report verbatim** to the user. The agent's output_format places the `## ⚠ Existing solution` callout (when applicable) immediately after the header line, so surfacing it correctly is just a matter of relaying the report unchanged. The `Saved:` path in the header is the canonical handoff artifact.

2. **Offer downstream chaining** if Open Questions is non-empty OR Footguns surfaced material findings. Use `AskUserQuestion`:
   - question: `"Research saved to <path>. What's next?"`
   - options:
     1. label: `"Brainstorm next"`, description: `"Feed Open Questions into superpowers:brainstorming"`
     2. label: `"Just save and exit"`, description: `"No follow-up"`

   Apply the chosen option in this session: invoke the named skill/command and pass the persisted research path as context.

3. **Final summary** (emit when a report was produced — skip when Step 1 stopped at "No topic provided."):

   ```text
      ✓ Research complete. Report: <path>  ·  Index: docs/research/index.md
   ```

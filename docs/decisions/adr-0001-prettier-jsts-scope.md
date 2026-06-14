---
title: 'ADR-0001: Markdown-tooling adoption deviations (Prettier JS/TS scope; MD060)'
status: accepted
date: 2026-06-08
---

# ADR-0001: Markdown-tooling adoption deviations

Two deliberate deviations were made while adopting the project-standards markdown-tooling standard. Both are recorded here per standard §14. The MD060 deviation was revised on 2026-06-14 (see the dated note under Decision Outcome).

## Context and Problem Statement

The standard makes Prettier the authority for formatting every file type it supports and ships a fully explicit markdownlint rule set. Two parts of that did not fit this plugins meta-repo as written:

1. **JS/TS source.** `prettier .` would format the 27 tracked TypeScript/JavaScript files of the `home-assistant-dev` MCP server (`.ts`/`.tsx`/`.js`/`.jsx`/`.mjs`/`.cjs`, incl. a bundled `dist/*.cjs`). That sub-project has its own `eslint.config.js` + `tsconfig` and no Prettier; reformatting it would risk fighting its ESLint.
2. **MD060 (table-column-style).** Prettier renders an empty table cell as `|  |` (one leading + one trailing space). The standard ships `MD060: { style: "any" }`, which infers each table's column style and then flags those empty cells as inconsistent with the inferred `"compact"` style. This was first read as an irreconcilable Prettier-vs-markdownlint conflict, so the rule was disabled.

## Considered Options

- **Include JS/TS in root Prettier** — the most literal reading of the standard, but it couples Markdown formatting to the MCP server's build/test toolchain and risks fighting its ESLint.
- **Exclude JS/TS via `.prettierignore`** — root Prettier governs only structured-text (`md`/`json`/`yaml`/`code-workspace`); the JS/TS sub-project keeps its own toolchain authoritative.
- **MD060: disable it** — turn the formatter-owned rule off, following the standard's own pattern for Prettier-owned rules (MD009/MD010/MD013/MD030/MD032 are already off for the same reason).
- **MD060: enable it at `style: "leading_and_trailing"`** — keep table-column linting active while accepting Prettier's output exactly (every cell, empty or not, carries one leading + one trailing space). Deviates from the standard's `"any"` default, which cannot be satisfied alongside Prettier once a table has empty cells.

## Decision Outcome

- **JS/TS scope:** `.prettierignore` excludes `*.ts *.tsx *.js *.jsx *.mjs *.cjs` (gitignore syntax, one pattern per line). The standard already scopes `.py` source out of Prettier (owned by ruff); JS/TS source is the direct analogue, and the reference repo's own `format.yml` never lists `js`/`ts`.
- **MD060** (revised 2026-06-14): `"MD060": { "style": "leading_and_trailing", "aligned_delimiter": false }` in `.markdownlint.json`. The rule stays **enabled** — table-column consistency is linted — pinned to the one style that matches Prettier's cell spacing. This supersedes the original 2026-06-08 decision to disable MD060 (`"MD060": false`), which was taken before the Prettier-compatible style was identified. The standard's shipped `style: "any"` is **not** used: it mis-infers empty-celled tables as `"compact"` and conflicts with Prettier (verified — 152 violations across this repo's generated indexes and plan tables, all cleared by `leading_and_trailing`).

### Consequences

- Root Prettier never fights the MCP server's ESLint; no MCP build/test gate is coupled to Markdown formatting.
- MD060 is active again, so table column style is linted while Prettier remains the formatter of record — the two no longer conflict because the rule's style is pinned to what Prettier produces.
- `style: "leading_and_trailing"` is a recorded deviation from the standard's `"any"` default. Revisit if the standard changes its shipped MD060 style, or if a future sub-project wants root-Prettier-governed JS/TS.

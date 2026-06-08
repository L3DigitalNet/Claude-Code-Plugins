---
title: 'ADR-0001: Markdown-tooling adoption deviations (Prettier JS/TS scope; MD060)'
status: accepted
date: 2026-06-08
---

# ADR-0001: Markdown-tooling adoption deviations

Two deliberate deviations were made while adopting the project-standards markdown-tooling standard. Both are recorded here per standard §14.

## Context and Problem Statement

The standard makes Prettier the authority for formatting every file type it supports and ships a fully explicit markdownlint rule set. Two parts of that did not fit this plugins meta-repo as written:

1. **JS/TS source.** `prettier .` would format the 27 tracked TypeScript/JavaScript files of the `home-assistant-dev` MCP server (`.ts`/`.tsx`/`.js`/`.jsx`/`.mjs`/`.cjs`, incl. a bundled `dist/*.cjs`). That sub-project has its own `eslint.config.js` + `tsconfig` and no Prettier; reformatting it would risk fighting its ESLint.
2. **MD060 (table-column-style).** Prettier emits `|  |` (two spaces) for empty table cells; markdownlint MD060 "compact" rejects that and a content fix is reverted on the next `prettier --write`. The two tools cannot both be satisfied.

## Considered Options

- **Include JS/TS in root Prettier / keep MD060 enabled** — the most literal reading of the standard, but it couples Markdown formatting to the MCP server's build/test toolchain and leaves MD060 in a permanent conflict with Prettier.
- **Exclude JS/TS via `.prettierignore`; disable MD060** — root Prettier governs only structured-text (`md`/`json`/`yaml`/`code-workspace`); the JS/TS sub-project keeps its own toolchain authoritative; the formatter-owned MD060 is turned off.

## Decision Outcome

Chosen: **exclude JS/TS and disable MD060.**

- `.prettierignore` excludes `*.ts *.tsx *.js *.jsx *.mjs *.cjs` (gitignore syntax, one pattern per line). The standard already scopes `.py` source out of Prettier (owned by ruff); JS/TS source is the direct analogue, and the reference repo's own `format.yml` never lists `js`/`ts`.
- `"MD060": false` in `.markdownlint.json`. This follows the standard's own documented principle of disabling markdownlint rules that Prettier owns (MD009/MD010/MD013/MD030/MD032 are already off for the same reason); MD060 is a newer rule the reference config left enabled by oversight.

### Consequences

- Root Prettier never fights the MCP server's ESLint or table whitespace; no MCP build/test gate is coupled to Markdown formatting.
- These are explicit, recorded deviations from the standard's "Prettier owns every supported file type" and "fully explicit rule set" intent. Revisit if a future sub-project wants root-Prettier-governed JS/TS, or if markdownlint changes MD060 to not conflict with Prettier's empty-cell output.

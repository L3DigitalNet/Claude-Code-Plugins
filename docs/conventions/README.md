---
schema_version: '1.1'
id: 'index-n7x3q1-repository-conventions'
title: 'Repository Conventions'
description: 'Repository conventions for Claude-Code-Plugins, covering frontmatter values and tooling.'
doc_type: 'index'
status: 'active'
created: '2026-06-08'
updated: '2026-06-08'
tags:
  - 'conventions'
  - 'readme'
aliases: []
related: []
---

# Repository Conventions

## Purpose

This document outlines conventions used throughout this repository. They must not and do not conflict with any standards adopted from [project-standards](https://github.com/L3DigitalNet/project-standards).

## Table of Contents

- [Repository Conventions](#repository-conventions)
  - [Purpose](#purpose)
  - [Table of Contents](#table-of-contents)
  - [Frontmatter Values and Format](#frontmatter-values-and-format)
    - [`id`](#id)
  - [Plans and Specs](#plans-and-specs)
  - [Frontmatter Scope Expansion](#frontmatter-scope-expansion)
    - [Prerequisites](#prerequisites)
    - [Widening Order](#widening-order)
    - [Out of Scope](#out-of-scope)
  - [Tooling](#tooling)

## Frontmatter Values and Format

The [SSOT](https://github.com/L3DigitalNet/project-standards/tree/main/standards/markdown-frontmatter).

### `id`

The document id shall consist of the document type followed by a random 6 character length base36 number followed by the document title stripped of date, numerical, or other prefixes.

`[doc_type]-[random base36-6]-[title]`

For example: `research-79ybcr-codex-cli-headless-exec-inter-agent`

## Plans and Specs

All plans and spec file names should be prefixed with the date in `YYYY-MM-DD` format followed by the spec name in lower kebab case.

For example: `2024-06-08-codex-cli-headless-exec-inter-agent.md`

## Frontmatter Scope Expansion

Frontmatter coverage is currently scoped to `docs/research/**/*.md`. Widening to additional directories is intentional but gated — expand only when the following criteria are met:

### Prerequisites

1. **Existing scope is stable.** CI is green on `validate-frontmatter`, no known lint violations or formatting drift in the current scope.
2. **The target directory has a defined `doc_type`.** Every file in the target must map to a controlled `doc_type` value supported by the schema. If a new type is needed, open a PR to `project-standards` first.
3. **A migration plan exists for existing files.** All files currently in the target directory must be audited and conforming frontmatter added before the path is added to `.project-standards.yml`. Do not widen the gate and then fix violations — the gate must be green from day one of the new scope.
4. **Vendored or generated files are explicitly excluded.** Any files in the target directory that are not first-party authored must be listed under `exclude` in `.project-standards.yml` before widening.

### Widening Order

Not on a fixed schedule — each step requires the prerequisites above:

1. `docs/conventions/`
2. `docs/research/`
3. `docs/superpowers/`
4. `docs/plans/`
5. `docs/decisions/`

**Do not:**

- Add a path to `.project-standards.yml` before all files in that path are conforming.
- Widen scope as part of a larger unrelated PR — scope expansions are their own commit so CI delta is readable.
- Widen scope to a directory that contains generated files without first adding those files to the `exclude` list.

### Out of Scope

Directories and files that tend to see high churn and are not of interest to the community should not be tracked.

1. `docs/handoff/` - agent-specific session state, high churn
2. Any dot folder (e.g. `.github/`) - repo backend operations

## Tooling

- **Markdown formatting → Prettier** (`npm run format` / `npm run format:check`). Prettier 3.8.3 is the pinned version; do not add a second formatter.
- **No Python `src/` package.** This repo has no installable Python library. Ad-hoc scripts live under `scripts/` and are run directly.

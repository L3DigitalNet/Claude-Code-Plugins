# Markdown Tooling Adoption Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Adopt the project-standards **markdown-tooling** standard (Prettier + markdownlint + EditorConfig, CI-enforced) across the `Claude-Code-Plugins` repo, with JS/TS source excluded via `.prettierignore`.

**Architecture:** Copy-adopt the reference dogfood from `~/projects/project-standards`. Prettier (pinned via a committed root `package.json`) formats `md`/`json`/`jsonc`/`yaml`/`code-workspace`; markdownlint (via `npx`/a reusable CI workflow) lints Markdown structure. A one-time bulk `--write`/`--fix` pass normalizes the existing tree; two CI workflows then enforce it. The mechanical reformat is isolated in its own commit, CI is added last, and the user's uncommitted `TODO.md` edits are protected by a preflight.

**Tech Stack:** Prettier 3.8.3, `markdownlint-cli2` + `markdownlint-cli2-action@v23` (reusable workflow `@v2`), EditorConfig, Node 24/npm 11 (local) / Node 22 (CI), GitHub Actions.

**Spec:** [`docs/superpowers/specs/2026-06-08-markdown-tooling-adoption-design.md`](../specs/2026-06-08-markdown-tooling-adoption-design.md) (Codex-converged, 4 rounds).

**Reference source of truth:** `~/projects/project-standards` (local checkout) — every config below is copied/adapted from it.

---

## File Structure

| Path | New/Modify | Responsibility |
| --- | --- | --- |
| `.prettierrc.json` | new | Prettier config (verbatim from reference; `proseWrap: never` + `useTabs: true`). |
| `.markdownlint.json` | new | markdownlint rule set (verbatim; 53 rules explicit, MD043 inert). |
| `.markdownlint-cli2.jsonc` | new | Local runner config (`globs`, `gitignore: true`). |
| `.editorconfig` | new | Cross-editor floor (verbatim; forward-compatible with later Python cycle). |
| `.prettierignore` | new | Exclude JS/TS source (D5 / ADR-0001). gitignore syntax. |
| `package.json` | new | Pin `prettier@3.8.3`; `format`/`format:check` scripts. |
| `package-lock.json` | new (generated) | Lockfile for reproducible CI installs. |
| `.gitignore` | modify | `.vscode/` → `.vscode/*` + negations for the two tracked editor files. |
| `.vscode/extensions.json` | new | Recommend the 3 Markdown/structured-text extensions (markdown-only subset). |
| `.vscode/settings.json` | new | Prettier as default formatter for md/json/jsonc/yaml (formatter blocks only). |
| `.github/workflows/lint-markdown.yml` | new | Caller of the reusable markdownlint workflow `@v2`. |
| `.github/workflows/format.yml` | new | Repo-local Prettier `--check` CI (verbatim from reference). |
| `.project-standards.yml` | new | `markdown_tooling.version: "1.0"` label (minimal). |
| `docs/decisions/adr-0001-prettier-jsts-scope.md` | new | ADR recording the D5 JS/TS exclusion. |
| `AGENTS.md` | modify | Append the standard's §12 tooling instruction block. |
| `TODO.md` | modify | Check the "Adopt markdown-tooling" box (hunk-isolated, last). |
| `docs/handoff/specs-plans.md` | modify | Flip spec row status to "Implemented". |
| (tracked, **non-ignored** `.md`/`.json`/`.yaml`/`.code-workspace`) | modify | One-time Prettier/markdownlint normalization. Post-fix `git diff --name-only` is the ground-truth touched-set. Two tracked-but-gitignored files are _not_ governed: `.claude/state/test-checklist.md` (root-ignored) and `plugins/home-assistant-dev/mcp-server/package-lock.json` (nested-ignored) — intentional. |

---

## Task 0: Preflight — protect the dirty `TODO.md` and clean the tree

**Files:** none yet (inspection only).

- [ ] **Step 1: Inspect working-tree state**

Run: `git status --short` Expected: `TODO.md` shows ` M` (the user's uncommitted Purpose/Usage restructure). The spec + codex-review files are already committed (`83a6cf9`). There should be no other dirty/untracked **supported** files.

- [ ] **Step 2: Enumerate untracked supported files (none may be silently reformatted)**

Run: `git ls-files -o --exclude-standard | grep -iE '\.(md|json|jsonc|ya?ml|code-workspace)$' || echo "NONE"` Expected: `NONE`. If any appear, **STOP** — commit, gitignore, or get explicit user approval before the Task 2 fix pass (it writes the whole working tree, not just tracked files).

- [ ] **Step 3: Resolve the dirty `TODO.md` before any reformat**

`TODO.md` is one of the Markdown files the Task 2 fix pass will rewrite. Its current edits are the user's in-progress work. **STOP and ask the user to commit (or set aside) their `TODO.md` edits**, OR get explicit consent to let the reformat touch it. Do **not** proceed to Task 2 until `git status --short` shows `TODO.md` either clean or explicitly approved.

- [ ] **Step 4: Confirm branch + tree ready**

Run: `git branch --show-current` → expect `main` (direct-commit convention; a topic branch is optional). Re-run `git status --short` and confirm only approved changes remain.

---

## Task 1: Tooling config files + Prettier pin

**Files:**

- Create: `.prettierrc.json`, `.markdownlint.json`, `.markdownlint-cli2.jsonc`, `.editorconfig`, `.prettierignore`, `package.json`
- Generate: `package-lock.json`
- Modify: `.gitignore`

- [ ] **Step 1: Baseline — confirm no formatter exists yet**

Run: `test -f package.json && echo EXISTS || echo "no root package.json (expected)"` Expected: `no root package.json (expected)`.

- [ ] **Step 2: Copy `.prettierrc.json` (verbatim from reference)**

Create `.prettierrc.json`:

```json
{
	"$schema": "https://json.schemastore.org/prettierrc.json",
	"printWidth": 88,
	"tabWidth": 2,
	"useTabs": true,
	"endOfLine": "lf",
	"semi": false,
	"singleQuote": false,
	"jsxSingleQuote": false,
	"quoteProps": "consistent",
	"trailingComma": "es5",
	"arrowParens": "always",
	"bracketSpacing": true,
	"bracketSameLine": false,
	"singleAttributePerLine": false,
	"objectWrap": "collapse",
	"proseWrap": "never",
	"htmlWhitespaceSensitivity": "css",
	"experimentalTernaries": false,
	"experimentalOperatorPosition": "end",
	"embeddedLanguageFormatting": "auto",
	"vueIndentScriptAndStyle": false,
	"requirePragma": false,
	"insertPragma": false,
	"overrides": [
		{ "files": "**/*.jsonc", "options": { "trailingComma": "none" } },
		{ "files": "**/*.md", "options": { "singleQuote": true } }
	]
}
```

- [ ] **Step 3: Copy the markdownlint rule set (`.markdownlint.json`, verbatim)**

The simplest reliable copy is from the local reference; it is byte-for-byte the seedable artifact.

Run: `cp ~/projects/project-standards/.markdownlint.json .markdownlint.json`

Then verify the load-bearing values are present:

Run: `python3 -c "import json; c=json.load(open('.markdownlint.json')); assert c['default'] is True; assert c['MD043'] is True; assert c['MD013'] is False; assert c['MD025']=={'front_matter_title':'','level':1}; print('rule set OK')"` Expected: `rule set OK` (confirms `default:true`, MD043 inert, MD013 off, MD025 frontmatter model).

- [ ] **Step 4: Create `.markdownlint-cli2.jsonc`**

```jsonc
{
	// Local runner config (CLI + the VS Code markdownlint extension). NOT part of the
	// published standard — the seedable artifact is .markdownlint.json, which
	// markdownlint-cli2 auto-merges. This file only controls which files a bare
	// `npx markdownlint-cli2` lints and that it honors .gitignore, so a local run
	// matches CI. CI passes `globs` explicitly because the action's own default is
	// the non-recursive `*.{md,markdown}`.
	"globs": ["**/*.md"],
	"gitignore": true,
}
```

- [ ] **Step 5: Copy `.editorconfig` byte-identically from the reference** (verbatim — forward-compatible with the later Python cycle)

Run: `cp ~/projects/project-standards/.editorconfig .editorconfig`

Then verify byte-identity: `diff .editorconfig ~/projects/project-standards/.editorconfig && echo "editorconfig OK"` → expect `editorconfig OK` (no diff). The reference file's `[*]` block is `indent_style = tab`, `[*.{yml,yaml}]`/`[*.md]` follow, plus `[*.py]`/`[*.toml]` (forward-compatible). Do **not** retype it inline — copy it so future reference syncs diff cleanly.

- [ ] **Step 6: Create `.prettierignore` (D5 / ADR-0001 — gitignore syntax, one pattern per line, NO braces)**

```gitignore
# JS/TS source is owned by each sub-project's own toolchain (the
# home-assistant-dev MCP server's ESLint + tsc), analogous to how this standard
# puts .py source out of Prettier's scope. Recorded as ADR-0001.
# .prettierignore uses gitignore syntax — one pattern per line, no brace expansion.
# A leading-slash-free pattern matches at any depth; *.cjs covers dist/server.bundle.cjs.
*.ts
*.tsx
*.js
*.jsx
*.mjs
*.cjs
```

- [ ] **Step 7: Create root `package.json` (pin Prettier)**

```json
{
	"name": "claude-code-plugins",
	"version": "0.0.0",
	"private": true,
	"description": "Dev tooling only (Prettier). Pins the Markdown/structured-text formatter for this plugins meta-repo; the repo's product is the plugins + docs, not a Node package.",
	"scripts": { "format": "prettier --write .", "format:check": "prettier --check ." },
	"devDependencies": { "prettier": "3.8.3" }
}
```

- [ ] **Step 8: Install Prettier (generates `package-lock.json`, fetches `node_modules/`)**

Run: `npm install` Expected: creates `package-lock.json` and `node_modules/`; exit 0.

- [ ] **Step 9: Verify the pinned Prettier resolves**

Run: `npx prettier --version` Expected: `3.8.3`.

- [ ] **Step 10: Edit `.gitignore` to un-ignore the two VS Code files**

`.gitignore` currently has a bare `.vscode/` line. Git **cannot** re-include a file whose parent dir is excluded, so change the directory pattern to `.vscode/*` and add negations. Replace the line `.vscode/` with:

```gitignore
.vscode/*
!.vscode/settings.json
!.vscode/extensions.json
```

(`node_modules/` is already present at `.gitignore:2` — do not duplicate it.)

- [ ] **Step 11: Verify the negation works (empirically)**

Use the **quiet** form — `git check-ignore -v` is unreliable here: with a `!` negation it prints the negation rule and exits `0` even though the file is _not_ ignored. The reliable signals are `-q` (exit 1 = not ignored) and a dry-run add:

```bash
git check-ignore -q .vscode/settings.json; echo "q-exit=$?  # expect 1 = NOT ignored"
mkdir -p .vscode && printf '{}\n' > .vscode/settings.json
git add --dry-run .vscode/settings.json   # expect: prints "add '.vscode/settings.json'" (would stage)
rm -rf .vscode
```

Expected: `q-exit=1` and the dry-run shows the file would be added. If `q-exit=0`, the pattern is wrong — re-check Step 10.

- [ ] **Step 12: Commit the config layer**

```bash
git add .prettierrc.json .markdownlint.json .markdownlint-cli2.jsonc .editorconfig .prettierignore package.json package-lock.json .gitignore
git commit -m "build(markdown-tooling): add Prettier + markdownlint config + pin (no reformat yet)"
```

---

## Task 2: One-time bulk reformat + markdownlint normalization

**Files:** tracked, **non-ignored** `.md`/`.json`/`.jsonc`/`.yaml`/`.code-workspace` (the mechanical diff). Excludes JS/TS via `.prettierignore`, and the two tracked-but-gitignored files (both tools honor `.gitignore`); the post-fix `git diff --name-only` is the authoritative touched-set.

- [ ] **Step 1: Confirm preflight still holds (no stray untracked supported files)**

Run: `git status --short` and `git ls-files -o --exclude-standard | grep -iE '\.(md|json|jsonc|ya?ml|code-workspace)$' || echo NONE` Expected: clean tree (Task 1 committed); `NONE` untracked supported files. If not, STOP (Task 0).

- [ ] **Step 2: Run the Prettier write pass**

Run: `npx prettier --write .` Expected: lists reformatted files (md/json/yaml/code-workspace). It must **not** list any `.ts`/`.js`/`.mjs`/`.cjs` (excluded by `.prettierignore`).

- [ ] **Step 3: Run the markdownlint auto-fix pass**

Run: `npx markdownlint-cli2 --fix "**/*.md"` Expected: auto-fixes structural issues in place; prints a summary. A non-zero exit here means residual (non-auto-fixable) violations remain — handle in Step 5.

- [ ] **Step 4: Scope guard — verify NO JS/TS was touched (inverted exit; success = no match)**

Run:

```bash
if git diff --name-only | grep -E '\.(ts|tsx|js|jsx|mjs|cjs)$'; then echo "FAIL: JS/TS leaked into the diff"; exit 1; else echo "scope guard OK"; fi
```

Expected: `scope guard OK`. If it fails, the `.prettierignore` is not matching — fix it before continuing.

- [ ] **Step 5: Run the check contract; triage any residual markdownlint violations**

Run: `npx prettier --check . && npx markdownlint-cli2 "**/*.md"` Expected: both clean (exit 0). The rule set is tuned not to fight Prettier, so the fix pass should yield a clean tree. **If markdownlint still reports violations** (these are content rules `--fix` cannot auto-resolve), fix the Markdown per the rule — do **not** disable the rule:

| Rule | Meaning | Fix |
| --- | --- | --- |
| MD040 | fenced code block has no language | add a language (` ```bash `, ` ```json `, ` ```text `) |
| MD033 | inline HTML element | replace with Markdown, or remove; HTML comments `<!-- -->` are not flagged |
| MD045 | image missing alt text | add `![alt](src)` text |
| MD034 | bare URL | wrap as `<https://…>` or a `[text](url)` link (usually auto-fixed) |
| MD059 | non-descriptive link text ("here"/"click here"/"link"/"more") | rewrite the link text to describe the target |
| MD042 | empty link `[]()` | give it a real destination or remove |

Re-run this step until both commands are clean.

- [ ] **Step 6: Sanity — all tracked JSON still parses**

Run: `git ls-files '*.json' -z | xargs -0 -n1 jq empty && echo "all JSON valid"` Expected: `all JSON valid` (no `jq` parse error).

- [ ] **Step 7: Sanity — marketplace + plugin manifests still validate**

Run: `bash scripts/validate-marketplace.sh` Expected: pass (whitespace-only changes do not affect Zod field validation).

- [ ] **Step 8: Sanity — no whitespace breakage**

Run: `git diff --check` Expected: no output.

- [ ] **Step 9: Commit the mechanical reformat in isolation**

```bash
git add -u
git commit -m "style(markdown-tooling): one-time Prettier + markdownlint normalization

Mechanical: prettier --write . + markdownlint-cli2 --fix over all tracked
md/json/yaml/code-workspace. JS/TS excluded via .prettierignore. No content changes."
```

(Use `git add -u` to stage only already-tracked modifications; the new `.vscode/` files come in Task 3.)

---

## Task 3: VS Code workspace config (markdown-only subset)

**Files:**

- Create: `.vscode/extensions.json`, `.vscode/settings.json` (must be `git add -f`-ed — `.vscode/` is otherwise ignored)

- [ ] **Step 1: Create `.vscode/extensions.json` (the 3 Markdown/structured-text extensions only)**

```json
{
	"recommendations": [
		"editorconfig.editorconfig",
		"esbenp.prettier-vscode",
		"DavidAnson.vscode-markdownlint"
	]
}
```

> Note: the reference repo's file also lists Python/ruff/basedpyright extensions because it adopts the Python standard too — those are intentionally **omitted** here (that's the deferred python-tooling cycle).

- [ ] **Step 2: Create `.vscode/settings.json` (formatter blocks only — no personal prefs)**

```json
{
	"[markdown]": {
		"editor.defaultFormatter": "esbenp.prettier-vscode",
		"editor.formatOnSave": true
	},
	"[json]": { "editor.defaultFormatter": "esbenp.prettier-vscode" },
	"[jsonc]": { "editor.defaultFormatter": "esbenp.prettier-vscode" },
	"[yaml]": { "editor.defaultFormatter": "esbenp.prettier-vscode" }
}
```

- [ ] **Step 3: Format the new files so they pass the Prettier gate**

Run: `npx prettier --write .vscode/extensions.json .vscode/settings.json` Expected: both reformatted to tabs (or already clean).

- [ ] **Step 4: Verify they are NOT ignored, then force-add**

Run:

```bash
if git check-ignore -q .vscode/settings.json .vscode/extensions.json; then echo "FAIL: still ignored"; exit 1; fi
git add -f .vscode/settings.json .vscode/extensions.json
git ls-files .vscode/settings.json .vscode/extensions.json
```

Expected: no "FAIL"; the final `git ls-files` lists **both** files.

- [ ] **Step 5: Commit**

```bash
git commit -m "build(markdown-tooling): add VS Code Prettier/markdownlint workspace config"
```

---

## Task 4: CI workflows (added before the seal, enforce on next push)

**Files:**

- Create: `.github/workflows/lint-markdown.yml`, `.github/workflows/format.yml`

- [ ] **Step 1: Create the markdownlint caller workflow `.github/workflows/lint-markdown.yml`**

```yaml
name: Lint Markdown

on:
  push:
    branches: ['main']
    paths:
      - '**/*.md'
      - '.markdownlint.json'
      - '.markdownlint-cli2.jsonc'
      - '.github/workflows/lint-markdown.yml'
  pull_request:
    paths:
      - '**/*.md'
      - '.markdownlint.json'
      - '.markdownlint-cli2.jsonc'
      - '.github/workflows/lint-markdown.yml'

jobs:
  lint-markdown:
    uses: L3DigitalNet/project-standards/.github/workflows/lint-markdown.yml@v2
    with:
      globs: '**/*.md'
```

- [ ] **Step 2: Create the Prettier workflow `.github/workflows/format.yml` (verbatim from reference)**

```yaml
name: Format

on:
  push:
    branches: ['main']
    paths:
      - '**/*.md'
      - '**/*.json'
      - '**/*.jsonc'
      - '**/*.yml'
      - '**/*.yaml'
      - '**/*.code-workspace'
      - '.prettierrc.json'
      - '.prettierignore'
      - 'package.json'
      - 'package-lock.json'
      - '.github/workflows/format.yml'
  pull_request:
    paths:
      - '**/*.md'
      - '**/*.json'
      - '**/*.jsonc'
      - '**/*.yml'
      - '**/*.yaml'
      - '**/*.code-workspace'
      - '.prettierrc.json'
      - '.prettierignore'
      - 'package.json'
      - 'package-lock.json'
      - '.github/workflows/format.yml'

jobs:
  prettier:
    name: Prettier
    runs-on: ubuntu-latest
    steps:
      - name: Check out repository
        uses: actions/checkout@v6
      - name: Set up Node
        uses: actions/setup-node@v6 # repo convention (existing workflows use @v6); reference uses @v4
        with:
          node-version: '22'
          cache: npm
      - name: Install pinned Prettier
        run: npm ci
      - name: Check formatting
        run: npx prettier --check .
```

- [ ] **Step 3: Format the new workflow files + verify the whole tree is still clean**

Run: `npx prettier --write .github/workflows/lint-markdown.yml .github/workflows/format.yml && npx prettier --check . && npx markdownlint-cli2 "**/*.md"` Expected: all clean (exit 0).

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/lint-markdown.yml .github/workflows/format.yml
git commit -m "ci(markdown-tooling): enforce markdownlint (reusable @v2) + Prettier --check"
```

---

## Task 5: Agent instructions + contract label + ADR

**Files:**

- Modify: `AGENTS.md`
- Create: `.project-standards.yml`, `docs/decisions/adr-0001-prettier-jsts-scope.md`

- [ ] **Step 1: Append the tooling block to `AGENTS.md`**

Append this section (the standard's §12 block, with the JS/TS exclusion noted). The outer fence below is **four backticks** so the inner ` ```bash ` fences render literally — write them as ordinary triple-backtick fences in `AGENTS.md`:

````markdown
## Markdown & Structured-Text Tooling

This repository follows the Markdown Tooling Standard. Prettier formats the structured-text it supports (`md`/`json`/`jsonc`/`yaml`/`code-workspace`); markdownlint lints Markdown structure only. JS/TS source is excluded from Prettier (see `docs/decisions/adr-0001-prettier-jsts-scope.md`). Do not introduce a competing formatter or linter.

### Fix pass

When changing Markdown, JSON, JSONC, or YAML, run the fix pass first:

```bash
npx prettier --write .
npx markdownlint-cli2 --fix "**/*.md"
```

### Check contract

Before considering work complete, run the non-mutating check:

```bash
npx prettier --check .
npx markdownlint-cli2 "**/*.md"
```

Do not claim completion if either command fails.

### Rules

- Prettier owns physical formatting. Do not fight its output or hand-format.
- markdownlint owns Markdown structure. Do not disable a rule to silence a warning — fix the Markdown.
- Do not edit `.prettierrc.json` or `.markdownlint.json` to bypass a check without a documented ADR exception.
````

- [ ] **Step 2: Create `.project-standards.yml` (minimal — markdown-tooling label only)**

```yaml
# Contract-version selection for the copy-adopted markdown-tooling standard.
# Validated-if-present metadata only — no enforcement by itself; the lint-markdown
# + format workflows are the enforcement. The markdown-frontmatter and python-tooling
# standards are NOT adopted in this cycle and are intentionally absent here.
markdown_tooling:
  version: '1.0'
```

- [ ] **Step 3: Create the ADR `docs/decisions/adr-0001-prettier-jsts-scope.md`**

```markdown
---
title: 'ADR-0001: Prettier scope excludes JS/TS source'
status: accepted
date: 2026-06-08
---

# ADR-0001: Prettier scope excludes JS/TS source

## Context and Problem Statement

Adopting the markdown-tooling standard wires `prettier .`, which formats every file type Prettier supports — including the 27 tracked TypeScript/JavaScript files of the `home-assistant-dev` MCP server (`.ts`/`.tsx`/`.js`/`.jsx`/`.mjs`/`.cjs`, including a bundled `dist/*.cjs`). That sub-project has its own `eslint.config.js` + `tsconfig` and no Prettier of its own. Letting root Prettier reformat it would produce a large diff and risk fighting its ESLint stylistic rules.

## Considered Options

- **A. Include JS/TS in root Prettier** — the most literal reading of the standard; requires adding `js`/`ts` to CI path filters and running the MCP server's lint/typecheck/test/build on every formatting change to prove no breakage.
- **B. Exclude JS/TS via `.prettierignore`** — root Prettier governs only structured-text (`md`/`json`/`yaml`/`code-workspace`); each JS/TS sub-project keeps its own toolchain authoritative.

## Decision Outcome

Chosen: **Option B**. The markdown-tooling standard already scopes source code (`.py`) out of Prettier (owned by ruff); JS/TS source is the direct analogue, and the reference repo's own `format.yml` never lists `js`/`ts`. `.prettierignore` excludes `*.ts *.tsx *.js *.jsx *.mjs *.cjs` (gitignore syntax, one pattern per line).

### Consequences

- Root Prettier never fights the MCP server's ESLint; no MCP build/test gate is coupled to Markdown formatting changes.
- This is an explicit, recorded deviation from the standard's "Prettier owns every supported file type" intent, per standard §14. Revisit if a future sub-project wants root-Prettier-governed JS/TS.
```

- [ ] **Step 4: Format the new/modified docs + verify the gate**

Run: `npx prettier --write AGENTS.md .project-standards.yml docs/decisions/adr-0001-prettier-jsts-scope.md && npx prettier --check . && npx markdownlint-cli2 "**/*.md"` Expected: all clean (exit 0). Fix any markdownlint hit in the new files per Task 2 Step 5.

- [ ] **Step 5: Commit**

```bash
git add AGENTS.md .project-standards.yml docs/decisions/adr-0001-prettier-jsts-scope.md
git commit -m "docs(markdown-tooling): agent tooling block + contract label + ADR-0001 (JS/TS scope)"
```

---

## Task 6: Seal — TODO checkbox, index status, final gate, push

**Files:**

- Modify: `TODO.md` (hunk-isolated), `docs/handoff/specs-plans.md`

- [ ] **Step 1: Flip the TODO checkbox (hunk-isolated — never `git add TODO.md` wholesale)**

In `TODO.md`, change exactly the one line: `  - [ ] Adopt markdown-tooling` → `  - [x] Adopt markdown-tooling` Leave the user's surrounding restructure untouched.

- [ ] **Step 2: Stage ONLY the checkbox hunk and verify isolation**

Run:

```bash
git add -p TODO.md   # stage only the checkbox hunk; skip all other hunks
git diff --cached -- TODO.md
```

Expected: the staged diff shows **only** the `- [ ]` → `- [x]` change. If other hunks are staged, `git restore --staged TODO.md` and redo.

- [ ] **Step 3: Update the spec-row status in `docs/handoff/specs-plans.md`**

Change the markdown-tooling spec row status from `In Codex review` to `Implemented — <range>`, where `<range>` is the **full implementation commit range** (first config commit `..` this seal commit), not the reformat commit alone — get it from `git log --oneline origin/main..HEAD`. Also add a row for this plan: `| 2026-06-08 | docs/superpowers/plans/2026-06-08-markdown-tooling-adoption.md | Implemented | Markdown-tooling adoption plan (6 tasks); executed. |`

Then format the edited index so it passes the gate: `npx prettier --write docs/handoff/specs-plans.md`

- [ ] **Step 4: Final full check contract (must be clean)**

Run: `npx prettier --check . && npx markdownlint-cli2 "**/*.md" && echo "GATE GREEN"` Expected: `GATE GREEN`.

- [ ] **Step 5: Commit the seal**

```bash
git add docs/handoff/specs-plans.md
git commit -m "chore(markdown-tooling): mark adoption complete (TODO + specs-plans)"
```

(The `TODO.md` checkbox hunk was already staged in Step 2; include it — confirm `git status` shows no unintended `TODO.md` hunks committed.)

- [ ] **Step 6: Review exactly what will publish, then push**

Run: `git log --oneline origin/main..HEAD` Expected: the markdown-tooling commit set (3 pre-existing design/spec/plan commits + the ~6 implementation commits from Tasks 1–6). Confirm nothing unexpected, then: Run: `git push origin main`

- [ ] **Step 7: Verify CI for THIS head SHA (not stale runs)**

Run:

```bash
SHA=$(git rev-parse HEAD)
gh run list --branch main --limit 20 --json headSha,name,conclusion,status \
  | jq -r --arg s "$SHA" '.[] | select(.headSha==$s) | "\(.name): \(.status)/\(.conclusion)"'
```

Expected — for this head SHA, these workflows run and conclude `success`:

- `Lint Markdown` ✅ and `Format` ✅ (the two new gates).
- `CodeQL` ✅ (runs on every push).
- `ha-dev-plugin-tests` ✅ — it **does** trigger, because the reformat touched `plugins/home-assistant-dev/**` (its path filter); confirm whitespace changes didn't regress it.

**Not applicable (must NOT be treated as red):** `plugin-test-harness-ci` does **not** trigger — its path filter is `plugins/plugin-test-harness/**` and that directory is absent. A workflow that correctly didn't run for this SHA is N/A, not a failure.

---

## Acceptance criteria (maps to spec §9)

1. `npx prettier --check .` and `npx markdownlint-cli2 "**/*.md"` exit clean locally.
2. `Lint Markdown` + `Format` workflows green on `main`; no pre-existing workflow regresses.
3. `scripts/validate-marketplace.sh` passes; all tracked JSON parses (`jq empty`).
4. No `.ts`/`.tsx`/`.js`/`.jsx`/`.mjs`/`.cjs` file appears in the adoption diff.
5. `.vscode/settings.json` + `.vscode/extensions.json` tracked (un-ignored, force-added); `AGENTS.md` carries the tooling block; `ADR-0001` present.
6. User's `TODO.md` restructure preserved; "Adopt markdown-tooling" checked via a hunk-isolated edit; `docs/handoff/specs-plans.md` updated; `state.md`-generator follow-up (spec §7) recorded for the Python cycle.

---

## Rollback

The adoption is a contiguous commit range on `main` (Tasks 1–6), so the clean rollback is to revert that range in reverse order:

- [ ] Identify the range: `git log --oneline origin/main..HEAD` (or the pushed range). The boundary is the **first config commit** (Task 1) through the **seal commit** (Task 6).
- [ ] Revert in reverse: `git revert --no-commit <seal>..<first-config>^` then `git commit`, **or** revert commits individually newest-first. This removes the CI workflows, `.vscode/` config, ADR/label/AGENTS block, the mechanical reformat, and the root `package.json`/lockfile/`.gitignore` edit together.
- [ ] The `TODO.md` checkbox revert returns it to `- [ ]`; re-confirm the user's surrounding restructure is intact.
- [ ] `node_modules/` is gitignored — delete it manually if desired (`rm -rf node_modules`).
- [ ] Re-run `bash scripts/validate-marketplace.sh` after rollback to confirm manifests still validate.

Partial rollback (e.g. keep the configs but undo only the reformat) is **not** recommended — it would leave CI red on the un-reformatted tree.

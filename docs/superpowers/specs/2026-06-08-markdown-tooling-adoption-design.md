# Markdown Tooling Standard — Adoption Design

**Date:** 2026-06-08
**Status:** Approved (brainstorm) — ready for implementation plan
**Standard:** [`L3DigitalNet/project-standards` → `standards/markdown-tooling`](https://github.com/L3DigitalNet/project-standards/tree/main/standards/markdown-tooling) (contract version `1.0`)
**Reference implementation:** the standards repo itself dogfoods this standard (`~/projects/project-standards`) — copy-adopt from there.
**TODO item closed by this work:** `TODO.md` → "Adopt markdown-tooling".

This is the **first of two independent adoption cycles**. The sibling "Adopt python-tooling" item is deferred to its own later spec/plan cycle and is **out of scope** here.

---

## 1. Goal & end state

Prettier (formatter), markdownlint (Markdown structural linter), and EditorConfig (cross-editor floor) govern all supported structured-text in the repo, enforced by CI. The completion gate is the standard's non-mutating **check contract**:

```bash
npx prettier --check .
npx markdownlint-cli2 "**/*.md"
```

The repo mirrors the standards repo's own dogfood: Prettier owns physical formatting of every file type it supports; markdownlint owns Markdown-only structure; the two are tuned **not to fight** (13 deliberate markdownlint deviations align to or defer to Prettier's output).

## 2. Locked scope decisions

| # | Decision | Choice | Rationale |
|---|---|---|---|
| D1 | Cycle structure | Two independent cycles; **Markdown first**, Python deferred | The standards are independent (different file types, tooling, enforcement). Markdown is the clean, high-value win; Python needs heavier scoping. |
| D2 | **Markdown** carve-outs | **None** — every tracked, non-gitignored `.md` is linted/formatted | Repo markdown is ~all first-party (143 `plugins/`, 102 `docs/`, 10 root, 10 hidden); no vendored/foreign bucket worth excluding. (Scope of this decision is *Markdown files only*; the separate JS/TS source decision is D5.) The exact touched-set is confirmed by the post-fix-pass diff, not an a-priori count — see §3. |
| D3 | Toolchain pinning | **Committed root `package.json`** (`prettier` pinned as devDep) + `package-lock.json`; `node_modules/` gitignored; `markdownlint-cli2` via npx/CI action | Exact mirror of the reference repo's dogfood (`package.json` pins only Prettier; markdownlint runs via the action in CI and npx locally). |
| D4 | Prettier scope (structured-text) | **Faithful** — Prettier formats `md` + `json`/`jsonc` + `yaml`/`yml` + `.code-workspace` repo-wide | This is exactly the surface the reference repo's own `format.yml` enforces. JSON reformatting (2-space → tabs) is semantically inert for the Zod-validated manifests (validation keys off field names/values, not whitespace). YAML is normalized in-place by Prettier **with spaces** (YAML forbids tab indentation) while preserving valid structure — workflow behavior is unchanged and CI parses them. |
| D5 | JS/TS source | **Out of scope** — excluded via `.prettierignore`; recorded as a **deliberate repo-specific exception** (ADR, §4) | 27 tracked `.ts`/`.js`/`.mjs`/`.cjs` files (the `home-assistant-dev` MCP server + e2e tests + a bundled `dist/*.cjs`) are a self-contained sub-project with its **own** `eslint.config.js` + `tsconfig.json` and no Prettier. **Honest framing:** Prettier *does* support JS/TS, and the standard says Prettier governs every supported type a repo contains — so excluding them is a **repo-specific exception**, not merely "matching the reference" (the reference simply had no JS/TS). The exception is justified — the MCP server's own ESLint/tsc stays authoritative, root Prettier never fights it, and the standard's §2 already scopes source code (`.py`) out — and is recorded as an ADR per standard §14. |

## 3. Blast radius (measured — `git ls-files`, tracked files)

Counts are from `git ls-files` (the **tracked** surface), **not** `fd` (which hides dot-dirs and may include untracked files). The earlier `fd`-based "254" undercounted by omitting 10 hidden tracked docs and 1 doc.

**Authoritative touched-set = the post-fix-pass `git diff`, not an a-priori count.** Both tools honor only the **root** `.gitignore`/`.prettierignore` from the run directory (a root `prettier .` does *not* reliably honor nested `.gitignore` files — verified: `git check-ignore` from root returns no match for the nested `plugins/home-assistant-dev/mcp-server/package-lock.json` or `.claude/state/test-checklist.md`). So rather than claim an exact "enforced" count, the spec treats the numbers above as the **expected blast radius** and makes §6's `git diff --name-only` classification the ground truth: it must contain only `md`/`json`/`yaml`/`code-workspace` and **zero** `js/ts/jsx/tsx/mjs/cjs`. Reformatting the nested generated `package-lock.json` (JSON, inert) is acceptable if it occurs; the only *principled* exclusion is the D5 JS/TS set.

- **265 `.md`** files — 143 `plugins/`, 102 `docs/`, 10 root, **5 `.github/`**, **5 `.claude/`** (the hidden dot-dir docs ARE tracked and in scope, consistent with D2 "no carve-outs"). Reflowed by Prettier (`proseWrap: never` puts each prose block on one line) and structurally normalized by markdownlint.
- **31 `.json`** files — **retabbed from 2-space to tabs** (`useTabs: true`), including all 6 `plugins/*/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, and both `.mcp.json`. Field names/values unchanged → no install or Zod-validation impact.
- **9 `.yaml`/`.yml`** files (GitHub workflows + configs) — normalized by Prettier **with spaces** (YAML disallows tab indentation; the `.editorconfig` sets `[*.{yml,yaml}] indent_style = space`). Structure-preserving; CI parses the workflows as the safety net. **Not** "retabbed to tabs."
- **1 `.code-workspace`** (`Claude-Code-Plugins.code-workspace`) — JSON-with-comments; in Prettier scope (matches the reference `format.yml` filter).
- **27 `.ts`/`.tsx`/`.js`/`.jsx`/`.mjs`/`.cjs`** files (MCP server + e2e + a bundled `dist/*.cjs`) — **excluded** (D5). Verified untouched post-fix-pass via `git diff --name-only` (§6).

## 4. Artifacts added (copy-adopt from the standards repo, verbatim unless noted)

| File | Purpose | Notes |
|---|---|---|
| `.prettierrc.json` | Prettier config | **Verbatim.** `proseWrap: never` + `useTabs: true` are load-bearing; copy explicitly. |
| `.markdownlint.json` | markdownlint rule set (`default: true` + 53 rules explicit, 13 deviations, MD043 inert via `true`) | **Verbatim** — this is the seedable artifact. |
| `.markdownlint-cli2.jsonc` | Repo-local runner config (`globs`, honors `.gitignore`) | So a bare local `npx markdownlint-cli2` matches CI (same files). |
| `.editorconfig` | Cross-editor floor (charset/eol/final-newline/indent; `[*.md] trim_trailing_whitespace = false`) | Copy the reference repo's full file — forward-compatible with the later Python cycle. |
| `package.json` | `private: true`; `prettier` pinned (reference: `3.8.3`); scripts `format`, `format:check` | Minimal; only Prettier pinned. Re-confirm the exact Prettier version against the reference at implementation time. |
| `package-lock.json` | Lockfile for reproducible CI installs | Generated by `npm install`. |
| `.project-standards.yml` | `markdown_tooling: version: '1.0'` label (+ `standards_version`) | **Only** the markdown-tooling label. **No** `markdown.frontmatter` block — that is the separate, un-adopted Frontmatter standard. |
| `.vscode/extensions.json` | Recommend `esbenp.prettier-vscode` + `DavidAnson.vscode-markdownlint` (+ `editorconfig.editorconfig`) | New `.vscode/`. **Must be `git add -f`-ed** and un-ignored (see `.gitignore` edit) — `.vscode/` is currently ignored. |
| `.vscode/settings.json` | Prettier as default formatter for `[markdown]`/`[json]`/`[jsonc]`/`[yaml]`; `formatOnSave` on `[markdown]` only | Formatter blocks only — **no** personal preferences. One-formatter-authority rule: markdownlint is diagnostics-only (no fix-on-save code action). |
| `.github/workflows/lint-markdown.yml` | Calls reusable `L3DigitalNet/project-standards/.github/workflows/lint-markdown.yml@v2` with `globs: '**/*.md'` | The markdownlint CI half. Pin `@v2` (the workflow first ships in `2.0.0`). |
| `.github/workflows/format.yml` | `npm ci` + `npx prettier --check .` | The Prettier CI half — copy-adopt (the standard ships **no** reusable Prettier workflow; the reference repo wires its own). **Path filters mirror the reference verbatim:** `**/*.{md,json,jsonc,yml,yaml,code-workspace}` + the config/lock files — **not** `js`/`ts`. With the `.prettierignore` (D5), a triggered `prettier --check .` and the path filter agree on scope. |
| `AGENTS.md` (append) | The standard's §12 agent instruction block ("Markdown & Structured-Text Tooling": fix pass + check contract + rules) | So future agents run the fix pass and do not fight the formatter. |
| `.prettierignore` (new) | Exclude JS/TS source. **`.prettierignore` uses gitignore syntax — no brace expansion** — so one pattern per line: `*.ts` / `*.tsx` / `*.js` / `*.jsx` / `*.mjs` / `*.cjs` (a leading-slash-free pattern matches at any depth; `*.cjs` covers the bundled `dist/server.bundle.cjs`). | Implements D5. Keeps local `prettier .` aligned with the CI path-filter scope and off the MCP server's ESLint-owned source. **SA-NEW-001 fix:** the earlier `**/*.{ts,js,…}` brace form is invalid in gitignore syntax and would match nothing. |
| `.gitignore` (edit) | **Un-ignore** the two VS Code files. Git cannot re-include a file whose parent dir is excluded, so change the rule from `.vscode/` to `.vscode/*` then negate: `.vscode/*` / `!.vscode/settings.json` / `!.vscode/extensions.json`. | **SA-002 fix (empirically verified):** with `.vscode/` the negation fails (file stays ignored); with `.vscode/*` it succeeds and other `.vscode/` contents stay ignored. `node_modules/` is already present (`.gitignore:2`) — no change. The two files still need `git add -f` on first add. |
| `docs/decisions/adr-0001-prettier-jsts-scope.md` (new) | ADR recording the D5 exception (MADR shape: Context/Problem · Considered Options · Decision Outcome + Consequences). | **SA-001 fix:** standard §14 records deviations as a conformant ADR. Self-contained (does not require adopting the full ADR standard); first ADR in the repo, hence `0001`. |

## 5. Rollout approach

**Direct commits to `main`** (repo convention — `BRANCH_PROTECTION.md`; single-developer, no PR required). A short-lived topic branch is *permitted* but not required; the staged commit sequence below is the unit of review either way. **CI sealed last; mechanical reformat isolated from hand edits.**

### Step 0 — Preflight (SA-003: protect the dirty `TODO.md`)

Before any file changes, run `git status --short`. **`TODO.md` currently carries substantial uncommitted user edits** (a Purpose/Usage restructure with an `LLM-EDIT-BOUNDARY` marker). Because `TODO.md` is itself one of the 265 Markdown files, the Step 2 `prettier --write .` would otherwise reformat those in-progress edits and entangle them with the mechanical diff. Therefore:

- The plan must **stop and ask the user to commit (or set aside) their `TODO.md` edits first**, OR get explicit consent, before running the bulk reformat.
- The "Adopt markdown-tooling" checkbox flip (`- [ ]` → `- [x]`) is a **separate, hunk-isolated `Edit`** at the very end (Step 4) — never a wholesale `git add TODO.md`. Verify with `git diff --cached -- TODO.md` that only the checkbox hunk is staged.

**Broader preflight (SA-NEW-003): the fix pass writes the whole working tree, not just tracked files.** `prettier --write .` and `markdownlint-cli2 --fix "**/*.md"` rewrite *every* supported file under the root, **including untracked, non-ignored ones**. Right now that includes the 3 untracked `docs/codex-reviews/*spec-review*.md` audit files. So before Step 2 the plan must enumerate `git ls-files -o --exclude-standard` (untracked) and `git status --short` (dirty), filter to supported extensions (`md/json/jsonc/yml/yaml/code-workspace`), and for each either **commit it, gitignore it, or get explicit user approval to reformat it** — otherwise the bulk pass silently mutates it. Concretely: **commit the codex-review audit trail (and this spec) first**, so the working tree is clean before the reformat and the reformat diff is purely the mechanical change to already-committed content.

### Commit sequence

1. **Configs** — add `.prettierrc.json`, `.markdownlint.json`, `.markdownlint-cli2.jsonc`, `.editorconfig`, `.prettierignore` (D5), `package.json`; run `npm install` to generate `package-lock.json`; edit `.gitignore` to un-ignore the two `.vscode/` files (`node_modules/` already present). Commit.
2. **Bulk reformat** (isolated commit) — `npx prettier --write .` then `npx markdownlint-cli2 --fix "**/*.md"`. Largest mechanical diff (md + json + yaml + code-workspace; JS/TS excluded by `.prettierignore`). Isolating it keeps `git show` reviewable. **Confirm `git diff --name-only` shows zero `.ts`/`.tsx`/`.js`/`.jsx`/`.mjs`/`.cjs` files** before committing.
3. **Residual content fixes** (only if §6 verification surfaces them) — hand-fixed, separate small commit. Not anticipated (the rule set is tuned not to fight Prettier).
4. **CI + agent + label + editor + ADR** — `.github/workflows/lint-markdown.yml` + `format.yml`, `AGENTS.md` tooling block, `.project-standards.yml`, `docs/decisions/adr-0001-prettier-jsts-scope.md` (the D5 exception), and `.vscode/{settings,extensions}.json` (`git add -f`). Add the enforcing workflows **last**, confirm green. Flip the `TODO.md` checkbox here (hunk-isolated, per Step 0). Note: the ADR + spec are themselves Markdown — they must be written Prettier/markdownlint-clean (or run through the fix pass) so this sealing commit doesn't fail its own CI.

**Why CI last:** wiring the enforcing workflows before the fix pass would make the first CI run red on 265 legacy files. Ordering keeps `main` green throughout.

*Alternatives rejected:* a single mega-commit (un-reviewable ~306-file diff: 265 md + 31 json + 9 yaml + 1 code-workspace); separate PRs per file-type (defeats the standard's "they move together" intent).

## 6. Verification (completion gate)

Run locally and in CI:

```bash
npx prettier --check .
npx markdownlint-cli2 "**/*.md"
```

Plus post-fix-pass sanity before the sealing commit. **Negative checks must be written with inverted exit handling** — `grep`/`git check-ignore` exit non-zero when they find nothing, which is the *success* state here (SA-NEW-002), so a bare command under `set -e` would falsely fail:

- **Scope guard (D5):** `if git diff --name-only | grep -E '\.(ts|tsx|js|jsx|mjs|cjs)$'; then echo "JS/TS leaked into diff"; exit 1; fi` — must find nothing.
- **VS Code artifacts un-ignored:** `if git check-ignore -q .vscode/settings.json .vscode/extensions.json; then echo "still ignored"; exit 1; fi`, **and** `git ls-files .vscode/settings.json .vscode/extensions.json` lists **both** files.
- **Diff classification (authoritative scope check):** `git diff --name-only` after the fix pass contains only `.md`/`.json`/`.yml`/`.yaml`/`.code-workspace` extensions — nothing else.
- **All tracked JSON parses:** `git ls-files '*.json' -z | xargs -0 -n1 jq empty`.
- `scripts/validate-marketplace.sh` passes (manifests unaffected by whitespace).
- **`TODO.md` hunk isolation:** `git diff --cached -- TODO.md` shows only the single checkbox hunk.
- **No whitespace breakage:** `git diff --check` is clean.
- The nested `pyproject.toml`-bearing suites and the MCP server `.ts`/`.js` are untouched (`.prettierignore` excludes them; Prettier never processes `.py`/`.toml`).
- **CI acceptance:** both new workflows (`lint-markdown`, `format`) are green, **and** any pre-existing workflow re-triggered by the changed paths (e.g. `ha-dev-plugin-tests`, `plugin-test-harness-ci`, `codeql`) still passes.

**Residual-violation expectation:** the rule set is tuned so the formatter and linter do not conflict, so the fix pass is expected to yield a clean tree. The check contract is the confirmation. Any stray content-rule hit (e.g. a bare URL under MD034, a missing code-fence language under MD040) is treated as a **fix-the-markdown** content bug per the standard — not a config change. An ADR exception (standard §14) is opened only if a rule proves *systemically* incompatible with house conventions; none is anticipated.

## 7. Known follow-up (flagged, out of scope this cycle)

`docs/handoff/state.md` is regenerated each session by the up-docs **propagate-repo** agent under a 2 KB cap. Once CI enforces Prettier, that agent (or the session-end ritual) must emit Prettier-clean output, or it re-dirties the file and fails CI on the next session. **Tracked as a follow-up** — it belongs with the later Python/agent cycle or a separate small fix, not this Markdown cycle.

## 8. Out of scope

- The **python-tooling** standard (its own later cycle; the `TODO.md` box stays unchecked).
- The **markdown-frontmatter** standard (a different standard; the 82 frontmatter-bearing files are not validated against its schema here).
- Fixing the `state.md` generator (§7).
- The 15 pre-existing failing pytest tests (unrelated to Markdown tooling).
- The `home-assistant-dev/mcp-server` TypeScript source — its `.ts`/`.js` are excluded by `.prettierignore` (D5) and stay owned by its own ESLint/tsc. Its `.json` config (`package.json`, `tsconfig*.json`) *is* reformatted (inert whitespace) along with all other JSON; nested `pyproject.toml`/`.py` are never processed by Prettier.

## 9. Success criteria

1. `npx prettier --check .` and `npx markdownlint-cli2 "**/*.md"` both exit clean locally.
2. The two new CI workflows (`lint-markdown`, `format`) are green on `main` after the sealing commit, and no pre-existing workflow regresses.
3. Marketplace + plugin manifests validate post-retab (`scripts/validate-marketplace.sh`); all tracked JSON parses (`jq empty`).
4. **JS/TS scope guard holds:** no `.ts`/`.tsx`/`.js`/`.jsx`/`.mjs`/`.cjs` file appears in the adoption diff.
5. `.vscode/settings.json` + `.vscode/extensions.json` are tracked (un-ignored, force-added); `AGENTS.md` carries the tooling block.
6. User's uncommitted `TODO.md` edits preserved; the "Adopt markdown-tooling" box is checked via a hunk-isolated edit; `docs/handoff/specs-plans.md` updated; follow-up (§7) recorded.

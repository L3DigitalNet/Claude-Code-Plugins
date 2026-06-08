### Executive summary

Claude Code’s revision resolves the dirty `TODO.md` handling and the YAML wording issue, and it substantially improves the file inventory. Significant findings remain. The revised spec still is not ready for planning/implementation because the `.vscode/` unignore fix is technically incomplete, the JS/TS exclusion is internally inconsistent with the adopted standard, and the new `.prettierignore` pattern is likely ineffective because it uses shell/fast-glob brace syntax in a gitignore-syntax file.

New internet research was required for the `.prettierignore`/gitignore semantics and markdownlint-cli2 ignore behavior.

### Verdict

Needs major specification correction before planning/implementation

### Audit loop status

- Audit type: Follow-up audit
- Spec path: `/home/chris/projects/Claude-Code-Plugins/docs/superpowers/specs/2026-06-08-markdown-tooling-adoption-design.md`
- Prior audit issue count: 5
- Resolved issue count: 2
- Still open issue count: 0
- Partially resolved issue count: 3
- New issue count: 2
- Regression count: 0
- Significant findings remaining: Yes

### Adversarial review performed

I re-read the revised spec, retested all five prior SA findings against current repo evidence, re-inventoried tracked Markdown/JSON/YAML/code-workspace/JS/TS/CJS files, checked current ignore rules, checked tracked-but-ignored files, inspected the local project-standards reference implementation, and attacked the revised acceptance criteria for false positives.

I did not run `npx`, `npm`, Prettier, markdownlint, pytest, or CI jobs because they can install dependencies, write caches/artifacts, rewrite files, or depend on mutable remote state. The remote `L3DigitalNet/project-standards` raw content could not be confirmed through the web tool; I used the local checkout at `/home/chris/projects/project-standards` as repository evidence.

### Prior findings status

#### SA-001: Prettier scope omits tracked TypeScript and JavaScript files

- Previous severity: High
- Current status: Partially resolved
- Evidence: The revised spec now makes an explicit D5 decision to exclude 27 tracked `.ts`/`.js`/`.mjs`/`.cjs` files, adds `.prettierignore`, and adds a post-format JS/TS diff guard. That resolves the prior absence of a decision. However, the spec still says Prettier owns “every file type it supports” and D2 says “File carve-outs: None — format everything,” while D5 carves out JS/TS/CJS. The local project-standards standard says Prettier governs every supported file type a repo contains; because Prettier supports JS/TS, this is a repo-specific exception, not simply “consistent with the reference.” The proposed `.prettierignore` brace pattern is also suspect; see SA-NEW-001.
- Remaining action for Claude Code: Rewrite D2/D4/D5 so JS/TS/CJS exclusion is explicitly a repo-specific exception or ADR-backed deviation, not “no carve-outs.” Use valid ignore patterns and align workflow filters, acceptance, and specs-plans summary with that choice.

#### SA-002: `.vscode/` artifacts are specified but ignored by the repo

- Previous severity: High
- Current status: Partially resolved
- Evidence: The revised spec now identifies the current `.vscode/` ignore and requires unignoring and force-adding the two files. But the exact proposed `.gitignore` edit says to add only `!.vscode/settings.json` and `!.vscode/extensions.json` after `.vscode/`. Git’s ignore rules do not allow re-including files when the parent directory remains excluded. Current `git check-ignore -v .vscode/settings.json .vscode/extensions.json` still reports `.gitignore:36:.vscode/`, and `git ls-files` lists neither file.
- Remaining action for Claude Code: Specify a complete negation pattern that re-includes the parent directory and only the two intended files, then validate with `git check-ignore` and `git ls-files`.

#### SA-003: Dirty `TODO.md` target is not protected from unrelated hunk capture

- Previous severity: High
- Current status: Resolved
- Evidence: The revised spec adds Step 0 requiring `git status --short`, explicitly recognizes the current uncommitted `TODO.md` restructure, requires stopping for user commit/set-aside or explicit consent before bulk reformat, and requires a separate hunk-isolated checkbox edit validated by `git diff --cached -- TODO.md`.
- Remaining action for Claude Code: None beyond following the revised preflight.

#### SA-004: Blast-radius counts omit tracked hidden docs and extra files

- Previous severity: Medium
- Current status: Partially resolved
- Evidence: The revised counts now match current tracked counts for 265 Markdown files, 31 JSON files, 9 YAML/YML files, 1 `.code-workspace`, and 27 JS/TS/MJS/CJS files. However, the spec’s statement that `git ls-files` is “the tracked surface Prettier/markdownlint enforce” is not fully true: `git ls-files -ci --exclude-standard` shows tracked ignored files, including `.claude/state/test-checklist.md`, and the copied `.markdownlint-cli2.jsonc` uses `"gitignore": true`, which imports `.gitignore` rules. The D2 rationale also still carries the old `101 docs` count while §3 says 102.
- Remaining action for Claude Code: Distinguish tracked inventory from actual tool-enforced inventory after `.gitignore`/`.prettierignore` are applied, and decide whether tracked ignored Markdown such as `.claude/state/test-checklist.md` is intentionally excluded or should be unignored.

#### SA-005: YAML “retabbed to tabs” and “GitHub Actions ignore indentation” claims are wrong

- Previous severity: Medium
- Current status: Resolved
- Evidence: The revised spec now states YAML is normalized with spaces, notes YAML disallows tab indentation, cites `.editorconfig` YAML spacing, and removes the incorrect “GitHub Actions ignore indentation” rationale.
- Remaining action for Claude Code: None.

### New blocking issues

#### SA-NEW-001: Proposed `.prettierignore` JS/TS pattern uses the wrong pattern language

- Severity: High
- Status: Confirmed
- Adversarial angle: The spec’s main safety mechanism for excluding JS/TS/CJS may not match the files it is supposed to exclude.
- Spec reference: Lines 58, 60, 77-78, 97, 118.
- Finding: The spec proposes `.prettierignore` content like `**/*.{ts,tsx,js,jsx,mjs,cjs}`. Prettier documents `.prettierignore` as using gitignore syntax, while Git’s pattern format documents `*`, `?`, ranges, and special `**`, not brace expansion. Brace alternation is documented for markdownlint/globby command globs and Prettier command-line glob examples, but that is not the same syntax as `.prettierignore`.
- Repository evidence: There are 27 tracked `.ts`/`.js`/`.mjs`/`.cjs` files, including `plugins/home-assistant-dev/mcp-server/dist/server.bundle.cjs`. These are exactly the files D5 says must remain untouched.
- External research evidence: Prettier ignore docs state `.prettierignore` uses gitignore syntax: https://prettier.io/docs/ignore. Git gitignore docs define the supported pattern format without brace expansion: https://git-scm.com/docs/gitignore.
- Why it matters: Claude could implement the spec as written, run `npx prettier --write .`, and still format the JS/TS/CJS files D5 claims are out of scope. That reopens the original blast-radius problem and could create a large MCP server diff without requiring MCP validation.
- Recommended action for Claude Code: Replace the brace pattern with explicit gitignore-compatible patterns, for example one extension per line, and keep the `dist/` rule precise. Also state that this is a repo-specific exception to the standard if JS/TS/CJS remain excluded.
- Suggested validation: After implementation, run the fix pass, then verify `git diff --name-only` contains no `.ts`, `.tsx`, `.js`, `.jsx`, `.mjs`, or `.cjs` files. If any appear, stop and correct `.prettierignore` before continuing.

### New non-blocking issues

#### SA-NEW-002: Negative validation commands are described as commands that must pass

- Severity: Medium
- Status: Confirmed
- Adversarial angle: The acceptance criteria can fail in the successful state or pass without being scriptable.
- Spec reference: Lines 95-101.
- Finding: The spec says each sanity command “must pass,” then includes checks whose desired result is no output/no match: `git diff --name-only | grep -E ...` should return nothing, and `git check-ignore -v` should return no match. In normal shell semantics, `grep` and `git check-ignore` return non-zero when they find no match, which is the desired state here.
- Repository evidence: Current `git check-ignore -v .vscode/settings.json .vscode/extensions.json` returns a match because `.vscode/` is ignored. Once fixed, the same command should return no match and exit non-zero.
- External research evidence: Not applicable.
- Why it matters: A later implementation plan could place these commands under `set -e` and fail even when the scope guard succeeds. Conversely, a human could ignore exit status and miss a real match.
- Recommended action for Claude Code: Write negative checks in scriptable form, e.g. `if git diff --name-only | grep -E '...'; then exit 1; fi` and `if git check-ignore -q ...; then exit 1; fi`.
- Suggested validation: Include expected exit behavior alongside expected output for all negative checks.

### Regressions

None found.

### Remaining ambiguities and decisions needed

- Ambiguity: Is JS/TS/CJS exclusion an approved repo-specific exception to the markdown-tooling standard, or should the repo adopt the standard literally?
- Why it matters: The local standard says Prettier governs every supported file type a repo contains; this repo contains JS/TS/CJS.
- Recommended clarification: State either “JS/TS/CJS are included” with MCP validation, or “JS/TS/CJS are excluded as an explicit repo exception/ADR” with valid ignore patterns.
- Blocking or non-blocking: Blocking.

- Ambiguity: Should tracked ignored Markdown under `.claude/state/` be linted/formatted or intentionally left outside the standard?
- Why it matters: The spec claims 265 Markdown files are in scope, but ignore-aware tooling can skip tracked ignored files.
- Recommended clarification: Identify tracked ignored structured-text files and either unignore them or document the exclusion.
- Blocking or non-blocking: Non-blocking.

### Internet research performed

- Source name: Prettier CLI documentation
- URL: https://prettier.io/docs/cli
- Access date: 2026-06-08
- What it was used to verify: `prettier .` directory traversal, supported-file discovery, default ignore files, and `--check`.
- Relevant conclusion: `prettier .` recursively finds supported files and uses ignore files; exclusions must be correctly expressed.

- Source name: Prettier Ignore documentation
- URL: https://prettier.io/docs/ignore
- Access date: 2026-06-08
- What it was used to verify: `.prettierignore` syntax and ignore behavior.
- Relevant conclusion: `.prettierignore` uses gitignore syntax, not command-line globby brace syntax.

- Source name: Git gitignore documentation
- URL: https://git-scm.com/docs/gitignore
- Access date: 2026-06-08
- What it was used to verify: Git ignore negation and pattern grammar.
- Relevant conclusion: Files cannot be re-included while the parent directory remains excluded; gitignore pattern syntax does not document brace expansion.

- Source name: markdownlint-cli2 README
- URL: https://github.com/DavidAnson/markdownlint-cli2/blob/main/README.md
- Access date: 2026-06-08
- What it was used to verify: glob syntax, `gitignore` behavior, and exit codes.
- Relevant conclusion: markdownlint-cli2 supports brace globs on the command line, but its `gitignore: true` setting imports gitignore files and can skip ignored tracked paths.

### Read-only validation performed

- `git status --short`, `git branch --show-current`, `git log --oneline -n 10`: confirmed branch `main`, current dirty spec/TODO state, and recent spec commit.
- Inspected `docs/handoff/state.md`, `AGENTS.md`, and `docs/handoff/conventions.md`: confirmed v3 startup context and direct-main convention.
- `nl -ba docs/superpowers/specs/2026-06-08-markdown-tooling-adoption-design.md`: re-read the revised spec with line references.
- `git diff -- docs/superpowers/specs/2026-06-08-markdown-tooling-adoption-design.md TODO.md`: confirmed the spec revisions and the still-dirty unrelated `TODO.md` restructure.
- `.gitignore` inspection plus `git check-ignore -v .vscode/settings.json .vscode/extensions.json`: confirmed `.vscode/` remains ignored today.
- `git ls-files` inventories for Markdown, JSON, YAML/YML, `.code-workspace`, and JS/TS/MJS/CJS: confirmed the revised counts, including 27 JS/TS/MJS/CJS files.
- `git ls-files -ci --exclude-standard`: found tracked ignored structured-text files relevant to the “tracked surface equals enforced surface” claim.
- Inspected local project-standards `.prettierrc.json`, `.editorconfig`, `.markdownlint-cli2.jsonc`, `format.yml`, `lint-markdown.yml`, `package.json`, and markdown-tooling docs: confirmed reference behavior and standard-scope wording.
- Inspected existing GitHub workflows and `plugins/home-assistant-dev/mcp-server/package.json`/`eslint.config.js`: confirmed existing CI surfaces and nested JS/TS ownership.
- Inspected `docs/handoff/specs-plans.md`, `TODO.md`, and `BRANCH_PROTECTION.md`: confirmed the specs-plans summary is stale relative to D5 and direct-main workflow is real.

### Recommended planning/implementation validation

- Before implementation: `git status --short` and `git diff -- TODO.md`; stop unless the user has committed/set aside or explicitly approved preserving/reformatting the dirty `TODO.md` changes.
- After `.gitignore` correction: use `git check-ignore -v .vscode/settings.json .vscode/extensions.json` only as a negative check with inverted exit handling; confirm `git ls-files .vscode/settings.json .vscode/extensions.json` lists both after adding.
- Run only after implementation: `npm install` at repo root to create `package-lock.json`.
- Run only after implementation: `npx prettier --write .` and `npx markdownlint-cli2 --fix "**/*.md"`.
- After implementation: `npx prettier --check .` and `npx markdownlint-cli2 "**/*.md"`.
- After implementation: `git diff --name-only` and classify changed file types; fail if JS/TS/MJS/CJS files appear while D5 remains out of scope.
- After implementation: `git ls-files -ci --exclude-standard` and confirm any tracked ignored structured-text file is intentionally excluded.
- After implementation: `git ls-files '*.json' -z | xargs -0 -n1 jq empty`.
- After implementation: `scripts/validate-marketplace.sh`.
- Run only after implementation if Home Assistant MCP JSON/package files change: `(cd plugins/home-assistant-dev/mcp-server && npm ci && npm run typecheck && npm run test:coverage && npm run build)`.
- After implementation: `git diff --check`.
- In CI: confirm `lint-markdown`, `format`, and any pre-existing workflow triggered by changed paths pass.

### Final recommendation

Claude Code should revise the specification using the findings above

### Review ledger for next loop

- Spec path: `/home/chris/projects/Claude-Code-Plugins/docs/superpowers/specs/2026-06-08-markdown-tooling-adoption-design.md`
- Audit round: 2
- Open issue IDs: SA-001, SA-002, SA-004, SA-NEW-001, SA-NEW-002
- Resolved issue IDs: SA-003, SA-005
- Superseded issue IDs: None
- Significant findings remaining: Yes
- Next audit should focus on: JS/TS/CJS exception wording and valid `.prettierignore` patterns, complete `.vscode/` unignore rules, tracked ignored structured-text scope, and scriptable negative validation checks.

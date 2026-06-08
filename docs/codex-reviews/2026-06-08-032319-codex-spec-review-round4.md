### Executive summary

Claude Code’s latest revisions resolved the JS/TS scope guard alignment, the untracked review-file preflight gap, and the prior `package-lock.json` handling problem in the operative verification section. One non-blocking specification inconsistency remains: D2 still says both tracked-but-gitignored files are skipped by both tools, while §3 now correctly says the nested `package-lock.json` may be reformatted by root Prettier and is acceptable if it appears in the diff.

New internet research was required only to re-check current Prettier, Git ignore, markdownlint-cli2, and markdownlint-cli2-action behavior.

### Verdict

Needs minor specification correction before planning/implementation

### Audit loop status

- Audit type: Follow-up audit
- Spec path: `/home/chris/projects/Claude-Code-Plugins/docs/superpowers/specs/2026-06-08-markdown-tooling-adoption-design.md`
- Prior audit issue count: 8
- Resolved issue count: 7
- Still open issue count: 0
- Partially resolved issue count: 1
- New issue count: 0
- Regression count: 0
- Significant findings remaining: Yes

### Adversarial review performed

I re-read the revised spec, retested all prior findings, rechecked current git state, re-inventoried tracked Markdown/JSON/YAML/code-workspace/JS/TS/CJS files, checked ignored tracked files, checked current untracked non-ignored Markdown files, compared the spec against the local `project-standards` markdown-tooling reference and `v2` tag, and re-attacked the fix-pass and acceptance criteria for false positives.

I did not run `npm`, `npx`, Prettier, markdownlint, pytest, or CI jobs because those can install dependencies, write caches/artifacts, or rewrite files.

### Prior findings status

#### SA-001: Prettier scope omits tracked TypeScript and JavaScript files

- Previous severity: High
- Current status: Resolved
- Evidence: D5 now frames JS/TS/MJS/CJS exclusion as an ADR-backed repo-specific exception; `.prettierignore` lists `*.ts`, `*.tsx`, `*.js`, `*.jsx`, `*.mjs`, and `*.cjs`; Step 2, the scope guard, Success Criterion 4, workflow filter discussion, and `docs/handoff/specs-plans.md` now include the full excluded extension set. `git ls-files '*.ts' '*.tsx' '*.js' '*.jsx' '*.mjs' '*.cjs' | wc -l` confirms 27 tracked files, including `plugins/home-assistant-dev/mcp-server/dist/server.bundle.cjs`. Minor wording cleanup remains available at spec line 44, which labels the 27-file set as `.ts`/`.js`/`.mjs` without naming `.cjs`, but the operative requirements cover `.cjs`.
- Remaining action for Claude Code: Optional wording cleanup only: include `.cjs` in the §3 bullet label.

#### SA-002: `.vscode/` artifacts are specified but ignored by the repo

- Previous severity: High
- Current status: Resolved
- Evidence: The spec still requires changing `.gitignore` from `.vscode/` to `.vscode/*` with negations for `.vscode/settings.json` and `.vscode/extensions.json`, then verifying `git check-ignore` and `git ls-files`. Git documentation confirms a file cannot be re-included if its parent directory remains excluded.
- Remaining action for Claude Code: None.

#### SA-003: Dirty `TODO.md` target is not protected from unrelated hunk capture

- Previous severity: High
- Current status: Resolved
- Evidence: Step 0 still identifies dirty `TODO.md`, requires stopping for commit/set-aside or explicit consent before the bulk pass, and requires hunk-isolated checkbox staging validated with `git diff --cached -- TODO.md`.
- Remaining action for Claude Code: None.

#### SA-004: Blast-radius counts omit tracked hidden docs and extra files

- Previous severity: Medium
- Current status: Partially resolved
- Evidence: The measured counts are now correct: 265 Markdown, 31 JSON, 9 YAML/YML, 1 code-workspace, and 27 JS/TS/MJS/CJS files. §3 also correctly avoids claiming an exact enforced count and accepts nested `plugins/home-assistant-dev/mcp-server/package-lock.json` reformatting if it occurs. The remaining inconsistency is D2: it still says “Two tracked-but-gitignored files are skipped by both tools,” but repository evidence shows one of those files is the nested JSON lockfile, and Prettier documents that root `prettier .` follows `.gitignore` in the run directory. `git check-ignore -v --no-index` shows the lockfile is ignored only by `plugins/home-assistant-dev/.gitignore`.
- Remaining action for Claude Code: Remove or narrow the stale D2 sentence. Say the tracked ignored Markdown file is expected to be skipped, while the nested tracked ignored `package-lock.json` may be formatted by root Prettier and is governed by §3’s diff classification.

#### SA-005: YAML “retabbed to tabs” and “GitHub Actions ignore indentation” claims are wrong

- Previous severity: Medium
- Current status: Resolved
- Evidence: The spec says YAML is normalized with spaces, notes YAML disallows tab indentation, and uses CI parsing as the safety net.
- Remaining action for Claude Code: None.

#### SA-NEW-001: Proposed `.prettierignore` JS/TS pattern uses the wrong pattern language

- Previous severity: High
- Current status: Resolved
- Evidence: The spec says `.prettierignore` uses gitignore syntax, no brace expansion, and lists one extension pattern per line.
- Remaining action for Claude Code: None.

#### SA-NEW-002: Negative validation commands are described as commands that must pass

- Previous severity: Medium
- Current status: Resolved
- Evidence: The spec uses inverted exit handling for both the JS/TS diff guard and `.vscode` ignore check.
- Remaining action for Claude Code: None.

#### SA-NEW-003: Bulk fix pass will mutate current untracked review files despite the “left untouched” requirement

- Previous severity: High
- Current status: Resolved
- Evidence: Step 0 now explicitly states that `prettier --write .` and `markdownlint-cli2 --fix "**/*.md"` rewrite supported working-tree files, including untracked non-ignored files. It requires enumerating `git ls-files -o --exclude-standard` and `git status --short`, filtering supported extensions, and committing, ignoring, or getting explicit approval before Step 2. Current repo evidence still has three untracked non-ignored codex-review Markdown files, and the spec now names them.
- Remaining action for Claude Code: None.

### New blocking issues

None found.

### New non-blocking issues

None found.

### Regressions

None found.

### Remaining ambiguities and decisions needed

- Ambiguity: D2 still says both tracked-but-gitignored files are skipped by both tools, while §3 says the nested `package-lock.json` may be formatted by Prettier.
- Why it matters: A planner could preserve the stale D2 claim and under-specify the lockfile blast radius.
- Recommended clarification: Make D2 Markdown-specific, or replace the sentence with a pointer to §3’s authoritative diff-classification rule.
- Blocking or non-blocking: Non-blocking.

### Internet research performed

- Source name: Prettier CLI documentation
- URL: <https://prettier.io/docs/cli>
- Access date: 2026-06-08
- What it was used to verify: `prettier . --write`, recursive supported-file discovery, `--check`, and exit codes.
- Relevant conclusion: `prettier . --write` formats supported files under the current directory and rewrites them in place.

- Source name: Prettier Ignore documentation
- URL: <https://prettier.io/docs/ignore>
- Access date: 2026-06-08
- What it was used to verify: `.prettierignore` syntax and `.gitignore` interaction.
- Relevant conclusion: `.prettierignore` uses gitignore syntax; Prettier follows `.gitignore` in the directory from which it is run.

- Source name: Git gitignore documentation
- URL: <https://git-scm.com/docs/gitignore>
- Access date: 2026-06-08
- What it was used to verify: tracked ignored files, nested `.gitignore` behavior, and negation rules.
- Relevant conclusion: Git checks `.gitignore` files from the path’s directory up to the worktree root, but already tracked files are not affected by ignore status.

- Source name: markdownlint-cli2 README
- URL: <https://github.com/DavidAnson/markdownlint-cli2/blob/main/README.md>
- Access date: 2026-06-08
- What it was used to verify: glob behavior, `--fix`, config discovery, and `gitignore: true`.
- Relevant conclusion: `**/*.md` is recursive, `--fix` writes files directly, and `gitignore: true` uses `.gitignore` files in the tree and up to the repository root.

- Source name: markdownlint-cli2-action README / action metadata
- URL: <https://github.com/DavidAnson/markdownlint-cli2-action/blob/main/README.md> and <https://raw.githubusercontent.com/DavidAnson/markdownlint-cli2-action/main/action.yml>
- Access date: 2026-06-08
- What it was used to verify: action inputs, recursive glob override, `@v23` examples, and Node runtime.
- Relevant conclusion: The action defaults to non-recursive `*.{md,markdown}` unless `globs: '**/*.md'` is passed; current metadata uses `node24`.

### Read-only validation performed

- `git status --short`, `git branch --show-current`, `git log --oneline -n 10`: confirmed branch `main`, dirty spec/TODO/specs-plans state, and three untracked codex-review Markdown files.
- Inspected `docs/handoff/state.md`, `AGENTS.md`, and `docs/handoff/conventions.md`: confirmed v3 repo context and direct-main workflow.
- `nl -ba docs/superpowers/specs/2026-06-08-markdown-tooling-adoption-design.md`: re-read the revised spec with line references.
- `git diff -- docs/superpowers/specs/2026-06-08-markdown-tooling-adoption-design.md TODO.md docs/handoff/specs-plans.md`: confirmed current corrections and the remaining dirty files.
- `git ls-files` counts for Markdown, JSON, YAML/YML, code-workspace, and JS/TS/MJS/CJS: confirmed the spec’s measured counts.
- `git ls-files -o --exclude-standard` and `git check-ignore -v` on codex-review files: confirmed three untracked, non-ignored Markdown files.
- `git ls-files -ci --exclude-standard`, `git check-ignore -v`, and `git check-ignore -v --no-index`: confirmed two tracked ignored files and that the nested lockfile ignore comes from `plugins/home-assistant-dev/.gitignore`.
- Inspected local `project-standards` markdown-tooling standard, configs, workflows, package pin, and `v2` tag contents: confirmed the reference Prettier pin, workflow filters, reusable lint workflow, and `@v2` availability.
- Inspected `.gitignore`, existing workflows, and HA MCP package/ESLint files: confirmed current ignore shape, pre-existing CI triggers, and JS/TS ownership.
- `git diff --check`: confirmed the current dirty tracked diff has no whitespace errors.

### Recommended planning/implementation validation

- Before implementation: `git status --short`; stop unless dirty/untracked supported files are committed, set aside, ignored, or explicitly approved for formatting.
- Before implementation: `git ls-files -o --exclude-standard` filtered to Prettier/markdownlint-supported extensions; stop if any untracked supported file would be touched.
- After `.gitignore` correction: use `if git check-ignore -q .vscode/settings.json .vscode/extensions.json; then exit 1; fi`, then confirm `git ls-files .vscode/settings.json .vscode/extensions.json` lists both after adding.
- Run only after implementation: `npm install` at repo root to create `package-lock.json`.
- Run only after implementation: `npx prettier --write .` and `npx markdownlint-cli2 --fix "**/*.md"`.
- After implementation: `npx prettier --check .` and `npx markdownlint-cli2 "**/*.md"`.
- After implementation: fail if `git diff --name-only` contains `.ts`, `.tsx`, `.js`, `.jsx`, `.mjs`, or `.cjs` while D5 remains out of scope.
- After implementation: inspect whether `plugins/home-assistant-dev/mcp-server/package-lock.json` changed and classify it under §3 rather than treating it as an unexpected leak.
- After implementation: `git ls-files '*.json' -z | xargs -0 -n1 jq empty`.
- After implementation: `scripts/validate-marketplace.sh`.
- After implementation: `git diff --check`.
- In CI: confirm `lint-markdown`, `format`, and any pre-existing workflow re-triggered by changed paths pass.

### Final recommendation

Claude Code should revise the specification using the findings above

### Review ledger for next loop

- Spec path: `/home/chris/projects/Claude-Code-Plugins/docs/superpowers/specs/2026-06-08-markdown-tooling-adoption-design.md`
- Audit round: 4
- Open issue IDs: SA-004
- Resolved issue IDs: SA-001, SA-002, SA-003, SA-005, SA-NEW-001, SA-NEW-002, SA-NEW-003
- Superseded issue IDs: None
- Significant findings remaining: Yes
- Next audit should focus on: removing the stale D2 “two tracked-but-gitignored files are skipped by both tools” claim and, optionally, ensuring the §3 JS/TS blast-radius bullet explicitly names `.cjs`.

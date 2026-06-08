### Executive summary

Claude Code’s revisions resolved the `.vscode/` negation pattern, the invalid `.prettierignore` brace syntax, and the negative-check exit-code problem. Significant findings remain. The spec still has an unsafe preflight gap: it says untracked review Markdown files are left untouched, but its bulk `prettier --write .` / `markdownlint --fix "**/*.md"` commands would process the current untracked, non-ignored review files. It also still overstates the tracked-ignored exclusion surface because Prettier’s documented `.gitignore` behavior does not prove it honors nested `.gitignore` files from the root run.

New internet research was required for Prettier ignore behavior and markdownlint-cli2 glob/fix behavior.

### Verdict

Needs major specification correction before planning/implementation

### Audit loop status

- Audit type: Follow-up audit
- Spec path: `/home/chris/projects/Claude-Code-Plugins/docs/superpowers/specs/2026-06-08-markdown-tooling-adoption-design.md`
- Prior audit issue count: 7
- Resolved issue count: 5
- Still open issue count: 0
- Partially resolved issue count: 2
- New issue count: 1
- Regression count: 0
- Significant findings remaining: Yes

### Adversarial review performed

I re-read the revised spec, retested all prior findings, rechecked current git state, reinventoryed tracked Markdown/JSON/YAML/code-workspace/JS/TS/CJS files, checked tracked ignored files, checked current untracked non-ignored Markdown files, inspected local project-standards markdown-tooling and ADR references, and attacked the fix-pass and acceptance criteria for false positives.

I did not run `npm`, `npx`, Prettier, markdownlint, pytest, or CI jobs because they can install dependencies, write caches/artifacts, or rewrite files.

### Prior findings status

#### SA-001: Prettier scope omits tracked TypeScript and JavaScript files

- Previous severity: High
- Current status: Partially resolved
- Evidence: D5 now explicitly frames JS/TS/MJS/CJS exclusion as a repo-specific ADR-backed exception, and `.prettierignore` now uses one gitignore-compatible extension pattern per line. However, Step 2 still says to confirm zero `.ts`/`.js`/`.mjs` files, and Success Criterion 4 also omits `.cjs`, `.tsx`, and `.jsx`, even though the repo has `plugins/home-assistant-dev/mcp-server/dist/server.bundle.cjs`. The format workflow filter discussion also does not explicitly include `.prettierignore`, which now controls Prettier scope. `docs/handoff/specs-plans.md` still summarizes the spec as “format everything” with faithful `md+json+yaml` scope and no D5 exception.
- Remaining action for Claude Code: Align every scope guard, success criterion, workflow path filter, and specs-plans summary with the full excluded extension set: `.ts`, `.tsx`, `.js`, `.jsx`, `.mjs`, `.cjs`.

#### SA-002: `.vscode/` artifacts are specified but ignored by the repo

- Previous severity: High
- Current status: Resolved
- Evidence: The revised spec now replaces `.vscode/` with `.vscode/*` plus negations for `.vscode/settings.json` and `.vscode/extensions.json`. Git’s official docs confirm files cannot be re-included while the parent directory is excluded, and the proposed parent-preserving pattern addresses that. Current repo evidence still shows `.vscode/` ignored because implementation has not happened yet, but the spec now gives the correct corrective shape and validation.
- Remaining action for Claude Code: None beyond implementing and validating the specified `.gitignore` edit.

#### SA-003: Dirty `TODO.md` target is not protected from unrelated hunk capture

- Previous severity: High
- Current status: Resolved
- Evidence: Step 0 explicitly identifies the dirty `TODO.md`, requires stopping for user commit/set-aside or explicit consent before bulk reformat, and requires hunk-isolated checkbox staging validated with `git diff --cached -- TODO.md`.
- Remaining action for Claude Code: None.

#### SA-004: Blast-radius counts omit tracked hidden docs and extra files

- Previous severity: Medium
- Current status: Partially resolved
- Evidence: The tracked counts are now correct: 265 Markdown, 31 JSON, 9 YAML/YML, 1 code-workspace, and 27 JS/TS/MJS/CJS files. The remaining problem is the enforced-count claim. The spec says two tracked-but-gitignored files are skipped by both tools, including `plugins/home-assistant-dev/mcp-server/package-lock.json`. Repository evidence shows that lockfile is ignored only by nested `plugins/home-assistant-dev/.gitignore`, while Prettier’s docs state it follows the `.gitignore` file in the directory from which it is run. The spec has not proven root `prettier .` will skip that nested-ignored JSON file. markdownlint-cli2’s `gitignore: true` behavior is broader, but that does not govern JSON.
- Remaining action for Claude Code: Either include the nested `package-lock.json` in Prettier’s blast radius or add an explicit root `.prettierignore`/root-ignore rule for it and validate that Prettier skips it.

#### SA-005: YAML “retabbed to tabs” and “GitHub Actions ignore indentation” claims are wrong

- Previous severity: Medium
- Current status: Resolved
- Evidence: The spec now says YAML is normalized with spaces, notes YAML disallows tab indentation, and removes the old GitHub Actions indentation claim.
- Remaining action for Claude Code: None.

#### SA-NEW-001: Proposed `.prettierignore` JS/TS pattern uses the wrong pattern language

- Previous severity: High
- Current status: Resolved
- Evidence: The revised spec explicitly says `.prettierignore` uses gitignore syntax, no brace expansion, and lists one extension pattern per line.
- Remaining action for Claude Code: None.

#### SA-NEW-002: Negative validation commands are described as commands that must pass

- Previous severity: Medium
- Current status: Resolved
- Evidence: The revised spec now uses inverted exit handling for both the JS/TS diff guard and the `.vscode` ignore check.
- Remaining action for Claude Code: None.

### New blocking issues

#### SA-NEW-003: Bulk fix pass will mutate current untracked review files despite the “left untouched” requirement

- Severity: High
- Status: Confirmed
- Adversarial angle: The spec’s local-work preservation guarantee contradicts the write commands it tells Claude Code to run.
- Spec reference: Lines 72-76 and 80-81.
- Finding: Step 0 says pre-existing dirty/untracked files, including prior codex-review outputs, are left untouched. But Step 2 runs `npx prettier --write .` and `npx markdownlint-cli2 --fix "**/*.md"`, which operate on working-tree files, not just tracked files. The current repo has two untracked, non-ignored Markdown review files under `docs/codex-reviews/`, so the fix pass can rewrite them.
- Repository evidence: `git status --short` lists `?? docs/codex-reviews/2026-06-08-024554-codex-spec-review-round1.md` and `?? docs/codex-reviews/2026-06-08-030232-codex-spec-review-round2.md`. `git ls-files -o --exclude-standard docs/codex-reviews` lists both, and `git check-ignore -v` reports no ignore match.
- External research evidence: Prettier CLI docs state `prettier . --write` formats supported files in the current directory and subdirectories: <https://prettier.io/docs/cli>. markdownlint-cli2 docs state `**` matches recursively and `--fix` updates files directly with no backup: <https://github.com/DavidAnson/markdownlint-cli2/blob/main/README.md>. Access date: 2026-06-08.
- Why it matters: Claude Code could follow the spec, mutate user-local untracked audit artifacts, and still see no tracked `git diff` evidence unless those files are later staged. This violates the spec’s own local-work preservation rule.
- Recommended action for Claude Code: Add a preflight gate for all dirty/untracked non-ignored supported files, not only `TODO.md`. Stop unless the user commits, removes, ignores, or explicitly approves formatting them. Alternatively, specify a tracked-file-only mechanical pass and reconcile that with the standard check contract.
- Suggested validation: Before any write-producing fix pass, run `git status --short` and `git ls-files -o --exclude-standard`, filter for Prettier/markdownlint-supported extensions, and stop if any untracked/dirty supported file is not explicitly approved.

### New non-blocking issues

None found.

### Regressions

None found.

### Remaining ambiguities and decisions needed

- Ambiguity: Should the initial fix pass require a clean working tree for all supported non-ignored files, or should it operate only on tracked files?
- Why it matters: The standard commands process the working tree, and the current repo has untracked Markdown files.
- Recommended clarification: State the required preflight and the exact handling for untracked supported files before any `--write`/`--fix`.
- Blocking or non-blocking: Blocking.

- Ambiguity: Is the nested tracked `package-lock.json` intentionally formatted by Prettier or intentionally excluded?
- Why it matters: It is ignored by a nested `.gitignore`, but Prettier’s documented root-run behavior does not establish that it will skip nested-ignore files.
- Recommended clarification: Either count it in the enforced JSON surface or add an explicit root `.prettierignore` exclusion.
- Blocking or non-blocking: Non-blocking.

### Internet research performed

- Source name: Prettier CLI documentation
- URL: <https://prettier.io/docs/cli>
- Access date: 2026-06-08
- What it was used to verify: `prettier . --write`, recursive supported-file discovery, and `--check` behavior.
- Relevant conclusion: `prettier .` operates over supported working-tree files under the directory, so untracked non-ignored files are in scope.

- Source name: Prettier Ignore documentation
- URL: <https://prettier.io/docs/ignore>
- Access date: 2026-06-08
- What it was used to verify: `.prettierignore` syntax and `.gitignore` interaction.
- Relevant conclusion: `.prettierignore` uses gitignore syntax; Prettier documents following the `.gitignore` file in the directory from which it is run.

- Source name: Git gitignore documentation
- URL: <https://git-scm.com/docs/gitignore>
- Access date: 2026-06-08
- What it was used to verify: negation and parent-directory exclusion rules.
- Relevant conclusion: The revised `.vscode/*` plus negation approach is the correct shape; re-including files under an excluded parent directory would not work.

- Source name: markdownlint-cli2 README
- URL: <https://github.com/DavidAnson/markdownlint-cli2/blob/main/README.md>
- Access date: 2026-06-08
- What it was used to verify: glob behavior, `--fix`, config discovery, and `gitignore: true`.
- Relevant conclusion: `**/*.md` recursively matches Markdown, `--fix` writes files in place, and `gitignore: true` imports gitignore rules for linting.

### Read-only validation performed

- `git status --short`, `git branch --show-current`, `git log --oneline -n 10`: confirmed branch `main`, dirty spec/TODO state, and two untracked codex-review Markdown files.
- Inspected `docs/handoff/state.md`, `AGENTS.md`, and `docs/handoff/conventions.md`: confirmed v3 repo context and direct-main workflow.
- `nl -ba docs/superpowers/specs/2026-06-08-markdown-tooling-adoption-design.md`: re-read the revised spec with line references.
- `git diff -- docs/superpowers/specs/2026-06-08-markdown-tooling-adoption-design.md TODO.md`: confirmed current spec corrections and the still-dirty `TODO.md` restructure.
- Inspected `.gitignore`, nested `plugins/home-assistant-dev/.gitignore`, and ran `git check-ignore --no-index`: confirmed `.claude/state/test-checklist.md` is root-ignored, while the nested `package-lock.json` is ignored only by nested `.gitignore`.
- `git ls-files` inventories and `wc -l`: confirmed 265 Markdown, 31 JSON, 9 YAML/YML, 1 code-workspace, and 27 JS/TS/MJS/CJS tracked files.
- `git ls-files -ci --exclude-standard`: confirmed exactly two tracked ignored files.
- `git ls-files -o --exclude-standard docs/codex-reviews` and `git check-ignore -v` on the untracked review files: confirmed they are untracked and non-ignored.
- Inspected local project-standards markdown-tooling and ADR docs plus `.prettierrc.json`, `.markdownlint-cli2.jsonc`, `format.yml`, `lint-markdown.yml`, and `package.json`: confirmed reference behavior and standard wording.
- Inspected existing GitHub workflows and HA MCP `package.json`/`eslint.config.js`: confirmed the nested JS/TS ownership surface and existing CI triggers.
- `git diff --check`: confirmed current dirty tracked diff has no whitespace errors.

### Recommended planning/implementation validation

- Before implementation: `git status --short`; stop unless dirty/untracked supported files are committed, set aside, ignored, or explicitly approved for formatting.
- Before implementation: `git ls-files -o --exclude-standard` filtered to Prettier/markdownlint-supported extensions; stop if any untracked supported file would be touched.
- After `.gitignore` correction: use `if git check-ignore -q .vscode/settings.json .vscode/extensions.json; then exit 1; fi`, then confirm `git ls-files .vscode/settings.json .vscode/extensions.json` lists both after adding.
- Run only after implementation: `npm install` at repo root to create `package-lock.json`.
- Run only after implementation: `npx prettier --write .` and `npx markdownlint-cli2 --fix "**/*.md"`.
- After implementation: `npx prettier --check .` and `npx markdownlint-cli2 "**/*.md"`.
- After implementation: fail if `git diff --name-only` contains `.ts`, `.tsx`, `.js`, `.jsx`, `.mjs`, or `.cjs` while D5 remains out of scope.
- After implementation: confirm whether `plugins/home-assistant-dev/mcp-server/package-lock.json` changed; if yes, either accept it in blast radius or add an explicit exclusion and rerun checks.
- After implementation: `git ls-files '*.json' -z | xargs -0 -n1 jq empty`.
- After implementation: `scripts/validate-marketplace.sh`.
- After implementation: `git diff --check`.
- In CI: confirm `lint-markdown`, `format`, and any pre-existing workflow triggered by changed paths pass.

### Final recommendation

Claude Code should revise the specification using the findings above

### Review ledger for next loop

- Spec path: `/home/chris/projects/Claude-Code-Plugins/docs/superpowers/specs/2026-06-08-markdown-tooling-adoption-design.md`
- Audit round: 3
- Open issue IDs: SA-001, SA-004, SA-NEW-003
- Resolved issue IDs: SA-002, SA-003, SA-005, SA-NEW-001, SA-NEW-002
- Superseded issue IDs: None
- Significant findings remaining: Yes
- Next audit should focus on: untracked non-ignored Markdown/worktree preservation before the bulk fix pass, package-lock enforced-surface truth under Prettier, and full JS/TS/MJS/CJS scope alignment in guards, workflow filters, and specs-plans metadata.

### Executive summary

The specification is not ready for Claude Code to use as the basis for planning or implementation. The core adoption direction is sound, but the spec materially underestimates Prettier’s actual scope in this repository, asks for tracked `.vscode/` files while the repo ignores `.vscode/`, and does not account for the currently dirty `TODO.md` file it intends to edit.

Internet research was required because the spec depends on current Prettier, markdownlint-cli2, reusable GitHub workflow, and YAML behavior. The major stale-assumption finding is that `prettier .` is not limited to Markdown/JSON/YAML in this repo; it also reaches the tracked TypeScript/JavaScript MCP server surface unless explicitly excluded.

### Verdict

Needs major specification correction before planning/implementation

### Audit loop status

* Audit type: First audit
* Spec path: `/home/chris/projects/Claude-Code-Plugins/docs/superpowers/specs/2026-06-08-markdown-tooling-adoption-design.md`
* Significant findings remaining: Yes
* Blocking issue count: 3
* Non-blocking issue count: 2

### What the specification gets right

* Correctly separates `markdown-tooling` from `python-tooling` and `markdown-frontmatter`.
* Correctly identifies the project-standards check contract: `npx prettier --check .` and `npx markdownlint-cli2 "**/*.md"`.
* Correctly plans a pinned root Prettier dependency and lockfile.
* Correctly calls out the `docs/handoff/state.md` generator as a future re-dirtying risk.
* Correctly pins the reusable markdownlint workflow to `project-standards` `@v2`, matching the local reference implementation.

### Adversarial review performed

I inventoried the spec requirements, artifact list, rollout/acceptance criteria, out-of-scope claims, and referenced standards repo. I falsified the file-count and file-scope claims against tracked files, root and nested ignore rules, existing CI workflows, package/tooling files, and project handoff docs. I attacked acceptance criteria for false positives, especially whether CI could pass while Prettier-supported files remain unenforced. I also checked external assumptions against Prettier, markdownlint-cli2, markdownlint-cli2-action, GitHub Actions reusable workflow, and YAML documentation.

Areas not checked: I did not run `npx`, `npm`, pytest, or formatter/linter commands because they can write dependency caches, `node_modules`, coverage, generated files, or formatting changes. I could not independently verify the current `L3DigitalNet/project-standards` remote contents through the web tool; I used the local checkout as reference evidence.

### Blocking issues

#### SA-001: Prettier scope omits tracked TypeScript and JavaScript files

* Severity: High
* Status: Confirmed
* Adversarial angle: The spec says “faithful” `prettier .`, but narrows the blast radius to Markdown/JSON/YAML and then declares the nested MCP toolchain otherwise untouched.
* Spec reference: Lines 15-22, 31, 35-37, 61-83, 97.
* Finding: `prettier .` will not be limited to `md`/`json`/`yaml` in this repo. There are 26 tracked `.ts`, `.js`, and `.mjs` files under `plugins/home-assistant-dev/mcp-server` and e2e tests that Prettier supports. The copied reference `format.yml` path filters also omit JS/TS, so CI could later fail to enforce files that `prettier .` would check when the workflow does run.
* Repository evidence: `git ls-files | rg '\.(js|jsx|ts|tsx|mjs)$'` found 26 tracked files. `plugins/home-assistant-dev/mcp-server/package.json` defines TypeScript build, lint, typecheck, and test scripts. The local project-standards `format.yml` only filters `md/json/jsonc/yml/yaml/code-workspace`, which matched that repo but not this one.
* External research evidence: Prettier CLI docs state that a directory argument recursively finds supported files by extension/well-known filename. Prettier options docs list TypeScript, JavaScript, JSON, Markdown, and YAML parsers.
* Why it matters: The implementation could make a much larger code-formatting change than the spec discloses, while the proposed acceptance criteria do not require MCP server lint/typecheck/test/build validation. Alternatively, if Claude tries to keep JS/TS out of scope, the current spec’s `prettier .` contract contradicts that.
* Recommended action for Claude Code: Decide explicitly whether JS/TS/MJS are in scope. If yes, update blast radius, CI path filters, acceptance criteria, and validation to include the MCP server. If no, document an ADR/exception and add a Prettier ignore strategy that still satisfies or intentionally deviates from the standard.
* Suggested validation: After implementation, inspect `git diff --name-only` for JS/TS/MJS changes and run the appropriate MCP server validation if they changed.

#### SA-002: `.vscode/` artifacts are specified but ignored by the repo

* Severity: High
* Status: Confirmed
* Adversarial angle: The spec requires new tracked editor config files but does not check whether the repo can track them.
* Spec reference: Lines 50-51, 55, 61, 64.
* Finding: `.vscode/settings.json` and `.vscode/extensions.json` are ignored by the current root `.gitignore`. The spec only says to append `node_modules/`, which already exists, and does not say to unignore `.vscode/` or force-add the files.
* Repository evidence: `.gitignore` lines 34-36 ignore `.vscode/`. `git check-ignore -v .vscode/settings.json .vscode/extensions.json` reports the `.vscode/` rule. `git ls-files .vscode/settings.json .vscode/extensions.json` returns no tracked files. The local project-standards repo tracks `.vscode/settings.json` and `.vscode/extensions.json` and does not ignore `.vscode/`.
* External research evidence: Prettier ignore docs confirm Prettier follows `.gitignore` rules from the run directory, so ignored `.vscode/` files would also be outside the default `prettier .` check unless ignore handling is changed.
* Why it matters: Claude could implement everything else and still silently omit the VS Code adoption artifacts, or force-add ignored files that future tooling does not check.
* Recommended action for Claude Code: Specify whether `.vscode/` should become tracked. If yes, update `.gitignore` with explicit negation rules for the intended files and add validation that they are tracked and not ignored.
* Suggested validation: `git check-ignore -v .vscode/settings.json .vscode/extensions.json` should return no ignore match after correction; `git ls-files .vscode/settings.json .vscode/extensions.json` should list both files.

#### SA-003: Dirty `TODO.md` target is not protected from unrelated hunk capture

* Severity: High
* Status: Confirmed
* Adversarial angle: The spec requires editing `TODO.md`, but the working tree already has unrelated local changes in that same file.
* Spec reference: Lines 7, 99-105.
* Finding: The current worktree has ` M TODO.md`. The diff rewrites the TODO document’s purpose/usage structure and keeps “Adopt markdown-tooling” unchecked. The spec says the implementation should check that item, but gives no dirty-tree or same-file hunk-isolation requirement.
* Repository evidence: `git status --short` shows ` M TODO.md`. `git diff -- TODO.md` shows pre-existing content changes unrelated to simply checking the `Adopt markdown-tooling` task.
* External research evidence: Not applicable.
* Why it matters: A later implementation commit sequence could accidentally stage or overwrite the user’s in-progress TODO edits while checking the markdown-tooling box.
* Recommended action for Claude Code: Add a preflight requirement to inspect `git status --short` and `git diff -- TODO.md`; require hunk-level isolation for only the checkbox change, or stop for user guidance if isolation is not possible.
* Suggested validation: Before committing, inspect `git diff --cached -- TODO.md` and confirm only the intended checkbox hunk is staged.

### Non-blocking issues

#### SA-004: Blast-radius counts omit tracked hidden docs and extra files

* Severity: Medium
* Status: Confirmed
* Adversarial angle: The spec’s measured blast radius should match the repository’s current tracked surface.
* Spec reference: Lines 29, 35-37, 68.
* Finding: The spec says 254 Markdown files based on 143 `plugins/`, 101 `docs/`, and 10 root files. Current tracked evidence is 265 Markdown files: 143 `plugins/`, 102 `docs/`, 10 root, and 10 hidden `.claude/.github` Markdown files. Current tracked JSON count is 31, not merely the listed manifest/marketplace/MCP subset. There is also one tracked `.code-workspace` file relevant to the copied reference `format.yml`.
* Repository evidence: `git ls-files '*.md' | wc -l` returned 265; grouping showed 102 `docs`, 143 `plugins`, 10 root, 10 hidden. `git ls-files '*.json' | wc -l` returned 31. `git ls-files '*.code-workspace'` listed `Claude-Code-Plugins.code-workspace`.
* External research evidence: Prettier CLI docs confirm directory formatting is based on supported file discovery, so accurate file inventory matters.
* Why it matters: Reviewers and implementers will underestimate diff size and may miss hidden agent/GitHub docs or workspace config during acceptance review.
* Recommended action for Claude Code: Recompute and state the current tracked and tool-matched file counts, and distinguish hidden ignored/unignored files from the normal `rg --files` surface.
* Suggested validation: Use `git ls-files` counts and a post-format `git diff --name-only` inventory.

#### SA-005: YAML “retabbed to tabs” and “GitHub Actions ignore indentation” claims are wrong

* Severity: Medium
* Status: Confirmed
* Adversarial angle: The spec treats YAML whitespace as semantically inert in a way that is too broad.
* Spec reference: Lines 31, 37.
* Finding: YAML indentation is structural and cannot be described as behavior-irrelevant retabbing. The local reference `.editorconfig` explicitly sets YAML indentation to spaces because YAML forbids tab indentation. The spec should say YAML is normalized by Prettier while preserving valid YAML structure, not “retabbed from 2-space to tabs.”
* Repository evidence: Local project-standards `.editorconfig` sets `[*.{yml,yaml}] indent_style = space` and `indent_size = 2`.
* External research evidence: YAML 1.2.2 states block structure is determined by indentation and tab characters must not be used for indentation.
* Why it matters: The implementation is probably still safe if Prettier handles YAML, but the spec’s safety rationale is technically false and could lead Claude to dismiss real workflow YAML risks.
* Recommended action for Claude Code: Correct the YAML blast-radius wording and add a lightweight YAML/workflow sanity check or require review of YAML diffs.
* Suggested validation: After implementation, inspect YAML diffs and run `git diff --check`; rely on GitHub Actions CI for workflow parse validation.

### Missing specification considerations

* Blocking: Decide whether Prettier-supported JS/TS/MJS files are in scope, and align the command, CI filters, blast radius, and validation accordingly.
* Blocking: Specify `.vscode/` tracking/unignore behavior before promising `.vscode/settings.json` and `.vscode/extensions.json`.
* Blocking: Add dirty-worktree and same-file hunk-isolation requirements for the already-modified `TODO.md`.
* Non-blocking: Correct current file counts, including hidden tracked Markdown, all JSON files, and the root `.code-workspace`.
* Non-blocking: Correct YAML indentation semantics and avoid saying GitHub Actions ignore indentation.
* Non-blocking: Clarify whether “both CI workflows” means only the two new workflows or all workflows triggered by the adoption diff, especially if `plugins/home-assistant-dev/**` files change.
* Non-blocking: Align “branch before merge” wording with this repo’s documented direct-commit-to-`main` workflow, or explicitly state this adoption is allowed to use a topic branch.

### Ambiguities and decisions needed

* Ambiguity: Are TypeScript/JavaScript/MJS files under `home-assistant-dev/mcp-server` intentionally governed by the new root Prettier config?
* Why it matters: This controls scope, validation, CI triggers, and review size.
* Recommended clarification: State “JS/TS are in scope” with validation, or “JS/TS are out of scope” with an ADR/ignore exception.
* Blocking or non-blocking: Blocking.

* Ambiguity: Should `.vscode/` become tracked despite the existing ignore rule?
* Why it matters: The spec currently requires files that normal Git operations will ignore.
* Recommended clarification: Define exact `.gitignore` negation rules or remove tracked `.vscode/` artifacts from scope.
* Blocking or non-blocking: Blocking.

* Ambiguity: How should Claude handle the currently dirty `TODO.md` target?
* Why it matters: The implementation must not stage or overwrite unrelated local work.
* Recommended clarification: Require hunk-isolated staging or stop for user input if clean isolation cannot be proven.
* Blocking or non-blocking: Blocking.

* Ambiguity: Does “green on the branch before merge” override the repo’s direct-main workflow?
* Why it matters: Acceptance and release sequencing differ between PR/topic branch and direct-main workflows.
* Recommended clarification: Use repo-native wording or explicitly approve a topic branch for this adoption.
* Blocking or non-blocking: Non-blocking.

### Internet research performed

* Source name: Prettier CLI documentation
* URL: https://prettier.io/docs/cli
* Access date: 2026-06-08
* What it was used to verify: Directory recursion, supported-file discovery, and `--check` behavior.
* Relevant conclusion: `prettier .` recursively finds every Prettier-supported file under the directory.

* Source name: Prettier Options documentation
* URL: https://prettier.io/docs/options
* Access date: 2026-06-08
* What it was used to verify: Supported parsers/options, including TypeScript, JavaScript, JSON, Markdown, YAML, and `proseWrap`.
* Relevant conclusion: This repo contains Prettier-supported file types beyond Markdown/JSON/YAML.

* Source name: Prettier Ignore documentation
* URL: https://prettier.io/docs/ignore
* Access date: 2026-06-08
* What it was used to verify: `.gitignore` and `node_modules` default ignore behavior.
* Relevant conclusion: Ignored `.vscode/` files require explicit tracking/ignore decisions.

* Source name: markdownlint-cli2 README
* URL: https://github.com/DavidAnson/markdownlint-cli2/blob/main/README.md
* Access date: 2026-06-08
* What it was used to verify: Glob syntax, config discovery, `--fix`, and `gitignore` option.
* Relevant conclusion: The spec’s markdownlint command shape is broadly valid, but config/glob scope must be explicit.

* Source name: markdownlint-cli2-action README and action.yml
* URL: https://github.com/DavidAnson/markdownlint-cli2-action
* Access date: 2026-06-08
* What it was used to verify: `@v23`, `globs`, `config`, `fix`, and Node runtime.
* Relevant conclusion: `@v23` and explicit `globs: '**/*.md'` match the current action guidance; action.yml uses Node 24.

* Source name: GitHub Docs, reusable workflows
* URL: https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows
* Access date: 2026-06-08
* What it was used to verify: Calling reusable workflows via job-level `uses`.
* Relevant conclusion: The planned reusable workflow call shape is valid.

* Source name: YAML 1.2.2 specification
* URL: https://yaml.org/spec/1.2.2/
* Access date: 2026-06-08
* What it was used to verify: YAML indentation semantics.
* Relevant conclusion: YAML block structure is indentation-based and tabs must not be used for indentation.

* Source name: L3DigitalNet/project-standards GitHub repository
* URL: https://github.com/L3DigitalNet/project-standards/tree/main/standards/markdown-tooling
* Access date: 2026-06-08
* What it was used to verify: Current remote standard contents.
* Relevant conclusion: The web tool did not return the repository content. I used the local checkout at `/home/chris/projects/project-standards` as reference evidence; Claude should re-confirm remote freshness if needed before implementation.

### Items Claude Code should verify before correcting the specification

* Reconfirm the exact current project-standards reference implementation, especially Prettier version and workflow contents.
* Decide and document whether JS/TS/MJS files are in scope.
* Verify `.vscode/` tracking behavior and required `.gitignore` changes.
* Re-read `git status --short` and `git diff -- TODO.md` before specifying any TODO edit.
* Recompute blast-radius counts using `git ls-files`, not only `rg --files`.
* Verify which existing workflows would be triggered by the eventual mechanical reformat.
* Verify whether the repo will use a topic branch/PR for this adoption or direct commits to `main`.

### Suggested corrections for Claude Code’s specification

* Replace the `md`/`json`/`yaml`-only Prettier scope with a repo-accurate supported-file inventory, including JS/TS/MJS or an explicit ignore/ADR exception.
* If JS/TS/MJS are in scope, add `**/*.js`, `**/*.ts`, `**/*.mjs`, and related extensions to the Prettier workflow path filters and require MCP server lint/typecheck/test/build validation.
* If JS/TS/MJS are out of scope, specify `.prettierignore` or equivalent and document the standards deviation.
* Add `.gitignore` changes to unignore only `.vscode/settings.json` and `.vscode/extensions.json`, or drop tracked `.vscode/` files from scope.
* Add a dirty-tree preflight and hunk-isolation rule for `TODO.md`.
* Correct Markdown/JSON/YAML counts and mention hidden tracked docs and `.code-workspace`.
* Correct YAML wording: YAML is space-indented and structure-sensitive; do not describe it as tab-retabbed.
* Clarify CI acceptance: new workflows only versus all triggered workflows.
* Align branch/merge wording with the repo’s direct-main convention.

### Read-only validation performed

* `pwd`: confirmed repository root is `/home/chris/projects/Claude-Code-Plugins`.
* `git status --short`, `git branch --show-current`, `git log --oneline -n 10`, `git diff --stat`: confirmed branch `main`, latest spec commit, and dirty `TODO.md`.
* Inspected `docs/handoff/state.md`, `AGENTS.md`, and `docs/handoff/conventions.md`: confirmed v3 handoff state and repo conventions.
* Inspected the target spec with `sed` and `nl -ba`: inventoried requirements and line references.
* `rg --files` and `git ls-files` queries for Markdown/JSON/YAML/config/workflow files: verified artifact existence and counts.
* `git ls-files | rg '\.(js|jsx|ts|tsx|mjs)$'`: found 26 tracked JS/TS/MJS files omitted by the spec.
* `git check-ignore -v .vscode/settings.json .vscode/extensions.json`: confirmed `.vscode/` is ignored.
* `git diff -- TODO.md`: confirmed `TODO.md` has existing unrelated local changes.
* Inspected local project-standards reference files: `.prettierrc.json`, `.markdownlint.json`, `.markdownlint-cli2.jsonc`, `.editorconfig`, `package.json`, `format.yml`, `lint-markdown.yml`, `.project-standards.yml`.
* Inspected existing repo workflows and MCP server package files: confirmed TypeScript validation scripts and workflow trigger surfaces.
* Inspected `scripts/validate-marketplace.sh`: confirmed marketplace/plugin manifest validation scope.

### Recommended planning/implementation validation

* Run only after implementation: `npm install` at repo root to create the root `package-lock.json`.
* Run only after implementation: `npx prettier --write .` and `npx markdownlint-cli2 --fix "**/*.md"`.
* After implementation: `npx prettier --check .` and `npx markdownlint-cli2 "**/*.md"`.
* After implementation: `git diff --name-only` and classify every changed file type.
* After implementation: `git ls-files .vscode/settings.json .vscode/extensions.json`.
* After implementation: `git diff --cached -- TODO.md` before committing any TODO change.
* After implementation: `git ls-files '*.json' -z | xargs -0 -n1 jq empty`.
* After implementation: `scripts/validate-marketplace.sh`.
* If JS/TS/MJS remain in Prettier scope, run only after implementation: `(cd plugins/home-assistant-dev/mcp-server && npm ci && npm run lint && npm run typecheck && npm test && npm run build)`.
* After implementation: `git diff --check`.
* In CI: confirm the markdownlint workflow, Prettier workflow, and any pre-existing workflows triggered by the changed paths.

### Final recommendation

Claude Code should revise the specification using the findings above

### Review ledger for next loop

* Spec path: `/home/chris/projects/Claude-Code-Plugins/docs/superpowers/specs/2026-06-08-markdown-tooling-adoption-design.md`
* Audit round: 1
* Open issue IDs: SA-001, SA-002, SA-003, SA-004, SA-005
* Resolved issue IDs: None
* Superseded issue IDs: None
* Significant findings remaining: Yes
* Next audit should focus on: Prettier scope for JS/TS/MJS, `.vscode/` tracking, dirty `TODO.md` handling, corrected blast-radius/YAML claims, and CI validation alignment.


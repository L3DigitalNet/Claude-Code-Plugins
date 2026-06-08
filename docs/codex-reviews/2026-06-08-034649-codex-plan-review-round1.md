### Executive summary

The implementation plan is close, but it should not be executed unchanged. The core adoption sequence is mostly grounded in repository evidence and the local `project-standards` reference, but the CI enforcement and final validation have false-positive gaps.

Internet research was required because the plan depends on current Prettier, markdownlint-cli2, markdownlint-cli2-action, and GitHub Actions behavior. No external source invalidated the main tool choices, but GitHub Actions path-filter behavior confirms that the proposed `format.yml` will not run on changes to `.prettierignore`, even though `.prettierignore` is a load-bearing repo-specific scope control.

### Verdict

Needs minor correction before execution

### Audit loop status

* Audit type: First audit
* Plan path: `/home/chris/projects/Claude-Code-Plugins/docs/superpowers/plans/2026-06-08-markdown-tooling-adoption.md`
* Significant findings remaining: Yes
* Blocking issue count: 0
* Non-blocking issue count: 4

### What the plan gets right

* It correctly protects the dirty `TODO.md` before bulk formatting and requires hunk-isolated staging for the checkbox.
* The root tool config largely matches the local `project-standards` reference: Prettier `3.8.3`, `.prettierrc.json`, `.markdownlint.json`, `.editorconfig`, and the reusable markdownlint workflow `@v2`.
* The `.prettierignore` JS/TS exclusion uses gitignore-style one-pattern-per-line syntax, which matches Prettier ignore behavior.
* The `.vscode/` un-ignore plan fixes the known Git negation trap by replacing `.vscode/` with `.vscode/*` plus file negations.
* The plan isolates the mechanical reformat in its own commit and includes useful sanity checks for JSON parsing, marketplace validation, whitespace errors, and JS/TS scope leakage.

### Adversarial review performed

I inventoried the plan’s file, command, CI, scope, and validation claims; re-read the referenced design; checked current git state, branch, upstream/ahead state, dirty files, untracked supported files, tracked file counts, ignored tracked files, existing CI workflows, marketplace validation, and the local `project-standards` reference.

I attacked the strongest assumptions: that CI truly enforces all load-bearing formatter scope files, that `gh run list` proves the intended workflows ran for the final commit, that “all tracked” supported files are actually formatted/linted, that the `.vscode` negation works, that JS/TS is excluded correctly, and that the plan’s handoff index update points to the right implementation commit.

I did not run `npm install`, `npx`, `prettier --write`, `markdownlint-cli2 --fix`, or any GitHub workflow because those may install dependencies, write caches/artifacts, rewrite files, or require post-implementation state.

### Blocking issues

None found.

### Non-blocking issues

#### CR-001: Format workflow does not trigger on `.prettierignore` scope changes

* Severity: Medium
* Status: Confirmed
* Adversarial angle: CI-enforcement claim can pass while the repo’s formatter scope control changes without running the formatter gate.
* Plan reference: [plan](/home/chris/projects/Claude-Code-Plugins/docs/superpowers/plans/2026-06-08-markdown-tooling-adoption.md:172) lines 172-186 and [plan](/home/chris/projects/Claude-Code-Plugins/docs/superpowers/plans/2026-06-08-markdown-tooling-adoption.md:402) lines 402-450.
* Finding: The plan creates `.prettierignore` as the load-bearing JS/TS exclusion, but the proposed `.github/workflows/format.yml` path filters omit `.prettierignore`. A future change to `.prettierignore` alone would not trigger `npx prettier --check .`.
* Repository evidence: The plan’s format workflow paths include Markdown/JSON/YAML/code-workspace, `.prettierrc.json`, package files, and the workflow file, but not `.prettierignore`. The local reference repo has no `.prettierignore`, so copying its path filter verbatim misses this repo-specific exception.
* External research evidence: Prettier documents that `.prettierignore` and `.gitignore` affect which files are ignored by the CLI (`https://prettier.io/docs/ignore`, accessed 2026-06-08). GitHub Actions documents that a workflow with `paths` runs only when at least one changed path matches (`https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax`, accessed 2026-06-08).
* Why it matters: The plan’s central safety claim is CI-enforced formatting with JS/TS excluded by `.prettierignore`. If the scope file can change without the workflow running, CI can silently stop proving that claim.
* Recommended action for Claude Code: Add `.prettierignore` to both `push.paths` and `pull_request.paths` in `format.yml`. Consider also adding `.editorconfig` and `.gitignore` because they can affect formatting/scope behavior, but `.prettierignore` is the minimum correction.
* Suggested validation: Inspect the final `format.yml` and confirm `.prettierignore` appears under both path filters; after implementation, use the final head SHA when checking that the `Format` workflow ran.

#### CR-002: Final CI check can report stale or non-triggered workflows as green

* Severity: Medium
* Status: Confirmed
* Adversarial angle: Validation can pass without proving the final commit’s workflows ran.
* Plan reference: [plan](/home/chris/projects/Claude-Code-Plugins/docs/superpowers/plans/2026-06-08-markdown-tooling-adoption.md:623) lines 623-628.
* Finding: `gh run list --branch main --limit 6` is too weak. It can show older successful runs and does not prove the listed workflows ran for the pushed head SHA. The plan also expects `plugin-test-harness-ci` to be green, but that workflow’s path filter points at `plugins/plugin-test-harness/**`, and that plugin directory is currently absent.
* Repository evidence: `.github/workflows/plugin-test-harness-ci.yml` only triggers for `plugins/plugin-test-harness/**` or its workflow file; `test -d plugins/plugin-test-harness` returned `missing`. `ha-dev-plugin-tests` is path-filtered to `plugins/home-assistant-dev/**`; CodeQL runs on every push.
* External research evidence: GitHub Actions path-filter docs state workflows run only when changed paths match the filter (`https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax`, accessed 2026-06-08).
* Why it matters: Claude Code could think CI passed while looking at stale runs, or wait for a workflow that correctly did not trigger.
* Recommended action for Claude Code: Replace the final CI validation with head-SHA-specific checks, for example querying runs for `git rev-parse HEAD`, and mark path-filtered workflows that did not trigger as `not applicable` rather than green.
* Suggested validation: After push, compare each reported run’s `headSha` to the pushed commit SHA and verify `Lint Markdown`, `Format`, CodeQL, and any path-triggered existing workflow that actually ran.

#### CR-003: `specs-plans.md` status points at the reformat commit, not the completed implementation

* Severity: Low
* Status: Confirmed
* Adversarial angle: Handoff status can become technically true too early and misleading later.
* Plan reference: [plan](/home/chris/projects/Claude-Code-Plugins/docs/superpowers/plans/2026-06-08-markdown-tooling-adoption.md:602) lines 602-607.
* Finding: The plan says to mark the spec row `Implemented - <commit>` using the reformat commit short hash. But the implementation is not complete at the reformat commit; VS Code config, CI workflows, AGENTS block, contract label, ADR, TODO seal, and specs-plans update happen later.
* Repository evidence: The plan’s commit sequence has the mechanical reformat in Task 2, while implementation-completing artifacts are added in Tasks 3-6.
* External research evidence: Not applicable.
* Why it matters: Future agents using `docs/handoff/specs-plans.md` as the artifact index may follow the wrong commit as the implementation boundary.
* Recommended action for Claude Code: Record the final seal commit or an explicit implementation commit range instead of the reformat commit alone.
* Suggested validation: After implementation, compare `docs/handoff/specs-plans.md` against `git log --oneline origin/main..HEAD` and confirm the status references the commit/range that includes CI, ADR, and seal changes.

#### CR-004: Plan wording overstates “all tracked” formatting/linting scope

* Severity: Low
* Status: Confirmed
* Adversarial angle: Scope wording can create a false expectation that tracked ignored files are governed.
* Plan reference: [plan](/home/chris/projects/Claude-Code-Plugins/docs/superpowers/plans/2026-06-08-markdown-tooling-adoption.md:17) lines 17-38 and [plan](/home/chris/projects/Claude-Code-Plugins/docs/superpowers/plans/2026-06-08-markdown-tooling-adoption.md:242) lines 242-244.
* Finding: The plan says the bulk pass covers “all tracked” supported files. Current repo evidence has tracked files that are ignored by `.gitignore` rules, so formatter/linter scope is more nuanced.
* Repository evidence: `.claude/state/test-checklist.md` and `plugins/home-assistant-dev/mcp-server/package-lock.json` are tracked. `git check-ignore -v --no-index` shows `.claude/state/test-checklist.md` is ignored by root `.gitignore`, and the nested package lock is ignored by `plugins/home-assistant-dev/.gitignore`.
* External research evidence: Prettier docs say it uses `.gitignore` and `.prettierignore` from the run directory by default (`https://prettier.io/docs/cli`, accessed 2026-06-08). markdownlint-cli2 docs state `gitignore: true` imports `.gitignore` files in the tree (`https://github.com/DavidAnson/markdownlint-cli2/blob/main/README.md`, accessed 2026-06-08).
* Why it matters: The check contract can pass while some tracked ignored files remain untouched. That may be acceptable, but the plan should say so explicitly.
* Recommended action for Claude Code: Change “all tracked” wording to “tracked, non-ignored supported files, with the post-fix `git diff --name-only` as ground truth,” and explicitly call out the known tracked ignored exceptions.
* Suggested validation: After the fix pass, inspect `git diff --name-only` and confirm the touched set is expected; do not require root-gitignored `.claude/state/test-checklist.md` to be formatted/linted.

### Missing considerations

* Non-blocking: Add a rollback note. The safest rollback is reverting the implementation commit range in reverse, including CI files, root package files, config files, generated lockfile, TODO checkbox, and specs-plans status.
* Non-blocking: Add a final push-range check before `git push origin main`. Current `main` is ahead of `origin/main` by three commits; the plan should explicitly show `git log --oneline origin/main..HEAD` before pushing so Claude Code knows exactly what will publish.
* Non-blocking: Clarify whether the new workflow should align with this repo’s existing `actions/setup-node@v6` convention or intentionally retain the reference repo’s `setup-node@v4`.

### Internet research performed

* Source name: Prettier CLI documentation
* URL: https://prettier.io/docs/cli
* Access date: 2026-06-08
* What it was used to verify: `prettier . --write`, supported-file recursion, `--check` behavior, ignore-path defaults.
* Relevant conclusion: The plan’s Prettier write/check model is valid, but ignore files are part of the formatter scope.

* Source name: Prettier Ignore documentation
* URL: https://prettier.io/docs/ignore
* Access date: 2026-06-08
* What it was used to verify: `.prettierignore` syntax and `.gitignore` interaction.
* Relevant conclusion: `.prettierignore` is load-bearing, so CI path filters should include it.

* Source name: markdownlint-cli2 README
* URL: https://github.com/DavidAnson/markdownlint-cli2/blob/main/README.md
* Access date: 2026-06-08
* What it was used to verify: CLI glob behavior, `--fix`, config discovery, and `gitignore` option.
* Relevant conclusion: The plan’s quoted globs and `.markdownlint-cli2.jsonc` approach are valid; tracked ignored files can still be skipped.

* Source name: markdownlint-cli2-action README
* URL: https://github.com/DavidAnson/markdownlint-cli2-action/blob/main/README.md
* Access date: 2026-06-08
* What it was used to verify: `@v23`, `globs`, `config`, and default glob behavior.
* Relevant conclusion: Passing `globs: "**/*.md"` is necessary and correct.

* Source name: GitHub Actions workflow syntax
* URL: https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax
* Access date: 2026-06-08
* What it was used to verify: `paths` filter behavior.
* Relevant conclusion: Workflows with `paths` filters only run when changed files match; `gh run list --branch` is insufficient proof of head-SHA validation.

* Source name: actions/checkout README
* URL: https://github.com/actions/checkout/blob/main/README.md
* Access date: 2026-06-08
* What it was used to verify: Current `actions/checkout@v6` availability.
* Relevant conclusion: `checkout@v6` exists and is not a blocker.

* Source name: actions/setup-node README
* URL: https://github.com/actions/setup-node/blob/main/README.md
* Access date: 2026-06-08
* What it was used to verify: Current setup-node usage, Node versions, and npm cache behavior.
* Relevant conclusion: Node 22 with npm cache is plausible; the plan’s `setup-node@v4` is older than this repo’s existing `@v6` convention but not proven unsafe.

### Items Claude Code should verify before correcting the plan

* Whether `format.yml` should include only `.prettierignore` or also `.editorconfig` and `.gitignore` in both path filters.
* The final push range with `git log --oneline origin/main..HEAD` before publishing.
* The exact head SHA after implementation and the workflow runs associated with that SHA.
* Whether the `docs/handoff/specs-plans.md` status should reference the final seal commit or an implementation commit range.
* Whether tracked ignored files are intentionally outside the check contract.

### Suggested corrections for Claude Code's plan

* Add `.prettierignore` to `format.yml` path filters; consider `.editorconfig` and `.gitignore`.
* Replace the `gh run list --branch main --limit 6` validation with head-SHA-specific workflow validation.
* Remove `plugin-test-harness-ci` from the expected green list unless it actually triggers for the pushed head SHA.
* Use the final implementation commit or commit range in `docs/handoff/specs-plans.md`, not just the reformat commit.
* Clarify “all tracked” scope wording to account for tracked ignored files.
* Add a short rollback section and a final “commits to push” check.

### Read-only validation performed

* `git status --short`, `git status --short --branch`, `git branch --show-current`, `git log --oneline -n 10`: confirmed branch `main`, dirty `TODO.md`, and `main...origin/main [ahead 3]`.
* `git remote -v` and `git log --oneline --left-right --cherry-pick origin/main...HEAD`: confirmed origin is `L3DigitalNet/Claude-Code-Plugins` and the three ahead commits are the markdown-tooling design/spec/plan commits.
* Read `docs/handoff/state.md`, `AGENTS.md`, and the Quick Reference in `docs/handoff/conventions.md`: confirmed repo startup and branch/direct-commit conventions.
* `nl -ba` on the plan, design spec, `docs/handoff/specs-plans.md`, `.gitignore`, workflows, and relevant package files: established line-referenced evidence.
* `rg` for markdown-tooling, Prettier, markdownlint, and frontmatter references: found prior spec review context and relevant docs.
* `git ls-files` counts and JS/TS listing: current tracked surface is 270 Markdown, 31 JSON, 9 YAML/YML, 1 code-workspace, and 27 JS/TS/MJS/CJS files.
* `git ls-files -o --exclude-standard | grep -iE ... || echo NONE`: confirmed no untracked supported files currently visible.
* `git diff --stat` and `git diff -- TODO.md`: confirmed only the user’s TODO restructure is dirty.
* `git check-ignore -v --no-index ...`: confirmed `.vscode/*` is currently ignored, `.claude/state/test-checklist.md` is root-ignored, and the nested MCP package lock is ignored by a nested `.gitignore`.
* Inspected `/home/chris/projects/project-standards` config files, workflows, tags, package pin, and `v2` contents: confirmed the local reference matches the plan’s copied artifacts.
* Compared current reference files to `v2^{}` with `git diff --quiet`: no drift for the copied config/workflow files checked.
* `node --version`, `npm --version`, `command -v jq gh git`: confirmed local Node 24.13.1/npm 11.8.0 and required inspection tools.
* `bash scripts/validate-marketplace.sh`: current marketplace/manifests validate cleanly.
* `git diff --check`: current dirty TODO diff has no whitespace errors.
* Existing local Prettier support-info from `project-standards/node_modules/.bin/prettier --support-info`: confirmed current tracked supported extensions align with the plan’s md/json/jsonc/yaml/code-workspace plus excluded JS/TS surface.

### Recommended implementation validation

* Before implementation: `git status --short --branch` and `git log --oneline origin/main..HEAD`.
* Before write passes: `git ls-files -o --exclude-standard | grep -iE '\.(md|json|jsonc|ya?ml|code-workspace)$' || echo NONE`.
* Run only after implementation starts: `npm install`.
* Run only after implementation starts: `npx prettier --write .`.
* Run only after implementation starts: `npx markdownlint-cli2 --fix "**/*.md"`.
* After implementation: `npx prettier --check .`.
* After implementation: `npx markdownlint-cli2 "**/*.md"`.
* After implementation: `git diff --name-only | grep -E '\.(ts|tsx|js|jsx|mjs|cjs)$'` with inverted success handling.
* After implementation: `git ls-files '*.json' -z | xargs -0 -n1 jq empty`.
* After implementation: `bash scripts/validate-marketplace.sh`.
* After implementation: `git diff --check`.
* After push: query GitHub Actions by the pushed head SHA, not just branch/limit output.

### Final recommendation

Claude Code should revise the plan using the findings above

### Review ledger for next loop

* Plan path: `/home/chris/projects/Claude-Code-Plugins/docs/superpowers/plans/2026-06-08-markdown-tooling-adoption.md`
* Audit round: 1
* Open issue IDs: CR-001, CR-002, CR-003, CR-004
* Resolved issue IDs: None
* Superseded issue IDs: None
* Significant findings remaining: Yes
* Next audit should focus on: CI path-filter correction, head-SHA workflow validation, specs-plans commit reference, and tracked-ignored scope wording.


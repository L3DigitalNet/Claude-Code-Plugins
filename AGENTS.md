# Codex Instructions

## Codex Code Review

- For comprehensive repo reviews, save reports to `docs/code-reviews/` as new timestamped Markdown files.
- Review implementation code by default, not the test suite as a standalone review target, unless I explicitly ask for a test review.
- If I explicitly ask for a test review, use the dedicated test-suite review workflow and save reports to `docs/test-reviews/` as new timestamped Markdown files.
- If I explicitly ask for a security review, use the dedicated security-review workflow and save reports to `docs/security-reviews/` as new timestamped Markdown files.
- If I explicitly ask for an API contract review, use the dedicated api-contract-review workflow and save reports to `docs/api-contract-reviews/` as new timestamped Markdown files.
- If I explicitly ask for an observability review, use the dedicated observability-review workflow and save reports to `docs/observability-reviews/` as new timestamped Markdown files.
- If I explicitly ask for a CI review or CI/CD review, use the dedicated ci-cd-review workflow and save reports to `docs/ci-reviews/` as new timestamped Markdown files.
- If I explicitly ask for a UI review, UX review, or accessibility review, use the dedicated ui-ux-accessibility-review workflow and save reports to `docs/ui-reviews/` as new timestamped Markdown files.
- If I explicitly ask for a performance review, use the dedicated performance-review workflow and save reports to `docs/performance-reviews/` as new timestamped Markdown files.
- Read `docs/conventions.md` when present and treat it as a primary review input.
- If no conventions file exists, recommend creating `docs/conventions.md` and propose concrete project-specific conventions based on the codebase.
- Write the saved report for Claude Code as the primary reader.
- At the top of the report, suggest Claude use the `superpowers:receiving-code-review` skill.

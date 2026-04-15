# Codex Instructions

**Session handoff:** [`docs/handoff.md`](docs/handoff.md) — read this first. Current deployed state, remaining work, bugs log,
architecture, credentials, and gotchas.

**Full conventions reference:** [`docs/conventions.md`](docs/conventions.md) — LLM-targeted pattern library. Every convention follows
the six-field schema (Applies-when / Rule / Code / Why / Sources / Related) with a Quick Reference table at the top for O(1) lookup. Do
not introduce new patterns without checking conventions first.

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
- If I explicitly ask for a data review or migration review, use the dedicated data-schema-migration-review workflow and save reports to `docs/data-reviews/` as new timestamped Markdown files.
- If I explicitly ask for a dependency review or supply chain review, use the dedicated dependency-supply-chain-review workflow and save reports to `docs/dependency-reviews/` as new timestamped Markdown files.
- If I explicitly ask for an architecture review or boundary review, use the dedicated architecture-boundary-review workflow and save reports to `docs/architecture-reviews/` as new timestamped Markdown files.
- If I explicitly ask for a privacy review, use the dedicated privacy-and-data-governance-review workflow and save reports to `docs/privacy-reviews/` as new timestamped Markdown files.
- If I explicitly ask for a documentation review or runbook review, use the dedicated documentation-and-runbook-review workflow and save reports to `docs/documentation-reviews/` as new timestamped Markdown files.
- If I explicitly ask for an incident readiness review, use the dedicated incident-readiness-review workflow and save reports to `docs/incident-readiness-reviews/` as new timestamped Markdown files.
- If I explicitly ask for a configuration review or secret-boundary review, use the dedicated configuration-and-secrets-boundary-review workflow and save reports to `docs/configuration-reviews/` as new timestamped Markdown files.
- If I explicitly ask for a release readiness review, use the dedicated release-readiness-review workflow and save reports to `docs/release-readiness-reviews/` as new timestamped Markdown files.
- If I explicitly ask for an async workflow review, background jobs review, worker review, or queue review, use the dedicated background-jobs-and-async-workflow-review workflow and save reports to `docs/async-workflow-reviews/` as new timestamped Markdown files.
- If I explicitly ask for an integration review, third-party boundary review, provider integration review, or webhook review, use the dedicated integration-and-third-party-boundary-review workflow and save reports to `docs/integration-reviews/` as new timestamped Markdown files.
- If I explicitly ask for a product logic review, business logic review, or workflow semantics review, use the dedicated product-and-business-logic-review workflow and save reports to `docs/product-logic-reviews/` as new timestamped Markdown files.
- If I explicitly ask for a frontend state review, client state review, or interaction correctness review, use the dedicated frontend-state-and-interaction-review workflow and save reports to `docs/frontend-state-reviews/` as new timestamped Markdown files.
- If I explicitly ask for a permissions review, authorization review, or access-control review, use the dedicated authorization-and-permission-model-review workflow and save reports to `docs/permissions-reviews/` as new timestamped Markdown files.
- If I explicitly ask for an MCP review, tool-boundary review, or agent-tool review, use the dedicated mcp-and-agent-tool-boundary-review workflow and save reports to `docs/mcp-reviews/` as new timestamped Markdown files.
- If I explicitly ask for a retrieval review, RAG review, or knowledge-base review, use the dedicated retrieval-and-knowledge-base-review workflow and save reports to `docs/retrieval-reviews/` as new timestamped Markdown files.
- If I explicitly ask for a desktop packaging review, installer review, or desktop distribution review, use the dedicated desktop-packaging-review workflow and save reports to `docs/desktop-packaging-reviews/` as new timestamped Markdown files.
- If I explicitly ask for a shell automation review, Bash review, or script safety review, use the dedicated shell-and-automation-script-review workflow and save reports to `docs/shell-automation-reviews/` as new timestamped Markdown files.
- If I explicitly ask for an AI workflow review, prompt workflow review, or model integration review, use the dedicated ai-and-prompt-workflow-review workflow and save reports to `docs/ai-workflow-reviews/` as new timestamped Markdown files.
- Read `docs/conventions.md` when present and treat it as a primary review input.
- If no conventions file exists, recommend creating `docs/conventions.md` and propose concrete project-specific conventions based on the codebase.
- Write the saved report for Claude Code as the primary reader.
- At the top of the report, suggest Claude use the `superpowers:receiving-code-review` skill.
## Review Orchestrator Note

- Full `review-orchestrator` sweeps now run selected child reviews with bounded parallelism by default, currently up to `8` in parallel after planning, preflight, and shared research complete.
- The shared-research phase can legitimately take around `10` minutes on larger or research-heavy repos before child reviews start, so treat that as normal unless heartbeats stop or no artifact activity appears beyond that window.
- Expect a top-level sweep index under `docs/review-orchestrator/` plus one `*-execution.json` manifest inside each selected review folder while the sweep is running.
- Do not describe sweep child reviews as running “one at a time” unless the sweep was explicitly configured down to serial execution.

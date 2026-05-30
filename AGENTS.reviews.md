# Review Workflows

Repo-local review guidance for Codex review tasks.

## Saved Reports

- Comprehensive code reviews: `docs/code-reviews/`
- Test reviews: `docs/test-reviews/`
- Security reviews: `docs/security-reviews/`
- API contract reviews: `docs/api-contract-reviews/`
- Observability reviews: `docs/observability-reviews/`
- CI / CI-CD reviews: `docs/ci-reviews/`
- UI / UX / accessibility reviews: `docs/ui-reviews/`
- Performance reviews: `docs/performance-reviews/`
- Data / migration reviews: `docs/data-reviews/`
- Dependency / supply-chain reviews: `docs/dependency-reviews/`
- Architecture / boundary reviews: `docs/architecture-reviews/`
- Privacy reviews: `docs/privacy-reviews/`
- Documentation / runbook reviews: `docs/documentation-reviews/`
- Incident readiness reviews: `docs/incident-readiness-reviews/`
- Configuration / secret-boundary reviews: `docs/configuration-reviews/`
- Release readiness reviews: `docs/release-readiness-reviews/`
- Async / background-job reviews: `docs/async-workflow-reviews/`
- Integration / webhook / third-party reviews: `docs/integration-reviews/`
- Product / business-logic reviews: `docs/product-logic-reviews/`
- Frontend state / interaction reviews: `docs/frontend-state-reviews/`
- Authorization / permissions reviews: `docs/permissions-reviews/`
- MCP / tool-boundary reviews: `docs/mcp-reviews/`
- Retrieval / RAG / knowledge-base reviews: `docs/retrieval-reviews/`
- Desktop packaging reviews: `docs/desktop-packaging-reviews/`
- Shell / automation reviews: `docs/shell-automation-reviews/`
- AI workflow / prompt workflow / model-integration reviews: `docs/ai-workflow-reviews/`

## Review Rules

- Review implementation code by default, not the test suite in isolation, unless the user explicitly asks for a test review.
- Detect handoff layout before review work: read `docs/state.md` and `docs/conventions.md` (v3 layout). Treat those files as primary review inputs.
- Write saved reports for Claude and Codex as the primary readers.
- Suggest the receiving-code-review workflow at the top of a saved report when that recommendation is relevant.

## Review Orchestrator

- Full `review-orchestrator` sweeps run selected child reviews with bounded parallelism by default, currently up to `8` in parallel.
- Shared research can take around `10` minutes on larger or research-heavy repos before child reviews start.
- Expect a top-level sweep index under `docs/review-orchestrator/` plus one `*-execution.json` manifest inside each selected review folder while the sweep is running.

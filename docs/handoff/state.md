# Handoff

**Last updated:** 2026-06-12 (uv-strict-python v0.2.0 released; release-pipeline PATH-shim fix committed, release pending)

## Session Instructions

1. Read this file first.
2. Check `docs/handoff/conventions.md` before introducing a new persistent pattern.
3. Branch workflow is direct commit to `main` — see `BRANCH_PROTECTION.md` (no `testing` branch since 2026-05-07).

## Active Incidents

### (none)

## Recently closed (this session, 2026-06-12)

- **uv-strict-python v0.2.0 released** (tag + GitHub release, `c981da1`). Conformance review vs project-standards found 1 direct conflict + drift → fixed (`e57850f`); features (`9d5761b`): scope-gated shims (Python projects only, `.local.md` override), BasedPyright LSP (`.lsp.json`), standard-sync drift test (byte-parity vs adopt bundle + SKILL.md sync pin), scaffold templates, tests→`tests/` (`missing_tests` waiver removed). 50 bats green.
- **Bug 8 fixed, unreleased** (`4f9fd1c`, `19595e2`): uv-strict-python shims blocked bare `python3` in 7 release-pipeline scripts (`detect-unreleased.sh` misreported "not a monorepo" mid-release) and 6 up-docs scripts (`commit-candidates.sh` snapshot failed during live pre-flight) → PATH guard added (ENV-001). Both fixes committed; both plugins' releases pending.

Detail in `sessions/2026-06.md`.

<!-- 2 KB cap (enforced by propagate-repo): keep ONLY the current session's close here. Older closes live as rows in docs/handoff/sessions/<YYYY-MM>.md. -->

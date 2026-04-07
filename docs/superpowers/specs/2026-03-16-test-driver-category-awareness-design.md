# Test Driver: Category-Aware Gap Analysis

**Date:** 2026-03-16
**Scope:** Three skill files in `plugins/test-driver/skills/`
**Problem:** Gap analysis only finds unit test gaps despite profiles defining six test categories

## Problem Statement

The gap-analysis skill's Step 5 (Map Coverage) is category-blind. It checks whether *any* test file references a source file, but never checks which *category* of test provides that coverage. When `test_auth.py` has unit tests for `auth.py`, the structural mapping considers `auth.py` "covered" across all categories. This causes the gap report to miss integration, e2e, contract, and security gaps entirely.

The convergence loop then only generates unit tests because those are the only gaps it receives.

## Changes

### 1. gap-analysis/SKILL.md — Step 5: Per-Category Coverage Mapping

Replace the current three-point structural mapping with a two-phase approach.

**Phase 1: Classify existing test files into categories.**
Priority order for classification:
1. Directory structure: `tests/unit/`, `tests/integration/`, `tests/e2e/`, `tests/contract/`, `tests/security/`, `tests/ui/`
2. Pytest markers: `@pytest.mark.unit`, `@pytest.mark.integration`, etc.
3. Conservative fallback: if neither directory nor marker is present, classify all tests as "unit"

The conservative fallback ensures that unorganized test suites flag gaps for every non-unit applicable category. This may over-report gaps, but under-reporting is worse (the whole reason this fix exists).

**Phase 2: Per-source-file, per-category mapping.**
For each source file and each applicable category (from the profile): does a test file *classified in that category* reference this source file? A source file with unit tests but no integration tests has an integration gap.

Step 6 (prioritization) stays unchanged but now receives multi-category gap data, producing a report with gaps across all applicable categories.

### 2. convergence-loop/SKILL.md — GENERATE Phase: Category-Specific Guidance

Add a new subsection under GENERATE that tells Claude what distinguishes each category's tests:

| Category | Key Difference from Unit Tests |
|----------|-------------------------------|
| Unit | Mock external dependencies, test isolated function/class behavior |
| Integration | Use real components (test DB, actual services), test data flow across component boundaries |
| E2E | Full request lifecycle through the actual app stack, minimal mocking |
| Contract | Validate API response schemas, status codes, error shapes, content-type headers; use schema validation, not value equality |
| Security | Auth bypass, input injection (SQL/XSS/command), secrets in responses, rate limiting, CORS |
| UI | User interaction via framework tools (pytest-qt, XCUITest, Charlotte); assert on visible outcomes |

Add category ordering preference: unit first (fastest feedback loop), then integration, then contract/security/e2e, then UI. This keeps the convergence loop efficient.

### 3. test-design/SKILL.md — Non-Unit Test Design Principles

Add a new section (Section 8) covering what changes when writing non-unit tests:

- **Integration tests**: Relax isolation; the point is testing component interaction. Use real dependencies. Assert on observable outcomes across boundaries, not internal state.
- **Contract tests**: Test the shape, not the content. Assert on structure, required fields, types. Use schema validation (jsonschema, pydantic). Should pass regardless of data state.
- **Security tests**: Each test represents a specific attack vector. Assert the attack fails gracefully with proper error codes and no data leakage in error messages.
- **E2E tests**: Test user-facing workflows end-to-end. Minimize mocking. Accept slower execution. Focus on critical paths.
- **UI tests**: Test user interaction, not implementation. Use accessibility identifiers. Assert on what the user sees.

## Files Modified

| File | Type of Change |
|------|---------------|
| `plugins/test-driver/references/gap-analysis.md` | Rewrite Step 5, minor adjustment to Step 6 |
| `plugins/test-driver/references/convergence-loop.md` | Add subsection under GENERATE |
| `plugins/test-driver/references/test-design.md` | Add Section 8 |

> **Note:** The final implementation placed these files in `references/` rather than `skills/` as originally planned.

## What Does NOT Change

- Stack profiles (they already define applicable categories correctly)
- TEST_STATUS.json schema (already has per-category fields)
- The analyze command (it delegates to gap-analysis)
- testing-mindset skill (it only drives awareness, not execution)
- test-status skill (schema already supports multi-category data)

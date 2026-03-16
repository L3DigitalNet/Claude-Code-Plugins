---
name: gap-analysis
description: >
  Test gap analysis methodology for finding missing tests across six categories (unit,
  integration, e2e, UI, contract, security). Use when conducting a gap analysis, auditing
  test coverage, identifying untested code, inventorying tests, or when /test-driver:analyze
  is invoked. Provides the step-by-step process for detecting project type, loading stack
  profiles, and producing a prioritized gap report.
---

# Gap Analysis: Finding Missing Tests

A systematic methodology for identifying which source files and functions lack adequate test coverage. This skill produces a structured gap report that the convergence-loop skill consumes.

## Step 1: Detect Project Type

Scan the project root for marker files to determine which stack profile to load:

| Marker | Profile |
|--------|---------|
| `pyproject.toml` with `fastapi` or `starlette` in dependencies | `python-fastapi` |
| `pyproject.toml` with `PySide6` or `PyQt6` in dependencies | `python-pyside6` |
| `pyproject.toml` with `django` in dependencies | `python-django` |
| `manifest.json` with `"domain"` key + `custom_components/` directory | `home-assistant` |
| `Package.swift` or `*.xcodeproj` | `swift-swiftui` |
| `pyproject.toml` with no framework match | Generic Python (use pytest conventions) |
| No marker found | Ask user which profile to use |

### No Profile Match

When detection fails or the matching profile skill doesn't exist:

> "No stack profile matches this project. I can run a basic gap analysis using generic conventions, but results will be more accurate with a dedicated profile. Want me to create a `profiles/<stack-name>/SKILL.md` for this project type?"

If the user agrees: inspect the project's test toolchain (test runner, coverage tool, directory conventions, UI framework), draft a profile answering the five standard questions, write it to `skills/profiles/<stack-name>/SKILL.md`, and proceed.

### Partial Match

If a profile exists but doesn't cover something the project uses (e.g., the `python-fastapi` profile is loaded but the project also has Playwright browser tests), suggest updating the profile to include the missing tooling.

### Multi-Framework Projects

Load one primary profile based on the dominant framework. If the project combines stacks (e.g., Django backend + PySide6 management tool), the primary profile covers the main application. For secondary components, consult additional profiles when running scoped analysis on those directories.

## Step 2: Determine Applicable Test Categories

Load the categories from the matched stack profile. The six categories:

| Category | Scope | Applicability |
|----------|-------|---------------|
| **Unit** | Single function/class, mocked dependencies | Always applicable |
| **Integration** | Multiple components, real dependencies | Always applicable |
| **E2E** | Full system flow, entry to exit | Profile-determined |
| **UI** | Visual interaction (Qt Pilot, Charlotte, XCUITest) | Profile-determined |
| **Contract** | API schema validation, request/response shapes | Profile-determined |
| **Security** | Injection, auth bypass, secrets exposure | Profile-determined |

Only analyze categories that the profile marks as applicable.

## Step 3: Inventory Existing Tests

Use Glob to find all test files based on the profile's discovery conventions:

- Match test file patterns (e.g., `test_*.py`, `*Tests.swift`)
- Categorize each test file by type based on directory structure (`tests/unit/`, `tests/integration/`) or pytest markers
- Count tests per category

**Read test files in parallel batches** (opus-context alignment). For files under 4000 lines, read them fully.

## Step 4: Inventory Source Files

Find all non-test source files. Exclude common non-source patterns:

- `__pycache__/`, `.pyc` files
- Migration files (`migrations/`, `alembic/`)
- Generated files (`moc_*`, `ui_*`, `*.generated.*`)
- Configuration files (`*.toml`, `*.yml`, `*.json` unless they contain logic)
- Build artifacts (`build/`, `dist/`, `.build/`)
- Virtual environments (`venv/`, `.venv/`, `env/`)

## Step 5: Map Coverage

For each source file, check which applicable test categories have corresponding tests:

- **Structural mapping:** Does a test file exist that imports or references this source file?
- **Naming convention:** Does `tests/test_<module>.py` exist for `src/<module>.py`?
- **Content scan:** Grep test files for imports of the source module

This is structural mapping (test file exists and references the source), not runtime coverage (line-level). Runtime coverage requires executing the test suite, which happens during the convergence loop.

## Step 6: Identify and Prioritize Gaps

For each source file missing test coverage in an applicable category, create a gap entry. Prioritize by:

1. **Public API surface** (highest) — exported functions, API endpoints, public class methods
2. **Complex logic** — functions with many branches, deep nesting, or multiple return paths
3. **Recently changed** — files modified in recent commits are more likely to have regressions
4. **Error handling paths** — exception handlers, error returns, validation logic

## Step 7: Gap Report Output

Produce a structured report that the convergence-loop skill can consume:

```
## Gap Analysis Report

**Project:** <project-name>
**Profile:** <stack-profile>
**Date:** <ISO-8601 timestamp>
**Source files analyzed:** <count>

### Gaps Found: <total-count>

| Priority | File | Category | Description |
|----------|------|----------|-------------|
| high | src/api/auth.py | unit | No unit tests for token validation functions |
| high | src/api/auth.py | integration | No integration test for token refresh with expired session |
| medium | src/services/email.py | unit | Email template rendering has no tests |
| low | src/utils/formatting.py | unit | String formatting helpers untested (low complexity) |

### Category Summary

| Category | Applicable | Existing Tests | Gaps |
|----------|-----------|----------------|------|
| unit | yes | 38 | 3 |
| integration | yes | 12 | 1 |
| e2e | yes | 4 | 0 |
| contract | yes | 0 | 0 |
```

This report feeds directly into the convergence-loop skill, which generates tests for the highest-priority gaps first.

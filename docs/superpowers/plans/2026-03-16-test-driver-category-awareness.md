# Test Driver Category-Aware Gap Analysis — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make test-driver's gap analysis find and fill gaps across all applicable test categories (unit, integration, e2e, contract, security, UI), not just unit tests.

**Architecture:** Three skill markdown files are edited. gap-analysis gets category-aware coverage mapping in Step 5. convergence-loop gets category-specific generation guidance in its GENERATE phase. test-design gets a new Section 8 on non-unit test design principles.

**Tech Stack:** Markdown skill files (no code, no tests, no build)

**Spec:** `docs/superpowers/specs/2026-03-16-test-driver-category-awareness-design.md`

---

## Chunk 1: All Tasks

### Task 1: Rewrite gap-analysis Step 5

**Files:**
- Modify: `plugins/test-driver/skills/gap-analysis/SKILL.md` (lines 81-89, current Step 5)

The current Step 5 has three category-blind bullet points. Replace it with a two-phase approach that classifies tests into categories then maps coverage per source file per category. Also update Step 3 (line 65) to explicitly note that categorization output feeds Step 5.

- [ ] **Step 1: Update Step 3 to note categorization feeds Step 5**

In Step 3 (Inventory Existing Tests), the line "Categorize each test file by type based on directory structure (`tests/unit/`, `tests/integration/`) or pytest markers" should be expanded to clarify this classification is used by Step 5 for per-category coverage mapping.

Change line 65 from:
```
- Categorize each test file by type based on directory structure (`tests/unit/`, `tests/integration/`) or pytest markers
```
To:
```
- Categorize each test file by type based on directory structure (`tests/unit/`, `tests/integration/`) or pytest markers. This classification feeds Step 5's per-category coverage mapping.
```

- [ ] **Step 2: Replace Step 5 content**

Replace lines 81-89 (the current Step 5 heading and content) with:

```markdown
## Step 5: Map Coverage Per Category

For each source file and each applicable category (from the profile), determine whether test coverage exists in that specific category.

### Phase 1: Classify Existing Tests

Use the categorization from Step 3. Classification priority:

1. **Directory structure**: Test files under `tests/unit/`, `tests/integration/`, `tests/e2e/`, `tests/contract/`, `tests/security/`, `tests/ui/` are classified by their directory.
2. **Pytest markers**: Test files using `@pytest.mark.unit`, `@pytest.mark.integration`, etc. are classified by their markers. A file can belong to multiple categories if it has multiple markers.
3. **Conservative fallback**: Test files that have neither a category directory nor markers are classified as **unit**. This intentionally over-reports gaps for non-unit categories; under-reporting is the problem this methodology exists to solve.

### Phase 2: Per-Source-File, Per-Category Mapping

For each source file, for each applicable category:

- Is there a test file **classified in that category** (from Phase 1) that imports or references this source file?
- Use the same structural mapping techniques (import scanning, naming conventions, content grep) but scoped to the test files in that specific category.

A source file that has unit tests but no integration tests still has an **integration gap**. A source file with no tests in any category has gaps in every applicable category.

This is structural mapping (test file exists in the right category and references the source), not runtime coverage. Runtime coverage requires executing the test suite, which happens during the convergence loop.
```

- [ ] **Step 3: Verify Step 6 references are coherent**

Read Step 6 after the edit. The current text at line 93 says "For each source file missing test coverage in an applicable category, create a gap entry." This already works correctly with the new Step 5 output since Step 5 now actually produces per-category data. No change needed to Step 6 unless it reads awkwardly after the edit.

- [ ] **Step 4: Commit**

```bash
git add plugins/test-driver/skills/gap-analysis/SKILL.md
git commit -m "fix(test-driver): make gap analysis category-aware in Step 5

Step 5 now classifies tests into categories (by directory, markers, or
conservative fallback to unit) and maps coverage per source file per
category. Source files with unit tests but no integration/security/etc
tests now correctly show gaps in those categories."
```

### Task 2: Add category-specific generation guidance to convergence-loop

**Files:**
- Modify: `plugins/test-driver/skills/convergence-loop/SKILL.md` (insert after GENERATE section, after line 54)

- [ ] **Step 1: Add category-specific subsection after GENERATE**

After line 54 (the last bullet of the GENERATE section: "Place test files according to the profile's discovery conventions"), insert:

```markdown

#### Category-Specific Generation

When generating tests for non-unit gaps, adapt the test approach to match the category:

| Category | Approach |
|----------|----------|
| **Unit** | Mock external dependencies. Test isolated function/class behavior. One function per test. |
| **Integration** | Use real components (test database, actual HTTP client, real service instances). Assert on observable outcomes across component boundaries, not internal state. |
| **E2E** | Full request lifecycle through the actual app stack with minimal mocking. Test critical user-facing workflows (e.g., authenticate, perform action, verify result). Accept slower execution. |
| **Contract** | Validate API response schemas, status codes, required fields, content-type headers, and error response shapes. Use schema validation (jsonschema, pydantic model parsing) rather than value equality. Tests should pass regardless of data state. |
| **Security** | Each test represents a specific attack vector: SQL injection in user inputs, auth token manipulation, accessing resources without credentials, accessing another user's resources. Assert the attack fails gracefully (proper error code, no data leakage in error messages). |
| **UI** | Use the framework's UI testing tool (pytest-qt, XCUITest, Charlotte). Interact via accessibility identifiers. Assert on what the user sees (text content, visibility, enabled state), not internal widget state. |

#### Category Ordering

When the gap report contains gaps across multiple categories, generate tests in this order:

1. **Unit** — fastest to write and run, catches the most bugs per iteration
2. **Integration** — validates component interactions
3. **Contract** / **Security** — validates API shape and attack resistance
4. **E2E** / **UI** — slowest, run last

Within each category, follow the gap report's priority ordering (high before medium before low).
```

- [ ] **Step 2: Commit**

```bash
git add plugins/test-driver/skills/convergence-loop/SKILL.md
git commit -m "feat(test-driver): add category-specific test generation guidance

The convergence loop's GENERATE phase now has explicit guidance for
writing integration, e2e, contract, security, and UI tests, plus a
category ordering preference for efficient convergence."
```

### Task 3: Add non-unit test design principles to test-design

**Files:**
- Modify: `plugins/test-driver/skills/test-design/SKILL.md` (append after Section 7, around line 177)

- [ ] **Step 1: Add Section 8**

Append after the end of Section 7 (Meaningful Assertions):

```markdown

## 8. Non-Unit Test Design

Sections 1-7 apply universally, but some principles shift weight when writing non-unit tests.

### Integration Tests

Relax isolation (Section 1): the point of integration tests is verifying that components work together. Use real dependencies where feasible (test database, actual HTTP client, real service wiring). Keep test independence (each test sets up its own state), but don't mock the interactions you're trying to test.

Assert on observable outcomes across boundaries: data persisted correctly, response includes data assembled from multiple components, side effects propagated through the real dependency chain. Avoid asserting on internal state of intermediate components.

### Contract Tests

Test the shape, not the content. Assert on response structure (required fields present, correct types, proper status codes, expected content-type headers, error response format). Use schema validation (jsonschema, pydantic model parsing) rather than value equality.

Contract tests should pass regardless of what data is in the system. If a contract test breaks when test data changes, it's testing values, not shape.

### Security Tests

Each test represents one attack vector. Write the test as an attacker would attempt the attack: SQL injection in a user input field, manipulated auth tokens, requests without credentials, accessing another user's resources via ID enumeration.

Assert that the attack fails gracefully: proper HTTP error code (401/403, not 500), no sensitive data leaked in error messages or response bodies, no state corruption from the malicious input.

### E2E Tests

Test user-facing workflows from entry point to final result. Minimize mocking: the value of E2E tests is proving the full stack works together. Accept slower execution as the cost of this confidence.

Focus on critical paths (authenticate, perform primary action, verify result) rather than exhaustive feature coverage. A few high-quality E2E tests covering the main workflows are worth more than dozens covering edge cases.

### UI Tests

Test what the user sees and does, not implementation details. Click buttons, fill forms, navigate between screens, verify visible outcomes (text content, element visibility, enabled/disabled state).

Use accessibility identifiers or object names for element lookup, not CSS selectors or internal widget hierarchy. If a test breaks because the widget tree changed but the user experience didn't, the test is too tightly coupled to implementation.
```

- [ ] **Step 2: Commit**

```bash
git add plugins/test-driver/skills/test-design/SKILL.md
git commit -m "feat(test-driver): add non-unit test design principles

Section 8 covers how universal test design principles shift for
integration, contract, security, e2e, and UI tests."
```

# Gap Analysis: Finding Missing Tests

test coverage, identifying untested code, inventorying tests, or when /test-driver:analyze is invoked. Provides the step-by-step process for detecting project type, loading stack profiles, and producing a prioritized gap report.

---

A systematic methodology for identifying which source files and functions lack adequate test coverage. This skill produces a structured gap report that the convergence-loop skill consumes.

## Step 1: Detect Project Type

Scan the project root for marker files to determine which stack profile to load:

| Marker | Profile |
| --- | --- |
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
| --- | --- | --- |
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
- Categorize each test file by type based on directory structure (`tests/unit/`, `tests/integration/`) or pytest markers. This classification feeds Step 5's per-category coverage mapping.
- Count tests per category

**Read test files in parallel batches** (full-context reading). For files under 4000 lines, read them fully.

**conftest.py / test infrastructure:** If `conftest.py` or equivalent files contain complex fixture logic — database setup, API client mocking, authentication simulation, multi-step setup procedures — note them for Step 5. Fixtures over ~30 lines with conditional logic or multiple code paths are candidates for their own tests; bugs in fixtures silently corrupt every test that depends on them.

## Step 4: Inventory and Enumerate Source Files

Find all non-test source files. Exclude common non-source patterns:

- `__pycache__/`, `.pyc` files
- Migration files (`migrations/`, `alembic/`)
- Generated files (`moc_*`, `ui_*`, `*.generated.*`)
- Configuration files (`*.toml`, `*.yml`, `*.json` unless they contain logic)
- Build artifacts (`build/`, `dist/`, `.build/`)
- Virtual environments (`venv/`, `.venv/`, `env/`)

After identifying source files, **read each one** (full read for files under 4000 lines) and enumerate:

- Public functions, class methods, and route handlers
- Distinct behaviors per function: happy path, error/exception paths, conditional branches that produce materially different outcomes, loop edge cases where empty or boundary inputs change behavior
- Component boundaries: functions that call external services, write to databases, or coordinate multiple modules

This enumeration is the foundation of Step 5's function-level mapping. Without it, coverage assessment degrades to file-level detection — checking whether a test file _exists_ for a source file rather than whether each function and behavior _within_ the file is actually tested.

## Step 5: Map Coverage Per Category

For each source file and each applicable category (from the profile), determine whether test coverage exists in that specific category.

### Phase 1: Classify Existing Tests

Use the categorization from Step 3. Classification priority:

1. **Directory structure**: Test files under `tests/unit/`, `tests/integration/`, `tests/e2e/`, `tests/contract/`, `tests/security/`, `tests/ui/` are classified by their directory.
2. **Pytest markers**: Test files using `@pytest.mark.unit`, `@pytest.mark.integration`, etc. are classified by their markers. A file can belong to multiple categories if it has multiple markers.
3. **Conservative fallback**: Test files that have neither a category directory nor markers are classified as **unit**. This intentionally over-reports gaps for non-unit categories; under-reporting is the problem this methodology exists to solve.

### Phase 2: Function-Level Behavior Mapping

File-level mapping ("does a test file reference this source file?") drastically under-reports gaps. A source file with 15 functions where only 3 are tested would report zero gaps at the file level. This phase maps at the function and behavior level instead.

For each source file, using the function/behavior enumeration from Step 4:

1. **Read the corresponding test files** (those classified in the relevant category from Phase 1 that reference this source file). Map each test function to the specific source function(s) it exercises. A test exercises a source function if it:
   - Calls it directly
   - Calls an endpoint or method that delegates to it
   - Mocks it to verify it was called with expected arguments

2. **Identify untested functions:** Source functions with zero tests exercising them in this category → gap.

3. **Identify undertested functions:** Source functions with tests that miss significant branches → gap at lower priority. "Significant" means the branch handles a materially different case (error vs. success, empty vs. populated, single vs. multi-item, different code paths in conditional logic). Trivial formatting differences or unreachable defensive code do not count.

4. **Cross-category awareness:** A function tested in unit but not integration still has an integration gap if it crosses component boundaries (calls external services, writes to databases, coordinates multiple modules). A route handler tested in integration but not contract has a contract gap if it returns structured API responses. Internal-only helpers (private functions, utility code) need only unit coverage.

**Example:** `app/plaid_client.py` contains `run_sync`, `sync_all`, `create_link_token`, `map_plaid_transaction`, and `sync_recurring_streams`. If `test_sync.py` tests `run_sync` happy path and `sync_all` but never exercises `run_sync`'s modified-transaction branch, `map_plaid_transaction`'s counterparties handling, or `create_link_token`'s update-mode path, the report should list each untested function/branch as a separate gap — not zero gaps because a test file exists for the source file.

### Phase 3: Test Quality Assessment

For functions that _do_ have tests (identified as "covered" in Phase 2), evaluate whether the tests are substantive. Phase 3 gaps are lower priority than Phase 2 gaps (untested functions) but can mask real bugs just as effectively.

1. **Assertion quality:** Check whether tests use specific assertions (`assert result == expected`, `assert response.status_code == 200`, `assert "field" in body`) vs. weak assertions (`assert result`, `assert response`, `assertTrue(output)`). A test with only truthiness assertions for a function that returns structured data would pass even if the function returned wrong data. Flag as a gap.

2. **Boundary coverage:** For functions with numeric, collection, date, or string parameters, check whether tests cover boundary values (zero/empty, single element, boundary threshold, one-past-boundary) or only typical inputs. A function tested once with `amount=50.00` but never with `amount=0`, negative amounts, or `None` has boundary gaps. Functions that would benefit from parametrized tests covering multiple input classes should be flagged.

3. **Mock depth:** Check whether tests mock so aggressively that they only verify wiring rather than behavior. Signs of over-mocking: the test creates >3 mocks for a single function, the only assertions are `mock.assert_called_once_with(...)`, or the test would pass with any implementation. Over-mocked tests provide false coverage confidence — they tell you the function _calls_ its dependencies, not that it _works_.

## Step 6: Identify and Prioritize Gaps

For each untested or undertested function/behavior identified in Step 5, create a separate gap entry. Each distinct untested behavior is its own gap — do not aggregate multiple missing tests into a single "file X needs tests" entry.

Prioritize by:

1. **Public API surface** (highest) — route handlers, exported functions, public class methods
2. **Complex logic** — functions with many branches, deep nesting, or multiple return paths
3. **Recently changed** — functions modified in recent commits are more likely to have regressions
4. **Error handling paths** — exception handlers, error returns, validation logic
5. **Untested functions** (higher priority within a file) over **undertested branches** of tested functions (lower priority)
6. **Weak-assertion tests** and **over-mocked tests** (Phase 3 gaps) — lowest priority within a file, but still worth reporting

### Recent-Change Priority Boost

Use `git log` to identify functions changed since the last analysis:

```bash
git log --since="<last_analysis_date>" -p -- <source_files> | grep "^[+-].*def \|^[+-].*async def "
```

Functions that appear in recent diffs get a priority boost — they're the most likely to have introduced untested behavior. If no `last_analysis_date` is available (first analysis), use the last 30 days.

## Step 7: Gap Report Output

Produce a structured report using Template 1 (Gap Analysis Report) from `${CLAUDE_PLUGIN_ROOT}/references/ux-templates.md`. This report feeds directly into the convergence-loop reference, which generates tests for the highest-priority gaps first.

# test-driver Plugin Design Spec

**Date:** 2026-03-16
**Version:** 0.1.0
**Status:** Draft

## Purpose

Teaches Claude to proactively drive thorough testing across any project type. Performs gap analysis, generates missing tests, runs convergence loops until all tests pass, and tracks testing posture in a persistent status file. Framework-agnostic core with stack-specific profiles.

Everything runs inline in the main context window with no agent delegation, aligned with the opus-context plugin's philosophy of maximizing context for better reasoning.

## Design Principles

- **P1 (Act on Intent):** Invoking `/test-driver:analyze` is consent to run the full gap analysis and (with confirmation) the convergence loop. No sub-step confirmation gates.
- **P3 (Succeed Quietly):** The testing-mindset skill notes changes silently and surfaces suggestions only at natural breakpoints. Convergence loops report at the end, not after every iteration.
- **P5 (Convergence is the Contract):** The convergence loop drives toward all-green with optional coverage targets. Oscillation detection stops runaway cycles.
- **P6 (Composable Units):** Each skill is independently useful. Stack profiles are independent of core skills. The plugin delegates framework-specific knowledge to existing plugins.

## Plugin Structure

```
plugins/test-driver/
├── .claude-plugin/
│   └── plugin.json
├── skills/
│   ├── testing-mindset/
│   │   └── SKILL.md              # Always-on: when to suggest testing
│   ├── gap-analysis/
│   │   └── SKILL.md              # How to conduct gap analysis
│   ├── convergence-loop/
│   │   └── SKILL.md              # Loop behavior and exit criteria
│   ├── test-status/
│   │   └── SKILL.md              # Reading/writing TEST_STATUS.json
│   ├── test-design/
│   │   └── SKILL.md              # Universal test design principles
│   └── profiles/
│       ├── python-fastapi/
│       │   └── SKILL.md
│       ├── python-pyside6/
│       │   └── SKILL.md
│       ├── python-django/
│       │   └── SKILL.md
│       ├── home-assistant/
│       │   └── SKILL.md
│       └── swift-swiftui/
│           └── SKILL.md
├── commands/
│   ├── analyze.md                # /test-driver:analyze
│   └── status.md                 # /test-driver:status
├── CHANGELOG.md
└── README.md
```

## Core Skills

### testing-mindset (Always-On Behavioral Driver)

The most important skill in the plugin. Broadly triggered so it loads into context for virtually any implementation task.

**Trigger words:** test, implement, feature, fix, bug, refactor, build, create, modify, change, add, update, debug, complete, finish, deploy, merge, PR, commit

*Intentionally broad — this is effectively an always-on skill.* The trigger list ensures testing-mindset loads into context for any implementation task. The non-intrusive cadence rules (behavior #4 below) prevent this from becoming noisy.

**Teaches Claude four behaviors:**

1. **Recognize proactive testing moments.** After any of these, evaluate whether testing is needed:
   - New function/class/module added
   - Existing behavior modified
   - Bug fixed (regression test required)
   - Feature completed (full category sweep)
   - Pre-commit or pre-merge (final gap check)

2. **Apply the assessment heuristic.** Before suggesting a gap analysis, check:
   - Have source files changed since the last analysis? (check TEST_STATUS.json)
   - Is this a natural breakpoint (feature done, bug fixed, refactor complete)?
   - How many source files changed vs test files changed? (ratio imbalance = likely gaps)

3. **Delegate framework specifics to existing plugins.** When writing tests, consult:
   - Python projects: `python-dev:python-testing-patterns`
   - PySide6 projects: `qt-suite:qtest-patterns`, `qt-suite:qt-pilot-usage`
   - HA integrations: `home-assistant-dev:ha-testing`
   - test-driver drives the *when* and *what*; existing plugins provide the *how*

4. **Maintain non-intrusive cadence.** Don't suggest testing after every edit. Note changes silently; suggest at natural breakpoints. If the user declines, wait for the next breakpoint.

**Coexistence with superpowers:test-driven-development:** If the user is in a TDD flow (test-first), testing-mindset should recognize this and not suggest redundant gap analysis. TDD drives test-first; test-driver drives test-after and gap-filling. They complement, not compete.

### gap-analysis (Methodology)

Activated when Claude decides (or is asked via `/test-driver:analyze`) to perform a gap analysis.

**Step 1 — Detect project type.** Scan for marker files:

| Marker File(s) | Profile |
|----------------|---------|
| `pyproject.toml` with `fastapi` or `starlette` in deps | `python-fastapi` |
| `pyproject.toml` with `PySide6` or `PyQt6` in deps | `python-pyside6` |
| `pyproject.toml` with `django` in deps | `python-django` |
| `manifest.json` with `"domain"` key + `custom_components/` dir | `home-assistant` |
| `Package.swift` or `*.xcodeproj` | `swift-swiftui` |
| `pyproject.toml` with no framework match | generic Python fallback |
| No marker found | ask user which profile to use |

**No profile match:** When detection fails or the matching profile doesn't exist as a skill:
> "No stack profile matches this project. I can run a basic gap analysis using generic conventions, but results will be more accurate with a dedicated profile. Want me to create a `profiles/<stack-name>/SKILL.md` for this project type?"

If the user agrees, Claude inspects the project's test toolchain, drafts a profile answering the five standard questions (see Stack Profiles section), writes it, and proceeds.

**Partial match:** If a profile exists but doesn't cover something the project uses (e.g., `python-fastapi` loaded but the project also has Playwright browser tests), suggest updating the profile.

**Multi-framework projects:** Load one primary profile based on the dominant framework. If the project combines stacks (e.g., Django backend + PySide6 management tool), the primary profile covers the main application; Claude can manually consult additional profiles for secondary components when running scoped analysis on those directories.

**Step 2 — Determine applicable test categories** from the loaded stack profile.

**Step 3 — Inventory existing tests.** Glob for test files, categorize each by type based on naming/location conventions from the profile.

**Step 4 — Inventory source files.** Identify all non-test source files.

**Step 5 — Map coverage.** For each source file, which test categories cover it? Which have no corresponding tests?

**Step 6 — Identify gaps.** Source files/functions with missing test categories, prioritized by:
- Public API surface (highest priority)
- Complex logic (many branches, deep nesting)
- Recently changed files
- Error handling paths

**Step 7 — Output.** Structured gap report that feeds into the convergence loop.

### convergence-loop (Iteration Engine)

Activated when gap analysis has identified gaps and Claude begins generating tests.

**Loop phases:**

```
ANALYZE ── identify gaps from gap-analysis output
   │
GENERATE ── write tests for highest-priority gaps (batch of 3-5)
   │
RUN ─────── execute the test suite
   │
EVALUATE ── classify failures
   │   ├─ Test bug ────── fix the test, re-run
   │   ├─ Source bug:
   │   │   ├─ Simple (off-by-one, null check, typo, wrong return type) → fix autonomously
   │   │   └─ Behavioral (changes functionality, API contract, feature) → STOP, surface to user
   │   └─ All green ──── check exit criteria
   │
EXIT CHECK
   ├─ All generated tests pass? ─── no → back to EVALUATE
   ├─ Coverage target defined and not met? ─── generate more → back to GENERATE
   ├─ No more meaningful tests to write? ─── exit with report
   └─ Oscillation detected? ─── STOP, surface pattern to user
   │
REPORT ──── update TEST_STATUS.json, summarize to user
```

**Guardrails:**
- **Max iterations:** 10 generate-run-fix cycles before forced stop with status report.
- **Oscillation detection (P5):** If any test that was previously green turns red after a fix, that counts as a regression. Two regressions within the same convergence run = oscillation. Flag the pattern immediately, list the involved tests and fixes, and stop.
- **Bug fix boundary:** Autonomous fixes for: typos, off-by-one, missing null checks, wrong return types, incorrect comparisons. Stop and report for: changed function signatures, altered business logic, modified API contracts, removed/added features.
- **Batch size:** 3-5 tests per generate cycle. Smaller batches catch issues earlier.
- **Source modification tracking:** Every autonomous source fix is recorded in the report with the file, what changed, and which test caught it.

### test-status (Persistent State)

Governs reading and writing `docs/testing/TEST_STATUS.json`. This path is a convention default; projects without a `docs/` directory get it created on first analysis.

**Schema:**

```json
{
  "project": "project-name",
  "stack_profile": "python-fastapi",
  "last_analysis": {
    "date": "2026-03-16T14:30:00Z",
    "source_files_analyzed": 42,
    "gaps_found": 7,
    "gaps_filled": 5,
    "gaps_deferred": 2
  },
  "categories": {
    "unit": {
      "applicable": true,
      "test_count": 38,
      "passing": 38,
      "failing": 0
    },
    "integration": {
      "applicable": true,
      "test_count": 12,
      "passing": 11,
      "failing": 1
    },
    "e2e": {
      "applicable": true,
      "test_count": 4,
      "passing": 4,
      "failing": 0
    },
    "ui": {
      "applicable": false
    },
    "contract": {
      "applicable": true,
      "test_count": 0,
      "passing": 0,
      "failing": 0
    },
    "security": {
      "applicable": false
    }
  },
  "coverage": {
    "target_percent": 80,
    "current_percent": 74,
    "tool": "coverage.py"
  },
  "known_gaps": [
    {
      "file": "src/api/auth.py",
      "category": "integration",
      "description": "No test for token refresh with expired session",
      "priority": "high",
      "reason_deferred": null
    }
  ],
  "source_bugs_fixed": [
    {
      "date": "2026-03-16T14:35:00Z",
      "file": "src/api/auth.py",
      "description": "Off-by-one in token expiry check: used < instead of <=",
      "test_that_caught_it": "test_auth_token_expiry_boundary"
    }
  ],
  "history": [
    {
      "date": "2026-03-16T14:30:00Z",
      "action": "gap_analysis",
      "summary": "7 gaps found across unit and integration categories"
    }
  ]
}
```

**Behaviors:**
- **Session start:** If TEST_STATUS.json exists, read it to understand current posture before any work begins.
- **After gap analysis:** Update `last_analysis`, `categories`, `known_gaps`.
- **After convergence loop:** Update `categories`, `coverage`, `source_bugs_fixed`, append to `history`.
- **Create if missing:** First analysis on a new project creates the file and parent directory.
- **Deferred gaps:** Gaps are marked as deferred (with `reason_deferred`) in two cases: (1) the user declines the convergence loop after gap analysis — all unfilled gaps are recorded with reason "User deferred"; (2) the convergence loop exits at max iterations with unfilled gaps remaining — those are deferred with reason "Max iterations reached".

### test-design (Universal Principles)

Framework-agnostic test design knowledge. Activated alongside gap-analysis or when writing tests.

**Covers:**
- Test isolation: each test independent, no shared mutable state between tests
- Boundary testing: edge cases, empty inputs, max values, type boundaries, off-by-one
- Error path coverage: every exception/error return should have a test
- Arrange-Act-Assert structure
- Test naming: describe the scenario and expected outcome, not the implementation
- Mock boundaries: mock external services and I/O; use real internal components
- Meaningful assertions: assert specific expected values, not just "no exception thrown"

## Stack Profiles

Each profile is a lightweight skill answering five standard questions. Claude loads only the matching profile.

### Standard Questions

1. **Applicable test categories** — which of the six (unit, integration, e2e, UI, contract, security) apply
2. **Test discovery** — where tests live, naming conventions, how to find them
3. **Test execution** — commands to run each applicable category
4. **Coverage measurement** — tool and command to get coverage metrics
5. **UI testing approach** — which tool (Qt Pilot, Charlotte, XCUITest, N/A) and how to invoke it

### python-fastapi

- **Categories:** unit, integration, e2e, contract, security
- **Discovery:** `tests/` directory; files named `test_*.py`; categorized by directory (`tests/unit/`, `tests/integration/`, `tests/e2e/`) or by pytest markers
- **Execution:** `pytest tests/` (all), `pytest -m unit`, `pytest -m integration`, `pytest -m e2e`
- **Coverage:** `pytest --cov=src --cov-report=term-missing`
- **UI:** N/A (API only)
- **Delegates to:** `python-dev:python-testing-patterns` for pytest patterns
- **Key tools:** pytest, httpx.AsyncClient for async API testing, pytest-asyncio, coverage.py, respx or pytest-httpx for HTTP mocking

### python-pyside6

- **Categories:** unit, integration, e2e, UI
- **Discovery:** `tests/` directory; widget tests in `tests/ui/` or marked with `@pytest.mark.ui`
- **Execution:** `pytest tests/`, `pytest -m ui` (requires display or Xvfb)
- **Coverage:** `pytest --cov=src --cov-report=term-missing`
- **UI:** Qt Pilot via Xvfb for headless GUI testing; `pytest-qt` for widget unit tests
- **Delegates to:** `qt-suite:qtest-patterns`, `qt-suite:qt-pilot-usage`
- **Key tools:** pytest, pytest-qt (qtbot fixture), Qt Pilot MCP, Xvfb, coverage.py

### python-django

- **Categories:** unit, integration, e2e, contract, security
- **Discovery:** `tests/` in each app or top-level `tests/`; files named `test_*.py`
- **Execution:** `pytest` (with pytest-django) or `python manage.py test`
- **Coverage:** `pytest --cov --cov-report=term-missing`
- **UI:** Charlotte or Playwright for browser-based testing (when frontend exists)
- **Delegates to:** `python-dev:python-testing-patterns`
- **Key tools:** pytest, pytest-django, Django test client, factory_boy, coverage.py

### home-assistant

- **Categories:** unit, integration
- **Discovery:** `tests/` mirroring `custom_components/<integration>/` structure
- **Execution:** `pytest tests/`
- **Coverage:** `pytest --cov=custom_components --cov-report=term-missing`
- **UI:** N/A (HA frontend is a separate concern)
- **Delegates to:** `home-assistant-dev:ha-testing`
- **Key tools:** pytest, pytest-homeassistant-custom-component (hass fixture), AsyncMock, aiohttp test utilities

### swift-swiftui

- **Categories:** unit, integration, UI
- **Discovery:** `Tests/` directory (SPM) or test targets in Xcode project
- **Execution:** `swift test` (SPM) or `xcodebuild test -scheme <scheme> -destination 'platform=iOS Simulator,name=iPhone 16'`
- **Coverage:** `swift test --enable-code-coverage` with `llvm-cov` export, or Xcode coverage reports
- **UI:** XCUITest for UI automation
- **Delegates to:** none (self-contained; no existing Swift testing plugin). If a Swift testing plugin is added in the future, this profile should be updated to delegate framework specifics.
- **Key tools:** XCTest, XCUITest, swift-testing (Swift 5.9+), Swift Package Manager

### Adding New Profiles

Adding a stack requires one file: `skills/profiles/<stack-name>/SKILL.md` answering the five standard questions. No changes to core skills needed. Gap analysis discovers profiles by scanning the profiles/ directory skill descriptions.

## Commands

### /test-driver:analyze

**Purpose:** Force a full gap analysis on the current project.

**Argument:** Optional path to narrow scope (directory or file). Without arguments, analyzes the entire project.

**Flow:**
1. Detect project type, load stack profile (or suggest creating one if missing)
2. Read `TEST_STATUS.json` if it exists (prior state)
3. Run full gap-analysis methodology
4. If gaps found, ask: "Found N gaps. Run convergence loop to fill them?"
   - Yes: enter convergence loop
   - No: update TEST_STATUS.json with gap inventory, done
5. Report summary

### /test-driver:status

**Purpose:** View current test posture without running anything.

**Argument:** None.

**Flow:**
1. Read `docs/testing/TEST_STATUS.json`
2. If missing: "No test status file found. Run `/test-driver:analyze` to create one."
3. If present, render compact summary:
   - Last analysis date and what changed since
   - Category breakdown (pass/fail counts)
   - Coverage percentage vs target
   - Top known gaps by priority
   - Source bugs fixed in last loop
4. End with: "Run `/test-driver:analyze` to refresh."

## Cross-Plugin Interaction

### Delegation Map

```
test-driver (drives WHEN and WHAT)
│
├── testing-mindset ──→ triggers at natural breakpoints
├── gap-analysis ─────→ identifies what's missing
├── convergence-loop ─→ iterates until green
│
└── delegates HOW to:
    ├── python-dev:python-testing-patterns
    ├── qt-suite:qtest-patterns
    ├── qt-suite:qt-pilot-usage
    ├── home-assistant-dev:ha-testing
    ├── superpowers:test-driven-development  (coexistence: TDD = test-first, test-driver = test-after)
    └── superpowers:verification-before-completion  (testing-mindset defers to this at commit/merge boundaries)
```

### Interaction Rules

1. **No duplication.** test-driver never restates framework-specific patterns. It identifies *that a parametrized fixture is the right tool for this gap*, then lets the existing skill guide implementation.

2. **Graceful degradation.** If a delegated plugin isn't installed, test-driver still works. Claude uses general knowledge instead of framework-specific skill guidance. Profiles note which plugins enhance the experience but don't require them.

3. **opus-context alignment.** test-driver respects all deep-context rules: read source files fully (no offset/limit under 4000 lines), read test files in parallel batches, keep everything in the main context window. No subagent delegation.

4. **superpowers coexistence.** TDD skill drives test-first; test-driver drives test-after and gap-filling. testing-mindset recognizes when TDD is active and doesn't suggest redundant gap analysis.

## What test-driver Does NOT Do

- **Run CI pipelines.** Tests run locally via the stack profile's commands.
- **Manage test infrastructure.** No Docker containers, test databases, or service dependencies. Assumes the dev environment can run tests.
- **Replace TDD.** test-driver is gap-analysis-driven (test-after). Defers to superpowers:test-driven-development for test-first workflows.
- **Generate test fixtures/data.** Generates test cases. Data factories and shared setup belong to framework-specific plugins.

## Test Categories

Six categories, with applicability determined by the stack profile:

| Category | Scope | Always/Profile |
|----------|-------|----------------|
| **Unit** | Single function/class, mocked dependencies | Always applicable |
| **Integration** | Multiple components, real dependencies | Always applicable |
| **E2E** | Full system flow, entry to exit | Profile-determined |
| **UI** | Visual interaction via Qt Pilot/Charlotte/XCUITest | Profile-determined |
| **Contract** | API schema validation, request/response shapes | Profile-determined |
| **Security** | Injection, auth bypass, secrets exposure | Profile-determined |

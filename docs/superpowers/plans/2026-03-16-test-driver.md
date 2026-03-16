# test-driver Plugin Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the test-driver plugin that teaches Claude to proactively drive thorough testing via gap analysis, convergence loops, and persistent status tracking.

**Architecture:** Skills-heavy plugin with no agents, no hooks, no MCP server. Six core skills define testing behavior, five stack profile skills map project types to toolchains, and two commands provide explicit entry points. Everything runs inline in the main context window, aligned with opus-context.

**Tech Stack:** Markdown (YAML frontmatter for skills/commands), JSON (plugin.json, marketplace entry, TEST_STATUS.json schema)

---

## File Structure

| File | Responsibility |
|------|---------------|
| `.claude-plugin/plugin.json` | Plugin identity and version |
| `skills/testing-mindset/SKILL.md` | Always-on behavioral driver: when to suggest testing |
| `skills/gap-analysis/SKILL.md` | Methodology for finding missing tests across categories |
| `skills/convergence-loop/SKILL.md` | Generate/run/fix/verify iteration with exit criteria |
| `skills/test-status/SKILL.md` | Read/write docs/testing/TEST_STATUS.json schema and rules |
| `skills/test-design/SKILL.md` | Universal test design principles (framework-agnostic) |
| `skills/profiles/python-fastapi/SKILL.md` | pytest + httpx + coverage.py profile |
| `skills/profiles/python-pyside6/SKILL.md` | pytest-qt + Qt Pilot + coverage.py profile |
| `skills/profiles/python-django/SKILL.md` | Django test client + factory_boy + coverage.py profile |
| `skills/profiles/home-assistant/SKILL.md` | hass fixture + AsyncMock profile |
| `skills/profiles/swift-swiftui/SKILL.md` | XCTest + XCUITest profile |
| `commands/analyze.md` | /test-driver:analyze command |
| `commands/status.md` | /test-driver:status command |
| `CHANGELOG.md` | Keep a Changelog format |
| `README.md` | From plugin-readme-template.md |

Marketplace entry added to: `../../.claude-plugin/marketplace.json`

---

## Chunk 1: Plugin Scaffold and Core Behavioral Skills

### Task 1: Create plugin.json

**Files:**
- Create: `plugins/test-driver/.claude-plugin/plugin.json`

- [ ] **Step 1: Write plugin.json**

```json
{
  "name": "test-driver",
  "version": "0.1.0",
  "description": "Teaches Claude to proactively drive thorough testing via gap analysis, convergence loops, and persistent status tracking. Framework-agnostic core with stack-specific profiles.",
  "author": {
    "name": "L3DigitalNet",
    "url": "https://github.com/L3DigitalNet"
  }
}
```

- [ ] **Step 2: Validate plugin loads**

Run: `ls plugins/test-driver/.claude-plugin/plugin.json && python3 -c "import json; d=json.load(open('plugins/test-driver/.claude-plugin/plugin.json')); print(f\"{d['name']} v{d['version']}\")"`
Expected: `test-driver v0.1.0`

- [ ] **Step 3: Commit**

```bash
git add plugins/test-driver/.claude-plugin/plugin.json
git commit -m "feat(test-driver): scaffold plugin with plugin.json"
```

### Task 2: Write testing-mindset skill

The most important skill in the plugin. Always-on behavioral driver that teaches Claude when to suggest testing. Broad trigger words ensure it loads for any implementation task.

**Files:**
- Create: `plugins/test-driver/skills/testing-mindset/SKILL.md`

**Spec reference:** Design spec sections "testing-mindset (Always-On Behavioral Driver)" and "Cross-Plugin Interaction"

- [ ] **Step 1: Write the skill**

The SKILL.md must include:

**Frontmatter:**
- `name: testing-mindset`
- `description:` — broad trigger list matching spec (test, implement, feature, fix, bug, refactor, build, create, modify, change, add, update, debug, complete, finish, deploy, merge, PR, commit). Include a note that this is intentionally always-on.

**Body content (four behaviors from spec + scope boundary section):**

1. **Proactive Testing Moments** (spec behavior 1) — list of triggers: new function/class/module, behavior modified, bug fixed (regression test), feature completed (full sweep), pre-commit/pre-merge (final check). Frame each as a question Claude asks itself.

2. **Assessment Heuristic** (spec behavior 2) — before suggesting gap analysis, check: (a) source files changed since last analysis per TEST_STATUS.json, (b) natural breakpoint reached, (c) source-to-test file change ratio imbalance. Suggested implementation: if 2+ checks pass, suggest analysis (this threshold is an implementation choice, not spec-mandated).

3. **Delegation Rules** (spec behavior 3) — when writing tests, consult the matching framework plugin. Map: Python → `python-dev:python-testing-patterns`, PySide6 → `qt-suite:qtest-patterns` + `qt-suite:qt-pilot-usage`, HA → `home-assistant-dev:ha-testing`. Note graceful degradation if plugin not installed.

4. **Cadence Rules** (spec behavior 4 + coexistence section) — don't suggest after every edit. Note changes silently. Surface at natural breakpoints. If user declines, wait for next breakpoint. Never suggest during active TDD flow (coexistence with `superpowers:test-driven-development`).

5. **Scope Boundaries** (from spec "What test-driver Does NOT Do") — does not run tests, does not write tests, does not manage test infrastructure. It only drives awareness and timing.

- [ ] **Step 2: Validate skill appears in plugin**

Run: `ls plugins/test-driver/skills/testing-mindset/SKILL.md && head -3 plugins/test-driver/skills/testing-mindset/SKILL.md`
Expected: File exists, frontmatter starts with `---` and `name: testing-mindset`.

- [ ] **Step 3: Commit**

```bash
git add plugins/test-driver/skills/testing-mindset/SKILL.md
git commit -m "feat(test-driver): add testing-mindset always-on behavioral skill"
```

### Task 3: Write gap-analysis skill

Methodology skill for conducting gap analysis across test categories. Activated when Claude decides or is asked to analyze.

**Files:**
- Create: `plugins/test-driver/skills/gap-analysis/SKILL.md`

**Spec reference:** Design spec section "gap-analysis (Methodology)"

- [ ] **Step 1: Write the skill**

**Frontmatter:**
- `name: gap-analysis`
- `description:` — triggered by: gap analysis, test gaps, missing tests, test coverage audit, untested code, test inventory. Mention it provides the methodology for finding missing tests across six categories.

**Body content (seven steps matching spec):**

1. **Detect Project Type** — marker file detection table from spec. Include the full table: pyproject.toml + fastapi → python-fastapi, pyproject.toml + PySide6 → python-pyside6, etc. Include the three fallback behaviors with their user-facing prompt text: no profile match (quote the suggestion prompt from spec), partial match (suggest updating), multi-framework (primary profile + scoped consultation).

2. **Determine Applicable Categories** — load from stack profile. List the six categories (unit, integration, e2e, UI, contract, security) and note which are always-applicable vs profile-determined.

3. **Inventory Existing Tests** — Glob patterns for test files. Categorize by directory structure or pytest markers per profile conventions.

4. **Inventory Source Files** — find all non-test source files. Exclude common non-source patterns (migrations, generated files, configs, __pycache__).

5. **Map Coverage** — for each source file, check which test categories have corresponding tests. Note: this is structural mapping (test file exists), not runtime coverage (line-level).

6. **Identify and Prioritize Gaps** — priority order from spec: public API surface > complex logic > recently changed > error paths. Produce a prioritized list of gaps (file, category, description, priority).

7. **Output Format** — define the structured gap report that feeds into convergence-loop. This is the final output of the skill. Include an example report showing 3-4 gaps formatted as a structured list that the convergence-loop skill can consume.

- [ ] **Step 2: Validate skill appears**

Run: `ls plugins/test-driver/skills/gap-analysis/SKILL.md && head -3 plugins/test-driver/skills/gap-analysis/SKILL.md`
Expected: File exists, frontmatter starts with `name: gap-analysis`.

- [ ] **Step 3: Commit**

```bash
git add plugins/test-driver/skills/gap-analysis/SKILL.md
git commit -m "feat(test-driver): add gap-analysis methodology skill"
```

### Task 4: Write convergence-loop skill

Defines the generate/run/fix/verify iteration engine with exit criteria and guardrails.

**Files:**
- Create: `plugins/test-driver/skills/convergence-loop/SKILL.md`

**Spec reference:** Design spec section "convergence-loop (Iteration Engine)"

- [ ] **Step 1: Write the skill**

**Frontmatter:**
- `name: convergence-loop`
- `description:` — triggered by: convergence loop, test loop, generate and fix tests, iterate tests, fill test gaps, run tests until green. The iterative generate/run/fix/verify engine for filling test gaps.

**Body content:**

1. **Loop Phases Diagram** — include the ASCII flow diagram from the spec (ANALYZE → GENERATE → RUN → EVALUATE → EXIT CHECK → REPORT).

2. **Phase Details:**
   - ANALYZE: read gap report from gap-analysis, prioritize by severity
   - GENERATE: write 3-5 tests per batch targeting highest-priority gaps. Consult test-design skill for principles. Consult stack profile for framework conventions.
   - RUN: execute tests using the command from the stack profile
   - EVALUATE: classify each failure as test bug, simple source bug, or behavioral source bug

3. **Bug Fix Boundary** — explicit list from spec. Autonomous: typos, off-by-one, missing null checks, wrong return types, incorrect comparisons. Stop and surface: changed function signatures, altered business logic, modified API contracts, removed/added features.

4. **Exit Criteria:**
   - All generated tests pass → check coverage target
   - Coverage target met (or no target defined) → exit with report
   - No more meaningful tests to write → exit with report
   - Oscillation detected → stop immediately
   - Max 10 iterations → forced stop

5. **Oscillation Detection** — concrete heuristic from spec: any previously-green test turning red after a fix = regression. Two regressions in same run = oscillation. List involved tests and fixes, then stop.

6. **Reporting** — after loop exits, update TEST_STATUS.json (defer to test-status skill for schema). Summarize: tests generated, tests passing, source bugs fixed, gaps remaining, iterations used.

- [ ] **Step 2: Validate skill appears**

Run: `ls plugins/test-driver/skills/convergence-loop/SKILL.md && head -3 plugins/test-driver/skills/convergence-loop/SKILL.md`
Expected: File exists, frontmatter starts with `name: convergence-loop`.

- [ ] **Step 3: Commit**

```bash
git add plugins/test-driver/skills/convergence-loop/SKILL.md
git commit -m "feat(test-driver): add convergence-loop iteration engine skill"
```

### Task 5: Write test-status skill

Governs the persistent TEST_STATUS.json file schema and update rules.

**Files:**
- Create: `plugins/test-driver/skills/test-status/SKILL.md`

**Spec reference:** Design spec section "test-status (Persistent State)"

- [ ] **Step 1: Write the skill**

**Frontmatter:**
- `name: test-status`
- `description:` — triggered by: test status, TEST_STATUS.json, test posture, testing state, test report, test history. Governs reading and writing the persistent test status file.

**Body content:**

1. **File Location** — `docs/testing/TEST_STATUS.json`. Convention default; created on first analysis if missing (including parent directory).

2. **Full JSON Schema** — include the complete schema from spec with all fields: project, stack_profile, last_analysis, categories (all six), coverage, known_gaps, source_bugs_fixed, history.

3. **Update Rules** — four behaviors from spec:
   - Session start: read if exists to understand posture
   - After gap analysis: update last_analysis, categories, known_gaps
   - After convergence loop: update categories, coverage, source_bugs_fixed, append to history
   - Create if missing: first analysis creates file + parent dir

4. **Deferred Gaps** — when reason_deferred gets set: (a) user declines convergence loop → "User deferred", (b) max iterations reached → "Max iterations reached".

5. **Reading the File** — when Claude reads TEST_STATUS.json at session start, it should note: last analysis date, how many gaps exist, current coverage, any failing tests. Use this to calibrate whether testing is needed during the session.

- [ ] **Step 2: Validate skill appears**

Run: `ls plugins/test-driver/skills/test-status/SKILL.md && head -3 plugins/test-driver/skills/test-status/SKILL.md`
Expected: File exists, frontmatter starts with `name: test-status`.

- [ ] **Step 3: Commit**

```bash
git add plugins/test-driver/skills/test-status/SKILL.md
git commit -m "feat(test-driver): add test-status persistent state skill"
```

### Task 6: Write test-design skill

Universal test design principles that apply regardless of framework. Consult official testing documentation (pytest docs, XCTest docs) for accuracy.

**Files:**
- Create: `plugins/test-driver/skills/test-design/SKILL.md`

**Spec reference:** Design spec section "test-design (Universal Principles)"

- [ ] **Step 1: Write the skill**

Note: Consult official documentation (pytest docs, XCTest docs) via Context7 MCP or web search as needed while writing to verify current best practices.

**Frontmatter:**
- `name: test-design`
- `description:` — triggered by: test design, writing tests, test quality, test principles, test structure, test patterns, good tests. Universal test design principles for writing effective tests regardless of framework.

**Body content (seven principles from spec, expanded with practical guidance):**

1. **Test Isolation** — each test independent, no shared mutable state. Explain: use fixtures for setup, avoid class-level state, avoid test ordering dependencies. Anti-pattern: test B depends on state created by test A.

2. **Boundary Testing** — edge cases, empty inputs, max values, type boundaries, off-by-one. Include a checklist: for each function parameter, test the zero/empty case, the boundary case, one past boundary, and typical case.

3. **Error Path Coverage** — every exception/error return should have a test. Rule: if a function has N error paths, there should be at least N error tests. Include: test that the right exception type is raised, test that the error message is useful.

4. **Arrange-Act-Assert** — three-phase structure. Keep each phase visually distinct. One act per test. Multiple asserts OK if they verify the same behavior.

5. **Test Naming** — describe the scenario and expected outcome: `test_<unit>_<scenario>_<expected>`. Anti-pattern: `test_1`, `test_user`, `test_function`. The test name should read as a specification.

6. **Mock Boundaries** — mock external services and I/O; use real internal components. Rule of thumb: if you control the code, don't mock it. If it touches the network, filesystem, or clock, mock it.

7. **Meaningful Assertions** — assert specific expected values, not just "didn't crash" or "returned something truthy." Anti-pattern: `assert result` (only checks truthiness). Better: `assert result == expected_value`.

- [ ] **Step 2: Validate skill appears**

Run: `ls plugins/test-driver/skills/test-design/SKILL.md && head -3 plugins/test-driver/skills/test-design/SKILL.md`
Expected: File exists, frontmatter starts with `name: test-design`.

- [ ] **Step 3: Commit**

```bash
git add plugins/test-driver/skills/test-design/SKILL.md
git commit -m "feat(test-driver): add test-design universal principles skill"
```

---

## Chunk 2: Stack Profile Skills

### Task 7: Write python-fastapi profile

**Files:**
- Create: `plugins/test-driver/skills/profiles/python-fastapi/SKILL.md`

**Spec reference:** Design spec section "python-fastapi" under Stack Profiles

- [ ] **Step 1: Consult official documentation**

Use Context7 MCP to look up current:
- FastAPI testing docs (TestClient, httpx.AsyncClient patterns)
- pytest-asyncio configuration
- coverage.py configuration for FastAPI projects
- respx or pytest-httpx for mocking HTTP

- [ ] **Step 2: Write the profile skill**

**Frontmatter:**
- `name: python-fastapi`
- `description:` — Stack profile for FastAPI/Starlette projects. Triggered when test-driver detects fastapi or starlette in pyproject.toml dependencies. Defines test categories, discovery, execution, and coverage for FastAPI.

**Body — five standard questions:**

1. **Applicable Categories:** unit, integration, e2e, contract, security

2. **Test Discovery:**
   - Location: `tests/` directory
   - Naming: `test_*.py`
   - Categorization: by directory (`tests/unit/`, `tests/integration/`, `tests/e2e/`) or by pytest markers (`@pytest.mark.unit`, `@pytest.mark.integration`, `@pytest.mark.e2e`)
   - Contract tests: `tests/contract/` or `@pytest.mark.contract`
   - Security tests: `tests/security/` or `@pytest.mark.security`

3. **Test Execution:**
   - All: `pytest tests/`
   - By category: `pytest -m unit`, `pytest -m integration`, `pytest -m e2e`
   - Single file: `pytest tests/test_specific.py -v`

4. **Coverage:**
   - Tool: coverage.py via pytest-cov
   - Command: `pytest --cov=<package> --cov-report=term-missing --cov-branch`
   - Config: `[tool.coverage.run]` in pyproject.toml

5. **UI Testing:** N/A (API-only projects)

**Additional sections:**
- **Key Testing Patterns:** httpx.AsyncClient for async endpoint testing, TestClient for sync, respx for HTTP mocking, dependency overrides for DI testing
- **Delegates to:** `python-dev:python-testing-patterns` for pytest patterns (graceful if not installed)
- **Example conftest.py** showing app fixture and async client fixture

- [ ] **Step 3: Validate skill appears**

Run: `ls plugins/test-driver/skills/profiles/python-fastapi/SKILL.md && head -3 plugins/test-driver/skills/profiles/python-fastapi/SKILL.md`
Expected: File exists, frontmatter starts with `name: python-fastapi`.

- [ ] **Step 4: Commit**

```bash
git add plugins/test-driver/skills/profiles/python-fastapi/SKILL.md
git commit -m "feat(test-driver): add python-fastapi stack profile"
```

### Task 8: Write python-pyside6 profile

**Files:**
- Create: `plugins/test-driver/skills/profiles/python-pyside6/SKILL.md`

**Spec reference:** Design spec section "python-pyside6"

- [ ] **Step 1: Consult official documentation**

Look up current:
- pytest-qt documentation (qtbot fixture, waitSignal, addWidget)
- PySide6 testing patterns
- Qt Pilot MCP tool usage for headless GUI testing
- Xvfb setup for headless Qt testing

- [ ] **Step 2: Write the profile skill**

**Frontmatter:**
- `name: python-pyside6`
- `description:` — Stack profile for PySide6/PyQt6 desktop applications. Triggered when test-driver detects PySide6 or PyQt6 in pyproject.toml dependencies. Defines test categories including UI testing via Qt Pilot.

**Body — five standard questions:**

1. **Applicable Categories:** unit, integration, e2e, UI

2. **Test Discovery:**
   - Location: `tests/` directory
   - Widget/UI tests: `tests/ui/` or `@pytest.mark.ui`
   - Unit tests: `tests/unit/` or `@pytest.mark.unit`
   - Naming: `test_*.py`

3. **Test Execution:**
   - All: `QT_QPA_PLATFORM=offscreen pytest tests/`
   - UI only: `pytest -m ui` (requires Xvfb or `QT_QPA_PLATFORM=offscreen`)
   - Non-UI: `pytest -m "not ui"`

4. **Coverage:**
   - Tool: coverage.py via pytest-cov
   - Command: `pytest --cov=src --cov-report=term-missing`
   - Note: UI tests may need `QT_QPA_PLATFORM=offscreen` for headless coverage

5. **UI Testing:**
   - Tool: Qt Pilot MCP for headless GUI testing, pytest-qt for widget unit tests
   - Headless setup: `Xvfb :99 -screen 0 1280x1024x24 &` then `DISPLAY=:99`
   - pytest-qt: `qtbot.addWidget()` for every widget created in tests, `qtbot.waitSignal()` for async signals

**Additional sections:**
- **Key Patterns:** qtbot fixture, QSignalSpy equivalent via waitSignal, offscreen platform for CI
- **Delegates to:** `qt-suite:qtest-patterns`, `qt-suite:qt-pilot-usage` (graceful if not installed)

- [ ] **Step 3: Validate skill appears**

Run: `ls plugins/test-driver/skills/profiles/python-pyside6/SKILL.md && head -3 plugins/test-driver/skills/profiles/python-pyside6/SKILL.md`
Expected: File exists, frontmatter starts with `name: python-pyside6`.

- [ ] **Step 4: Commit**

```bash
git add plugins/test-driver/skills/profiles/python-pyside6/SKILL.md
git commit -m "feat(test-driver): add python-pyside6 stack profile"
```

### Task 9: Write python-django profile

**Files:**
- Create: `plugins/test-driver/skills/profiles/python-django/SKILL.md`

**Spec reference:** Design spec section "python-django"

- [ ] **Step 1: Consult official documentation**

Look up current:
- Django testing docs (TestCase, Client, TransactionTestCase)
- pytest-django configuration and fixtures
- factory_boy patterns for test data
- Django test database configuration

- [ ] **Step 2: Write the profile skill**

**Frontmatter:**
- `name: python-django`
- `description:` — Stack profile for Django web applications. Triggered when test-driver detects django in pyproject.toml dependencies. Defines test categories, discovery, execution, and coverage for Django projects.

**Body — five standard questions:**

1. **Applicable Categories:** unit, integration, e2e, contract, security

2. **Test Discovery:**
   - Location: `tests/` in each app or top-level `tests/`
   - Naming: `test_*.py`
   - Django convention: `tests.py` in each app (simple) or `tests/` package (complex)

3. **Test Execution:**
   - pytest: `pytest` (with pytest-django and `DJANGO_SETTINGS_MODULE` set)
   - Django: `python manage.py test`
   - By app: `pytest <app>/tests/`

4. **Coverage:**
   - Tool: coverage.py via pytest-cov
   - Command: `pytest --cov --cov-report=term-missing`

5. **UI Testing:**
   - Tool: Charlotte or Playwright for browser-based testing (when frontend exists)
   - Django LiveServerTestCase for serving pages during browser tests
   - StaticLiveServerTestCase for static file serving

**Additional sections:**
- **Key Patterns:** Django test client for HTTP, factory_boy for model factories, TransactionTestCase for tests needing real transactions
- **Delegates to:** `python-dev:python-testing-patterns` (graceful if not installed)

- [ ] **Step 3: Validate skill appears**

Run: `ls plugins/test-driver/skills/profiles/python-django/SKILL.md && head -3 plugins/test-driver/skills/profiles/python-django/SKILL.md`
Expected: File exists, frontmatter starts with `name: python-django`.

- [ ] **Step 4: Commit**

```bash
git add plugins/test-driver/skills/profiles/python-django/SKILL.md
git commit -m "feat(test-driver): add python-django stack profile"
```

### Task 10: Write home-assistant profile

**Files:**
- Create: `plugins/test-driver/skills/profiles/home-assistant/SKILL.md`

**Spec reference:** Design spec section "home-assistant"

- [ ] **Step 1: Consult official documentation**

Look up current:
- Home Assistant testing guide for custom integrations
- pytest-homeassistant-custom-component fixture patterns
- hass fixture usage
- Config flow testing patterns

- [ ] **Step 2: Write the profile skill**

**Frontmatter:**
- `name: home-assistant`
- `description:` — Stack profile for Home Assistant custom integrations. Triggered when test-driver detects manifest.json with "domain" key and custom_components/ directory. Defines test categories for HA integrations.

**Body — five standard questions:**

1. **Applicable Categories:** unit, integration

2. **Test Discovery:**
   - Location: `tests/` mirroring `custom_components/<integration>/` structure
   - Key files: `test_config_flow.py`, `test_init.py`, `test_sensor.py`, `test_coordinator.py`
   - conftest.py: shared fixtures for hass instance

3. **Test Execution:**
   - All: `pytest tests/`
   - Single: `pytest tests/test_config_flow.py -v`

4. **Coverage:**
   - Tool: coverage.py via pytest-cov
   - Command: `pytest --cov=custom_components --cov-report=term-missing`

5. **UI Testing:** N/A (HA frontend is separate)

**Additional sections:**
- **Key Patterns:** hass fixture, MockConfigEntry, AsyncMock for async coordinator, aiohttp test utilities
- **Minimum test requirements** per HA Integration Quality Scale: config flow tests (success, connection failure, auth failure)
- **Delegates to:** `home-assistant-dev:ha-testing` (graceful if not installed)

- [ ] **Step 3: Validate skill appears**

Run: `ls plugins/test-driver/skills/profiles/home-assistant/SKILL.md && head -3 plugins/test-driver/skills/profiles/home-assistant/SKILL.md`
Expected: File exists, frontmatter starts with `name: home-assistant`.

- [ ] **Step 4: Commit**

```bash
git add plugins/test-driver/skills/profiles/home-assistant/SKILL.md
git commit -m "feat(test-driver): add home-assistant stack profile"
```

### Task 11: Write swift-swiftui profile

**Files:**
- Create: `plugins/test-driver/skills/profiles/swift-swiftui/SKILL.md`

**Spec reference:** Design spec section "swift-swiftui"

- [ ] **Step 1: Consult official documentation**

Look up current:
- Apple XCTest documentation
- Swift Testing framework (swift-testing, Swift 5.9+)
- XCUITest for UI automation
- swift test --enable-code-coverage usage
- llvm-cov export for coverage reports

- [ ] **Step 2: Write the profile skill**

**Frontmatter:**
- `name: swift-swiftui`
- `description:` — Stack profile for Swift/SwiftUI iOS and macOS applications. Triggered when test-driver detects Package.swift or .xcodeproj. Defines test categories including XCUITest for UI automation.

**Body — five standard questions:**

1. **Applicable Categories:** unit, integration, UI

2. **Test Discovery:**
   - SPM: `Tests/` directory, test targets in Package.swift
   - Xcode: test targets in .xcodeproj
   - Naming: `*Tests.swift` containing `XCTestCase` subclasses

3. **Test Execution:**
   - SPM: `swift test`
   - Xcode: `xcodebuild test -scheme <scheme> -destination 'platform=iOS Simulator,name=iPhone 16'`
   - Single test: `swift test --filter <TestClass>/<testMethod>`

4. **Coverage:**
   - SPM: `swift test --enable-code-coverage` then `llvm-cov export .build/debug/<package>.xctest`
   - Xcode: built-in coverage reports in Xcode organizer
   - `xcrun llvm-cov report` for command-line summary

5. **UI Testing:**
   - Tool: XCUITest
   - Launch: `let app = XCUIApplication(); app.launch()`
   - Queries: `app.buttons["Save"]`, `app.textFields["Username"]`
   - Assertions: `XCTAssertTrue(app.staticTexts["Welcome"].exists)`

**Additional sections:**
- **Key Patterns:** XCTestCase for unit tests, XCUIApplication for UI tests, swift-testing @Test macro (Swift 5.9+)
- **Delegates to:** none (self-contained). Note: if a Swift testing plugin is added, update this profile to delegate.

- [ ] **Step 3: Validate skill appears**

Run: `ls plugins/test-driver/skills/profiles/swift-swiftui/SKILL.md && head -3 plugins/test-driver/skills/profiles/swift-swiftui/SKILL.md`
Expected: File exists, frontmatter starts with `name: swift-swiftui`.

- [ ] **Step 4: Commit**

```bash
git add plugins/test-driver/skills/profiles/swift-swiftui/SKILL.md
git commit -m "feat(test-driver): add swift-swiftui stack profile"
```

---

## Chunk 3: Commands, Marketplace, README, and CHANGELOG

### Task 12: Write analyze command

**Files:**
- Create: `plugins/test-driver/commands/analyze.md`

**Spec reference:** Design spec section "/test-driver:analyze"

- [ ] **Step 1: Write the command**

**Frontmatter:**
- `name: analyze`
- `description:` — Force a full gap analysis on the current project. Detects project type, loads stack profile, inventories source and test files, identifies gaps, and optionally enters a convergence loop to fill them.
- `argument-hint: "[optional: path to scope analysis]"`
- `allowed-tools:` — Read, Write, Edit, Bash, Glob, Grep, AskUserQuestion

**Body — five steps from spec:**

1. **Detect and Load Profile** — run the gap-analysis skill's Step 1. If argument provided, scope to that directory. Note: consult the `gap-analysis` skill for full methodology.

2. **Read Prior State** — if `docs/testing/TEST_STATUS.json` exists, read it. Note last analysis date, known gaps, current coverage. Consult `test-status` skill for schema.

3. **Run Gap Analysis** — follow the full gap-analysis methodology. Consult `gap-analysis` skill. Read source files fully (opus-context: no offset/limit under 4000 lines). Read test files in parallel batches.

4. **Present Results and Offer Convergence** — if gaps found, present structured summary then ask via AskUserQuestion:
   - "Yes, fill all gaps" → enter convergence-loop
   - "Yes, but only for specific files" → follow up with another AskUserQuestion listing the gap files as options, then enter convergence-loop scoped to selection
   - "No, just record the gaps" → update TEST_STATUS.json with gap inventory, done

5. **Report** — compact summary: gaps found, categories affected, coverage status. Update TEST_STATUS.json per test-status skill rules.

- [ ] **Step 2: Validate command appears**

Run: `ls plugins/test-driver/commands/analyze.md && head -3 plugins/test-driver/commands/analyze.md`
Expected: File exists, frontmatter starts with `name: analyze`.

- [ ] **Step 3: Commit**

```bash
git add plugins/test-driver/commands/analyze.md
git commit -m "feat(test-driver): add /test-driver:analyze command"
```

### Task 13: Write status command

**Files:**
- Create: `plugins/test-driver/commands/status.md`

**Spec reference:** Design spec section "/test-driver:status"

- [ ] **Step 1: Write the command**

**Frontmatter:**
- `name: status`
- `description:` — View current test posture from TEST_STATUS.json without running any tests or analysis.
- `allowed-tools:` — Read, Glob, Bash

**Body — four steps from spec:**

1. **Read Status File** — read `docs/testing/TEST_STATUS.json`. If missing, report: "No test status file found. Run `/test-driver:analyze` to create one." and stop.

2. **Render Summary** — compact markdown table:
   - Last analysis: date, files analyzed, gaps found/filled/deferred
   - Categories: table with applicable, test count, passing, failing per category
   - Coverage: current vs target percentage
   - Top 3 known gaps by priority
   - Source bugs fixed in last convergence loop (if any)

3. **Staleness Check** — use `git log --since="<last_analysis_date>" --oneline -- "*.py" "*.swift"` (via Bash) to check for source changes since last analysis. If last analysis is more than 7 days old or significant source changes exist, note: "Status may be stale. Consider running `/test-driver:analyze` to refresh."

4. **End** — "Run `/test-driver:analyze` to refresh."

- [ ] **Step 2: Validate command appears**

Run: `ls plugins/test-driver/commands/status.md && head -3 plugins/test-driver/commands/status.md`
Expected: File exists, frontmatter starts with `name: status`.

- [ ] **Step 3: Commit**

```bash
git add plugins/test-driver/commands/status.md
git commit -m "feat(test-driver): add /test-driver:status command"
```

### Task 14: Add marketplace entry

**Files:**
- Modify: `.claude-plugin/marketplace.json`

- [ ] **Step 1: Read current marketplace.json**

Read the file to find the `plugins` array and identify the correct insertion point (alphabetical by name).

- [ ] **Step 2: Add test-driver entry**

Add to the `plugins` array:

```json
{
  "name": "test-driver",
  "description": "Teaches Claude to proactively drive thorough testing via gap analysis, convergence loops, and persistent status tracking. Framework-agnostic core with stack-specific profiles.",
  "version": "0.1.0",
  "author": {
    "name": "L3DigitalNet",
    "url": "https://github.com/L3DigitalNet"
  },
  "category": "testing",
  "source": "./plugins/test-driver",
  "homepage": "https://github.com/L3DigitalNet/Claude-Code-Plugins/tree/main/plugins/test-driver"
}
```

- [ ] **Step 3: Validate marketplace**

Run: `./scripts/validate-marketplace.sh`
Expected: Validation passes with no errors.

- [ ] **Step 4: Commit**

```bash
git add .claude-plugin/marketplace.json
git commit -m "feat(test-driver): add marketplace entry"
```

### Task 15: Write CHANGELOG.md

**Files:**
- Create: `plugins/test-driver/CHANGELOG.md`

- [ ] **Step 1: Write changelog**

```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [0.1.0] - YYYY-MM-DD  <!-- use actual implementation date -->

### Added

- testing-mindset skill: always-on behavioral driver for proactive testing suggestions
- gap-analysis skill: methodology for finding missing tests across six categories
- convergence-loop skill: generate/run/fix/verify iteration engine with oscillation detection
- test-status skill: persistent TEST_STATUS.json state management
- test-design skill: universal test design principles (isolation, boundaries, error paths)
- Stack profiles: python-fastapi, python-pyside6, python-django, home-assistant, swift-swiftui
- /test-driver:analyze command for forced gap analysis with optional convergence loop
- /test-driver:status command for viewing current test posture
```

- [ ] **Step 2: Commit**

```bash
git add plugins/test-driver/CHANGELOG.md
git commit -m "docs(test-driver): add CHANGELOG.md"
```

### Task 16: Write README.md

**Files:**
- Create: `plugins/test-driver/README.md`

**Reference:** `docs/plugin-readme-template.md` for structure. `plugins/opus-context/README.md` for tone and style.

- [ ] **Step 1: Write README**

Follow the template structure:

1. **Title + one-liner:** "Teaches Claude to proactively drive thorough testing across any project type via gap analysis, convergence loops, and persistent status tracking."

2. **Summary:** 2-4 sentences. The problem: Claude doesn't systematically think about testing unless asked. This plugin installs an always-on testing mindset that suggests gap analysis at natural breakpoints, runs convergence loops to fill gaps, and tracks test posture in a persistent JSON file across sessions.

3. **Principles:**
   - [P1] Test at Breakpoints, Not Every Edit: Surface testing at natural breakpoints (feature done, bug fixed, pre-merge), never after individual edits.
   - [P2] Inline Over Delegated: All analysis and test generation happens in the main context window for maximum code awareness. No agent delegation.
   - [P3] Converge, Don't Repeat: The convergence loop drives toward all-green with oscillation detection, not blind retry.
   - [P4] Profile-Driven Stack Knowledge: Framework-specific testing knowledge lives in lightweight profiles, not hardcoded in core skills.

4. **Requirements:** None beyond Claude Code. Enhanced by: python-dev plugin (pytest patterns), qt-suite plugin (Qt testing), home-assistant-dev plugin (HA testing).

5. **Installation:** Standard marketplace install block.

6. **How It Works:** Mermaid flowchart showing: Task received → testing-mindset evaluates → natural breakpoint? → yes → gap-analysis scans project → gaps found? → yes → user confirms → convergence-loop iterates → TEST_STATUS.json updated.

7. **Usage:** Two entry points: always-on skill (automatic) and explicit commands. Show `/test-driver:analyze` and `/test-driver:status` examples.

8. **Commands table:** analyze, status with descriptions.

9. **Skills table:** all 11 skills with "Loaded when" descriptions.

10. **Design Decisions:**
    - No agents: aligned with opus-context; testing benefits from full project context
    - No hooks: behavioral skill handles proactive triggers without mechanical file counting
    - Delegates framework knowledge: avoids duplicating python-dev, qt-suite, HA testing patterns

11. **Planned Features:**
    - Additional stack profiles (Rust, Go, TypeScript/Node)
    - PreCompact hook to save test analysis state before context compaction

12. **Known Issues:**
    - Profile detection relies on pyproject.toml dependency names; custom setups may need manual profile selection
    - Coverage metrics require the project's coverage toolchain to be installed and configured

13. **Links:** Standard links block.

- [ ] **Step 2: Commit**

```bash
git add plugins/test-driver/README.md
git commit -m "docs(test-driver): add README.md"
```

### Task 17: Final validation

- [ ] **Step 1: Validate full plugin structure**

Run: `find plugins/test-driver -type f | sort`
Expected: All 15 files present matching the file structure table.

- [ ] **Step 2: Validate marketplace**

Run: `./scripts/validate-marketplace.sh`
Expected: Passes.

- [ ] **Step 3: Validate plugin loads**

Run: `find plugins/test-driver/skills -name SKILL.md | wc -l && find plugins/test-driver/commands -name "*.md" | wc -l`
Expected: 11 skills, 2 commands.

- [ ] **Step 4: Commit final state**

If any fixes were needed, stage only the specific changed files and commit:
```bash
git add plugins/test-driver/<specific-files-that-changed>
git commit -m "fix(test-driver): address validation issues"
```

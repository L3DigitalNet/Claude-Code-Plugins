---
name: Qt Coverage Workflow
description: >
  This skill should be used when the user asks about "coverage", "test coverage", "coverage gaps",
  "untested code", "gcov", "lcov", "coverage report", "improve coverage", "missing tests",
  "coverage threshold", "coverage-driven test generation", or "what code isn't tested".
  Covers the full coverage feedback loop for both Python/PySide6 (coverage.py) and C++/Qt (gcov + lcov).
  Also activates for "pytest-cov", "run coverage on my Qt project", or "CI coverage report".
---

# Qt Coverage Workflow

Coverage-driven test generation is a loop: **run tests with instrumentation → generate report → identify gaps → generate targeted tests → re-run to verify improvement**. This skill covers the full loop for both Python and C++ Qt projects.

## The Coverage Loop

```
run instrumented tests
        ↓
parse coverage report (gaps list)
        ↓
send gaps to Claude / test-generator agent
        ↓
generate targeted tests
        ↓
run tests again → verify delta
        ↓
repeat until threshold met
```

Use `/qt:coverage` to execute this loop. The `test-generator` agent activates automatically after `/qt:coverage` identifies gaps.

## Python Projects (coverage.py)

### Run with Coverage

```bash
# Install if needed
pip install coverage pytest-cov

# Run tests with coverage
coverage run -m pytest tests/
# or equivalently:
pytest --cov=myapp --cov-report=html tests/
```

### Generate Reports

```bash
# Terminal report (shows missing lines)
coverage report --show-missing

# HTML report (human-readable, browsable)
coverage html -d htmlcov/
# Open htmlcov/index.html in a browser

# XML for CI parsing
coverage xml -o coverage.xml
```

### Coverage Config (.coveragerc or pyproject.toml)

```ini
# .coveragerc
[run]
source = myapp
omit =
    tests/*
    */migrations/*

[report]
fail_under = 80
show_missing = true
```

```toml
# pyproject.toml
[tool.coverage.run]
source = ["myapp"]
omit = ["tests/*"]

[tool.coverage.report]
fail_under = 80
show_missing = true
```

### Reading Gap Output

`coverage report --show-missing` produces:

```
Name                    Stmts   Miss  Cover   Missing
calculator.py              24      6    75%   18-22, 45, 67
utils/formatter.py         12      4    67%   8-10, 30
```

- **Miss** — uncovered statement count
- **Missing** — specific line ranges not executed by any test
- Target these lines when generating new tests

### CI Integration: Python Coverage

See this skill's `templates/qt-coverage.yml` for the complete GitHub Actions workflow and `templates/run-coverage.sh` for a portable shell version. Both files live at `skills/qt-coverage-workflow/templates/` in the plugin.

Key CI step pattern:
```yaml
- name: Run coverage
  run: pytest --cov=myapp --cov-report=xml --cov-fail-under=80 tests/
```

## C++ Projects (gcov + lcov)

### Build with Coverage Instrumentation

Add to `CMakeLists.txt` or use a coverage preset:

```cmake
# CMakePresets.json or CMakeLists.txt
option(ENABLE_COVERAGE "Build with gcov coverage" OFF)

if(ENABLE_COVERAGE)
    add_compile_options(-O0 -g --coverage -fprofile-arcs -ftest-coverage)
    add_link_options(--coverage)
endif()
```

Build with coverage:
```bash
cmake -B build -DENABLE_COVERAGE=ON
cmake --build build
```

### Run Tests and Capture Coverage

```bash
# Run tests (generates .gcda files)
cd build && ctest --output-on-failure

# Capture coverage data
lcov --capture \
     --directory . \
     --output-file coverage.info \
     --no-external          # exclude system headers

# Remove test files from report (test coverage of tests is noise)
lcov --remove coverage.info \
     '*/tests/*' '*/moc_*' \
     --output-file coverage_filtered.info

# Generate HTML report
genhtml coverage_filtered.info \
        --output-directory htmlcov \
        --title "Qt Project Coverage"
```

### Reading lcov Output

```
Overall coverage rate:
  lines......: 72.4% (581 of 802 lines)
  functions..: 81.3% (65 of 80 functions)
```

HTML report shows file-by-file breakdown with red (uncovered) / green (covered) highlighting per line.

### Coverage Baseline and Delta Tracking

Save coverage percentage between runs to measure improvement:

```bash
COVERAGE=$(lcov --summary coverage_filtered.info 2>&1 | grep "lines" | grep -oP '\d+\.\d+%' | head -1)
echo "Coverage: ${COVERAGE}"
```

### CI Integration: C++ Coverage

```yaml
# .github/workflows/qt-coverage.yml excerpt
- name: Build with coverage
  run: |
    cmake -B build -DENABLE_COVERAGE=ON
    cmake --build build

- name: Run tests and capture coverage
  run: |
    cd build && ctest --output-on-failure
    lcov --capture --directory . --output-file coverage.info --no-external
    lcov --remove coverage.info '*/tests/*' --output-file coverage_filtered.info
    genhtml coverage_filtered.info --output-directory htmlcov

- name: Upload HTML report
  uses: actions/upload-artifact@v4
  with:
    name: coverage-report
    path: htmlcov/
```

See this skill's `templates/qt-coverage.yml` for the complete workflow and `templates/run-coverage.sh` for the portable shell script (both in `skills/qt-coverage-workflow/templates/`).

## Coverage Thresholds

Configure thresholds in `.qt-test.json`:

```json
{
  "coverage_threshold": 80,
  "coverage_exclude": ["tests/*", "*/migrations/*"]
}
```

| Threshold | When appropriate |
|---|---|
| 60–70% | Early-stage projects, rapid prototyping |
| 80% | General production code (recommended default) |
| 90%+ | Safety-critical components |
| 100% MC/DC | Aerospace/automotive (requires Coco) |

## Identifying High-Value Coverage Gaps

When analyzing gaps, prioritize:

1. **Business logic classes** — highest risk of regression
2. **Error paths** (exception handlers, validation failures) — often untested
3. **Complex conditionals** — branches with multiple conditions
4. **Public API methods** — surface area for other code to depend on
5. **Skip** test infrastructure, generated `moc_*` files, pure UI glue code

## Handoff to test-generator Agent

After identifying gaps, structure the handoff:

```
Gaps found in calculator.py: lines 18-22 (divide by zero path), line 45 (overflow check)
Gaps found in formatter.py: lines 8-10 (empty string handling)
Current coverage: 74%. Target: 80%.
Generate tests targeting these specific lines.
```

The `test-generator` agent activates automatically after `/qt:coverage` completes and gaps are found.

## Additional Resources

- **`references/gcov-lcov-workflow.md`** — Full gcov/lcov command reference, CMake preset patterns, troubleshooting
- **`references/python-coverage-workflow.md`** — coverage.py configuration, branch coverage, parallel test runs
- **`templates/qt-coverage.yml`** — Ready-to-use GitHub Actions workflow (Python + C++ variants)
- **`templates/run-coverage.sh`** — Portable shell script for local and generic CI use

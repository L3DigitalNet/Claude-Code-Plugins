---
name: coverage
description: Run coverage analysis for the Qt project. Instruments the build, executes tests, generates an HTML report, identifies coverage gaps, and optionally triggers the test-generator agent to fill them.
argument-hint: "[optional: --python | --cpp | --threshold N]"
allowed-tools:
  - Read
  - Bash
  - Glob
---

# /qt-suite:coverage — Coverage Analysis

Run coverage instrumentation, generate an HTML report, and identify untested code paths. Optionally triggers the `test-generator` agent when gaps are found.

## Step 1: Parse Arguments and Config

Parse the command argument for flags:
- `--python` — force Python mode
- `--cpp` — force C++ mode
- `--threshold N` — override coverage threshold (default 80)

Read `.qt-test.json` if present:
- `project_type` — python | cpp
- `coverage_threshold` — numeric, default 80
- `build_dir` — default "build-coverage"
- `coverage_exclude` — list of patterns to exclude

Auto-detect project type if not specified (CMakeLists.txt = C++, pyproject.toml = Python).

## Step 2: Run Coverage — Python

First verify the prerequisite tools are available:
```bash
python3 -c "import coverage, pytest_cov" 2>&1 || echo "Install: pip install coverage pytest-cov"
```

Run tests with coverage instrumentation:
```bash
QT_QPA_PLATFORM=offscreen \
  pytest \
    --cov=<package_name> \
    --cov-branch \
    --cov-report=term-missing \
    --cov-report=html:htmlcov \
    --cov-report=json:.coverage.json \
    tests/
```

Determine `<package_name>` from `pyproject.toml` `[tool.coverage.run] source` field, or from the project's main package directory.

## Step 3: Run Coverage — C++

First verify prerequisites:
```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/check-prerequisites.sh"
```

Build with coverage instrumentation:
```bash
echo "Configuring with coverage instrumentation..."
cmake -B build-coverage -DCMAKE_BUILD_TYPE=Debug -DENABLE_COVERAGE=ON
echo "Building..."
cmake --build build-coverage --parallel 4
```

Collect coverage:
```bash
cd build-coverage
echo "Running tests (pass 1 — zeroing counters)..."
ctest --output-on-failure

lcov --zerocounters --directory .
# (re-run tests to collect fresh counters)
echo "Running tests (pass 2 — collecting coverage data)..."
ctest --output-on-failure

echo "Generating coverage report..."
lcov --capture \
     --directory . \
     --output-file ../coverage_raw.info \
     --no-external

lcov --remove ../coverage_raw.info \
     '*/tests/*' '*/moc_*' '*/ui_*' \
     --output-file ../coverage.info

genhtml ../coverage.info \
        --output-directory ../htmlcov \
        --title "Coverage Report" \
        --legend
cd ..
```

## Step 4: Parse and Display Coverage Summary

**Python:** Parse `.coverage.json`:
```python
import json
data = json.load(open('.coverage.json'))
totals = data['totals']
print(f"Coverage: {totals['percent_covered']:.1f}% ({totals['covered_lines']}/{totals['num_statements']} lines)")
```

Display a table of files below threshold:
```
File                      Coverage   Missing Lines
calculator.py               74.2%    18-22, 45, 67
utils/formatter.py          61.5%    8-10, 30
```

**C++:** Parse lcov summary output for file-level breakdown.

## Step 5: Compare Against Threshold

If overall coverage >= threshold: report "✅ Coverage ${N}% — above threshold (${THRESHOLD}%)"
If below: report "❌ Coverage ${N}% — ${DELTA}% below target (${THRESHOLD}%)"

## Step 6: Offer to Fill Gaps

When files below threshold exist, use `AskUserQuestion` with bounded options:

```
Question: "Coverage is X%. N files are below threshold. Generate tests to fill the gaps?"
Options:
  - "Yes, generate tests for all gaps"
  - "Yes, but only for specific files" (follow up: which files?)
  - "No, show report only"
```

If the user selects "Yes" (or the command was invoked with `--generate`), hand off to the `test-generator` agent.

<!-- cross-file contract: the handoff format below is consumed by agents/test-generator.md Step 1.
     Changing field names or structure here requires matching changes in test-generator.md. -->
Format the handoff:
```
Files below threshold:
- calculator.py: 74% (missing lines 18-22, 45, 67 — error path in divide(), overflow check)
- formatter.py: 62% (missing lines 8-10 — empty string handling)
Target: 80%. Generate tests for these specific lines/paths.
```

## Step 7: Report Location

Always end by reporting where the HTML report was saved:
```
HTML coverage report: htmlcov/index.html
Open with: xdg-open htmlcov/index.html
```

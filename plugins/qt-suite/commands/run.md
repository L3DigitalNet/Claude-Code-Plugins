---
name: run
description: Build and run the Qt project's test suite. Auto-detects Python (pytest) vs C++ (CMake + CTest) and reports results with a pass/fail summary.
argument-hint: "[optional: test name pattern or file to run]"
allowed-tools:
  - Read
  - Bash
  - Glob
---

# /qt-suite:run — Run Test Suite

Run the project's Qt test suite and report results. Auto-detect whether this is a Python/PySide6 or C++ project based on project files.

## Step 1: Read Config and Detect Project Type

Read `.qt-test.json` if present — use `project_type`, `build_dir`, and `test_dir` fields.

If no config file:
- Check for `CMakeLists.txt` → C++ project (CTest)
- Check for `pyproject.toml` or `setup.cfg` or `pytest.ini` → Python project (pytest)
- Check for both → run both suites

## Step 2: Run Python Tests (pytest)

When project type is `python` or `both`:

```bash
# Set offscreen platform for headless CI compatibility
QT_QPA_PLATFORM=offscreen pytest tests/ -v --tb=short
```

If an argument was provided (e.g., `/qt-suite:run test_calculator`):
```bash
QT_QPA_PLATFORM=offscreen pytest tests/ -v --tb=short -k "test_calculator"
```

For projects with `pyproject.toml` defining `qt_api = pyside6`, no extra flags are needed — pytest-qt picks up the config automatically.

## Step 3: Run C++ Tests (CMake + CTest)

When project type is `cpp` or `both`:

Determine build directory from config (`build_dir` field) or default to `build/`.

```bash
# Configure if build dir doesn't exist yet
cmake -B build -DCMAKE_BUILD_TYPE=Debug

# Build (incremental — only changed files)
cmake --build build --parallel 4

# Run all tests
cd build && ctest --output-on-failure --parallel 4
```

If an argument was provided (e.g., `/qt-suite:run TestCalculator`):
```bash
cd build && ctest -R "TestCalculator" --output-on-failure
```

## Step 4: Report Results

Parse and report the test outcomes clearly:

**Python (pytest):**
```
Test Results: 23 passed, 1 failed, 2 skipped  (4.2s)

FAILED tests/test_calculator.py::TestCalculator::test_divide_by_zero
  AssertionError: ZeroDivisionError not raised
  (show the full failure message)
```

**C++ (CTest):**
```
Test Results: 18/20 tests passed  (2.1s)

FAILED: TestMainWindow (exit code 1)
  (show stdout from the failing test)
```

If all tests pass, report the count and time concisely — no further detail needed.

If tests fail:
- Show the complete failure output for each failing test
- Identify the likely cause if determinable from the output
- Suggest whether the fix is in test setup, application code, or a missing dependency

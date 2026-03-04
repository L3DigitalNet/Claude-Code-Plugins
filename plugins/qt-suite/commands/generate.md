---
name: generate
description: Generate unit tests for Qt/PySide6 source files. Claude scans the project, identifies files that need better test coverage, and writes test files following the project's testing conventions.
argument-hint: "[optional: specific file or class to generate tests for]"
allowed-tools:
  - Read
  - Write
  - Glob
  - Grep
  - Bash
---

# /qt-suite:generate — AI Test Generation

Generate unit tests for this Qt project. When an argument is provided, generate tests for that specific file or class. When no argument is provided, scan the project to identify the files most in need of tests.

## Step 1: Identify Targets

**If an argument was provided** (e.g., `/qt-suite:generate src/calculator.py`):
- Use the argument as the target file or class name
- Find the file with Glob if only a filename was given

**If no argument was provided**:
1. Read `.qt-test.json` if present to determine `project_type` and `test_dir`
2. Detect project type by checking for `CMakeLists.txt` (C++) or `pyproject.toml`/`setup.cfg` (Python)
3. Use Glob to find all source files:
   - Python: `**/*.py` (excluding `tests/`, `__init__.py`, migration files)
   - C++: `**/*.cpp` and `**/*.h` (excluding `tests/`, `moc_*`, `ui_*`, `build/`)
4. For each source file, check if a corresponding test file exists:
   - Python: `tests/test_<module>.py` for `src/<module>.py`
   - C++: `tests/<name>_test.cpp` or `tests/test_<name>.cpp` for `src/<name>.cpp`
5. Prioritize files with **no test file at all**, then files with low complexity coverage (look for classes with multiple public methods but few or no tests)
6. Present the top 3 candidates and select the best target. Prefer business logic classes over utility/helper files.

## Step 2: Read and Analyze the Source File

Read the target source file completely. Identify:
- Class names and their public interface
- Methods and their signatures, parameters, return types
- Side effects: file I/O, signals emitted, state mutations
- Edge cases visible from the code: null checks, boundary conditions, exception paths
- Qt-specific elements: signals, slots, widget interactions, model overrides

## Step 3: Check Existing Tests

If a test file already exists for this source:
- Read it to understand existing coverage
- Focus generated tests on uncovered methods and edge cases
- Do not duplicate tests that already exist

## Step 4: Determine Test File Location and Framework

**Python projects:**
- Test file: `tests/test_<module_name>.py`
- Framework: pytest + pytest-qt (for GUI classes), plain pytest (for non-GUI)
- Detect if class inherits from `QWidget`/`QDialog`/etc. → use `qtbot` fixture

**C++ projects:**
- Test file: `tests/<ClassName>Test.cpp` (or `tests/test_<name>.cpp`)
- Framework: QTest
- Each test class is a `QObject` subclass with `Q_OBJECT` macro
- End file with `QTEST_MAIN(TestClassName)` and `#include "<file>.moc"`

**QML:**
- Test file: `tests/tst_<ComponentName>.qml`
- Framework: QtQuickTest `TestCase` item

## Step 5: Generate Tests

Write comprehensive tests targeting:
1. **Happy path** — each public method with valid inputs
2. **Edge cases** — empty input, null/None, boundary values, max values
3. **Error paths** — invalid input, exceptions thrown, signals emitted on error
4. **State transitions** — object state before and after operations
5. **Signal behavior** — signals emitted with correct arguments (use `QSignalSpy` in C++, `waitSignal`/`waitSignals` in pytest-qt)

Reference the `qtest-patterns` skill for correct syntax and patterns.

For pytest-qt tests, always use `qtbot.addWidget()` for any widget created in a test.
For QTest C++ tests, use `init()` / `cleanup()` slots for per-test setup/teardown.

## Step 6: Write the Test File

Write the test file to the determined location. If the file already exists, append new test classes/functions — never overwrite existing tests.

## Step 7: Report

Report concisely:
- File generated: `tests/test_calculator.py`
- Tests written: N test functions / N test cases
- Coverage targets: list the methods/paths covered
- To run: `pytest tests/test_calculator.py -v` (Python) or `cmake --build build && ctest -R TestCalculator` (C++)
- Note any methods that couldn't be tested without further context (e.g., methods that require a running database)

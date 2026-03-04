---
name: qtest-patterns
description: >
  This skill should be used when the user asks to "write a test", "add tests to", "create a QTest",
  "how do I test a widget", "unit test for Qt", "pytest-qt", "test a PySide6 class",
  "QML test", "QtQuickTest", "write a test case", "test this class", or "generate a test file".
  Covers C++ QTest, Python pytest-qt, and QML TestCase patterns with CMake integration.
  Also activates for "write a C++ Qt test", "add a CMake test target", or "set up testlib".
---

# Qt Test Patterns

Qt testing spans three ecosystems: **C++ QTest** (native, zero dependencies), **Python pytest-qt** (PySide6 apps), and **QML TestCase** (QML component logic). This skill covers all three with CMake integration.

## Choosing a Test Framework

| Scenario | Framework |
|---|---|
| C++ Qt classes / business logic | C++ QTest (`QObject` subclass + `QTEST_MAIN`) |
| PySide6 GUI application | pytest + pytest-qt (`qtbot` fixture) |
| QML component behavior | QtQuickTest (`TestCase` QML type) |
| PySide6 non-GUI logic | pytest (no pytest-qt needed) |

## Python / PySide6 with pytest-qt

**Complete pytest-qt patterns** — see [references/python-pytest-qt.md](references/python-pytest-qt.md) for the full `qtbot` fixture API, signal waiting, conftest patterns, model testing, parametrize, async tests, and common gotchas.

Key config:
```ini
# pytest.ini
[pytest]
testpaths = tests
qt_api = pyside6
```

## C++ QTest

**Complete C++ QTest patterns** — see [references/cpp-qtest.md](references/cpp-qtest.md) for the full macro reference, `QSignalSpy`, GUI/input simulation, benchmark macros, output formats, CMake patterns, and troubleshooting.

Key structure: each test class is a `QObject` subclass; private slots are test functions; `QTEST_MAIN(ClassName)` + `#include "test_name.moc"` at the end of the file.

## QML TestCase

**Complete QML TestCase patterns** — see [references/qml-testcase.md](references/qml-testcase.md) for the full assertion API, component creation, `SignalSpy`, async/timer testing, CMake setup, and common issues.

Key structure: `TestCase` QML item; test functions must start with `test_`; always call `obj.destroy()` to prevent leaks.

## Additional Resources

Consult reference files in this skill's `references/` directory for detailed patterns:

- **`references/cpp-qtest.md`** — Full QTest macro reference, `QSignalSpy`, benchmark macros, output formats
- **`references/python-pytest-qt.md`** — Complete pytest-qt fixture API, async patterns, model testing, common gotchas
- **`references/qml-testcase.md`** — QML TestCase full API, async signal testing, component creation patterns

Working examples:
- **`examples/test_calculator.py`** — Complete pytest-qt example with fixtures
- **`examples/calculator_test.cpp`** — Complete C++ QTest example with data-driven tests

---
name: Qt Test Patterns
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

### File Naming and Location

Test files live in `tests/` at project root. File name: `test_<module_name>.py`. Class names: `Test<ClassName>`. Functions: `test_<behavior>`.

```python
# tests/test_calculator.py
import pytest
from myapp.calculator import Calculator

class TestCalculator:
    def test_add_returns_sum(self):
        calc = Calculator()
        assert calc.add(2, 3) == 5

    def test_divide_by_zero_raises(self):
        calc = Calculator()
        with pytest.raises(ZeroDivisionError):
            calc.divide(10, 0)
```

### GUI Tests with qtbot

`qtbot` is a pytest-qt fixture that manages QApplication lifetime and widget cleanup. Always add widgets under test with `qtbot.addWidget` to prevent leaks.

```python
# tests/test_main_window.py
import pytest
from pytestqt.qtbot import QtBot
from myapp.main_window import MainWindow

class TestMainWindow:
    def test_button_click_updates_label(self, qtbot: QtBot):
        window = MainWindow()
        qtbot.addWidget(window)
        window.show()

        # Simulate a click; waitSignal blocks until the signal fires or times out
        with qtbot.waitSignal(window.result_ready, timeout=1000):
            qtbot.mouseClick(window.calculate_btn, Qt.MouseButton.LeftButton)

        assert window.result_label.text() != ""

    def test_line_edit_accepts_input(self, qtbot: QtBot):
        window = MainWindow()
        qtbot.addWidget(window)
        qtbot.keyClicks(window.input_field, "42")
        assert window.input_field.text() == "42"
```

### conftest.py Pattern

Create `tests/conftest.py` for shared fixtures:

```python
# tests/conftest.py
import pytest
from myapp.main_window import MainWindow

@pytest.fixture
def main_window(qtbot):
    """Create and show MainWindow, cleaned up after each test."""
    window = MainWindow()
    qtbot.addWidget(window)
    window.show()
    return window
```

### pytest.ini / pyproject.toml

```ini
# pytest.ini
[pytest]
testpaths = tests
qt_api = pyside6
```

```toml
# pyproject.toml
[tool.pytest.ini_options]
testpaths = ["tests"]
qt_api = "pyside6"
```

## C++ QTest

### Class Structure

Each test class is a `QObject` subclass. Private slots are test functions; lifecycle slots are `initTestCase`, `cleanupTestCase`, `init`, `cleanup`.

```cpp
// tests/test_calculator.cpp
#include <QTest>
#include "calculator.h"

class TestCalculator : public QObject {
    Q_OBJECT

private slots:
    void initTestCase() { /* runs once before all tests */ }
    void cleanupTestCase() { /* runs once after all tests */ }
    void init() { /* runs before each test */ }
    void cleanup() { /* runs after each test */ }

    void addReturnsSum();
    void divideByZeroReturnsNaN();
    void addReturnsSum_data();  // data function for data-driven test
};

void TestCalculator::addReturnsSum_data() {
    QTest::addColumn<int>("a");
    QTest::addColumn<int>("b");
    QTest::addColumn<int>("expected");

    QTest::newRow("positive") << 2 << 3 << 5;
    QTest::newRow("negative") << -1 << 1 << 0;
}

void TestCalculator::addReturnsSum() {
    QFETCH(int, a);
    QFETCH(int, b);
    QFETCH(int, expected);
    Calculator calc;
    QCOMPARE(calc.add(a, b), expected);
}

void TestCalculator::divideByZeroReturnsNaN() {
    Calculator calc;
    QVERIFY(std::isnan(calc.divide(1.0, 0.0)));
}

QTEST_MAIN(TestCalculator)
#include "test_calculator.moc"
```

### Key Macros

| Macro | Purpose |
|---|---|
| `QVERIFY(expr)` | Fails if expr is false |
| `QCOMPARE(actual, expected)` | Fails with diff on mismatch |
| `QVERIFY_THROWS_EXCEPTION(type, expr)` | Verifies exception is thrown |
| `QSKIP("reason")` | Skip test with message |
| `QFETCH(type, name)` | Pull column from data-driven table |

### Widget / GUI Tests in C++

```cpp
#include <QTest>
#include <QSignalSpy>
#include <QPushButton>
#include "main_window.h"

class TestMainWindow : public QObject {
    Q_OBJECT
private slots:
    void buttonClickEmitsSignal() {
        MainWindow win;
        QSignalSpy spy(&win, &MainWindow::resultReady);

        QTest::mouseClick(win.calculateButton(), Qt::LeftButton);

        QCOMPARE(spy.count(), 1);
    }
};
```

### CMakeLists.txt for C++ Tests

```cmake
# tests/CMakeLists.txt
find_package(Qt6 REQUIRED COMPONENTS Test)

function(add_qt_test target source)
    add_executable(${target} ${source})
    target_link_libraries(${target}
        PRIVATE Qt6::Test myapp_lib
    )
    add_test(NAME ${target} COMMAND ${target})
endfunction()

add_qt_test(TestCalculator test_calculator.cpp)
add_qt_test(TestMainWindow test_main_window.cpp)
```

Root `CMakeLists.txt` additions:
```cmake
enable_testing()
add_subdirectory(tests)
```

## QML TestCase

QML tests use the `QtQuickTest` module. Each `.qml` test file contains one or more `TestCase` items.

```qml
// tests/tst_MyComponent.qml
import QtQuick 2.15
import QtTest 1.15
import MyApp 1.0  // your registered QML module

TestCase {
    name: "MyComponent"

    function test_initialState() {
        var component = Qt.createComponent("qrc:/MyComponent.qml")
        var obj = component.createObject(null)
        verify(obj !== null)
        compare(obj.title, "Untitled")
        obj.destroy()
    }

    function test_buttonClickChangesState() {
        var component = Qt.createComponent("qrc:/MyComponent.qml")
        var obj = component.createObject(null)
        obj.submitButton.clicked()
        compare(obj.state, "submitted")
        obj.destroy()
    }
}
```

### CMake for QML Tests

```cmake
find_package(Qt6 REQUIRED COMPONENTS QuickTest)

add_executable(qml_tests qml_test_main.cpp)
target_link_libraries(qml_tests PRIVATE Qt6::QuickTest)
add_test(NAME QmlTests COMMAND qml_tests -input ${CMAKE_CURRENT_SOURCE_DIR})
```

Minimal C++ entry point:
```cpp
// qml_test_main.cpp
#include <QtQuickTest>
QUICK_TEST_MAIN(qml_tests)
```

## Additional Resources

Consult reference files in this skill's `references/` directory for detailed patterns:

- **`references/cpp-qtest.md`** — Full QTest macro reference, `QSignalSpy`, benchmark macros, output formats
- **`references/python-pytest-qt.md`** — Complete pytest-qt fixture API, async patterns, model testing, common gotchas
- **`references/qml-testcase.md`** — QML TestCase full API, async signal testing, component creation patterns

Working examples:
- **`examples/test_calculator.py`** — Complete pytest-qt example with fixtures
- **`examples/calculator_test.cpp`** — Complete C++ QTest example with data-driven tests

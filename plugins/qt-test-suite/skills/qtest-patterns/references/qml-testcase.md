# QML TestCase Reference

## Module Import

```qml
import QtTest 1.15
// or for Qt 6.x:
import QtTest
```

## TestCase Structure

```qml
TestCase {
    name: "MyComponentTests"   // required — identifies this test suite

    // Optional lifecycle functions
    function initTestCase() { /* before all tests */ }
    function cleanupTestCase() { /* after all tests */ }
    function init() { /* before each test */ }
    function cleanup() { /* after each test */ }

    // Test functions — must start with "test_"
    function test_initialState() { ... }
    function test_buttonClick() { ... }
}
```

## Assertion Functions

| Function | Passes when |
|---|---|
| `verify(expr)` | expr is truthy |
| `verify(expr, msg)` | expr is truthy (custom failure message) |
| `compare(actual, expected)` | values are equal |
| `fuzzyCompare(a, b, delta)` | `\|a - b\| <= delta` |
| `fail(msg)` | unconditional failure |
| `skip(msg)` | skip test with message |
| `expectFail("", msg, AbortTestOnFail)` | next compare is expected to fail |

## Component Creation

```qml
TestCase {
    name: "MyComponent"

    function test_createAndDestroy() {
        // Inline component (preferred for simple cases)
        var component = Qt.createComponent("MyComponent.qml")
        verify(component !== null, "Component loaded")
        verify(component.status === Component.Ready,
               "Component ready: " + component.errorString())

        var obj = component.createObject(null)  // null parent = no visual parent
        verify(obj !== null, "Object created")

        compare(obj.title, "Untitled")

        obj.destroy()  // always destroy to prevent leaks
    }
}
```

### Inline Component Pattern (Qt 5.15+)

```qml
TestCase {
    name: "InlinePattern"

    Component {
        id: myComp
        MyWidget {
            width: 100; height: 100
        }
    }

    function test_inlineCreate() {
        var obj = myComp.createObject(null)
        verify(obj)
        compare(obj.width, 100)
        obj.destroy()
    }
}
```

## Signal Testing

```qml
TestCase {
    name: "SignalTests"

    SignalSpy {
        id: spy
        target: null  // set in test
        signalName: "clicked"
    }

    function test_buttonEmitsClicked() {
        var btn = Qt.createComponent("MyButton.qml").createObject(null)
        spy.target = btn

        btn.simulateClick()
        compare(spy.count, 1)

        btn.destroy()
        spy.target = null
        spy.clear()
    }
}
```

`SignalSpy` must have `target` and `signalName` set before the signal fires. Reset between tests with `spy.clear()`.

## Async / Timer Testing

```qml
TestCase {
    name: "AsyncTests"

    function test_timerFires() {
        var obj = Qt.createComponent("TimedComponent.qml").createObject(null)
        compare(obj.status, "idle")

        obj.start()
        wait(200)  // wait 200ms for timer to fire

        compare(obj.status, "done")
        obj.destroy()
    }

    function test_signalEventuallyFired() {
        var spy = createTemporaryQmlObject(
            'import QtTest; SignalSpy { signalName: "finished" }', null)
        var worker = Qt.createComponent("Worker.qml").createObject(null)
        spy.target = worker

        worker.start()
        spy.wait(2000)  // waits until count > 0 or timeout

        compare(spy.count, 1)
        worker.destroy()
    }
}
```

## Running QML Tests

### CMake Setup

```cmake
find_package(Qt6 REQUIRED COMPONENTS Quick QuickTest)

# Minimal C++ entry point required by QtQuickTest
add_executable(qml_tests qml_test_main.cpp)
target_link_libraries(qml_tests PRIVATE Qt6::Quick Qt6::QuickTest)

add_test(NAME QmlTests
    COMMAND qml_tests -input ${CMAKE_CURRENT_SOURCE_DIR}/tests
)
```

```cpp
// qml_test_main.cpp — boilerplate, don't modify
#include <QtQuickTest>
QUICK_TEST_MAIN(qml_tests)
```

### qmltestrunner (Alternative)

If Qt is installed with `qmltestrunner`:
```bash
qmltestrunner -input tests/
```

### Import Path Configuration

If your QML module is registered but not in the default import path:
```cpp
// Extended entry point with custom import path
#include <QtQuickTest>
#include <QGuiApplication>
#include <QQmlEngine>

class Setup : public QObject {
    Q_OBJECT
public slots:
    void applicationAvailable() {
        // called before QML engine is created
    }
    void qmlEngineAvailable(QQmlEngine *engine) {
        engine->addImportPath(":/imports");
    }
};
#include "qml_test_main.moc"
QUICK_TEST_MAIN_WITH_SETUP(qml_tests, Setup)
```

## File Naming Convention

QML test files should be prefixed with `tst_` to distinguish them from the components they test:

```
tests/
├── tst_Calculator.qml
├── tst_MainWindow.qml
└── tst_Navigation.qml
```

## Common Issues

**`Component.Error` status**: The QML import path doesn't include your module. Check `engine->addImportPath()` or `QML_IMPORT_PATH` env var.

**`compare` fails on object references**: QML `compare` uses `===` semantics for objects. For property comparisons, access the property: `compare(obj.value, expected)`.

**`wait()` causes flakiness on slow CI**: Increase wait duration or use `SignalSpy.wait()` which is event-driven instead of time-based.

**`obj.destroy()` not called**: QML test leaks objects if `destroy()` is not called. This can cause subsequent tests to see stale state from previous test objects.

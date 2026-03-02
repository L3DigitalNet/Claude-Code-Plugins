# C++ QTest Reference

## Complete Macro Reference

### Assertion Macros

| Macro | Passes when | Fails with |
|---|---|---|
| `QVERIFY(expr)` | expr is truthy | "expr returned false" |
| `QVERIFY2(expr, msg)` | expr is truthy | custom message |
| `QCOMPARE(actual, expected)` | values are equal | diff showing both values |
| `QVERIFY_THROWS_EXCEPTION(ExType, expr)` | expr throws ExType | no throw or wrong type |
| `QVERIFY_THROWS_NO_EXCEPTION(expr)` | expr doesn't throw | exception message |
| `QTRY_VERIFY(expr)` | expr eventually true within 5s | timeout |
| `QTRY_COMPARE(a, b)` | values eventually equal within 5s | timeout |
| `QTRY_VERIFY_WITH_TIMEOUT(expr, ms)` | expr eventually true | timeout |
| `QSKIP("reason")` | — | marks test as skipped |
| `QEXPECT_FAIL("", "reason", Continue)` | — | marks next QVERIFY expected to fail |

### Data-Driven Tests

```cpp
void MyTest::myTest_data() {
    QTest::addColumn<QString>("input");
    QTest::addColumn<int>("expected");

    QTest::newRow("empty") << QString("") << 0;
    QTest::newRow("one word") << QString("hello") << 5;
    QTest::newRow("unicode") << QString("héllo") << 5;
}

void MyTest::myTest() {
    QFETCH(QString, input);
    QFETCH(int, expected);
    QCOMPARE(computeLength(input), expected);
}
```

The `_data()` function must have the same name as the test function with `_data` appended and be a private slot.

### Signal Spy

`QSignalSpy` records all signal emissions for later inspection:

```cpp
#include <QSignalSpy>

QLineEdit *edit = new QLineEdit();
QSignalSpy spy(edit, &QLineEdit::textChanged);

edit->setText("hello");

QCOMPARE(spy.count(), 1);
QList<QVariant> args = spy.takeFirst();
QCOMPARE(args.at(0).toString(), "hello");
```

For signals with multiple parameters, `args` contains all parameters in order.

### GUI/Input Simulation

```cpp
#include <QTest>

// Mouse
QTest::mouseClick(widget, Qt::LeftButton);
QTest::mouseClick(widget, Qt::LeftButton, Qt::NoModifier, QPoint(10, 10));
QTest::mouseDClick(widget, Qt::LeftButton);
QTest::mousePress(widget, Qt::LeftButton);
QTest::mouseRelease(widget, Qt::LeftButton);
QTest::mouseMove(widget, QPoint(50, 50));

// Keyboard
QTest::keyClick(widget, Qt::Key_Return);
QTest::keyClick(widget, 'a', Qt::ControlModifier);
QTest::keyClicks(widget, "hello world");
QTest::keyPress(widget, Qt::Key_Shift);
QTest::keyRelease(widget, Qt::Key_Shift);

// Delay (for animation / debounce scenarios)
QTest::qWait(100);  // ms
QTest::qSleep(100); // ms (blocks event loop — avoid in GUI tests)
```

### Benchmark Macros

```cpp
void MyBenchmark::sortBenchmark() {
    QVector<int> data = generateData(10000);

    QBENCHMARK {
        std::sort(data.begin(), data.end());
    }
}
```

Run benchmarks: `./my_test -benchmark`.

Available measurement backends:
- Default: walltime
- `-callgrind`: Valgrind Callgrind
- `-perf`: Linux perf event counters
- `-tickcounter`: CPU tick counter

## Output Formats

```bash
./my_test                        # plain text (default)
./my_test -o results.xml,xml     # JUnit XML (CI-friendly)
./my_test -o results.tap,tap     # TAP format
./my_test -o -,txt -o results.xml,xml  # multiple outputs simultaneously
./my_test -v1                    # verbose: print test names
./my_test -v2                    # very verbose: all assertions
./my_test TestClass::specificTest  # run one test by name
./my_test -functions             # list all test function names
```

## CMake Patterns

### Simple (one test per executable)

```cmake
find_package(Qt6 REQUIRED COMPONENTS Test)

add_executable(TestCalculator test_calculator.cpp)
target_link_libraries(TestCalculator PRIVATE Qt6::Test calculator_lib)
add_test(NAME TestCalculator COMMAND TestCalculator)
```

### Helper Function (recommended for multiple tests)

```cmake
function(qt_add_unit_test name)
    add_executable(${name} ${ARGN})
    target_link_libraries(${name}
        PRIVATE Qt6::Test ${PROJECT_NAME}_lib
    )
    set_target_properties(${name} PROPERTIES
        RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/tests"
    )
    add_test(NAME ${name} COMMAND ${name} -o "${name}.xml,xml")
endfunction()

qt_add_unit_test(TestCalculator test_calculator.cpp)
qt_add_unit_test(TestMainWindow test_main_window.cpp)
```

### CTest Configuration

```cmake
# Set timeout per test (default unlimited)
set_tests_properties(TestCalculator PROPERTIES TIMEOUT 30)

# Run in parallel
set(CTEST_PARALLEL_LEVEL 4)
```

Run all tests: `ctest --output-on-failure --parallel 4`

## Linking Against Application Code

Avoid linking tests directly against the application executable. Instead, extract logic into a static or shared library:

```cmake
# Main CMakeLists.txt
add_library(myapp_lib STATIC
    src/calculator.cpp
    src/formatter.cpp
)
target_link_libraries(myapp_lib PUBLIC Qt6::Core Qt6::Widgets)

add_executable(myapp main.cpp)
target_link_libraries(myapp PRIVATE myapp_lib)

# Tests link the library, not the executable
enable_testing()
add_subdirectory(tests)
```

## Troubleshooting

**`undefined reference to 'TestFoo::staticMetaObject'`**: Missing `#include "test_foo.moc"` at the end of the test file.

**Test doesn't find Qt headers**: `find_package(Qt6 REQUIRED COMPONENTS Test)` must come before `target_link_libraries`.

**GUI tests fail on CI**: Use `QT_QPA_PLATFORM=offscreen` or Xvfb. CI machines have no display.

**`QCOMPARE` fails with no diff shown**: Type may not have `operator<<(QDebug, T)`. Register it or use `QVERIFY(a == b)` with a manual message.

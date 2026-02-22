// Example: C++ QTest suite for a Calculator class.
// Demonstrates: QCOMPARE/QVERIFY, data-driven tests, QSignalSpy, GUI simulation,
// benchmark macros, and proper CMakeLists.txt integration.
//
// CMakeLists.txt entry:
//   add_qt_test(TestCalculator calculator_test.cpp)

#include <QTest>
#include <QSignalSpy>
#include <QApplication>

#include "calculator.h"           // adjust to your project structure
#include "calculator_widget.h"

// ── Pure unit tests ──────────────────────────────────────────────────────────

class TestCalculatorLogic : public QObject {
    Q_OBJECT

private slots:
    void addTwoPositiveNumbers() {
        Calculator calc;
        QCOMPARE(calc.add(2, 3), 5);
    }

    void addNegativeNumbers() {
        Calculator calc;
        QCOMPARE(calc.add(-1, -4), -5);
    }

    void divideByZeroReturnsNaN() {
        Calculator calc;
        QVERIFY(std::isnan(calc.divide(1.0, 0.0)));
    }

    // Data-driven: one test function, multiple data rows
    void addParametrized_data() {
        QTest::addColumn<double>("a");
        QTest::addColumn<double>("b");
        QTest::addColumn<double>("expected");

        QTest::newRow("zeros")    << 0.0    << 0.0   << 0.0;
        QTest::newRow("large")    << 100.0  << 200.0 << 300.0;
        QTest::newRow("floats")   << 1.5    << 2.5   << 4.0;
        QTest::newRow("negative") << -5.0   << 5.0   << 0.0;
    }

    void addParametrized() {
        QFETCH(double, a);
        QFETCH(double, b);
        QFETCH(double, expected);

        Calculator calc;
        QCOMPARE(calc.add(a, b), expected);
    }

    void benchmarkAdd() {
        Calculator calc;
        QBENCHMARK {
            volatile auto result = calc.add(1.23456789, 9.87654321);
            Q_UNUSED(result)
        }
    }
};

// ── GUI / Widget tests ────────────────────────────────────────────────────────

class TestCalculatorWidget : public QObject {
    Q_OBJECT

private:
    CalculatorWidget *widget = nullptr;

private slots:
    void init() {
        // Runs before each test — create fresh widget
        widget = new CalculatorWidget();
        widget->show();
        QTest::qWaitForWindowExposed(widget);
    }

    void cleanup() {
        // Runs after each test — destroy widget
        delete widget;
        widget = nullptr;
    }

    void initialDisplayIsZero() {
        QCOMPARE(widget->display()->text(), QStringLiteral("0"));
    }

    void numberButtonUpdatesDisplay() {
        QTest::mouseClick(widget->button5(), Qt::LeftButton);
        QCOMPARE(widget->display()->text(), QStringLiteral("5"));
    }

    void clearButtonResetsDisplay() {
        QTest::keyClicks(widget->display(), "123");
        QTest::mouseClick(widget->clearButton(), Qt::LeftButton);
        QCOMPARE(widget->display()->text(), QStringLiteral("0"));
    }

    void equalsButtonEmitsCalculationDone() {
        // 2 + 3 = 5
        QTest::mouseClick(widget->button2(), Qt::LeftButton);
        QTest::mouseClick(widget->buttonAdd(), Qt::LeftButton);
        QTest::mouseClick(widget->button3(), Qt::LeftButton);

        // Record signal before clicking equals
        QSignalSpy spy(widget, &CalculatorWidget::calculationDone);
        QTest::mouseClick(widget->buttonEquals(), Qt::LeftButton);

        // Signal should fire once
        QCOMPARE(spy.count(), 1);
        QList<QVariant> args = spy.takeFirst();
        QCOMPARE(args.at(0).toDouble(), 5.0);
        QCOMPARE(widget->display()->text(), QStringLiteral("5"));
    }

    void keyboardInputAccepted() {
        QTest::keyClicks(widget, "42");
        QVERIFY(widget->display()->text().contains("42"));
    }

    void divisionDisplayedCorrectly() {
        // 8 / 4 = 2
        QTest::mouseClick(widget->button8(),      Qt::LeftButton);
        QTest::mouseClick(widget->buttonDivide(), Qt::LeftButton);
        QTest::mouseClick(widget->button4(),      Qt::LeftButton);
        QTest::mouseClick(widget->buttonEquals(), Qt::LeftButton);

        QCOMPARE(widget->display()->text(), QStringLiteral("2"));
    }
};

// ── Entry point ───────────────────────────────────────────────────────────────
// Use QTEST_GUILESS_MAIN for logic-only tests (faster), QTEST_MAIN for GUI tests.
// Each test class needs its own translation unit (file) with its own QTEST_MAIN.
// If combining multiple classes in one file, use a custom main instead:

int main(int argc, char *argv[]) {
    QApplication app(argc, argv);  // required for GUI tests

    int result = 0;
    {
        TestCalculatorLogic logicTests;
        result |= QTest::qExec(&logicTests, argc, argv);
    }
    {
        TestCalculatorWidget widgetTests;
        result |= QTest::qExec(&widgetTests, argc, argv);
    }
    return result;
}

#include "calculator_test.moc"  // required for Q_OBJECT — must be last line

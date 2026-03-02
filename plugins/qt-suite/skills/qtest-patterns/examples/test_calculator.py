"""
Example: pytest-qt test suite for a Calculator class.
Demonstrates: basic assertions, qtbot usage, conftest fixtures, parametrize, signal testing.
"""
import pytest
from PySide6.QtCore import Qt
from pytestqt.qtbot import QtBot

# Adjust import to match your project structure
from myapp.calculator import Calculator
from myapp.calculator_widget import CalculatorWidget


# ── Pure unit tests (no GUI) ─────────────────────────────────────────────────

class TestCalculatorLogic:
    """Tests for the Calculator class — no GUI needed."""

    def test_add_two_positive_numbers(self):
        calc = Calculator()
        assert calc.add(2, 3) == 5

    def test_add_negative_numbers(self):
        calc = Calculator()
        assert calc.add(-1, -4) == -5

    def test_divide_by_zero_raises(self):
        calc = Calculator()
        with pytest.raises(ZeroDivisionError):
            calc.divide(10, 0)

    def test_divide_returns_float(self):
        calc = Calculator()
        result = calc.divide(7, 2)
        assert isinstance(result, float)
        assert result == pytest.approx(3.5)

    @pytest.mark.parametrize("a,b,expected", [
        (0, 0, 0),
        (100, 200, 300),
        (-5, 5, 0),
        (1.5, 2.5, 4.0),
    ])
    def test_add_parametrized(self, a, b, expected):
        calc = Calculator()
        assert calc.add(a, b) == pytest.approx(expected)


# ── GUI / widget tests ───────────────────────────────────────────────────────

class TestCalculatorWidget:
    """Tests for the CalculatorWidget PySide6 UI."""

    def test_initial_display_is_zero(self, qtbot: QtBot):
        widget = CalculatorWidget()
        qtbot.addWidget(widget)
        widget.show()

        assert widget.display.text() == "0"

    def test_number_button_updates_display(self, qtbot: QtBot):
        widget = CalculatorWidget()
        qtbot.addWidget(widget)
        widget.show()

        qtbot.mouseClick(widget.btn_5, Qt.MouseButton.LeftButton)
        assert widget.display.text() == "5"

    def test_clear_resets_display(self, qtbot: QtBot):
        widget = CalculatorWidget()
        qtbot.addWidget(widget)
        widget.show()

        # Type something, then clear
        qtbot.keyClicks(widget.display, "123")
        qtbot.mouseClick(widget.btn_clear, Qt.MouseButton.LeftButton)

        assert widget.display.text() == "0"

    def test_calculate_button_emits_result_signal(self, qtbot: QtBot):
        widget = CalculatorWidget()
        qtbot.addWidget(widget)
        widget.show()

        # Enter "2 + 3 ="
        qtbot.mouseClick(widget.btn_2, Qt.MouseButton.LeftButton)
        qtbot.mouseClick(widget.btn_add, Qt.MouseButton.LeftButton)
        qtbot.mouseClick(widget.btn_3, Qt.MouseButton.LeftButton)

        with qtbot.waitSignal(widget.calculation_done, timeout=1000) as blocker:
            qtbot.mouseClick(widget.btn_equals, Qt.MouseButton.LeftButton)

        assert blocker.args[0] == pytest.approx(5.0)
        assert widget.display.text() == "5.0"

    def test_keyboard_input_accepted(self, qtbot: QtBot):
        widget = CalculatorWidget()
        qtbot.addWidget(widget)
        widget.show()
        widget.setFocus()

        qtbot.keyClick(widget, "4")
        qtbot.keyClick(widget, "2")
        assert "42" in widget.display.text()


# ── Fixture-based tests ───────────────────────────────────────────────────────

@pytest.fixture
def calc_widget(qtbot: QtBot) -> CalculatorWidget:
    """Shared fixture: a visible CalculatorWidget, cleaned up after test."""
    widget = CalculatorWidget()
    qtbot.addWidget(widget)
    widget.show()
    qtbot.waitExposed(widget)
    return widget


class TestCalculatorWithFixture:
    """Tests using the shared calc_widget fixture."""

    def test_division_result_displayed(self, calc_widget: CalculatorWidget, qtbot: QtBot):
        qtbot.mouseClick(calc_widget.btn_8, Qt.MouseButton.LeftButton)
        qtbot.mouseClick(calc_widget.btn_divide, Qt.MouseButton.LeftButton)
        qtbot.mouseClick(calc_widget.btn_4, Qt.MouseButton.LeftButton)
        qtbot.mouseClick(calc_widget.btn_equals, Qt.MouseButton.LeftButton)
        assert calc_widget.display.text() == "2.0"

    def test_chain_operations(self, calc_widget: CalculatorWidget, qtbot: QtBot):
        """1 + 2 + 3 = 6"""
        for btn_name in ["btn_1", "btn_add", "btn_2", "btn_add", "btn_3", "btn_equals"]:
            qtbot.mouseClick(getattr(calc_widget, btn_name), Qt.MouseButton.LeftButton)
        assert calc_widget.display.text() == "6.0"

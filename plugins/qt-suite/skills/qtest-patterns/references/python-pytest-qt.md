# Python pytest-qt Reference

## Installation

```bash
pip install pytest pytest-qt
# For PySide6 specifically:
pip install pytest pytest-qt PySide6
```

Specify the Qt binding in config:
```ini
# pytest.ini
[pytest]
qt_api = pyside6
```

## qtbot Fixture API

`qtbot` is the central fixture. It manages a `QApplication` instance and ensures widgets are cleaned up after each test.

### Widget Registration

Always register widgets under test to ensure cleanup:

```python
def test_something(qtbot):
    widget = MyWidget()
    qtbot.addWidget(widget)  # cleaned up after test, even if test fails
    widget.show()
```

### Mouse Simulation

```python
from pytestqt.qtbot import QtBot
from PySide6.QtCore import Qt
from PySide6.QtCore import QPoint

def test_clicks(qtbot: QtBot):
    w = MyWidget()
    qtbot.addWidget(w)
    w.show()

    qtbot.mouseClick(w.button, Qt.MouseButton.LeftButton)
    qtbot.mouseClick(w.button, Qt.MouseButton.LeftButton, pos=QPoint(5, 5))
    qtbot.mouseDClick(w.button, Qt.MouseButton.LeftButton)
    qtbot.mousePress(w.button, Qt.MouseButton.RightButton)
    qtbot.mouseRelease(w.button, Qt.MouseButton.RightButton)
    qtbot.mouseMove(w, pos=QPoint(100, 100))
```

### Keyboard Simulation

```python
from PySide6.QtCore import Qt

def test_keys(qtbot):
    w = MyWidget()
    qtbot.addWidget(w)
    w.show()

    qtbot.keyClick(w.input, Qt.Key.Key_Return)
    qtbot.keyClicks(w.input, "hello world")
    qtbot.keyPress(w, Qt.Key.Key_Control)
    qtbot.keyRelease(w, Qt.Key.Key_Control)
    qtbot.keyClick(w.input, "a", Qt.KeyboardModifier.ControlModifier)
```

### Signal Waiting

`waitSignal` and `waitSignals` block until a signal fires or timeout expires (raises `TimeoutError`):

```python
def test_async_result(qtbot):
    worker = MyWorker()
    qtbot.addWidget(worker)

    # Block until result_ready fires (max 2 seconds)
    with qtbot.waitSignal(worker.result_ready, timeout=2000) as blocker:
        worker.start()
    assert blocker.args[0] == expected_value

    # Wait for multiple signals
    with qtbot.waitSignals([worker.started, worker.finished], timeout=5000):
        worker.run()
```

### Waiting for Conditions

```python
def test_eventual_state(qtbot):
    w = MyWidget()
    qtbot.addWidget(w)

    w.start_async_operation()
    qtbot.waitUntil(lambda: w.status_label.text() == "Done", timeout=3000)
    assert w.result == expected
```

### Signal Recording

```python
from pytestqt.qt_compat import qt_api

def test_signal_emitted_n_times(qtbot):
    w = MyWidget()
    qtbot.addWidget(w)

    with qtbot.waitSignals([w.changed] * 3, timeout=1000):
        w.trigger_three_changes()
```

## conftest.py Patterns

### Application Fixture

```python
# tests/conftest.py
import pytest
from myapp.main_window import MainWindow

@pytest.fixture
def app_window(qtbot):
    """Provides a fully initialized and shown MainWindow."""
    window = MainWindow()
    qtbot.addWidget(window)
    window.show()
    qtbot.waitExposed(window)  # wait until window is actually visible
    return window

@pytest.fixture
def populated_window(app_window, qtbot):
    """Provides MainWindow with sample data loaded."""
    app_window.load_sample_data()
    qtbot.waitUntil(lambda: app_window.is_data_loaded(), timeout=2000)
    return app_window
```

### Temporary Directory Fixture

```python
@pytest.fixture
def temp_project(tmp_path):
    """Provides a temp dir with a minimal project structure."""
    (tmp_path / "data").mkdir()
    (tmp_path / "config.json").write_text('{"version": 1}')
    return tmp_path
```

## Testing Models (QAbstractItemModel)

```python
def test_model_data(qtbot):
    model = MyTableModel()
    qtbot.addWidget(model)  # not strictly required but good practice

    assert model.rowCount() == 0

    model.add_item({"name": "Alice", "age": 30})
    assert model.rowCount() == 1

    idx = model.index(0, 0)
    assert model.data(idx, Qt.ItemDataRole.DisplayRole) == "Alice"
```

## Common Gotchas

**`QApplication` already exists**: pytest-qt creates one automatically. Never create a `QApplication` inside a test fixture — it conflicts.

**`RuntimeError: wrapped C++ object deleted`**: Widget was garbage collected because Python lost the reference. Keep a reference in the test or use `qtbot.addWidget`.

**Signal test flakiness**: Use `waitSignal` instead of `assert` + `qWait`. `qWait` is a time-based race condition; `waitSignal` is event-driven.

**`waitSignal` timeout**: Increase timeout for slow operations. Default is 1000ms. Use `timeout=5000` for file I/O or network operations.

**Headless CI failures**: Set `QT_QPA_PLATFORM=offscreen` in the CI environment or use Xvfb. Tests will fail with `Could not connect to display` otherwise.

```yaml
# .github/workflows/test.yml
env:
  QT_QPA_PLATFORM: offscreen
  DISPLAY: ":99"
```

## Parametrize Pattern

```python
import pytest

@pytest.mark.parametrize("value,expected", [
    ("", False),
    ("a", True),
    ("hello world", True),
    ("   ", False),  # whitespace-only is falsy in our validator
])
def test_input_validator(qtbot, value, expected):
    validator = InputValidator()
    assert validator.is_valid(value) == expected
```

## Async Test Pattern (Qt event loop)

```python
import pytest

@pytest.mark.asyncio
async def test_async_operation(qtbot):
    # For coroutine-based logic that doesn't use Qt signals directly
    result = await my_async_function()
    assert result == expected
```

For Qt-native async (signals/slots), prefer `waitSignal` over `asyncio`.

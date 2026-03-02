---
name: qt-debugging
description: >
  Diagnosing and fixing Qt application issues — crashes, event loop problems, widget rendering failures, segfaults, and common runtime errors. Use when Qt crashes, a widget doesn't appear, the event loop freezes, signals aren't connecting, or the app exits unexpectedly.

  Trigger phrases: "Qt error", "crash", "segfault", "widget not showing", "event loop", "app exits unexpectedly", "Qt warning", "QPainter error", "assertion failed", "QObject destroyed", "application not responding"
version: 1.0.0
---

## Qt Debugging

### Diagnostic Approach

1. **Read the full Qt warning output** — Qt prints actionable warnings before crashes
2. **Categorize the failure type** (see categories below)
3. **Isolate** — reproduce with a minimal test case
4. **Fix and verify** with `QT_QPA_PLATFORM=offscreen pytest`

### Enabling Verbose Qt Output

```bash
# Show all Qt debug/warning messages
QT_LOGGING_RULES="*.debug=true" python -m myapp

# Filter to specific categories
QT_LOGGING_RULES="qt.qpa.*=true;qt.widgets.*=true" python -m myapp

# C++
qputenv("QT_LOGGING_RULES", "*.debug=true");
```

```python
# Python: install message handler to capture Qt output
from PySide6.QtCore import qInstallMessageHandler, QtMsgType

def qt_message_handler(mode: QtMsgType, context, message: str) -> None:
    if mode == QtMsgType.QtCriticalMsg or mode == QtMsgType.QtFatalMsg:
        import traceback
        traceback.print_stack()
    print(f"Qt [{mode.name}]: {message}")

qInstallMessageHandler(qt_message_handler)
```

### Common Failure Categories

#### Widget Never Appears
- `show()` not called on top-level widget
- Parent widget not shown (child inherits visibility)
- `setFixedSize(0, 0)` or zero content margins collapsing it
- Widget created after `app.exec()` returns (after event loop exits)
- `setVisible(False)` still in effect

```python
# Diagnostic
print(widget.isVisible(), widget.size(), widget.parentWidget())
```

#### Crash / Segfault on Widget Access
- Widget garbage-collected (Python deleted the QWidget before Qt finished with it)
- Common cause: widget stored only in a local variable, not `self._widget`
- Fix: always assign widgets to `self` attributes in `__init__`

```python
# BAD — local variable, GC can collect it
def setup(self):
    btn = QPushButton("Click")   # may be deleted immediately

# GOOD
def setup(self):
    self._btn = QPushButton("Click")
```

#### "QObject: Cannot create children for a parent in a different thread"
- A `QObject` with a parent is being created in a non-main thread
- Fix: create the object parentless, then use `moveToThread` or `deleteLater` for cleanup

#### "QPixmap: Must construct a QGuiApplication before a QPaintDevice"
- `QPixmap`, `QImage`, or `QIcon` created before `QApplication` exists
- Fix: move all Qt object construction after `app = QApplication(sys.argv)`

#### "RuntimeError: Internal C++ object (QWidget) already deleted"
- Accessing a Python wrapper after Qt deleted the underlying C++ object
- Common with `deleteLater()` — the deletion happens asynchronously
- Fix: check `sip.isdeleted(widget)` (PyQt6) or use `QPointer` pattern

#### Event Loop Frozen / UI Unresponsive
- Blocking call on main thread (I/O, `time.sleep`, heavy computation)
- Fix: move to `QRunnable`/`QThread` (see `qt-threading` skill)

```python
# Quick diagnostic: add to slow code path
from PySide6.QtCore import QCoreApplication
QCoreApplication.processEvents()  # temporarily unblocks — confirms event loop is stuck
```

#### Signal Connected But Never Fires
1. Verify the sender object is still alive
2. Add debug connection: `signal.connect(lambda *a: print("FIRED", a))`
3. Check signal type signature matches — `Signal(int)` will not fire if you emit `Signal(str)` equivalent
4. For C++: verify `Q_OBJECT` is present and moc ran after last change

### Memory / Resource Leak Detection

```python
# Track live QObject count
from PySide6.QtCore import QObject
# No built-in — use objgraph
import objgraph
objgraph.show_most_common_types(limit=20)
objgraph.show_growth()
```

### Useful Diagnostic Patterns

```python
# Dump full widget tree
def dump_widget_tree(widget, indent=0):
    print("  " * indent + repr(widget))
    for child in widget.children():
        if isinstance(child, QWidget):
            dump_widget_tree(child, indent + 1)

# Check if event loop is running
from PySide6.QtCore import QEventLoop
print(QCoreApplication.instance().loopLevel())  # > 0 if exec() is running

# Force sync paint (debugging paint issues)
widget.repaint()  # synchronous vs update() which defers
```

### QSS / Style Debugging

```python
# Print effective stylesheet for a widget
print(widget.styleSheet())

# Check if style rules are applying
# Add a unique background to isolate
widget.setStyleSheet("background: lime;")   # visible indicator

# Force re-evaluation after property change
widget.style().unpolish(widget)
widget.style().polish(widget)
widget.update()
```

### C++ Specific

```cpp
// Enable ASAN for memory errors
// cmake -DCMAKE_CXX_FLAGS="-fsanitize=address" ...

// Qt debug output
qDebug() << "Widget size:" << widget->size();
qWarning() << "Unexpected state:" << state;

// Print all object properties
qDebug() << widget->metaObject()->className();
```

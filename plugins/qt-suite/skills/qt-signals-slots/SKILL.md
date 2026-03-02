---
name: qt-signals-slots
description: >
  Qt signals and slots — the core inter-object communication mechanism. Use when connecting signals to slots, defining custom signals, debugging disconnected signals, passing data between objects, or handling cross-thread communication safely.

  Trigger phrases: "connect signal", "custom signal", "slot not firing", "disconnect signal", "cross-thread signal", "signal not working", "emit signal", "define signal", "QObject signal"
version: 1.0.0
---

## Signals and Slots

### Defining Custom Signals

**Python/PySide6 and PyQt6:**
```python
from PySide6.QtCore import QObject, Signal

class DataProcessor(QObject):
    # Class-level signal declarations — NOT instance attributes
    processing_started = Signal()
    data_ready = Signal(list)          # carries a list
    progress_updated = Signal(int)     # carries an int (0–100)
    error_occurred = Signal(str)       # carries an error message
    result_ready = Signal(object)      # carries any Python object

    def process(self, data: list) -> None:
        self.processing_started.emit()
        # ... processing ...
        self.data_ready.emit(result)
```

Signals must be declared as **class attributes**, not inside `__init__`. Declaring them in `__init__` causes them to shadow the descriptor and break connection tracking.

**C++/Qt:**
```cpp
class DataProcessor : public QObject {
    Q_OBJECT  // REQUIRED — enables signals/slots
public:
    explicit DataProcessor(QObject *parent = nullptr);

signals:
    void processingStarted();
    void dataReady(const QList<QVariant> &data);
    void progressUpdated(int percent);
    void errorOccurred(const QString &message);
};
```

`Q_OBJECT` macro is mandatory in every `QObject` subclass that uses signals/slots. Missing it causes runtime failures without a compile error in some configurations.

### Connecting Signals

**New-style syntax (use this):**
```python
# Direct method connection
button.clicked.connect(self._on_button_clicked)

# Lambda for simple transformations
slider.valueChanged.connect(lambda v: self._label.setText(str(v)))

# Cross-object
self._processor.data_ready.connect(self._table.populate)
self._processor.error_occurred.connect(self._status_bar.showMessage)
```

**C++:**
```cpp
connect(button, &QPushButton::clicked, this, &MainWindow::onButtonClicked);
connect(slider, &QSlider::valueChanged, this, [this](int v) {
    label->setText(QString::number(v));
});
```

Never use old-style `SIGNAL()`/`SLOT()` macros in new C++ code — they bypass type checking and fail silently on name mismatches.

### @Slot Decorator (Required for PySide6)

Always mark slot methods with `@Slot`. The official Qt for Python docs state that omitting it:
- Causes **runtime overhead** — the method is dynamically added to `QMetaObject` on every `connect()` call
- **Causes `TypeError` in QML** — QML invocables require `@Slot` (there is no `Q_INVOKABLE` equivalent without it)
- **Can cause segfaults across threads** — without `@Slot`, a proxy object may be created on the wrong thread

```python
from PySide6.QtCore import QObject, Signal, Slot

class DataProcessor(QObject):
    result_ready = Signal(dict)
    error_occurred = Signal(str)

    @Slot()
    def start(self) -> None:
        """No-arg slot."""
        ...

    @Slot(str)
    def on_input(self, text: str) -> None:
        """Slot receiving a string."""
        ...

    @Slot(float, result=int)
    def convert(self, value: float) -> int:
        """Slot with return value — replaces C++ Q_INVOKABLE."""
        return int(value)
```

`@Slot` parameters must match the signal's declared types. For QML-callable methods with no signal connection, `@Slot` is still required — it registers the method as invokable in the meta-object system.

Enable the warning to catch missing decorators during development:
```bash
QT_LOGGING_RULES="qt.pyside.libpyside.warning=true" python -m myapp
```

### Connection Types

| Type | When to use |
|------|-------------|
| `Qt.AutoConnection` (default) | Same or different thread — auto-selects |
| `Qt.DirectConnection` | Forced same-thread, synchronous |
| `Qt.QueuedConnection` | Cross-thread, or defer to next event loop iteration |
| `Qt.BlockingQueuedConnection` | Cross-thread, caller blocks until slot finishes (deadlock risk) |

```python
# Explicit queued connection for thread safety
worker.result_ready.connect(self._on_result, Qt.QueuedConnection)
```

### Cross-Thread Signals (Safe Pattern)

Qt signals are the only safe way to communicate from a worker thread to the UI thread.

```python
from PySide6.QtCore import QObject, Signal, QThread

class Worker(QObject):
    result_ready = Signal(dict)
    error_occurred = Signal(str)
    finished = Signal()

    def run(self) -> None:
        try:
            result = self._do_work()   # blocking operation
            self.result_ready.emit(result)
        except Exception as e:
            self.error_occurred.emit(str(e))
        finally:
            self.finished.emit()

class MainWindow(QMainWindow):
    def _start_work(self) -> None:
        self._thread = QThread(self)
        self._worker = Worker()
        self._worker.moveToThread(self._thread)

        # Connect before starting thread
        self._thread.started.connect(self._worker.run)
        self._worker.result_ready.connect(self._on_result)   # AutoConnection → queued
        self._worker.finished.connect(self._thread.quit)
        self._worker.finished.connect(self._worker.deleteLater)
        self._thread.finished.connect(self._thread.deleteLater)

        self._thread.start()
```

`moveToThread` + `AutoConnection` means `result_ready` automatically becomes a queued connection, making it safe to update UI widgets from the slot.

### Disconnecting

```python
# Disconnect specific connection
button.clicked.disconnect(self._on_click)

# Disconnect all connections to a specific slot
button.clicked.disconnect()

# Python: disconnect on object deletion handled automatically
# C++: use QMetaObject::Connection handle for manual control
```

In Python, connections to methods of live objects are automatically cleaned up when the receiving object is destroyed. Connections to lambdas and free functions are not — disconnect them explicitly.

### Debugging Disconnected Signals

Checklist when a signal isn't firing:
1. Confirm the emitting object is alive (not prematurely garbage-collected)
2. Verify `connect()` was called and returned successfully
3. Check signal type matches — `Signal(int)` won't fire if you pass a `str`
4. For C++: verify `Q_OBJECT` is present and `moc` ran (rebuild after adding it)
5. For cross-thread: verify `moveToThread` happened before the thread started
6. Add a debug connection: `signal.connect(lambda *args: print("FIRED", args))`

### Overloaded Signals (PyQt6 / C++)

When a signal has multiple overloads, use the subscript syntax:
```python
# PyQt6 only — PySide6 handles this automatically
from PyQt6.QtWidgets import QSpinBox
spin_box.valueChanged[int].connect(self._on_value)
```

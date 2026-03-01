---
name: qt-threading
description: >
  Qt threading patterns — QThread, QRunnable, QThreadPool, and thread safety for GUI applications. Use when running background tasks, keeping the UI responsive during long operations, managing worker threads, using thread pools, or debugging race conditions and deadlocks.

  Trigger phrases: "QThread", "worker", "background task", "thread safety", "UI freezing", "long operation", "QRunnable", "QThreadPool", "thread pool", "concurrent", "responsive UI", "blocking the event loop"
version: 1.0.0
---

## Qt Threading

### The Golden Rule

**Never update UI widgets from a non-main thread.** All widget operations must happen on the main (GUI) thread. Use signals to marshal results back from worker threads.

### Pattern 1: Worker Object + QThread (preferred for stateful workers)

Move a `QObject` subclass to a `QThread`. The worker's slots execute in the thread's event loop.

```python
from PySide6.QtCore import QObject, QThread, Signal, Slot

class DataFetcher(QObject):
    """Worker that fetches data in a background thread."""
    result_ready = Signal(dict)
    error_occurred = Signal(str)
    progress = Signal(int)
    finished = Signal()

    def __init__(self, url: str) -> None:
        super().__init__()
        self._url = url
        self._cancelled = False

    @Slot()
    def cancel(self) -> None:
        self._cancelled = True

    @Slot()   # @Slot required — this is connected via thread.started signal
    def fetch(self) -> None:
        """Slot — executes in the worker thread."""
        try:
            for i, chunk in enumerate(stream_data(self._url)):
                if self._cancelled:
                    break
                self.progress.emit(int(i / total * 100))
            self.result_ready.emit(final_data)
        except Exception as e:
            self.error_occurred.emit(str(e))
        finally:
            self.finished.emit()

class MainWindow(QMainWindow):
    def _start_fetch(self, url: str) -> None:
        self._thread = QThread(self)
        self._fetcher = DataFetcher(url)
        self._fetcher.moveToThread(self._thread)

        # Wire before starting — all connections are established atomically
        self._thread.started.connect(self._fetcher.fetch)
        self._fetcher.result_ready.connect(self._on_result)
        self._fetcher.error_occurred.connect(self._on_error)
        self._fetcher.progress.connect(self._progress_bar.setValue)
        self._fetcher.finished.connect(self._thread.quit)
        self._fetcher.finished.connect(self._fetcher.deleteLater)
        self._thread.finished.connect(self._thread.deleteLater)

        self._thread.start()
        self._cancel_btn.setEnabled(True)

    def _on_result(self, data: dict) -> None:
        """Slot — executes in the main thread (AutoConnection → queued)."""
        self._table.populate(data)
        self._cancel_btn.setEnabled(False)
```

The `finished → deleteLater` chain ensures Qt cleans up the worker and thread objects when done, preventing memory leaks.

### Pattern 2: QRunnable + QThreadPool (fire-and-forget tasks)

For tasks that don't need cancellation or per-instance state:

```python
from PySide6.QtCore import QRunnable, QThreadPool, QObject, Signal, Slot

class WorkerSignals(QObject):
    """QRunnable can't have signals directly — use a QObject container."""
    finished = Signal()
    result = Signal(object)
    error = Signal(str)

class ProcessTask(QRunnable):
    def __init__(self, data: list) -> None:
        super().__init__()
        self.signals = WorkerSignals()
        self._data = data
        self.setAutoDelete(True)   # pool deletes task after run()

    @Slot()   # @Slot required — prevents segfault if called from different thread
    def run(self) -> None:
        try:
            result = expensive_computation(self._data)
            self.signals.result.emit(result)
        except Exception as e:
            self.signals.error.emit(str(e))
        finally:
            self.signals.finished.emit()

# Usage
pool = QThreadPool.globalInstance()
task = ProcessTask(my_data)
task.signals.result.connect(self._on_result)
pool.start(task)

# Limit threads
pool.setMaxThreadCount(4)
```

### Pattern 3: Simple Background Task with QTimer

For periodic, lightweight tasks that don't need a separate thread:

```python
from PySide6.QtCore import QTimer

# Poll every 500ms without blocking
self._timer = QTimer(self)
self._timer.timeout.connect(self._check_status)
self._timer.start(500)

# Single-shot — fire once after 2 seconds
QTimer.singleShot(2000, self._delayed_init)
```

### Thread Safety: Shared Data

Qt containers and Python objects are not thread-safe. Use a mutex or queue:

```python
from threading import Lock

class SafeDataStore(QObject):
    data_updated = Signal()

    def __init__(self) -> None:
        super().__init__()
        self._data: list = []
        self._lock = Lock()

    def append(self, item: object) -> None:
        with self._lock:
            self._data.append(item)
        self.data_updated.emit()   # safe — emitting a signal is thread-safe

    def snapshot(self) -> list:
        with self._lock:
            return list(self._data)
```

**Emitting signals is thread-safe.** `AutoConnection` automatically queues the slot call when emitter and receiver are in different threads.

### Debugging Thread Issues

**UI freezes (janky response):** A blocking call is running on the main thread. Common culprits: `requests.get()`, `time.sleep()`, large file I/O, heavy computation. Move to `QRunnable` or worker `QThread`.

**Crash with "QObject: Cannot create children for a parent that is in a different thread":** A `QObject` created in the worker thread has a parent owned by the main thread. Create objects parentless and use `moveToThread` or `deleteLater`.

**Signal emitted but slot never called:** Verify `moveToThread` happened before `start()`. Verify receiver's thread has a running event loop (`QThread.exec()` or `QThread.start()`).

**Race condition:** Never read mutable shared state in a slot without a lock. Prefer passing data as signal arguments (copied by value) over shared mutable objects.

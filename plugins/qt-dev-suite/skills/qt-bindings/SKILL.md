---
name: qt-bindings
description: >
  Python Qt binding differences and migration guides — PySide6 vs PyQt6 API differences, and migration paths from PyQt5 to both modern bindings. Use when choosing between PySide6 and PyQt6, porting a PyQt5 codebase, handling binding-specific API differences, or writing code that must work with both bindings.

  Trigger phrases: "PySide6 vs PyQt6", "PyQt5 migration", "binding difference", "migrate from PyQt5", "PyQt6 migration", "PySide6 or PyQt6", "binding compatibility", "porting Qt Python", "LGPL vs GPL"
version: 1.0.0
---

## Python Qt Bindings

### Choosing a Binding

| Criteria | PySide6 | PyQt6 |
|----------|---------|-------|
| Maintainer | Qt Company (official) | Riverbank Computing |
| License | LGPL v3 | GPL v3 / commercial |
| Commercial use | Free (LGPL) | Requires commercial license |
| QML/Qt Quick support | Excellent | Good |
| Type stubs | Built-in | `PyQt6-stubs` (third-party) |
| `pyqtSignal` / `Signal` | `Signal` | `pySignal` |
| `pyqtSlot` / `Slot` | `Slot` | `pyqtSlot` |
| Availability | pip | pip |

**Default recommendation: PySide6** — official binding, LGPL, ships with complete type stubs, better QML tooling.

### API Compatibility Layer

For code that must support both:
```python
try:
    from PySide6.QtWidgets import QApplication, QPushButton
    from PySide6.QtCore import Signal, Slot
    PYSIDE6 = True
except ImportError:
    from PyQt6.QtWidgets import QApplication, QPushButton
    from PyQt6.QtCore import pyqtSignal as Signal, pyqtSlot as Slot
    PYSIDE6 = False
```

Or use **`qtpy`** — an abstraction layer maintained by the community:
```python
from qtpy.QtWidgets import QApplication, QPushButton
from qtpy.QtCore import Signal, Slot
# Works with PySide6, PyQt6, PySide2, PyQt5 — set QT_API env var to select
```

### PySide6 vs PyQt6: Key Differences

#### Signals and Slots
```python
# PySide6
from PySide6.QtCore import Signal, Slot
class Foo(QObject):
    my_signal = Signal(int)

    @Slot(int)
    def my_slot(self, value: int): ...

# PyQt6
from PyQt6.QtCore import pyqtSignal, pyqtSlot
class Foo(QObject):
    my_signal = pyqtSignal(int)

    @pyqtSlot(int)
    def my_slot(self, value: int): ...
```

#### Enum Access
Both require fully-qualified enum access (breaking change from Qt5):
```python
# CORRECT (both bindings)
Qt.AlignmentFlag.AlignLeft
QSizePolicy.Policy.Expanding
QPushButton.setCheckable(True)

# WRONG — Qt5 style (no longer works)
Qt.AlignLeft
```

#### Exec Method (PyQt6 breaking change)
```python
# PySide6
app.exec()
dialog.exec()

# PyQt6 — exec() also works in PyQt6 (exec_ removed)
app.exec()
dialog.exec()
```

Both use `exec()` — the old `exec_()` workaround is no longer needed or available in PyQt6.

#### Property Decorator
```python
# PySide6
from PySide6.QtCore import Property
@Property(int, notify=value_changed)
def value(self) -> int: return self._value

# PyQt6
from PyQt6.QtCore import pyqtProperty
@pyqtProperty(int, notify=value_changed)
def value(self) -> int: return self._value
```

### Migrating PyQt5 → PySide6

**Step 1: Update imports**
```bash
# Mass replace with sed
sed -i 's/from PyQt5\./from PySide6./g' src/**/*.py
sed -i 's/import PyQt5\./import PySide6./g' src/**/*.py
```

**Step 2: Replace signal/slot decorators**
```python
# PyQt5 → PySide6
pyqtSignal → Signal
pyqtSlot  → Slot
pyqtProperty → Property
```

**Step 3: Fix enum usage** (most common PyQt5→PySide6 breakage)
```python
# PyQt5 (short form)
Qt.AlignLeft          → Qt.AlignmentFlag.AlignLeft
Qt.Horizontal         → Qt.Orientation.Horizontal
QSizePolicy.Expanding → QSizePolicy.Policy.Expanding
Qt.WindowModal        → Qt.WindowModality.WindowModal
```

**Step 4: Fix exec() calls** — remove `exec_()` suffix:
```python
app.exec_()   → app.exec()
dialog.exec_() → dialog.exec()
```

**Step 5: Remove deprecated Qt5 API**
```python
# Removed in Qt6
QWidget.show() — still works
QApplication.setDesktopSettingsAware() — removed
QFontDatabase.addApplicationFont() — still works
```

### Migrating PyQt5 → PyQt6

Same steps as PySide6 migration, but:
```python
# PyQt5 → PyQt6 signals (keep pyqt prefix)
pyqtSignal → pyqtSignal  (unchanged)
pyqtSlot   → pyqtSlot    (unchanged)

# Imports change
from PyQt5.QtWidgets import ... → from PyQt6.QtWidgets import ...
```

Enum changes are identical to PySide6 — both Qt6 bindings enforce fully-qualified enums.

### Migrating PySide2 → PySide6

```python
# Imports
from PySide2. → from PySide6.

# exec_ removal
.exec_() → .exec()

# Enum qualification (same as PyQt5→PySide6)
```

PySide6 also drops Python 3.6/3.7 support — minimum is Python 3.8 (3.11 recommended).

### Type Stubs

```bash
# PySide6 ships stubs — no extra install
pip install PySide6

# PyQt6
pip install PyQt6-stubs

# Configure pyright/mypy
# pyproject.toml
[tool.pyright]
pythonVersion = "3.11"
```

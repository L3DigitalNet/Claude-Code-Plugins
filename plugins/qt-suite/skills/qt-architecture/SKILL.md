---
name: qt-architecture
description: >
  Qt application architecture, project structure, and entry-point patterns for PySide6, PyQt6, and C++/Qt. Use when structuring a Qt app, setting up QApplication, designing the main window, choosing between MVC/MVP patterns, organizing a src layout, or deciding how to separate concerns in a GUI application.

  Trigger phrases: "structure my Qt app", "QApplication setup", "app entry point", "Qt project layout", "organize Qt code", "Qt MVC", "Qt MVP", "main window architecture", "new Qt project"
version: "1.0.0"
---

## Qt Application Architecture

### Entry-Point Pattern

Every Qt application requires exactly one `QApplication` (widgets) or `QGuiApplication` (QML-only) instance. Create it before any widgets.

**Python/PySide6 canonical entry point:**
```python
# src/myapp/__main__.py
import sys
from PySide6.QtWidgets import QApplication
from myapp.ui.main_window import MainWindow

def main() -> None:
    app = QApplication(sys.argv)
    app.setApplicationName("MyApp")
    app.setOrganizationName("MyOrg")
    app.setOrganizationDomain("myorg.com")
    window = MainWindow()
    window.show()
    sys.exit(app.exec())

if __name__ == "__main__":
    main()
```

Using `__main__.py` enables `python -m myapp` invocation. Set `applicationName` and `organizationName` before creating any widgets — these values seed `QSettings`.

**C++/Qt canonical main.cpp:**
```cpp
#include <QApplication>
#include "mainwindow.h"

int main(int argc, char *argv[]) {
    QApplication app(argc, argv);
    app.setApplicationName("MyApp");
    app.setOrganizationName("MyOrg");
    MainWindow window;
    window.show();
    return app.exec();
}
```

### Project Layout (Python/PySide6)

Use `src` layout to prevent accidental imports from the project root:

```
my-qt-app/
├── src/
│   └── myapp/
│       ├── __init__.py
│       ├── __main__.py          # Entry point
│       ├── ui/
│       │   ├── __init__.py
│       │   ├── main_window.py   # QMainWindow subclass
│       │   ├── dialogs/         # QDialog subclasses
│       │   └── widgets/         # Custom QWidget subclasses
│       ├── models/              # Data models (non-Qt)
│       ├── services/            # Business logic, I/O
│       └── resources/           # .qrc compiled output
├── tests/
│   ├── conftest.py
│   └── test_*.py
├── resources/
│   ├── icons/
│   └── resources.qrc
├── pyproject.toml
└── .qt-test.json                # qt-test-suite config
```

Keep `ui/`, `models/`, and `services/` separate. UI code should never contain business logic.

### QMainWindow Structure

```python
# src/myapp/ui/main_window.py
from PySide6.QtWidgets import QMainWindow, QWidget, QVBoxLayout
from PySide6.QtCore import Qt

class MainWindow(QMainWindow):
    def __init__(self, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self.setWindowTitle("MyApp")
        self.setMinimumSize(800, 600)
        self._setup_ui()
        self._setup_menu()
        self._connect_signals()

    def _setup_ui(self) -> None:
        """Build central widget and layout."""
        central = QWidget()
        self.setCentralWidget(central)
        layout = QVBoxLayout(central)
        # Add widgets to layout here

    def _setup_menu(self) -> None:
        """Build menu bar and actions."""
        pass

    def _connect_signals(self) -> None:
        """Wire all signal→slot connections."""
        pass
```

Separate `_setup_ui`, `_setup_menu`, and `_connect_signals` into distinct methods. This makes each responsibility findable and testable.

### Architectural Patterns

**MVP (Model-View-Presenter)** — preferred for testable Qt applications:
- **Model**: Pure Python classes, no Qt imports. Holds data and business logic.
- **View**: QWidget subclasses. Emits signals for user actions; receives data to display.
- **Presenter**: Mediates between Model and View. Contains decision logic. Testable without Qt.

```python
# Presenter owns the view and model
class CalculatorPresenter:
    def __init__(self, view: CalculatorView, model: CalculatorModel) -> None:
        self._view = view
        self._model = model
        view.calculate_requested.connect(self._on_calculate)

    def _on_calculate(self, expression: str) -> None:
        result = self._model.evaluate(expression)
        self._view.display_result(result)
```

**MVC** maps less naturally to Qt's signal/slot system. MVP is the idiomatic choice.

**For simple apps**: Direct signal/slot connections are fine. Introduce MVP when you need unit-testable business logic.

### pyproject.toml Configuration

```toml
[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[project]
name = "myapp"
version = "0.1.0"
requires-python = ">=3.11"
dependencies = ["PySide6>=6.6"]

[project.scripts]
myapp = "myapp.__main__:main"

[tool.hatch.build.targets.wheel]
packages = ["src/myapp"]

[tool.pytest.ini_options]
testpaths = ["tests"]
qt_api = "pyside6"

[tool.pyright]
pythonVersion = "3.11"
include = ["src"]
```

### Qt Project Config (.qt-test.json)

Always create this at project root for `qt-test-suite` compatibility:

```json
{
  "project_type": "python",
  "app_entry": "src/myapp/__main__.py",
  "test_dir": "tests/",
  "coverage_source": ["src/myapp"]
}
```

### Critical Constraints

- One `QApplication` per process — never create it twice or inside a function that may be called multiple times
- All widget creation must happen after `QApplication` is constructed
- Widgets created without a parent become top-level windows; always pass `parent` to avoid orphaned widgets
- Never store Qt objects (QWidget, QObject) in module-level globals — deferred destruction causes segfaults
- `app.exec()` blocks until the last window closes; all application logic runs via signals/slots within this loop

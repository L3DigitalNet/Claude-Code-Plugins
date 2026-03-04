---
name: scaffold
description: Scaffold a new Python/PySide6 application with pyproject.toml, src layout, and qt-suite config.
argument-hint: "[app-name] [optional: description]"
allowed-tools:
  - Read
  - Write
  - Bash
  - Glob
---

# /qt-suite:scaffold — Scaffold New Qt Application

Create a complete Python/PySide6 project structure. Default layout: `pyproject.toml` + `src/` layout with a working `QMainWindow` entry point.

## Step 1: Determine App Name and Location

If an argument was provided (e.g., `/qt-suite:scaffold my-music-app`), use it as the app name.

If no argument was provided, check the current directory:
- If it's an empty or new directory, scaffold here using the directory name as the app name
- Otherwise, ask the user for a name using `AskUserQuestion`

Derive the Python package name: convert the app name to `snake_case` (replace hyphens with underscores).

## Step 2: Create Directory Structure

```bash
mkdir -p <app-name>/src/<package_name>/ui/widgets
mkdir -p <app-name>/src/<package_name>/ui/dialogs
mkdir -p <app-name>/src/<package_name>/models
mkdir -p <app-name>/src/<package_name>/services
mkdir -p <app-name>/src/<package_name>/resources
mkdir -p <app-name>/resources/icons
mkdir -p <app-name>/tests
```

## Step 3: Write Project Files

### `pyproject.toml`
```toml
[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[project]
name = "<app-name>"
version = "0.1.0"
description = "<description or empty string>"
requires-python = ">=3.11"
dependencies = ["PySide6>=6.7"]

[project.scripts]
<app-name> = "<package_name>.__main__:main"

[tool.hatch.build.targets.wheel]
packages = ["src/<package_name>"]

[tool.pytest.ini_options]
testpaths = ["tests"]
qt_api = "pyside6"

[tool.pyright]
pythonVersion = "3.11"
include = ["src"]
```

### `src/<package_name>/__init__.py`
Empty file.

### `src/<package_name>/__main__.py`
```python
import sys
from PySide6.QtWidgets import QApplication
from <package_name>.ui.main_window import MainWindow


def main() -> None:
    app = QApplication(sys.argv)
    app.setApplicationName("<AppName>")
    app.setOrganizationName("MyOrg")
    app.setOrganizationDomain("myorg.com")
    window = MainWindow()
    window.show()
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
```

### `src/<package_name>/ui/__init__.py`
Empty file.

### `src/<package_name>/ui/main_window.py`
```python
from PySide6.QtWidgets import QMainWindow, QWidget, QVBoxLayout, QLabel
from PySide6.QtCore import Qt


class MainWindow(QMainWindow):
    def __init__(self, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self.setWindowTitle("<AppName>")
        self.setMinimumSize(800, 600)
        self._setup_ui()
        self._setup_menu()
        self._connect_signals()

    def _setup_ui(self) -> None:
        central = QWidget()
        self.setCentralWidget(central)
        layout = QVBoxLayout(central)
        layout.setAlignment(Qt.AlignmentFlag.AlignCenter)

        placeholder = QLabel("Welcome to <AppName>")
        placeholder.setObjectName("welcome_label")
        layout.addWidget(placeholder)

    def _setup_menu(self) -> None:
        menu_bar = self.menuBar()
        file_menu = menu_bar.addMenu("&File")

        from PySide6.QtGui import QAction
        quit_action = QAction("&Quit", self)
        quit_action.setShortcut("Ctrl+Q")
        quit_action.triggered.connect(self.close)
        file_menu.addAction(quit_action)

    def _connect_signals(self) -> None:
        pass
```

### `src/<package_name>/ui/widgets/__init__.py` and `dialogs/__init__.py`
Empty files.

### `src/<package_name>/models/__init__.py` and `services/__init__.py`
Empty files.

### `src/<package_name>/resources/__init__.py`
Empty file.

### `tests/__init__.py`
Empty file.

### `tests/conftest.py`
```python
import pytest
from PySide6.QtWidgets import QApplication


@pytest.fixture(scope="session")
def qapp():
    """Shared QApplication instance for all tests."""
    app = QApplication.instance() or QApplication([])
    yield app
```

### `.qt-test.json`
```json
{
  "project_type": "python",
  "app_entry": "src/<package_name>/__main__.py",
  "test_dir": "tests/",
  "coverage_source": ["src/<package_name>"]
}
```

### `.gitignore`
```
__pycache__/
*.pyc
*.pyo
.venv/
dist/
build/
*.egg-info/
.coverage
htmlcov/
src/<package_name>/resources/rc_*.py
```

## Step 4: Install Dependencies

If `uv` is available:
```bash
cd <app-name> && uv venv && uv pip install -e . PySide6 pytest pytest-qt
```

Otherwise:
```bash
cd <app-name> && python -m venv .venv && .venv/bin/pip install -e . PySide6 pytest pytest-qt
```

## Step 5: Report

Lead with the outcome, then show the tree:

```
Initialized <app-name>/ — <N> files across <M> directories.
```

Then:
- List the directory tree (1 level deep)
- Show how to run: `python -m <package_name>` or `uv run <app-name>`
- Show how to run tests: `QT_QPA_PLATFORM=offscreen pytest tests/`
- Note: add `.qrc` file to `resources/` and compile with `pyside6-rcc` when ready to add icons

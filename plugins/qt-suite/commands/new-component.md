---
name: new-component
description: Generate a new Qt widget, dialog, or window class with correct boilerplate and object names.
argument-hint: "<component-name> [widget|dialog|window]"
allowed-tools:
  - Read
  - Write
  - Bash
  - Glob
---

# /qt-suite:new-component — Generate Qt Component

Create a new PySide6 widget, dialog, or window class with correct boilerplate, layout structure, signal declarations, and `setObjectName()` calls for testability.

## Step 1: Parse Arguments

Extract from the argument string:
- **name**: CamelCase class name (e.g., `UserProfileWidget`, `ConfirmDeleteDialog`, `DocumentWindow`)
- **type**: one of `widget`, `dialog`, or `window`
  - If not specified, infer from name suffix: `*Widget` → widget, `*Dialog` → dialog, `*Window` → window
  - If still ambiguous, ask with `AskUserQuestion`

Derive the file name: `snake_case` of the class name (e.g., `UserProfileWidget` → `user_profile_widget.py`).

## Step 2: Find Destination Directory

Read `.qt-test.json` to find `app_entry` and derive the package root. Then:
- For `widget`: write to `src/<package>/ui/widgets/<filename>.py`
- For `dialog`: write to `src/<package>/ui/dialogs/<filename>.py`
- For `window`: write to `src/<package>/ui/<filename>.py`

If the directory doesn't exist, create it.

## Step 3: Generate Component

### Widget Template

```python
from PySide6.QtWidgets import QWidget, QVBoxLayout
from PySide6.QtCore import Signal


class <ClassName>(QWidget):
    """<Brief description of what this widget displays or does>."""

    # Signals — declare what this widget emits for parent components to respond to
    # Example: data_submitted = Signal(dict)

    def __init__(self, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self.setObjectName("<snake_case_name>")
        self._setup_ui()
        self._connect_signals()

    def _setup_ui(self) -> None:
        """Build and arrange child widgets."""
        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        # TODO: add widgets

    def _connect_signals(self) -> None:
        """Wire internal signal→slot connections."""
        pass
```

### Dialog Template

```python
from PySide6.QtWidgets import QDialog, QDialogButtonBox, QVBoxLayout, QWidget
from PySide6.QtCore import Signal


class <ClassName>(QDialog):
    """<Brief description of what data this dialog collects or presents>."""

    def __init__(self, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self.setObjectName("<snake_case_name>")
        self.setWindowTitle("<Human-Readable Title>")
        self.setModal(True)
        self.setMinimumWidth(360)
        self._setup_ui()

    def _setup_ui(self) -> None:
        layout = QVBoxLayout(self)

        # TODO: add form fields

        buttons = QDialogButtonBox(
            QDialogButtonBox.StandardButton.Ok | QDialogButtonBox.StandardButton.Cancel
        )
        buttons.accepted.connect(self._on_accept)
        buttons.rejected.connect(self.reject)
        layout.addWidget(buttons)

    def _on_accept(self) -> None:
        """Validate inputs before accepting. Call self.accept() if valid."""
        self.accept()

    # TODO: add accessor properties to retrieve dialog values
    # Example:
    # @property
    # def name(self) -> str:
    #     return self._name_edit.text().strip()
```

### Window Template

```python
from PySide6.QtWidgets import QMainWindow, QWidget, QVBoxLayout
from PySide6.QtCore import Qt


class <ClassName>(QMainWindow):
    """<Brief description of this window's purpose>."""

    def __init__(self, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self.setObjectName("<snake_case_name>")
        self.setWindowTitle("<Human-Readable Title>")
        self.setMinimumSize(640, 480)
        self._setup_ui()
        self._setup_menu()
        self._connect_signals()

    def _setup_ui(self) -> None:
        central = QWidget()
        self.setCentralWidget(central)
        layout = QVBoxLayout(central)
        # TODO: add widgets

    def _setup_menu(self) -> None:
        pass

    def _connect_signals(self) -> None:
        pass

    def closeEvent(self, event) -> None:
        # TODO: save state, stop timers/threads before closing
        super().closeEvent(event)
```

## Step 4: Report

After writing the file:
- Show the full path created
- Show the class header (first 10 lines — enough to confirm class name and constructor signature)
- Remind: run `pyside6-rcc` if adding icons, and set `setObjectName()` on all interactive child widgets

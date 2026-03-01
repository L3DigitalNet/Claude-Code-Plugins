---
name: qt-dialogs
description: >
  Qt dialog patterns — QDialog, QMessageBox, QFileDialog, QInputDialog, and custom modal/modeless dialogs. Use when creating confirmation prompts, file pickers, settings dialogs, custom data entry dialogs, or wizard-style multi-step dialogs.

  Trigger phrases: "dialog", "QMessageBox", "QFileDialog", "QInputDialog", "modal", "modeless", "settings dialog", "confirm dialog", "custom dialog", "file picker", "wizard", "popup"
version: 1.0.0
---

## Qt Dialog Patterns

### QMessageBox — Standard Prompts

```python
from PySide6.QtWidgets import QMessageBox

# Confirmation dialog
def confirm_delete(parent, item_name: str) -> bool:
    result = QMessageBox.question(
        parent,
        "Confirm Delete",
        f"Delete '{item_name}'? This cannot be undone.",
        QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
        QMessageBox.StandardButton.No,   # default button
    )
    return result == QMessageBox.StandardButton.Yes

# Error
QMessageBox.critical(parent, "Error", f"Failed to save: {error}")

# Warning
QMessageBox.warning(parent, "Warning", "File already exists. Overwrite?")

# Information
QMessageBox.information(parent, "Done", "Export completed successfully.")

# Custom buttons
msg = QMessageBox(parent)
msg.setWindowTitle("Unsaved Changes")
msg.setText("You have unsaved changes.")
msg.setInformativeText("Do you want to save before closing?")
save_btn = msg.addButton("Save", QMessageBox.ButtonRole.AcceptRole)
discard_btn = msg.addButton("Discard", QMessageBox.ButtonRole.DestructiveRole)
msg.addButton(QMessageBox.StandardButton.Cancel)
msg.exec()
if msg.clickedButton() is save_btn:
    self._save()
elif msg.clickedButton() is discard_btn:
    pass  # discard
# else: Cancel — do nothing
```

### QFileDialog — File and Directory Pickers

```python
from PySide6.QtWidgets import QFileDialog
from pathlib import Path

# Open single file
path, _ = QFileDialog.getOpenFileName(
    parent,
    "Open File",
    str(Path.home()),
    "CSV Files (*.csv);;Text Files (*.txt);;All Files (*)",
)
if path:
    self._load(Path(path))

# Open multiple files
paths, _ = QFileDialog.getOpenFileNames(parent, "Select Images", "", "Images (*.png *.jpg *.svg)")

# Save file
path, _ = QFileDialog.getSaveFileName(
    parent, "Save As", "export.csv", "CSV (*.csv)"
)
if path:
    self._export(Path(path))

# Select directory
directory = QFileDialog.getExistingDirectory(parent, "Select Output Folder")
```

The filter string format is `"Description (*.ext *.ext2);;Description2 (*.ext3)"`.

### Custom QDialog

```python
from PySide6.QtWidgets import (
    QDialog, QDialogButtonBox, QFormLayout, QLineEdit, QVBoxLayout
)
from PySide6.QtCore import Qt

class AddPersonDialog(QDialog):
    def __init__(self, parent=None) -> None:
        super().__init__(parent)
        self.setWindowTitle("Add Person")
        self.setModal(True)
        self.setMinimumWidth(300)
        self._setup_ui()

    def _setup_ui(self) -> None:
        layout = QVBoxLayout(self)

        form = QFormLayout()
        self._name_edit = QLineEdit()
        self._name_edit.setPlaceholderText("Full name")
        self._email_edit = QLineEdit()
        self._email_edit.setPlaceholderText("email@example.com")
        form.addRow("Name:", self._name_edit)
        form.addRow("Email:", self._email_edit)
        layout.addLayout(form)

        # Standard OK / Cancel buttons
        buttons = QDialogButtonBox(
            QDialogButtonBox.StandardButton.Ok | QDialogButtonBox.StandardButton.Cancel
        )
        buttons.accepted.connect(self._on_accept)
        buttons.rejected.connect(self.reject)
        layout.addWidget(buttons)

    def _on_accept(self) -> None:
        if not self._name_edit.text().strip():
            QMessageBox.warning(self, "Validation", "Name is required.")
            return
        self.accept()   # closes dialog and returns QDialog.Accepted

    def name(self) -> str:
        return self._name_edit.text().strip()

    def email(self) -> str:
        return self._email_edit.text().strip()

# Usage
dialog = AddPersonDialog(self)
if dialog.exec() == QDialog.DialogCode.Accepted:
    self._model.add_person(dialog.name(), dialog.email())
```

Use `QDialogButtonBox` for standard buttons — it respects platform button order conventions (OK/Cancel vs Cancel/OK).

### Modal vs Modeless

```python
# Modal — blocks input to parent window
dialog.setModal(True)
dialog.exec()      # blocks until closed

# Modeless — user can interact with parent
dialog.setModal(False)
dialog.show()      # non-blocking
dialog.raise_()    # bring to front
dialog.activateWindow()
```

For modeless dialogs, keep a reference to prevent garbage collection:
```python
self._settings_dialog = SettingsDialog(self)
self._settings_dialog.show()
```

### Settings Dialog Pattern

Settings dialogs should apply changes live (on change) or on explicit OK:

```python
class SettingsDialog(QDialog):
    settings_changed = Signal(dict)

    def __init__(self, settings: dict, parent=None) -> None:
        super().__init__(parent)
        self._original = dict(settings)
        self._current = dict(settings)
        self._setup_ui(settings)

    def _on_change(self) -> None:
        self._current["theme"] = self._theme_combo.currentText()
        self.settings_changed.emit(self._current)   # live preview

    def reject(self) -> None:
        self.settings_changed.emit(self._original)  # restore on cancel
        super().reject()
```

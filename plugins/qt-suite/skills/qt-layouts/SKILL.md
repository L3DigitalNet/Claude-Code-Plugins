---
name: qt-layouts
description: >
  Qt layout managers — arranging and sizing widgets within containers. Use when placing widgets, controlling resize behavior, building form layouts, creating splitters, nesting containers, or debugging widgets that don't appear where expected.

  Trigger phrases: "arrange widgets", "layout", "resize behavior", "QSplitter", "center widget", "widget not visible", "expand to fill", "fixed size", "stretch factor", "form layout", "grid layout", "spacing", "margins"
version: 1.0.0
---

## Qt Layout Managers

### Layout Hierarchy

Qt lays out widgets using layout objects attached to containers. Never call `setGeometry()` manually — use layouts.

```
QWidget (parent)
└── QVBoxLayout (attached via setLayout or constructor arg)
    ├── QLabel
    ├── QHBoxLayout (nested)
    │   ├── QPushButton
    │   └── QPushButton
    └── QTextEdit
```

### Core Layout Types

| Layout | Use case |
|--------|----------|
| `QVBoxLayout` | Stack items vertically |
| `QHBoxLayout` | Stack items horizontally |
| `QGridLayout` | Row/column grid |
| `QFormLayout` | Label + field pairs |
| `QStackedLayout` | Multiple pages, one visible |

### Basic Usage

```python
from PySide6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QLabel, QPushButton, QSizePolicy
)

class MyWidget(QWidget):
    def __init__(self) -> None:
        super().__init__()
        # Pass widget as parent to layout — attaches layout automatically
        main_layout = QVBoxLayout(self)
        main_layout.setContentsMargins(12, 12, 12, 12)
        main_layout.setSpacing(8)

        label = QLabel("Hello")
        main_layout.addWidget(label)

        # Nested horizontal row
        button_row = QHBoxLayout()
        button_row.addWidget(QPushButton("OK"))
        button_row.addWidget(QPushButton("Cancel"))
        main_layout.addLayout(button_row)
```

Pass the parent widget to the layout constructor (`QVBoxLayout(self)`) — this is cleaner than calling `self.setLayout(layout)` separately, and prevents forgetting to attach the layout.

### Stretch and Size Policy

**Stretch factors** distribute extra space when the window resizes:
```python
layout.addWidget(sidebar, stretch=1)    # gets 1/4 of extra space
layout.addWidget(main_area, stretch=3)  # gets 3/4 of extra space
```

**Size policy** controls how individual widgets resize:
```python
# Expand to fill available horizontal space
widget.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Preferred)

# Fixed size — never grows or shrinks
widget.setSizePolicy(QSizePolicy.Policy.Fixed, QSizePolicy.Policy.Fixed)
widget.setFixedSize(200, 40)
```

Common policies: `Fixed`, `Minimum`, `Maximum`, `Preferred`, `Expanding`, `MinimumExpanding`.

**Spacers:**
```python
from PySide6.QtWidgets import QSpacerItem, QSizePolicy

# Push buttons to the right
layout.addStretch()                          # flexible spacer
layout.addSpacing(16)                        # fixed-size gap
layout.addItem(QSpacerItem(                  # explicit spacer
    40, 20, QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Minimum
))
```

### QGridLayout

```python
grid = QGridLayout(self)
grid.addWidget(QLabel("Name:"),    0, 0)   # row, col
grid.addWidget(name_edit,          0, 1)
grid.addWidget(QLabel("Email:"),   1, 0)
grid.addWidget(email_edit,         1, 1)
grid.addWidget(submit_btn,         2, 0, 1, 2)  # row, col, rowspan, colspan

# Column stretch — second column takes all extra space
grid.setColumnStretch(0, 0)
grid.setColumnStretch(1, 1)
```

### QFormLayout

Use for settings dialogs and data entry forms — automatically handles label alignment:
```python
from PySide6.QtWidgets import QFormLayout

form = QFormLayout(self)
form.addRow("Username:", QLineEdit())
form.addRow("Password:", QLineEdit())
form.addRow("", QPushButton("Login"))   # empty label for button row
```

### QSplitter

```python
from PySide6.QtWidgets import QSplitter
from PySide6.QtCore import Qt

splitter = QSplitter(Qt.Orientation.Horizontal)
splitter.addWidget(sidebar)
splitter.addWidget(main_content)
splitter.setSizes([200, 600])           # initial pixel widths
splitter.setStretchFactor(0, 0)         # sidebar: don't stretch
splitter.setStretchFactor(1, 1)         # main: takes all extra space

# Persist splitter state
settings.setValue("splitter", splitter.saveState())
splitter.restoreState(settings.value("splitter"))
```

### Centering a Widget in Its Parent

```python
# Via layout
layout = QVBoxLayout(self)
layout.addStretch()
layout.addWidget(target_widget, alignment=Qt.AlignmentFlag.AlignHCenter)
layout.addStretch()
```

### Debugging Layout Issues

**Widget appears but is zero-size:**
- Set a size hint: `widget.setMinimumSize(100, 40)` or override `sizeHint()`
- Check that the parent layout is actually attached (`self.layout()` returns non-None)

**Widget not visible at all:**
- Confirm `show()` was called (or parent is visible)
- Check `isHidden()` and `isVisible()`
- Ensure no `setFixedSize(0, 0)` or zero margins collapsing the widget

**Layout ignoring size changes:**
- Call `layout.invalidate()` after programmatic geometry changes
- Verify size policy is not `Fixed` when you want expansion

**Margins and spacing defaults:**
- Default content margins: 9px on all sides (varies by style)
- Reset to zero: `layout.setContentsMargins(0, 0, 0, 0)` and `layout.setSpacing(0)`

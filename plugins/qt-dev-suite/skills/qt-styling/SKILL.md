---
name: qt-styling
description: >
  Qt stylesheets (QSS) and theming — custom widget appearance, dark/light mode, color palettes, and platform-consistent styling. Use when applying custom styles, implementing dark mode, theming an application, styling specific widget states, or overriding platform defaults.

  Trigger phrases: "stylesheet", "QSS", "theme", "dark mode", "custom widget appearance", "style widget", "QPalette", "widget color", "hover style", "disabled style", "app theme", "visual style"
version: 1.0.0
---

## Qt Stylesheets (QSS)

### Applying Stylesheets

```python
# Application-wide (affects all widgets)
app.setStyleSheet("""
    QWidget {
        font-family: "Inter", "Segoe UI", sans-serif;
        font-size: 13px;
    }
    QPushButton {
        background-color: #0078d4;
        color: white;
        border: none;
        border-radius: 4px;
        padding: 6px 16px;
        min-width: 80px;
    }
    QPushButton:hover {
        background-color: #106ebe;
    }
    QPushButton:pressed {
        background-color: #005a9e;
    }
    QPushButton:disabled {
        background-color: #cccccc;
        color: #888888;
    }
""")

# Per-widget (overrides application stylesheet)
my_button.setStyleSheet("background-color: #e74c3c; color: white;")
```

### QSS Selector Syntax

```css
/* Type selector */
QPushButton { ... }

/* Class selector (use setProperty for custom classes) */
QPushButton[class="danger"] { background-color: #e74c3c; }

/* Object name selector */
QPushButton#submit_btn { font-weight: bold; }

/* Child selector — direct children only */
QDialog > QPushButton { margin: 4px; }

/* Descendant selector */
QGroupBox QPushButton { padding: 4px; }

/* Pseudo-states */
QLineEdit:focus { border: 2px solid #0078d4; }
QCheckBox:checked { color: #0078d4; }
QListWidget::item:selected { background: #0078d4; color: white; }

/* Sub-controls */
QComboBox::drop-down { border: none; width: 20px; }
QScrollBar::handle:vertical { background: #888; border-radius: 4px; }
```

### Dark/Light Mode

**Detect system preference:**
```python
from PySide6.QtGui import QPalette
from PySide6.QtCore import Qt

def is_dark_mode(app: QApplication) -> bool:
    palette = app.palette()
    bg = palette.color(QPalette.ColorRole.Window)
    return bg.lightness() < 128
```

**Programmatic dark theme via QPalette (no stylesheet needed):**
```python
from PySide6.QtGui import QPalette, QColor
from PySide6.QtCore import Qt

def apply_dark_palette(app: QApplication) -> None:
    palette = QPalette()
    palette.setColor(QPalette.ColorRole.Window,          QColor(32, 32, 32))
    palette.setColor(QPalette.ColorRole.WindowText,      QColor(220, 220, 220))
    palette.setColor(QPalette.ColorRole.Base,            QColor(25, 25, 25))
    palette.setColor(QPalette.ColorRole.AlternateBase,   QColor(40, 40, 40))
    palette.setColor(QPalette.ColorRole.Text,            QColor(220, 220, 220))
    palette.setColor(QPalette.ColorRole.Button,          QColor(48, 48, 48))
    palette.setColor(QPalette.ColorRole.ButtonText,      QColor(220, 220, 220))
    palette.setColor(QPalette.ColorRole.Highlight,       QColor(0, 120, 212))
    palette.setColor(QPalette.ColorRole.HighlightedText, Qt.GlobalColor.white)
    palette.setColor(QPalette.ColorRole.Link,            QColor(64, 160, 255))
    app.setPalette(palette)
```

**QSS-based theme switching:**
```python
class ThemeManager:
    def __init__(self, app: QApplication) -> None:
        self._app = app

    def apply_theme(self, theme: str) -> None:  # "light" | "dark"
        path = Path(__file__).parent.parent / "resources" / f"{theme}.qss"
        self._app.setStyleSheet(path.read_text())
```

Load QSS from files for maintainability — inline strings become unwieldy beyond a few rules.

### Dynamic Property-Based Styling

Set custom properties to switch styles without subclassing:

```python
# Mark a button as "primary"
btn.setProperty("variant", "primary")
btn.style().unpolish(btn)   # force style re-evaluation
btn.style().polish(btn)

# QSS rule
"""
QPushButton[variant="primary"] {
    background: #0078d4;
    color: white;
    font-weight: bold;
}
QPushButton[variant="danger"] {
    background: #d32f2f;
    color: white;
}
"""
```

Always call `unpolish` + `polish` after changing a property — Qt caches style results and won't re-evaluate otherwise.

### Platform Fusion Style

For consistent cross-platform appearance, force the Fusion style:
```python
from PySide6.QtWidgets import QStyleFactory
app.setStyle(QStyleFactory.create("Fusion"))
```

Fusion renders identically on Windows, macOS, and Linux. Use it as the base when applying custom QSS, because native styles (Windows11, macOS) partially ignore QSS rules.

### QSS Limitations

- QSS has no variables or inheritance — use Python to template the stylesheet string
- Not all sub-controls are styleable — some complex widgets (QCalendarWidget, QMdiArea) have limited QSS support
- `border-radius` on `QGroupBox` requires `background-color` to be set or it's ignored
- `margin` and `padding` interact with `border` — box model differs from CSS in some cases

---
name: qt-resources
description: >
  Qt resource system — .qrc files, embedding icons and assets, loading resources at runtime, and using pyrcc6 or PySide6-rcc. Use when bundling icons, images, or other files into the application, loading resources via ":/" paths, or migrating from a file-system asset approach.

  Trigger phrases: ".qrc file", "embed icon", "pyrcc6", "PySide6-rcc", "bundled assets", "resource path", ":/icons/", "QIcon", "QPixmap from resources", "bundle image"
version: 1.0.0
---

## Qt Resource System

### .qrc File Format

```xml
<!-- resources/resources.qrc -->
<!DOCTYPE RCC>
<RCC version="1.0">
  <qresource prefix="/icons">
    <file alias="app.png">icons/app.png</file>
    <file alias="save.svg">icons/save.svg</file>
    <file alias="open.svg">icons/open.svg</file>
  </qresource>
  <qresource prefix="/themes">
    <file>dark.qss</file>
    <file>light.qss</file>
  </qresource>
  <qresource prefix="/data">
    <file>default_config.json</file>
  </qresource>
</RCC>
```

File paths in `.qrc` are relative to the `.qrc` file's location. The `alias` attribute sets the name used at runtime.

### Compiling Resources (Python)

**PySide6:**
```bash
pyside6-rcc resources/resources.qrc -o src/myapp/resources/rc_resources.py
```

**PyQt6:**
```bash
pyrcc6 resources/resources.qrc -o src/myapp/resources/rc_resources.py
```

Add to `pyproject.toml` build scripts or a `Makefile` to keep in sync. The compiled file imports cleanly:

```python
# src/myapp/resources/__init__.py
from . import rc_resources  # noqa: F401 — side-effect import registers resources
```

Import `rc_resources` before any code that uses `:/` paths. The module-level import in `resources/__init__.py` is the cleanest approach — it runs once when the package is first imported.

### Using Resources at Runtime

```python
from PySide6.QtGui import QIcon, QPixmap

# Icons
icon = QIcon(":/icons/save.svg")
button.setIcon(icon)
button.setIconSize(QSize(16, 16))

# Pixmaps
pixmap = QPixmap(":/icons/app.png")
label.setPixmap(pixmap.scaled(64, 64, Qt.AspectRatioMode.KeepAspectRatio))

# Text files (themes, config)
from PySide6.QtCore import QFile, QTextStream

file = QFile(":/themes/dark.qss")
if file.open(QFile.OpenModeFlag.ReadOnly | QFile.OpenModeFlag.Text):
    stream = QTextStream(file)
    stylesheet = stream.readAll()
    file.close()
```

### Inline Resource Loading (No Compile Step)

For small assets during development, embed directly:

```python
import base64
from PySide6.QtGui import QIcon, QPixmap
from PySide6.QtCore import QByteArray

def icon_from_base64(data: str) -> QIcon:
    b = QByteArray.fromBase64(data.encode())
    pix = QPixmap()
    pix.loadFromData(b)
    return QIcon(pix)
```

### SVG Icons

SVGs are the preferred format — they scale perfectly at all DPIs:

```python
from PySide6.QtSvgWidgets import QSvgWidget
from PySide6.QtGui import QIcon

# In a layout
svg = QSvgWidget(":/icons/logo.svg")
svg.setFixedSize(48, 48)

# As window icon (QIcon handles SVG natively on most platforms)
self.setWindowIcon(QIcon(":/icons/app.svg"))
```

### High-DPI (Retina/4K) Support

```python
# In main() — before QApplication
os.environ["QT_ENABLE_HIGHDPI_SCALING"] = "1"

app = QApplication(sys.argv)
app.setHighDpiScaleFactorRoundingPolicy(
    Qt.HighDpiScaleFactorRoundingPolicy.PassThrough
)
```

Use SVG icons wherever possible. For raster icons, provide `@2x` variants:
```xml
<qresource prefix="/icons">
  <file alias="save.png">icons/save.png</file>
  <file alias="save@2x.png">icons/save@2x.png</file>
</qresource>
```

Qt automatically selects `@2x` variants on high-DPI displays.

### Project Automation

Add resource compilation to your build process:

```toml
# pyproject.toml — using hatch
[tool.hatch.build.hooks.custom]
path = "build_hooks.py"
```

```python
# build_hooks.py
import subprocess
from pathlib import Path

def build_editable(config, ...):
    subprocess.run([
        "pyside6-rcc",
        "resources/resources.qrc",
        "-o", "src/myapp/resources/rc_resources.py"
    ], check=True)
```

Or a simple `Makefile` target:
```makefile
resources: resources/resources.qrc
	pyside6-rcc $< -o src/myapp/resources/rc_resources.py
```

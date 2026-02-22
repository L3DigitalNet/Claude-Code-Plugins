# QML Architecture: QQmlApplicationEngine Bootstrap

Minimal PySide6 + QML application wiring. `engine.rootObjects()` returns empty on load failure — always guard it.

## Python Entry Point

```python
# src/myapp/__main__.py
import sys
from pathlib import Path
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine

def main() -> None:
    app = QGuiApplication(sys.argv)
    app.setApplicationName("MyApp")

    engine = QQmlApplicationEngine()
    qml_file = Path(__file__).parent / "ui" / "main.qml"
    engine.load(str(qml_file))

    if not engine.rootObjects():
        sys.exit(-1)

    sys.exit(app.exec())
```

## Root QML File

```qml
// src/myapp/ui/main.qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: root
    visible: true
    width: 800
    height: 600
    title: "MyApp"

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 8

        Label {
            text: "Hello, Qt Quick!"
            font.pixelSize: 24
        }

        Button {
            text: "Click Me"
            onClicked: console.log("Button clicked")
        }
    }
}
```

## QRC Resource Files

Use QRC for all QML assets — keeps paths consistent across dev and installed builds:

```xml
<qresource prefix="/ui">
  <file>main.qml</file>
  <file>components/Card.qml</file>
</qresource>
<qresource prefix="/icons">
  <file>logo.svg</file>
</qresource>
```

```python
# Load from QRC (preferred over filesystem paths in shipped apps)
engine.load("qrc:/ui/main.qml")
```

```qml
// Reference QRC resources in QML
Image { source: "qrc:/icons/logo.svg" }
```

## Debugging

```qml
// Print to console from QML
Component.onCompleted: console.log("loaded, width:", width)
```

```bash
QML_IMPORT_TRACE=1 python -m myapp      # trace QML import resolution
QSG_VISUALIZE=overdraw python -m myapp  # visualize rendering overdraw
```

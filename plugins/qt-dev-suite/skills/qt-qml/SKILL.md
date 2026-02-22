---
name: qt-qml
description: >
  QML and Qt Quick — declarative UI language for modern Qt applications. Use when building a QML-based UI, embedding QML in a Python/C++ app, exposing Python/C++ objects to QML, creating QML components, or choosing between QML and widgets.

  Trigger phrases: "QML", "Qt Quick", "declarative UI", "QQmlApplicationEngine", "expose to QML", "QML component", "QML signal", "pyqtProperty", "QML vs widgets", "QtQuick.Controls", "Item", "Rectangle"
version: 1.0.0
---

## QML and Qt Quick

### QML vs Widgets: When to Choose QML

| Use QML when... | Use Widgets when... |
|-----------------|---------------------|
| Building modern, animated, fluid UIs | Building traditional desktop tools |
| Targeting mobile or embedded | Heavy data tables and forms |
| Designers are involved in the UI | Rich text editing required |
| GPU-accelerated rendering needed | Complex platform widget integration |
| Writing a new app from scratch | Extending an existing widget app |

For new Python/PySide6 desktop applications, QML offers better visual results with less code. For data-heavy enterprise tools, widgets remain the pragmatic choice.

### Minimal PySide6 + QML Application

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

### Official Best Practices (Qt Quick)

**1. Type-safe property declarations** — Always use explicit types, not `var`:
```qml
// WRONG — prevents static analysis, unclear errors
property var name
property var count

// CORRECT
property string name
property int count
property MyModel optionsModel
```

**2. Prefer declarative bindings over imperative assignments:**
```qml
// WRONG — imperative assignment overwrites bindings, double-evaluates, breaks Qt Design Studio
Rectangle {
    Component.onCompleted: color = "red"
}

// CORRECT — declarative binding, evaluates once at load
Rectangle {
    color: "red"
}
```

**3. Interaction signals over value-change signals:**
```qml
// WRONG — valueChanged fires on clamping/rounding, causes event cascades
Slider { onValueChanged: model.update(value) }

// CORRECT — moved only fires on user interaction
Slider { onMoved: model.update(value) }
```

**4. Don't anchor the immediate children of Layouts:**
```qml
// WRONG — anchors on direct Layout children cause binding loops
RowLayout {
    Rectangle { anchors.fill: parent }   // broken
}

// CORRECT — use Layout attached properties
RowLayout {
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 40
    }
}
```

**5. Don't customize native styles** — Windows and macOS native styles ignore QSS. Base all custom styling on cross-platform styles: `Basic`, `Fusion`, `Material`, or `Universal`:
```qml
// In main() — must be set before QGuiApplication
QQuickStyle.setStyle("Material")
```

**6. Make all user-visible strings translatable from the start:**
```qml
Label { text: qsTr("Save File") }
Button { text: qsTr("Cancel") }
```

### Exposing Python Objects to QML

**Method 1: Required Properties (preferred — modern Qt 6 approach)**

Instead of `setContextProperty`, use `setInitialProperties` to push named objects in via `required property`:

```python
# In Python — set initial properties before loading
backend = Backend()
engine.setInitialProperties({"backend": backend})
engine.load("qrc:/ui/main.qml")
```

```qml
// In QML root — declare as required property
ApplicationWindow {
    required property Backend backend
    // ...
}
```

`required property` is type-checked at load time; `setContextProperty` is untyped and global. Use required properties for new code.

**Method 2: Context Property (still valid for existing code)**
```python
from PySide6.QtCore import QObject, Signal, Property, Slot

class Backend(QObject):
    countChanged = Signal()

    def __init__(self) -> None:
        super().__init__()
        self._count = 0

    @Property(int, notify=countChanged)
    def count(self) -> int:
        return self._count

    @Slot()                          # @Slot is REQUIRED for QML invocation
    def increment(self) -> None:
        self._count += 1
        self.countChanged.emit()

    @Slot(str, result=str)           # return type declared in @Slot
    def greet(self, name: str) -> str:
        return f"Hello, {name}!"

backend = Backend()
engine.rootContext().setContextProperty("backend", backend)
```

```qml
Label { text: "Count: " + backend.count }
Button { onClicked: backend.increment() }
Label { text: backend.greet("World") }
```

**@Slot is mandatory for QML-callable methods.** QML has no `Q_INVOKABLE` equivalent — any Python method callable from QML must have `@Slot`. Missing it causes `TypeError` at runtime.

**Method 3: Registered QML Type (reusable, namespaced)**
```python
from PySide6.QtQml import QmlElement

QML_IMPORT_NAME = "com.myorg.myapp"
QML_IMPORT_MAJOR_VERSION = 1

@QmlElement
class PersonModel(QAbstractListModel):
    ...
```

```qml
import com.myorg.myapp 1.0

PersonModel { id: model }
ListView { model: model; ... }
```

### QML Signals and Connections

```qml
// Define signal in QML
signal dataChanged(var newData)

// Connect in QML
Connections {
    target: someItem
    function onDataChanged(data) {
        console.log("Got:", data)
    }
}

// Connect QML signal to Python slot
engine.rootObjects()[0].dataChanged.connect(backend.on_data_changed)
```

### Common QtQuick.Controls Components

```qml
import QtQuick.Controls

// Layout containers
ColumnLayout { ... }
RowLayout { ... }
GridLayout { columns: 3; ... }
StackLayout { currentIndex: tabBar.currentIndex; ... }

// Input
TextField { placeholderText: "Enter name..." }
TextArea { wrapMode: TextArea.Wrap }
ComboBox { model: ["Option 1", "Option 2"] }
CheckBox { text: "Enable feature" }
Slider { from: 0; to: 100; value: 50 }
SpinBox { from: 0; to: 999 }

// Display
Label { text: "Hello"; font.bold: true }
Image { source: "qrc:/icons/logo.svg" }
ProgressBar { value: 0.75 }

// Containers
ScrollView { clip: true; ListView { ... } }
GroupBox { title: "Settings"; ... }
TabBar { id: tabBar; TabButton { text: "Tab 1" } }
```

### Resource Files in QML

Use QRC for all QML assets:
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
# Load from QRC
engine.load("qrc:/ui/main.qml")
```

```qml
// Reference QRC resources
Image { source: "qrc:/icons/logo.svg" }
```

### Debugging QML

```qml
// Print to console
Component.onCompleted: console.log("loaded, width:", width)

// Qt Quick Inspector (Qt Creator integration)
// QML_IMPORT_PATH env var for custom import paths
```

```bash
QML_IMPORT_TRACE=1 python -m myapp   # trace QML imports
QSG_VISUALIZE=overdraw python -m myapp  # visualize rendering
```

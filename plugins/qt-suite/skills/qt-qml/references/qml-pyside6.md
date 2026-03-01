# QML + PySide6: Exposing Python Objects to QML

Three methods, listed newest-to-oldest. Prefer Method 1 for new code.

## Method 1: Required Properties (preferred — Qt 6 idiomatic)

`setInitialProperties` + `required property` gives type-checked, scoped injection.
`setContextProperty` is untyped and global — avoid for new code.

```python
# Python — set before engine.load()
backend = Backend()
engine.setInitialProperties({"backend": backend})
engine.load("qrc:/ui/main.qml")
```

```qml
// QML root — declare as required property; type-checked at load time
ApplicationWindow {
    required property Backend backend
    // access via: backend.count, backend.increment(), etc.
}
```

## Method 2: Context Property (valid for existing code)

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

**`@Slot` is mandatory for QML-callable methods.** QML has no `Q_INVOKABLE` equivalent — any Python method callable from QML must have `@Slot`. Missing it causes `TypeError` at runtime.

## Method 3: Registered QML Type (reusable, namespaced)

Use when the Python class is a model or component that QML should instantiate directly.

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

# QML Signals and Connections

## Defining and Connecting Signals in QML

```qml
// Define signal in a QML component
signal dataChanged(var newData)

// Connect in QML using Connections block
Connections {
    target: someItem
    function onDataChanged(data) {
        console.log("Got:", data)
    }
}
```

## Connecting QML Signals to Python Slots

```python
# After engine.load(), connect QML signal to Python slot
engine.rootObjects()[0].dataChanged.connect(backend.on_data_changed)
```

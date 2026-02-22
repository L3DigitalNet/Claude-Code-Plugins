# Common QtQuick.Controls Components

Quick reference for the standard component palette. All require `import QtQuick.Controls`.

## Layout Containers

```qml
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout { spacing: 8; ... }
RowLayout { spacing: 4; ... }
GridLayout { columns: 3; ... }
StackLayout { currentIndex: tabBar.currentIndex; ... }
```

## Input Controls

```qml
TextField { placeholderText: "Enter name..." }
TextArea { wrapMode: TextArea.Wrap }
ComboBox { model: ["Option 1", "Option 2"] }
CheckBox { text: "Enable feature" }
Slider { from: 0; to: 100; value: 50 }
SpinBox { from: 0; to: 999 }
```

## Display

```qml
Label { text: "Hello"; font.bold: true }
Image { source: "qrc:/icons/logo.svg" }
ProgressBar { value: 0.75 }
```

## Containers

```qml
ScrollView { clip: true; ListView { ... } }
GroupBox { title: "Settings"; ... }
TabBar { id: tabBar; TabButton { text: "Tab 1" } }
```

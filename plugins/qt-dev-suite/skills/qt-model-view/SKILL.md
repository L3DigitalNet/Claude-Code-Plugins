---
name: qt-model-view
description: >
  Qt Model/View architecture — QAbstractItemModel, table/list/tree views, item delegates, and proxy models. Use when displaying tabular data, building a list with custom items, implementing a tree, creating a sortable/filterable table, or writing a custom item delegate.

  Trigger phrases: "QAbstractItemModel", "table view", "list model", "QTableView", "QListView", "tree view", "item delegate", "sort table", "filter model", "QSortFilterProxyModel", "custom model", "model data"
version: 1.0.0
---

## Qt Model/View Architecture

### Architecture Overview

```
Data Source ──→ Model ──→ [Proxy Model] ──→ View ──→ Delegate (renders cells)
                 ↕                            ↕
              QAbstractItemModel         QAbstractItemView
```

Separate data (model) from presentation (view). The delegate handles painting and editing per-cell. Proxy models layer transformations (sort, filter) without modifying the source model.

### Choosing a Model Base Class

| Base class | When to use |
|------------|-------------|
| `QStringListModel` | Simple list of strings |
| `QStandardItemModel` | Quick prototype or small dataset |
| `QAbstractListModel` | Custom list with single column |
| `QAbstractTableModel` | Custom table with rows × columns |
| `QAbstractItemModel` | Tree structures with parent/child |

For anything non-trivial, subclass `QAbstractTableModel` or `QAbstractListModel` — `QStandardItemModel` has poor performance with large datasets and poor testability.

### Custom Table Model

```python
from PySide6.QtCore import QAbstractTableModel, QModelIndex, Qt
from PySide6.QtGui import QColor

class PersonTableModel(QAbstractTableModel):
    HEADERS = ["Name", "Age", "Email"]

    def __init__(self, data: list[dict], parent=None) -> None:
        super().__init__(parent)
        self._data = data

    # --- Required overrides ---

    def rowCount(self, parent: QModelIndex = QModelIndex()) -> int:
        return 0 if parent.isValid() else len(self._data)

    def columnCount(self, parent: QModelIndex = QModelIndex()) -> int:
        return 0 if parent.isValid() else len(self.HEADERS)

    def data(self, index: QModelIndex, role: int = Qt.ItemDataRole.DisplayRole) -> object:
        if not index.isValid():
            return None
        row, col = index.row(), index.column()
        item = self._data[row]

        match role:
            case Qt.ItemDataRole.DisplayRole:
                return str(item[self.HEADERS[col].lower()])
            case Qt.ItemDataRole.BackgroundRole if item.get("active") is False:
                return QColor("#f5f5f5")
            case Qt.ItemDataRole.ToolTipRole:
                return f"Row {row}: {item}"
            case _:
                return None

    def headerData(self, section: int, orientation: Qt.Orientation, role: int = Qt.ItemDataRole.DisplayRole) -> object:
        if role == Qt.ItemDataRole.DisplayRole and orientation == Qt.Orientation.Horizontal:
            return self.HEADERS[section]
        return None

    # --- Mutation support ---

    def setData(self, index: QModelIndex, value: object, role: int = Qt.ItemDataRole.EditRole) -> bool:
        if not index.isValid() or role != Qt.ItemDataRole.EditRole:
            return False
        self._data[index.row()][self.HEADERS[index.column()].lower()] = value
        self.dataChanged.emit(index, index, [role])
        return True

    def flags(self, index: QModelIndex) -> Qt.ItemFlag:
        base = super().flags(index)
        return base | Qt.ItemFlag.ItemIsEditable

    # --- Batch updates (correct reset pattern) ---

    def replace_all(self, new_data: list[dict]) -> None:
        self.beginResetModel()
        self._data = new_data
        self.endResetModel()

    def append_row(self, item: dict) -> None:
        pos = len(self._data)
        self.beginInsertRows(QModelIndex(), pos, pos)
        self._data.append(item)
        self.endInsertRows()
```

Always bracket mutations with `begin*/end*` methods (`beginInsertRows`, `beginRemoveRows`, `beginResetModel`). Skipping them causes views to lose sync with the model.

### Connecting Model to View

```python
from PySide6.QtWidgets import QTableView

model = PersonTableModel(people_data)
view = QTableView()
view.setModel(model)

# Tuning
view.horizontalHeader().setStretchLastSection(True)
view.setSelectionBehavior(QTableView.SelectionBehavior.SelectRows)
view.setSortingEnabled(True)   # requires QSortFilterProxyModel for custom models
view.resizeColumnsToContents()
```

### Sort and Filter with QSortFilterProxyModel

```python
from PySide6.QtCore import QSortFilterProxyModel, Qt

source_model = PersonTableModel(data)
proxy = QSortFilterProxyModel()
proxy.setSourceModel(source_model)
proxy.setFilterCaseSensitivity(Qt.CaseSensitivity.CaseInsensitive)
proxy.setFilterKeyColumn(0)   # filter on "Name" column

view.setModel(proxy)
view.setSortingEnabled(True)

# Filter dynamically from a search box
# setFilterRegularExpression is preferred for new code (uses QRegularExpression internally)
search_box.textChanged.connect(proxy.setFilterRegularExpression)

# For modifying multiple filter parameters efficiently, use beginFilterChange/endFilterChange
# rather than calling invalidateFilter() after each change
```

For custom filter logic, subclass `QSortFilterProxyModel` and override `filterAcceptsRow`.

### Custom Item Delegate

Use delegates to render non-text data (progress bars, icons, custom widgets):

```python
from PySide6.QtWidgets import QStyledItemDelegate, QStyleOptionViewItem, QApplication
from PySide6.QtGui import QPainter
from PySide6.QtCore import QRect, Qt

class ProgressDelegate(QStyledItemDelegate):
    def paint(self, painter: QPainter, option: QStyleOptionViewItem, index: QModelIndex) -> None:
        value = index.data(Qt.ItemDataRole.DisplayRole)
        if not isinstance(value, int):
            super().paint(painter, option, index)
            return
        # Draw progress bar using the style
        opt = QStyleOptionProgressBar()
        opt.rect = option.rect.adjusted(2, 4, -2, -4)
        opt.minimum = 0
        opt.maximum = 100
        opt.progress = value
        opt.text = f"{value}%"
        opt.textVisible = True
        QApplication.style().drawControl(QStyle.ControlElement.CE_ProgressBar, opt, painter)

view.setItemDelegateForColumn(2, ProgressDelegate(view))
```

### Key Rules

- Never access `self._data` directly from outside the model — always go through the model API
- `rowCount()` and `columnCount()` must return 0 when `parent.isValid()` (Qt tree contract, even for tables)
- `dataChanged` must be emitted with the exact changed index range — emitting the full model unnecessarily forces full view repaint
- For large datasets (>10k rows), consider lazy loading via `canFetchMore()` / `fetchMore()`

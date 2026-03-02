---
name: qt-settings
description: >
  Persistent application settings using QSettings — storing and restoring user preferences, window geometry, recent files, and application state. Use when saving user preferences, persisting window size/position, storing recent file lists, or managing application configuration.

  Trigger phrases: "QSettings", "persistent settings", "save preferences", "restore window", "user preferences", "remember state", "save window geometry", "recent files", "app configuration", "settings persistence"
version: 1.0.0
---

## QSettings — Persistent Application Settings

### Setup and Initialization

Set application metadata before first `QSettings` use — these seed the default storage path:

```python
app.setApplicationName("MyApp")
app.setOrganizationName("MyOrg")
app.setOrganizationDomain("myorg.com")
```

Default storage locations (no path argument needed):
- **Windows**: Registry `HKCU\Software\MyOrg\MyApp`
- **macOS**: `~/Library/Preferences/com.myorg.myapp.plist`
- **Linux**: `~/.config/MyOrg/MyApp.ini`

### Basic Usage

```python
from PySide6.QtCore import QSettings

# Construct with no args — uses app name/org set on QApplication
settings = QSettings()

# Write
settings.setValue("theme", "dark")
settings.setValue("font_size", 13)
settings.setValue("recent_files", ["/path/to/file1.csv", "/path/to/file2.csv"])

# Read with default
theme = settings.value("theme", "light")
font_size = settings.value("font_size", 12, type=int)   # type= forces cast
recent = settings.value("recent_files", [], type=list)

# Delete
settings.remove("obsolete_key")

# Check existence
if settings.contains("theme"):
    ...

# Force write to disk (normally deferred)
settings.sync()
```

Always provide a default in `settings.value()` — returns `None` otherwise, which causes type errors when passed to Qt methods expecting a specific type.

### Groups (Namespacing)

```python
settings = QSettings()

# Group context manager (not built-in — use begin/end)
settings.beginGroup("window")
settings.setValue("width", 1200)
settings.setValue("height", 800)
settings.setValue("maximized", False)
settings.endGroup()

# Read grouped values
settings.beginGroup("window")
width = settings.value("width", 800, type=int)
settings.endGroup()

# Or use slash-delimited keys
settings.setValue("window/width", 1200)
width = settings.value("window/width", 800, type=int)
```

### Window Geometry (Common Pattern)

```python
class MainWindow(QMainWindow):
    def __init__(self) -> None:
        super().__init__()
        self._restore_geometry()

    def closeEvent(self, event) -> None:
        self._save_geometry()
        super().closeEvent(event)

    def _save_geometry(self) -> None:
        settings = QSettings()
        settings.setValue("window/geometry", self.saveGeometry())
        settings.setValue("window/state", self.saveState())
        settings.setValue("window/maximized", self.isMaximized())

    def _restore_geometry(self) -> None:
        settings = QSettings()
        geometry = settings.value("window/geometry")
        if geometry:
            self.restoreGeometry(geometry)
        state = settings.value("window/state")
        if state:
            self.restoreState(state)
```

`saveGeometry()` and `restoreGeometry()` handle multi-monitor setups correctly.

### Recent Files List

```python
class RecentFilesManager:
    MAX_RECENT = 10
    KEY = "recent_files"

    def __init__(self) -> None:
        self._settings = QSettings()

    def add(self, path: str) -> None:
        files = self.all()
        if path in files:
            files.remove(path)
        files.insert(0, path)
        self._settings.setValue(self.KEY, files[:self.MAX_RECENT])

    def all(self) -> list[str]:
        return self._settings.value(self.KEY, [], type=list)

    def clear(self) -> None:
        self._settings.remove(self.KEY)
```

### Settings Dialog Integration

```python
class SettingsDialog(QDialog):
    def _load_settings(self) -> None:
        s = QSettings()
        self._theme_combo.setCurrentText(s.value("theme", "light"))
        self._font_spin.setValue(s.value("font_size", 12, type=int))

    def _save_settings(self) -> None:
        s = QSettings()
        s.setValue("theme", self._theme_combo.currentText())
        s.setValue("font_size", self._font_spin.value())
```

### INI File (Portable / Version-Controlled Config)

For config files that should be next to the executable or in a known location:

```python
config_path = Path(QStandardPaths.writableLocation(
    QStandardPaths.StandardLocation.AppConfigLocation
)) / "settings.ini"
config_path.parent.mkdir(parents=True, exist_ok=True)

settings = QSettings(str(config_path), QSettings.Format.IniFormat)
```

### QStandardPaths — Platform-Correct File Locations

```python
from PySide6.QtCore import QStandardPaths

# User data (documents, exports)
data_dir = QStandardPaths.writableLocation(QStandardPaths.StandardLocation.AppDataLocation)

# Cache
cache_dir = QStandardPaths.writableLocation(QStandardPaths.StandardLocation.CacheLocation)

# Temp
temp_dir = QStandardPaths.writableLocation(QStandardPaths.StandardLocation.TempLocation)
```

Use `QStandardPaths` instead of hardcoding `~/.config` or `%APPDATA%` — it returns the correct platform path automatically.

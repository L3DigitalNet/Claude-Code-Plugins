---
name: qt-packaging
description: >
  Packaging and distributing Qt Python applications — PyInstaller, Briefcase, and platform-specific build configurations. Use when distributing a PySide6 or PyQt6 app as a standalone executable, creating installers, configuring macOS bundles, Windows executables, or Linux AppImages.

  Trigger phrases: "package app", "PyInstaller", "distribute", "deploy", "standalone executable", "installer", "bundle app", "briefcase", "Windows build", "macOS build", "AppImage", "one-file"
version: 1.0.0
---

## Packaging Qt Python Applications

### PyInstaller (most common)

**Critical: Virtual Environment Isolation**

The official Qt for Python docs document a known PyInstaller gotcha: **if a system-level PySide6 is installed, PyInstaller silently picks it instead of your venv version**. Before building:

```bash
# Remove ALL system-level PySide6 installs from the build machine
pip uninstall pyside6 pyside6_essentials pyside6_addons shiboken6 -y

# Verify only venv version remains
python -c "import PySide6; print(PySide6.__file__)"
# Must show a path inside .venv/, not /usr/lib or system site-packages
```

**`--onefile` limitation:** For Qt6, `--onefile` bundles cannot deploy Qt plugins automatically. The one-directory (`dist/MyApp/`) approach is reliable. Use `--onefile` only if you understand its limitations and handle Qt plugins manually.

**Installation:**
```bash
uv add --dev pyinstaller
```

**Basic one-directory build:**
```bash
pyinstaller --name MyApp \
  --windowed \
  --icon resources/icons/app.ico \
  src/myapp/__main__.py
```

**Spec file (reproducible builds):**
```python
# MyApp.spec
block_cipher = None

a = Analysis(
    ["src/myapp/__main__.py"],
    pathex=[],
    binaries=[],
    datas=[
        ("src/myapp/resources", "resources"),   # (src, dest inside bundle)
    ],
    hiddenimports=[
        "PySide6.QtSvg",          # SVG support
        "PySide6.QtSvgWidgets",   # SVG widgets
        "PySide6.QtXml",          # required by some Qt modules
    ],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=["tkinter", "matplotlib"],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=False,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name="MyApp",
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=False,
    console=False,           # True for CLI apps
    disable_windowed_traceback=False,
    argv_emulation=False,    # macOS: use True for drag-and-drop files
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    icon="resources/icons/app.ico",
)

coll = COLLECT(
    exe,
    a.binaries,
    a.zipfiles,
    a.datas,
    strip=False,
    upx=False,
    upx_exclude=[],
    name="MyApp",
)
```

Run: `pyinstaller MyApp.spec`

**Qt plugin detection issues:** PySide6 often needs explicit plugin imports. Add to `hiddenimports`:
```python
hiddenimports = [
    "PySide6.QtSvg", "PySide6.QtSvgWidgets",
    "PySide6.QtPrintSupport",   # required by QTextEdit on some platforms
    "PySide6.QtDBus",           # Linux
]
```

**QRC compiled resources:** Include compiled `.py` resource files in `datas` or ensure they're importable. The cleanest approach is importing `rc_resources` in `__init__.py` so PyInstaller detects it automatically.

### Briefcase (cross-platform, preferred for distribution)

Briefcase produces native platform installers (`.msi`, `.dmg`, `.AppImage`):

```bash
pip install briefcase
briefcase create     # create platform package
briefcase build      # compile
briefcase run        # run from package
briefcase package    # create installer
```

**pyproject.toml for Briefcase:**
```toml
[tool.briefcase]
project_name = "MyApp"
bundle = "com.myorg.myapp"
version = "1.0.0"
url = "https://myorg.com"
license = "MIT"
author = "My Name"
author_email = "me@myorg.com"

[tool.briefcase.app.myapp]
formal_name = "My Application"
description = "Description here"
icon = "resources/icons/app"   # no extension — briefcase uses platform-appropriate format
sources = ["src/myapp"]
requires = ["PySide6>=6.6"]
```

Briefcase handles Qt plugin bundling more reliably than PyInstaller for PySide6.

### Windows: windeployqt + Code Signing

After PyInstaller builds the one-directory package, run `windeployqt` from the Qt SDK to copy any missing Qt plugins and translations:

```bash
# Run from the Qt SDK tools directory (or add to PATH)
windeployqt dist/MyApp/MyApp.exe
```

This ensures platform plugins (`qwindows.dll`) and other Qt plugin DLLs are present. PyInstaller hooks should collect most of them automatically, but `windeployqt` catches stragglers.

```bash
# Sign the executable (requires a code signing certificate)
signtool sign /fd SHA256 /a /tr http://timestamp.digicert.com dist/MyApp.exe
```

Unsigned Windows executables trigger SmartScreen warnings. For internal distribution, instruct users to right-click → Properties → Unblock.

### macOS: App Bundle

PyInstaller produces a `.app` bundle. For distribution outside the App Store:
```bash
# Ad-hoc signing (no developer ID)
codesign --force --deep --sign - dist/MyApp.app

# With developer ID
codesign --force --deep --sign "Developer ID Application: Name (TEAM_ID)" dist/MyApp.app

# Notarization (required for Gatekeeper)
xcrun notarytool submit dist/MyApp.zip --apple-id me@example.com --team-id TEAM_ID
```

### Linux: AppImage via PyInstaller

```bash
# Build one-directory first, then package as AppImage
# Use https://github.com/AppImage/AppImageKit
appimagetool dist/MyApp/ MyApp-x86_64.AppImage
```

### Build Automation (CI)

```yaml
# .github/workflows/build.yml
jobs:
  build-windows:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4
      - run: pip install pyinstaller PySide6
      - run: pyinstaller MyApp.spec
      - uses: actions/upload-artifact@v4
        with:
          name: windows-build
          path: dist/MyApp/
```

### Common Packaging Pitfalls

- **Missing Qt platform plugins**: `qt.qpa.plugin: Could not find the Qt platform plugin` — ensure `PySide6/Qt/plugins/platforms/` is included. PyInstaller hooks usually handle this; rebuild if not.
- **Missing SVG support**: Import `PySide6.QtSvg` in `hiddenimports` or the app will crash loading SVGs silently.
- **Relative path assumptions**: Use `Path(__file__).parent` for locating resource files in development; use `sys._MEIPASS` for PyInstaller runtime paths (or bundle via QRC to avoid the problem entirely).
- **App freezes on macOS**: Set `argv_emulation=True` in the spec if the app needs to handle file associations.

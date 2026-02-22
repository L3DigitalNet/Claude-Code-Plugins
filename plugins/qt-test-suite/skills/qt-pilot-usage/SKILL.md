---
name: Qt Pilot Usage
description: >
  This skill should be used when the user asks to "visual test", "test the GUI", "headless test",
  "test a running app", "interact with the UI", "take a screenshot of the app", "click a widget",
  "find a widget", "test UI behavior", "Qt Pilot", "launch app headlessly", or "test what the user sees".
  Covers the Qt Pilot MCP server's 15 tools for AI-driven headless GUI testing of Qt/PySide6 applications.
  Also activates for "Xvfb", "automate UI", "visual regression", "capture screenshot of app".
---

# Qt Pilot Usage

Qt Pilot is a bundled MCP server that lets Claude launch, interact with, and visually test PySide6 Qt applications — without a physical display. It uses Xvfb (X Virtual Framebuffer) for headless rendering and communicates with a test harness over a Unix socket.

Use `/qt:visual` to start a visual testing session.

## Architecture

```
Claude (MCP tools)
       ↓
Qt Pilot MCP server (mcp/qt-pilot/main.py)
       ↓  (Unix socket)
Qt Pilot Harness (runs inside Xvfb)
       ↓
Target Qt/PySide6 Application
```

The harness launches inside the virtual display, imports the application, and exposes widget interactions back to the MCP server.

## Prerequisites

- **Xvfb** installed (`Xvfb` binary on PATH). Run `scripts/check-prerequisites.sh` to verify.
- Application widgets must have **object names set** with `setObjectName()` to be targetable by name.
- Application must use `QApplication` (or `QGuiApplication`) — not just a bare Qt import.

## Setting Object Names (Required for Most Tools)

Without object names, only coordinate-based interaction (`click_at`) and `list_all_widgets` work. Add names to all interactive elements:

```python
# Python/PySide6
self.calculate_btn = QPushButton("Calculate")
self.calculate_btn.setObjectName("calculate_btn")

self.result_label = QLabel("")
self.result_label.setObjectName("result_label")

self.input_field = QLineEdit()
self.input_field.setObjectName("input_field")
```

```cpp
// C++ equivalent
QPushButton *btn = new QPushButton("Calculate");
btn->setObjectName("calculate_btn");
```

## Available MCP Tools (15 total)

### App Lifecycle

| Tool | Purpose | Key Args |
|---|---|---|
| `launch_app` | Start app headlessly via Xvfb | `script_path` or `module` + `working_dir` |
| `get_app_status` | Check if app is running / get diagnostics | — |
| `close_app` | Terminate the app and clean up Xvfb | — |
| `wait_for_idle` | Wait for Qt event queue to drain | `timeout` (float, default 5.0) |

### Discovery

| Tool | Purpose | Key Args |
|---|---|---|
| `find_widgets` | List widgets matching a glob pattern | `name_pattern` (default `"*"`) |
| `list_all_widgets` | List ALL widgets with coordinates | `include_invisible` (bool) |
| `get_widget_info` | Get size, position, visibility, enabled state | `widget_name` |
| `list_actions` | List all QActions (menus, toolbars) | — |

### Interaction (by name — requires `setObjectName`)

| Tool | Purpose | Key Args |
|---|---|---|
| `click_widget` | Click a named widget | `widget_name`, `button` ("left"/"right"/"middle") |
| `hover_widget` | Hover over a named widget | `widget_name` |
| `type_text` | Type into focused or named widget | `text`, optional `widget_name` |
| `press_key` | Simulate key press with optional modifiers | `key`, `modifiers` list |
| `trigger_action` | Trigger a QAction directly by name | `action_name` |

### Interaction (by coordinate — no object name needed)

| Tool | Purpose | Key Args |
|---|---|---|
| `click_at` | Click at screen coordinates | `x`, `y`, `button` |

### Visual Capture

| Tool | Purpose | Key Args |
|---|---|---|
| `capture_screenshot` | Capture PNG screenshot | optional `output_path` |

## Standard Workflow

### 1. Launch the App

```
launch_app(script_path="/path/to/project/main.py")
# or for module mode:
launch_app(module="myapp.main", working_dir="/path/to/project")
```

Wait for `success: true` before proceeding. If `success: false`, check `get_app_status` for stderr.

### 2. Discover Widgets

```
find_widgets("*")            → lists all named widgets
list_all_widgets()           → lists everything including unnamed, with coordinates
list_actions()               → lists all menu/toolbar actions
```

Use discovery before writing the test scenario — it reveals what's actually available.

### 3. Interact

```
click_widget("calculate_btn")
wait_for_idle()              → let Qt process the click event
type_text("42", widget_name="input_field")
press_key("Enter")
```

Always call `wait_for_idle()` after actions that trigger async processing or animations.

### 4. Verify State

```
get_widget_info("result_label")   → check text, visibility, enabled
capture_screenshot()              → visual confirmation
```

### 5. Close

```
close_app()
```

## Typical Visual Test Session

```
1. launch_app(script_path="main.py")
2. find_widgets("*")                    → discover widget names
3. click_widget("open_file_btn")
4. wait_for_idle()
5. capture_screenshot() → save to tests/reports/
6. get_widget_info("file_path_label")   → verify file loaded
7. type_text("42", widget_name="amount_input")
8. click_widget("calculate_btn")
9. wait_for_idle()
10. get_widget_info("result_display")   → assert result
11. capture_screenshot() → document final state
12. close_app()
```

## Common Failure Modes

| Symptom | Likely Cause | Fix |
|---|---|---|
| `launch_app` returns `success: false` | Import error in app, missing dependency | Check `stderr` in `get_app_status` |
| Widget not found by name | `setObjectName()` not called | Add names to widgets; use `list_all_widgets` for coords |
| Connection refused | App crashed after launch | Call `get_app_status` to see exit code + stderr |
| Click has no effect | Event not processed yet | Add `wait_for_idle()` after click |
| Screenshot is black | Xvfb not running / display not set | Check prerequisites with `scripts/check-prerequisites.sh` |

## Writing a Markdown Test Report

The `gui-tester` agent saves reports to `tests/reports/gui-YYYY-MM-DD-HH-MM.md`. Report format:

```markdown
# GUI Test Report — 2026-02-22 14:35

**App:** main.py
**Result:** PASS (4/4 interactions succeeded)

## Test Steps

| Step | Action | Expected | Result |
|------|--------|----------|--------|
| 1 | Click calculate_btn | result_label updates | ✅ PASS |
| 2 | Type "abc" in amount_input | Validation error shown | ✅ PASS |
| 3 | Press Escape | Dialog closes | ✅ PASS |
| 4 | Trigger save_action | File saved message | ✅ PASS |

## Screenshots
- [Before](screenshot_before.png)
- [After](screenshot_after.png)
```

## Additional Resources

- **`references/mcp-tools-reference.md`** — Full argument types, return schemas, and error handling for all 15 MCP tools

## Examples

- **`examples/visual_test_session.py`** — Annotated walkthrough of a complete Qt Pilot session: launch → discover → interact → verify → screenshot → close → report

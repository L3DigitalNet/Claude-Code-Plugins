# Qt Pilot MCP Tools Reference

All 15 tools exposed by the bundled Qt Pilot MCP server (`mcp/qt-pilot/main.py`).

## App Lifecycle

### launch_app

Launch a PySide6 application headlessly via Xvfb.

```json
{
  "tool": "launch_app",
  "arguments": {
    "script_path": "/abs/path/to/main.py",
    "module": "myapp.main",
    "working_dir": "/abs/path/to/project",
    "python_paths": ["/extra/path"],
    "timeout": 10
  }
}
```

- Use `script_path` **or** `module` — not both.
- `module` mode requires `working_dir`.
- `python_paths` adds to `sys.path` inside the harness — useful for monorepos.
- `timeout`: seconds to wait for the app window to appear (default 10).

Returns:
```json
{"success": true, "message": "App launched successfully", "socket_path": "/tmp/qt_gui_tester_xxx.sock", "display": ":99"}
```

### get_app_status

Check if the app is still running and retrieve any stderr output.

Returns:
```json
{
  "running": true,
  "exit_code": null,
  "stderr": "",
  "display": ":99",
  "socket_path": "/tmp/qt_gui_tester_xxx.sock"
}
```

If `running: false`, `exit_code` and `stderr` explain why the app stopped. Check this when other tool calls return `"App has exited"` errors.

### wait_for_idle

Wait for Qt's event queue to drain — call after any action that triggers async processing, animations, or signal chains.

```json
{"tool": "wait_for_idle", "arguments": {"timeout": 5.0}}
```

Returns `{"success": true, "message": "App is idle"}` or `{"success": false, "message": "Wait failed"}` on timeout.

### close_app

Attempt graceful shutdown (sends quit command), then terminates Xvfb.

Returns: `{"success": true, "message": "App closed"}`

---

## Widget Discovery

### find_widgets

List named widgets matching a glob pattern.

```json
{"tool": "find_widgets", "arguments": {"name_pattern": "*btn*"}}
```

Returns:
```json
{
  "success": true,
  "count": 3,
  "widgets": [
    {"name": "calculate_btn", "type": "QPushButton"},
    {"name": "clear_btn", "type": "QPushButton"},
    {"name": "cancel_btn", "type": "QPushButton"}
  ]
}
```

Use `"*"` to list all named widgets. Widget names are the values set via `setObjectName()`.

### list_all_widgets

List all widgets including unnamed ones, with screen coordinates.

```json
{"tool": "list_all_widgets", "arguments": {"include_invisible": false}}
```

Returns:
```json
{
  "success": true,
  "count": 12,
  "widgets": [
    {
      "name": "calculate_btn",
      "type": "QPushButton",
      "text": "Calculate",
      "x": 120, "y": 45, "width": 80, "height": 30,
      "visible": true,
      "enabled": true
    }
  ]
}
```

Use this for apps that don't have `setObjectName()` set — interact by coordinates using `click_at`.

### get_widget_info

Get detailed info about a specific named widget.

```json
{"tool": "get_widget_info", "arguments": {"widget_name": "result_label"}}
```

Returns:
```json
{
  "success": true,
  "info": {
    "name": "result_label",
    "type": "QLabel",
    "text": "42.0",
    "x": 10, "y": 80, "width": 200, "height": 24,
    "visible": true,
    "enabled": true,
    "checked": null
  }
}
```

`text` field present for QLabel, QPushButton, QLineEdit, QCheckBox. `checked` present for QCheckBox, QRadioButton.

### list_actions

List all QActions registered in the application (menus, toolbars, shortcuts).

Returns:
```json
{
  "success": true,
  "count": 5,
  "actions": [
    {
      "name": "action_save",
      "text": "Save",
      "shortcut": "Ctrl+S",
      "enabled": true,
      "checked": false
    }
  ]
}
```

---

## Named Widget Interaction

### click_widget

```json
{"tool": "click_widget", "arguments": {"widget_name": "calculate_btn", "button": "left"}}
```

`button`: `"left"` (default), `"right"`, or `"middle"`.

### hover_widget

```json
{"tool": "hover_widget", "arguments": {"widget_name": "tooltip_target"}}
```

Useful for testing tooltip display or hover-triggered behavior.

### type_text

```json
{"tool": "type_text", "arguments": {"text": "hello world", "widget_name": "input_field"}}
```

`widget_name` is optional — types into the currently focused widget if omitted. Sends individual key events, not clipboard paste, so input masks and validators apply.

### press_key

```json
{
  "tool": "press_key",
  "arguments": {
    "key": "Return",
    "modifiers": ["Ctrl", "Shift"]
  }
}
```

Key names: `"Return"`, `"Escape"`, `"Tab"`, `"Backspace"`, `"Delete"`, `"Space"`, `"F1"`–`"F12"`, `"Up"`, `"Down"`, `"Left"`, `"Right"`, `"Home"`, `"End"`, single characters `"A"`–`"Z"`, `"0"`–`"9"`.

Modifiers: `"Ctrl"`, `"Shift"`, `"Alt"`, `"Meta"` (Meta = Windows key / Cmd on macOS).

### trigger_action

Directly trigger a QAction without navigating menus — useful for testing that menu items work correctly.

```json
{"tool": "trigger_action", "arguments": {"action_name": "action_save"}}
```

Action names come from `setObjectName()` on the QAction, or from `list_actions`.

---

## Coordinate Interaction

### click_at

Click at screen coordinates. Use when widgets don't have object names.

```json
{"tool": "click_at", "arguments": {"x": 150, "y": 87, "button": "left"}}
```

Returns:
```json
{"success": true, "message": "Clicked at (150, 87) on QPushButton"}
```

Get coordinates from `list_all_widgets` first.

---

## Visual Capture

### capture_screenshot

```json
{"tool": "capture_screenshot", "arguments": {"output_path": "/tmp/screenshot_001.png"}}
```

`output_path` is optional — a temp file is created if omitted.

Returns:
```json
{"success": true, "path": "/tmp/screenshot_001.png", "message": "Screenshot saved to /tmp/screenshot_001.png"}
```

Claude can then read the image file to visually inspect the UI state.

---

## Error Response Schema

All tool calls return `success: false` on failure:

```json
{"success": false, "message": "Widget 'calculate_btn' not found"}
{"success": false, "error": "App has exited (code: 1)\nstderr: ..."}
```

When `success: false`:
1. Check the `message` or `error` field
2. Call `get_app_status` to see if the app crashed
3. Call `find_widgets("*")` to verify widget names
4. Call `list_all_widgets` if the widget name doesn't appear in find_widgets

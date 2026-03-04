---
name: visual
description: Launch the Qt/PySide6 application headlessly and run visual GUI tests using the bundled Qt Pilot MCP server. Claude interacts with the live UI via screenshots, clicks, and text input.
argument-hint: "[optional: test scenario description or app entry point]"
allowed-tools:
  - Read
  - Write
  - Bash
  - Glob
---

# /qt-suite:visual — Headless GUI Testing

Launch the application headlessly and run visual tests using the Qt Pilot MCP server. Claude interacts with the live UI, verifies behavior, and writes a test report.

## Step 1: Prerequisites Check

Run the prerequisites check before attempting to launch:
```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/check-prerequisites.sh"
```

If Xvfb is missing, stop and report the install instructions — do not proceed.

## Step 2: Find App Entry Point

Determine the application entry point:

1. If an argument was provided that looks like a file path (e.g., `/qt-suite:visual src/main.py`), use it.
2. Read `.qt-test.json` — use `app_entry` field if set.
3. If no config, search for common entry points:
   - Glob for `main.py`, `app.py`, `__main__.py` in project root and `src/`
   - Choose the one that imports `QApplication` (Grep for `QApplication`)
4. Resolve to an absolute path.

## Step 3: Check If App Is Already Running

Call the Qt Pilot `get_app_status` MCP tool. If `running: true`, attach to the existing session. If not running (or crashed), launch fresh.

## Step 4: Launch the App

Call `launch_app` with the resolved entry point:
```
launch_app(script_path="/abs/path/to/main.py")
```

Or for module-based apps:
```
launch_app(module="myapp.main", working_dir="/abs/path/to/project")
```

Wait for `success: true`. If launch fails, call `get_app_status` to retrieve stderr output and report the error with the full stderr content — do not attempt workarounds.

## Step 5: Discover the UI

Before testing, always discover available widgets:
```
find_widgets("*")        → lists all named widgets
list_actions()           → lists all menu/toolbar actions
```

If the argument provided describes a specific UI scenario (e.g., "test the file open dialog"), use `list_all_widgets` to discover the full hierarchy including unnamed elements.

## Step 6: Execute the Test Scenario

**If a scenario was provided in the argument**, execute it. For example, if the user says `/qt-suite:visual test the save workflow`:
1. Click the "Save" button or trigger the `action_save` action
2. Verify the save dialog appears
3. Interact with the dialog
4. Verify the file was saved (check for status label update or file existence)

**If no scenario was specified**, run a general smoke test:
1. Take a screenshot of the initial state
2. Interact with each primary widget (buttons, inputs, menus)
3. Verify the app doesn't crash after each interaction (`get_app_status`)
4. Take a final screenshot

After every click or input action that may trigger async behavior, call `wait_for_idle` before the next action.

## Step 7: Capture Screenshots

Capture screenshots at key moments:
```
capture_screenshot(output_path="tests/reports/visual_<timestamp>_initial.png")
capture_screenshot(output_path="tests/reports/visual_<timestamp>_final.png")
```

Use ISO timestamp format: `2026-02-22_14-35`.

## Step 8: Close the App

```
close_app()
```

## Step 9: Write Test Report

Write a markdown report to `tests/reports/gui-<timestamp>.md` (create the `tests/reports/` directory if needed):

```markdown
# GUI Test Report — <date> <time>

**App:** <entry_point>
**Scenario:** <description or "smoke test">
**Result:** PASS / FAIL (N/M interactions succeeded)

## Test Steps

| Step | Action | Expected | Result | Notes |
|------|--------|----------|--------|-------|
| 1 | launch_app | Window appears | ✅ PASS | |
| 2 | click calculate_btn | Display updates | ✅ PASS | |
| 3 | type "abc" in input | Validation error | ✅ PASS | |

## Failures

(list any FAIL steps with full error messages from Qt Pilot)

## Screenshots

- Initial state: `visual_<timestamp>_initial.png`
- Final state: `visual_<timestamp>_final.png`

## Recommendations

(optional: widget object names missing, behaviors to fix, edge cases to add)
```

Report the path to the markdown file when done.

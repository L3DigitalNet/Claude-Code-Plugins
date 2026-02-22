"""
Example: Complete Qt Pilot visual test session for a PySide6 calculator app.

This script shows the full flow a Claude agent follows when using Qt Pilot tools:
  launch_app → discover → interact → verify → screenshot → close → report

The actual tool calls happen via MCP — this file shows the conceptual sequence
so you can understand the interaction pattern before writing your own test scenarios.
"""

# ─── STEP 1: Prerequisites ───────────────────────────────────────────────────
# Always check before attempting to launch.
# bash "${CLAUDE_PLUGIN_ROOT}/scripts/check-prerequisites.sh"

# ─── STEP 2: Launch the app ──────────────────────────────────────────────────
# Tool: launch_app
#
# launch_app(script_path="/abs/path/to/calculator/main.py")
#
# Response: {"success": true, "message": "App launched successfully", "display": ":99"}
#
# If it fails, call get_app_status() to read the stderr and diagnose the error.
# Never retry in a loop — fix the root cause first.

# ─── STEP 3: Discover the widget tree ────────────────────────────────────────
# Tool: find_widgets, list_actions
#
# find_widgets("*")
# Response: {"success": true, "count": 12, "widgets": [
#   {"name": "display",       "type": "QLineEdit"},
#   {"name": "btn_0",         "type": "QPushButton"},
#   {"name": "btn_1",         "type": "QPushButton"},
#   ...
#   {"name": "btn_equals",    "type": "QPushButton"},
#   {"name": "btn_add",       "type": "QPushButton"},
#   {"name": "btn_clear",     "type": "QPushButton"},
# ]}
#
# list_actions()
# Response: {"success": true, "count": 3, "actions": [
#   {"name": "action_copy",  "text": "Copy",  "shortcut": "Ctrl+C"},
#   {"name": "action_paste", "text": "Paste", "shortcut": "Ctrl+V"},
#   {"name": "action_quit",  "text": "Quit",  "shortcut": "Ctrl+Q"},
# ]}

# ─── STEP 4: Capture initial state ───────────────────────────────────────────
# Tool: capture_screenshot
#
# capture_screenshot(output_path="tests/reports/calc_2026-02-22_14-35_initial.png")
# Response: {"success": true, "path": "tests/reports/calc_2026-02-22_14-35_initial.png"}

# ─── STEP 5: Test scenario — "2 + 3 = 5" ────────────────────────────────────
# Tool sequence: click_widget × 5, wait_for_idle × 4, get_widget_info

# click_widget("btn_2")
# wait_for_idle(timeout=2.0)

# click_widget("btn_add")
# wait_for_idle(timeout=2.0)

# click_widget("btn_3")
# wait_for_idle(timeout=2.0)

# click_widget("btn_equals")
# wait_for_idle(timeout=2.0)

# get_widget_info("display")
# Response: {"success": true, "info": {"name": "display", "text": "5", "visible": true, "enabled": true}}
# VERIFY: info["text"] == "5"  → PASS

# ─── STEP 6: Test error path — divide by zero ────────────────────────────────
# click_widget("btn_clear")
# wait_for_idle(timeout=1.0)

# click_widget("btn_5")
# click_widget("btn_divide")
# click_widget("btn_0")
# click_widget("btn_equals")
# wait_for_idle(timeout=2.0)

# get_widget_info("display")
# VERIFY: text is "Error" or "∞" — depends on app implementation
# capture_screenshot(output_path="tests/reports/calc_2026-02-22_14-35_divide_by_zero.png")

# ─── STEP 7: Test keyboard input ─────────────────────────────────────────────
# click_widget("btn_clear")
# wait_for_idle(timeout=1.0)

# type_text("42", widget_name="display")
# wait_for_idle(timeout=1.0)

# get_widget_info("display")
# VERIFY: text contains "42"

# ─── STEP 8: Test menu action ─────────────────────────────────────────────────
# trigger_action("action_copy")
# wait_for_idle(timeout=1.0)
# VERIFY: no crash — get_app_status() confirms still running

# ─── STEP 9: Capture final state ─────────────────────────────────────────────
# capture_screenshot(output_path="tests/reports/calc_2026-02-22_14-35_final.png")

# ─── STEP 10: Close the app ──────────────────────────────────────────────────
# close_app()
# Response: {"success": true, "message": "App closed"}

# ─── STEP 11: Write report ───────────────────────────────────────────────────
# The gui-tester agent writes the report to tests/reports/gui-2026-02-22_14-35.md
# See the report format in qt-pilot-usage/SKILL.md → "Writing a Markdown Test Report"

# ─── Common failure patterns ─────────────────────────────────────────────────
#
# Problem: launch_app returns success: false
#   → Call get_app_status() immediately to read stderr
#   → Common causes: import error, missing PySide6, missing widget setup
#
# Problem: click_widget("btn_equals") returns success: false, "widget not found"
#   → The widget has no setObjectName("btn_equals") — use list_all_widgets() to find coords
#   → Use click_at(x, y) as fallback
#   → Note in report: "btn_equals lacks objectName — recommend adding setObjectName()"
#
# Problem: get_widget_info("display") shows wrong text after clicking equals
#   → Likely async computation — increase wait_for_idle timeout
#   → Or the signal chain uses a timer: wait_for_idle(timeout=5.0)
#
# Problem: capture_screenshot returns a black image
#   → Xvfb is not running or the wrong DISPLAY is set
#   → get_app_status().display should show ":99" or similar
#   → Rerun check-prerequisites.sh

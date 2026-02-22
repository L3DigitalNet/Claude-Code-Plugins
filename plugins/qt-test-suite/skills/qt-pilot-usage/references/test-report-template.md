# GUI Test Report Template

The `gui-tester` agent saves reports to `tests/reports/gui-YYYY-MM-DD-HH-MM.md`.

## Report Format

```markdown
# GUI Test Report — YYYY-MM-DD HH:MM

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

## Field Descriptions

- **App** — the `script_path` or module passed to `launch_app`
- **Result** — overall PASS/FAIL with a `(n/total interactions succeeded)` count
- **Test Steps table** — one row per interaction; Result is `✅ PASS`, `❌ FAIL`, or `⚠️ SKIP`
- **Screenshots** — relative paths to PNG files saved via `capture_screenshot`; include at minimum a before and after shot, plus one per significant state transition

## Naming Convention

```
tests/reports/gui-YYYY-MM-DD-HH-MM.md
tests/reports/screenshot_before.png
tests/reports/screenshot_after.png
```

Use ISO 8601 timestamps with hyphens so reports sort lexicographically by date.

## FAIL Entry Format

When a step fails, include the actual vs expected in the Result column and append a **Failures** section:

```markdown
| 3 | get_widget_info("result_label") | text == "42.0" | ❌ FAIL — got "" |

## Failures

### Step 3 — result_label empty after click
- **Action**: click_widget("calculate_btn") → wait_for_idle() → get_widget_info("result_label")
- **Expected**: text = "42.0"
- **Actual**: text = "" (empty)
- **Likely cause**: Signal not connected — `calculate_btn.clicked` not wired to update slot
- **Screenshot**: [step3_failure.png](step3_failure.png)
```

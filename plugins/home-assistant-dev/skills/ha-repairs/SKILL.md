---
name: ha-repairs
description: Implement repair issues for Home Assistant integrations. Gold tier IQS requirement. Use when asked about repair issues, issue registry, user notifications, fixable issues, or actionable alerts.
---

# Home Assistant Repair Issues

Repair issues provide actionable notifications to users about problems that require attention. **Gold tier IQS requirement.**

## When to Use Repairs

Use repair issues for:
- Configuration problems the user can fix
- Firmware updates available
- Deprecated features being used
- Missing optional dependencies
- Service disruptions with user action needed

Do NOT use for:
- Transient errors (use logging)
- Entity unavailability (use `available` property)
- Internal errors (use exceptions)

## Severity Levels

| Severity | Constant | When to use |
|----------|----------|-------------|
| Critical | `IssueSeverity.CRITICAL` | Immediate action required |
| Error | `IssueSeverity.ERROR` | Something is broken |
| Warning | `IssueSeverity.WARNING` | Should be addressed soon |

```python
from homeassistant.helpers.issue_registry import IssueSeverity
```

## Issue Types

| Type | `is_fixable` | User action |
|------|-------------|-------------|
| Non-fixable | `False` | Must act outside Home Assistant (e.g., update firmware) |
| Fixable | `True` | Can resolve via a repair flow inside Home Assistant |

## Core Implementation Steps

1. Import `issue_registry as ir` from `homeassistant.helpers`
2. Call `ir.async_create_issue(hass, DOMAIN, issue_id, ...)` when condition is detected
3. Call `ir.async_delete_issue(hass, DOMAIN, issue_id)` when condition clears
4. For fixable issues: create `repairs.py` with a `RepairsFlow` subclass and `async_create_fix_flow`
5. Add translation strings to `strings.json` under the `"issues"` key

**Repair code examples (non-fixable, fixable, strings.json)** — see [references/repair-examples.md](references/repair-examples.md)

**Coordinator integration pattern (create + clear in update cycle)** — see [references/testing-repairs.md](references/testing-repairs.md)

## Related Skills

- Config flow → `ha-config-flow`
- Coordinator → `ha-coordinator`
- Quality review → `ha-quality-review`

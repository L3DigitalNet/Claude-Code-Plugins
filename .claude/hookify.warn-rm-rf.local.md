---
name: warn-rm-rf
enabled: true
event: bash
pattern: rm\s+-rf
action: warn
---

⚠️ **Destructive rm -rf detected**

You're about to run a recursive force-delete. Before proceeding:

- Verify the target path is correct
- Confirm this is intentional and not a workaround for an underlying problem
- Prefer `find ... -delete` or `rmdir` for more targeted deletion

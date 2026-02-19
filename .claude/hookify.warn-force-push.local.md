---
name: warn-force-push
enabled: true
event: bash
pattern: git\s+push\s+.*--force|git\s+push\s+.*-f\b
action: warn
---

⚠️ **Force push detected**

Force-pushing rewrites remote history and can destroy teammates' work.

- Are you pushing to a shared branch (main, master, testing)?
- If so, prefer `--force-with-lease` — it fails if the remote has changed since your last fetch
- If this is a personal/feature branch with no other users, proceed carefully

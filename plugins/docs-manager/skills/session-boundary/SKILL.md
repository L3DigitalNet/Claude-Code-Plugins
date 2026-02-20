---
name: session-boundary
description: Reminds about queued documentation items at session boundaries. Use when Claude is wrapping up work or the user signals session end.
---

When wrapping up a session, check the docs-manager queue:

1. Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/queue-read.sh --count`
2. If count > 0: remind the user about pending documentation items
   - "There are N queued documentation items. Run `/docs queue review` to review them before ending the session."
3. If count = 0: stay silent

This skill complements the Stop hook — the hook fires mechanically at session end, while this skill fires when Claude detects session-boundary intent in the conversation (e.g., "let's wrap up", "I'm done for today", "commit and push").

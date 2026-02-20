---
name: docs
description: Documentation lifecycle management
---

Parse the first argument as `<subcommand>`. Route to the matching section below. If no argument, run **status (brief)**.

**Scripts directory:** `${CLAUDE_PLUGIN_ROOT}/scripts`

## Pre-flight

Before routing, check if `~/.docs-manager/config.yaml` exists. If missing and subcommand is not `help`:
1. Inform the user: "docs-manager needs initial setup."
2. Ask via `AskUserQuestion`: "Where is your documentation index stored?" with options:
   - "Local git repo (git-markdown)" — ask for path, validate it exists or offer to create
   - "JSON file only" — use `~/.docs-manager/docs-index.json`
3. Ask machine identity — default to `$(hostname)`, confirm or override
4. Write `~/.docs-manager/config.yaml` with chosen settings
5. Run `bootstrap.sh`
6. Continue to subcommand

---

## queue

Display current queue. Run: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/queue-read.sh`

Format the output as a markdown table if items exist.

## queue review

Interactive review of queued items:

1. Run `queue-read.sh --json` to get pending items
2. If empty, say "No items to review" and stop
3. For each pending item, read the associated file at `doc-path` and assess its current state
4. Draft a 1-3 sentence proposed update per item
5. Present via `AskUserQuestion` with `multiSelect: true`:
   - Each option label: `"[filename] — [type]: [proposed summary]"`
   - Each option description: the drafted update detail
   - Selected = approved for update
6. For unselected items, present second `AskUserQuestion` with `multiSelect: true`:
   - "These N items were not approved. Select any to permanently dismiss — the rest defer to next session."
7. Apply approved updates — edit the documents using Edit tool
8. For dismissed items: run `queue-clear.sh` per-item with the dismiss reason
9. For deferred items: update their status to `"deferred"` in queue.json via jq

## queue clear

Requires a reason. Run: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/queue-clear.sh --reason "<reason>"`

If the user provides `/docs queue clear` without a reason, ask for one via `AskUserQuestion`.

## status

Operational and library health dashboard.

**Operational Health** — gather:
- Config: check `~/.docs-manager/config.yaml` exists and is valid YAML
- Hooks: read timestamps from `~/.docs-manager/hooks/*.last-fired`, report age
- Queue: validate `queue.json` is parseable, report item count
- Lock: check if `~/.docs-manager/index.lock` exists (stale lock warning)
- Fallback: check if `queue.fallback.json` exists (pending merge warning)

**Library Health** (stub until index system exists):
- Report "Index system not yet configured" if no `docs-index.json`

Format output:
```
Operational Health
  Config:    ✓ loaded
  Hooks:     PostToolUse (2m ago) | Stop (last session)
  Queue:     3 pending items
  Lock:      none
  Fallback:  none

Library Health
  [Index system not yet configured]
```

With `--test` flag: run all operational checks and report pass/fail for each.

## hook status

Read and display hook last-fired timestamps from `~/.docs-manager/hooks/`:
- `post-tool-use.last-fired`
- `stop.last-fired`

Report each as "Xm ago" or "never fired". Check that `hooks.json` is properly registered.

## help

Output:
```
/docs — Documentation Lifecycle Manager

Commands:
  queue              Display current queue items
  queue review       Review and approve queued items
  queue clear        Dismiss all items (reason required)
  status [--test]    Operational and library health
  hook status        Check hook registration and timestamps
  help               This help text

Coming soon: new, onboard, find, update, review, organize, library,
index, audit, dedupe, consistency, streamline, compress, full-review,
template, verify
```

---

## Stub commands

For any of these subcommands, output: `"The /docs <subcommand> command will be available in a future update. Current version: 0.1.0"`

Stubs: `new`, `onboard`, `find`, `update`, `review`, `organize`, `library`, `index`, `audit`, `dedupe`, `consistency`, `streamline`, `compress`, `full-review`, `template`, `verify`

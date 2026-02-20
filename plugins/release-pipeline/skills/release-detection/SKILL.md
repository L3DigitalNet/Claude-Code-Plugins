---
name: release-detection
description: >
  Detect release intent in natural language and route to the /release command menu.
  Triggers on: "Release vX.Y.Z", "cut a release", "ship it", "merge to main",
  "deploy to production", "push to main", "release for <repo>",
  "release <plugin-name> vX.Y.Z", "ship <plugin-name>".
---

# Release Detection

You detected release intent in the user's message. Route to the `/release` command.

## Action

Invoke the `/release` command. The command will gather context and present an interactive menu — do NOT try to parse arguments or select a mode yourself.

Tell the user what was detected. If the user mentioned a specific plugin name (e.g., "release release-pipeline"), say: `"Detected release intent for <plugin-name>. Opening the release menu…"`. Otherwise say: `"Detected release intent. Opening the release menu…"`. Then invoke `/release`.

If the user mentioned a specific repo (e.g., "for HA-Light-Controller"), `cd` to that repo first before invoking `/release`.

---
name: release-detection
description: >
  Detect release intent in natural language and route to the /release command.
  Triggers on: "Release vX.Y.Z", "cut a release", "ship it", "merge to main",
  "deploy to production", "push to main", "release for <repo>".
---

# Release Detection

You detected release intent in the user's message. Route to the appropriate release mode.

## Parse the Request

1. **Look for a version number**: pattern `v?[0-9]+\.[0-9]+\.[0-9]+`
   - Found → Full Release mode
   - Not found → Quick Merge mode

2. **Look for a repo name**: if the user mentions a specific repo (e.g., "for HA-Light-Controller"), note it — you may need to `cd` to that repo first.

## Execute

Follow the exact same workflow as the `/release` command defined in `${CLAUDE_PLUGIN_ROOT}/commands/release.md`.

Read that file and follow its instructions with the parsed version (if any) and repo context.

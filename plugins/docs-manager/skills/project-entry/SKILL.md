---
name: project-entry
description: Triggers freshness scan when entering a new project directory. Use when Claude detects a directory context change or the user navigates to a new project.
---

When entering a project directory, check if docs-manager has a registered library for this location:

1. Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/index-query.sh --search "$(basename $(pwd))"` to check for matching libraries
2. If no match: skip silently — this project isn't managed
3. If match found: run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/index-query.sh --library "<name>"` to get all docs
4. Check each doc's `last-verified` date — flag any >90 days old
5. Check queue for any pending items related to this library
6. If concerning items found, inject brief context: "N documentation items queued for this project."

Do not interrupt the user's workflow. Only surface findings if there are actionable items.

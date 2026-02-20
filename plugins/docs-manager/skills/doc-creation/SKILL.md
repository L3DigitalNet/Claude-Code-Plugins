---
name: doc-creation
description: Suggests using /docs new when creating markdown files in managed locations. Use when Claude is about to create a new .md file.
---

Before creating a new `.md` file, check if the target directory is within a docs-manager library:

1. Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/index-query.sh --search "$(dirname "$TARGET_PATH")"` to check
2. If the directory is within a managed library:
   - Suggest: "This directory is part of the **[library]** documentation library. Use `/docs new` to create a managed document with proper frontmatter and index registration."
   - If the user declines, proceed with normal file creation
3. If not in a managed location: proceed normally without suggestion

This prevents untracked documents from accumulating in managed directories.

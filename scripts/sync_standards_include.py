"""Sync markdown.frontmatter.include in .project-standards.yml from .vscode/settings.json.

Reads ``folder-color.pathColors`` from the VS Code workspace settings and rewrites the
``markdown.frontmatter.include`` list so that it exactly matches the entries colored
``foldercolorizer.color_d7af00``:

- ``filePath`` entries → exact path patterns (prefix stripped).
- ``folderPath`` entries → ``<dir>/**/*.md`` glob patterns (prefix + trailing slash stripped).
- Entries with any other color are excluded from the list.

Note: folder patterns are always reconstructed with the ``/**/*.md`` suffix.  If the
original pattern used a different glob (e.g. ``/**`` or ``/**/*.yaml``), the round-trip
will not reproduce it exactly.

Usage:
    sync-standards-include [standards-file] [settings-file]

Defaults (resolved relative to the git repo root):
    standards-file  .project-standards.yml
    settings-file   .vscode/settings.json
"""

from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path
from typing import Any, cast

_COLOR = "foldercolorizer.color_d7af00"


def _repo_root() -> Path:
    result = subprocess.run(
        ["git", "rev-parse", "--show-toplevel"],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        sys.exit("error: not inside a git repository")
    return Path(result.stdout.strip())


def read_path_colors(settings_path: Path) -> list[dict[str, str]]:
    """Return all folder-color.pathColors entries from *settings_path*."""
    original = settings_path.read_text()
    clean = re.sub(r"(?m)^\s*//[^\n]*\n?", "", original)
    data = cast(dict[str, Any], json.loads(clean))
    raw = data.get("folder-color.pathColors", [])
    return cast(list[dict[str, str]], raw if isinstance(raw, list) else [])


def path_colors_to_patterns(entries: list[dict[str, str]], prefix: str) -> list[str]:
    """Derive include patterns from *entries* that have the project color.

    ``filePath`` entries become exact path patterns; ``folderPath`` entries become
    ``<dir>/**/*.md`` globs.  Entries without the expected color are silently skipped.
    """
    patterns: list[str] = []
    for entry in entries:
        if entry.get("color") != _COLOR:
            continue
        if "filePath" in entry:
            stripped = entry["filePath"].removeprefix(f"{prefix}/")
            patterns.append(stripped)
        elif "folderPath" in entry:
            stripped = entry["folderPath"].removeprefix(f"{prefix}/").rstrip("/")
            patterns.append(f"{stripped}/**/*.md")
    return patterns


def update_include_list(standards_path: Path, new_patterns: list[str]) -> None:
    """Replace the markdown.frontmatter.include block in-place, preserving all other content.

    Only the list items under ``    include:`` (4-space indent) are replaced; surrounding
    keys, comments, and the rest of the file are untouched.  Raises SystemExit if the
    include block cannot be located.
    """
    content = standards_path.read_text()
    new_items = "".join(f'      - "{p}"\n' for p in new_patterns)
    # Match the include: header and all immediately-following 6-space-indented lines.
    updated = re.sub(
        r"(    include:\n)((?:      [^\n]*\n)*)",
        f"    include:\n{new_items}",
        content,
    )
    if updated == content and not re.search(r"    include:\n", content):
        sys.exit(
            f"error: could not locate 'include:' block in {standards_path}"
            " — only block-style YAML is supported"
        )
    standards_path.write_text(updated)


def main() -> None:
    root = _repo_root()
    standards_path = Path(sys.argv[1]) if len(sys.argv) > 1 else root / ".project-standards.yml"
    settings_path = Path(sys.argv[2]) if len(sys.argv) > 2 else root / ".vscode" / "settings.json"

    if not standards_path.is_file():
        sys.exit(f"error: {standards_path} not found")
    if not settings_path.is_file():
        sys.exit(f"error: {settings_path} not found")

    prefix = root.name
    entries = read_path_colors(settings_path)
    patterns = path_colors_to_patterns(entries, prefix)

    if not patterns:
        print(
            "warning: no color_d7af00 entries found — include list will be emptied",
            file=sys.stderr,
        )

    update_include_list(standards_path, patterns)
    print(f"synced: {len(patterns)} include patterns written to {standards_path}")


if __name__ == "__main__":
    main()

"""Sync folder-color.pathColors in .vscode/settings.json from .project-standards.yml.

Reads the ``markdown.frontmatter.include`` list from a project-standards config
file and writes a matching ``folder-color.pathColors`` block into the VS Code
workspace settings.  Patterns containing ``**`` become ``folderPath`` entries;
everything else becomes ``filePath`` entries.

Usage:
    sync-vscode-colors [standards-file] [settings-file]

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

import yaml

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


def read_include_patterns(standards_path: Path) -> list[str]:
    """Return the markdown.frontmatter.include list from *standards_path*."""
    raw = yaml.safe_load(standards_path.read_text())
    data = cast(dict[str, Any], raw) if isinstance(raw, dict) else {}
    try:
        patterns = data["markdown"]["frontmatter"]["include"]
    except KeyError, TypeError:
        patterns = None
    if not patterns:
        sys.exit(
            f"error: no include patterns found under markdown.frontmatter.include"
            f" in {standards_path}"
        )
    return [str(p) for p in patterns]


def patterns_to_path_colors(patterns: list[str], prefix: str) -> list[dict[str, str]]:
    """Translate glob patterns to folder-color entry dicts.

    Patterns with ``**`` become ``folderPath`` entries (the directory up to the
    first ``/**``); plain paths become ``filePath`` entries.
    """
    entries: list[dict[str, str]] = []
    for pattern in patterns:
        if "**" in pattern:
            dir_part = pattern.split("/**")[0]
            entries.append({"folderPath": f"{prefix}/{dir_part}/", "color": _COLOR})
        else:
            entries.append({"filePath": f"{prefix}/{pattern}", "color": _COLOR})
    return entries


def rewrite_settings(settings_path: Path, path_colors: list[dict[str, str]]) -> None:
    """Replace folder-color.pathColors in *settings_path*, preserving JSONC comments."""
    original = settings_path.read_text()

    # Preserve leading // comment lines that appear immediately after the opening '{'
    # so they survive the json.dumps round-trip (JSONC is not valid JSON).
    header_comments: list[str] = []
    for line in original.splitlines()[1:]:
        if re.match(r"^\s*//", line):
            header_comments.append(line)
        else:
            break

    clean = re.sub(r"(?m)^\s*//[^\n]*\n?", "", original)
    data = cast(dict[str, Any], json.loads(clean))
    data["folder-color.pathColors"] = path_colors

    serialized = json.dumps(data, indent="\t")

    if header_comments:
        first_nl = serialized.index("\n")
        serialized = (
            serialized[: first_nl + 1]
            + "\n".join(header_comments)
            + "\n"
            + serialized[first_nl + 1 :]
        )

    settings_path.write_text(serialized + "\n")


def main() -> None:
    root = _repo_root()
    standards_path = Path(sys.argv[1]) if len(sys.argv) > 1 else root / ".project-standards.yml"
    settings_path = Path(sys.argv[2]) if len(sys.argv) > 2 else root / ".vscode" / "settings.json"

    if not standards_path.is_file():
        sys.exit(f"error: {standards_path} not found")
    if not settings_path.is_file():
        sys.exit(f"error: {settings_path} not found")

    prefix = root.name
    patterns = read_include_patterns(standards_path)
    path_colors = patterns_to_path_colors(patterns, prefix)
    rewrite_settings(settings_path, path_colors)

    print(f"synced: {len(path_colors)} path color entries written to {settings_path}")


if __name__ == "__main__":
    main()

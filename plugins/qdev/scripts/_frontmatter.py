"""Shared YAML-frontmatter parsing for the qdev research-KB scripts.

Recognises a frontmatter block only at the very top of the file (the \\A
anchor), matching the canonical project-standards validator: a `---` block
appearing anywhere else is intentionally NOT treated as frontmatter.

Unquoted YAML dates (`created: 2026-06-03`) parse as `datetime.date`, but the
schema validates those fields as strings; `_coerce_dates` converts them to ISO
strings so authors may write either form. (Parity with the canonical
project-standards `_coerce_dates` - CR-003.)
"""
from __future__ import annotations

import datetime
import re
from pathlib import Path

import yaml

_FM_RE = re.compile(r"\A---\r?\n(.*?)\r?\n---(?:\r?\n|$)", re.DOTALL)


def _coerce_dates(obj):
    """Recursively convert datetime.date/datetime values to ISO strings."""
    if isinstance(obj, datetime.datetime):
        return obj.date().isoformat()
    if isinstance(obj, datetime.date):
        return obj.isoformat()
    if isinstance(obj, dict):
        return {k: _coerce_dates(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [_coerce_dates(v) for v in obj]
    return obj


def extract_frontmatter(text: str) -> dict | None:
    """Parsed frontmatter mapping (dates coerced to ISO strings), or None if
    absent or not a mapping. Raises yaml.YAMLError on malformed YAML - callers
    that validate files catch it and report a per-file error."""
    match = _FM_RE.match(text)
    if not match:
        return None
    data = yaml.safe_load(match.group(1))
    return _coerce_dates(data) if isinstance(data, dict) else None


def read_frontmatter(path: Path) -> dict | None:
    """Read a file and return its frontmatter mapping (or None)."""
    return extract_frontmatter(Path(path).read_text(encoding="utf-8"))

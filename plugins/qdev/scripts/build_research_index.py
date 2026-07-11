# /// script
# requires-python = ">=3.11"
# dependencies = ["pyyaml>=6.0.2"]
# ///
"""Regenerate docs/research/index.md from report frontmatter.

Scans the TOP-LEVEL <research-dir>/*.md reports (non-recursive), reads each
report's project-standards `research` frontmatter, and rewrites index.md
(doc_type: index) as a table sorted by `created` desc. Regenerate-only - it
never appends, so the index cannot drift from the reports.

The index's own created/updated derive from report content (min/max), so
re-running with unchanged reports yields an identical file (idempotent).

Usage: uv run build_research_index.py <research-dir>      # e.g. docs/research
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

import yaml

from _frontmatter import read_frontmatter

INDEX_NAME = "index.md"


class _IndentedDumper(yaml.SafeDumper):
    """SafeDumper that indents block sequences under their mapping key.

    PyYAML's default emits `tags:\\n- research` (flush-left), but Prettier's
    canonical Markdown-frontmatter style is `tags:\\n  - research` — so a
    default-dumped index red-failed consumer repos' Format CI on every
    regeneration (third defect found in the 2026-07-10 sweep, after the
    MD060 empty cells and the non-v3 id).
    """

    def increase_indent(self, flow: bool = False, indentless: bool = False):
        return super().increase_indent(flow, False)
_COLUMNS = ("id", "title", "created", "updated", "status", "confidence", "tags", "related")


def collect_reports(research_dir: Path) -> list[dict]:
    """Frontmatter of every top-level research report, sorted by created desc."""
    rows: list[dict] = []
    for md in sorted(Path(research_dir).glob("*.md")):
        if md.name == INDEX_NAME:
            continue
        # A single unparseable/unreadable report must not abort regeneration of
        # the whole index (parity with the validator's per-file resilience).
        try:
            fm = read_frontmatter(md)
        except (yaml.YAMLError, OSError, UnicodeDecodeError) as exc:
            print(f"warning: skipping {md.name}: {exc}", file=sys.stderr)
            continue
        if fm is None or fm.get("doc_type") != "research":
            continue
        rows.append(fm)
    rows.sort(key=lambda fm: str(fm.get("created", "")), reverse=True)
    return rows


def _cell(value) -> str:
    if isinstance(value, list):
        text = " ".join(str(v) for v in value)
    else:
        text = "" if value is None else str(value)
    # An empty value must render as an em dash, not an empty `|  |` cell:
    # markdownlint MD060 (table-column-style) rejects ambiguous empty cells,
    # so a tag-less/related-less report would red-fail every consumer repo's
    # lint CI on regeneration (bit homelab 2026-07-05..10; same lesson as the
    # homelab bugs-INDEX generator, 2026-06-14).
    if not text.strip():
        return "—"
    # Escape table delimiters so a report field can't inject columns or rows
    # into the generated index (`|` -> `\|`; newlines collapsed to spaces).
    return text.replace("|", "\\|").replace("\r", " ").replace("\n", " ")


_ID_RE = r"index-[0-9a-z]{6}-[a-z0-9][a-z0-9-]*"


def render_index(rows: list[dict], existing: dict | None = None) -> str:
    created = min((str(r.get("created", "")) for r in rows), default="")
    updated = max((str(r.get("updated", "")) for r in rows), default="")
    existing = existing or {}
    # Preserve a consumer repo's own id/description across regenerations: the
    # id is referenced per-repo (validate-references) and MUST NOT churn, and
    # repos hand-tune the description. The fixed-token default only seeds a
    # FRESH index (project-standards v3 validate-id format; a fixed token —
    # never random — so back-to-back regens stay idempotent).
    existing_id = str(existing.get("id") or "")
    doc_id = existing_id if re.fullmatch(_ID_RE, existing_id) else "index-7x8u66-research-index"
    description = str(existing.get("description") or "") \
        or "Generated index of qdev research reports. Do not edit by hand."
    fm = {
        "schema_version": "1.0",
        "id": doc_id,
        "title": "Research Index",
        "description": description,
        "doc_type": "index",
        "status": "active",
        "created": created or "1970-01-01",
        "updated": updated or "1970-01-01",
        "tags": ["research", "index"],
        "aliases": [],
        "related": [],
    }
    header = ("---\n"
              + yaml.dump(fm, Dumper=_IndentedDumper, sort_keys=False).strip()
              + "\n---\n")
    lines = [
        "",
        "# Research Index",
        "",
        "| " + " | ".join(_COLUMNS) + " |",
        "| " + " | ".join("---" for _ in _COLUMNS) + " |",
    ]
    for r in rows:
        lines.append("| " + " | ".join(_cell(r.get(c)) for c in _COLUMNS) + " |")
    return header + "\n".join(lines) + "\n"


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print("usage: build_research_index.py <research-dir>", file=sys.stderr)
        return 2
    research_dir = Path(argv[1])
    if not research_dir.is_dir():
        print(f"not a directory: {research_dir}", file=sys.stderr)
        return 2
    rows = collect_reports(research_dir)
    # Existing-index frontmatter feeds id/description preservation; a missing
    # or unparseable index simply seeds the defaults.
    existing = None
    index_path = research_dir / INDEX_NAME
    if index_path.exists():
        try:
            existing = read_frontmatter(index_path)
        except (yaml.YAMLError, OSError, UnicodeDecodeError):
            existing = None
    (research_dir / INDEX_NAME).write_text(render_index(rows, existing), encoding="utf-8")
    print(f"index: {len(rows)} report(s) -> {research_dir / INDEX_NAME}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))

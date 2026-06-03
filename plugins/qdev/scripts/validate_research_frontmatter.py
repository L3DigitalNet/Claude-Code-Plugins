# /// script
# requires-python = ">=3.11"
# dependencies = ["pyyaml>=6.0.2", "jsonschema>=4.23.0"]
# ///
"""Validate research-report frontmatter against the vendored project-standards schema.

Frontmatter is REQUIRED: a top-level docs/research report with no leading
frontmatter block is a failure (the one legacy report is migrated into
compliance - see the D1 spec section 4.4). Validates against the co-located
markdown-frontmatter.schema.json (JSON Schema Draft 2020-12).

Usage: uv run validate_research_frontmatter.py <file.md> [<file.md> ...]
Exit:  0 all valid; 1 any invalid; 2 bad invocation
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import yaml
from jsonschema import Draft202012Validator

from _frontmatter import extract_frontmatter

SCHEMA_PATH = Path(__file__).with_name("markdown-frontmatter.schema.json")


def build_validator() -> Draft202012Validator:
    schema = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
    return Draft202012Validator(schema)


def validate_file(path: Path, validator: Draft202012Validator) -> list[str]:
    """Return a list of human-readable error strings ([] means valid).

    Read/parse failures become a single per-file error rather than a crash, so
    one bad file among many does not abort the run (CR-003)."""
    try:
        text = Path(path).read_text(encoding="utf-8")
    except OSError as exc:
        return [f"cannot read file: {exc}"]
    try:
        fm = extract_frontmatter(text)
    except yaml.YAMLError as exc:
        return [f"invalid YAML frontmatter: {exc}"]
    if fm is None:
        return ["no frontmatter block found (required)"]
    errors = sorted(validator.iter_errors(fm), key=lambda e: list(e.path))
    return [f"{'/'.join(map(str, e.path)) or '<root>'}: {e.message}" for e in errors]


def main(argv: list[str]) -> int:
    files = argv[1:]
    if not files:
        print("usage: validate_research_frontmatter.py <file.md> ...", file=sys.stderr)
        return 2
    validator = build_validator()
    failed = False
    for f in files:
        for err in validate_file(Path(f), validator):
            failed = True
            print(f"{f}: {err}")
    if not failed:
        print(f"ok: {len(files)} file(s) valid")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))

import textwrap
from pathlib import Path

import validate_research_frontmatter as val

VALID = textwrap.dedent("""\
    ---
    schema_version: "1.0"
    id: "2026-01-01-alpha"
    title: "Research: Alpha"
    description: "A one-sentence description."
    doc_type: "research"
    status: "active"
    created: "2026-01-01"
    updated: "2026-01-01"
    tags: ["alpha"]
    aliases: []
    related: []
    ---

    # Body
    """)


def _write(p: Path, text: str) -> Path:
    p.write_text(text, encoding="utf-8")
    return p


def test_valid_report_has_no_errors(tmp_path):
    f = _write(tmp_path / "a.md", VALID)
    assert val.validate_file(f, val.build_validator()) == []


def test_missing_required_field_fails(tmp_path):
    f = _write(tmp_path / "a.md", VALID.replace('tags: ["alpha"]\n', ""))
    assert val.validate_file(f, val.build_validator())  # non-empty


def test_bad_enum_fails(tmp_path):
    f = _write(tmp_path / "a.md", VALID.replace('doc_type: "research"', 'doc_type: "bogus"'))
    assert val.validate_file(f, val.build_validator())


def test_additional_property_fails(tmp_path):
    f = _write(tmp_path / "a.md", VALID.replace("---\n\n# Body", "extra_key: nope\n---\n\n# Body"))
    assert val.validate_file(f, val.build_validator())


def test_missing_frontmatter_fails(tmp_path):
    f = _write(tmp_path / "a.md", "# Just a heading, no frontmatter\n")
    errs = val.validate_file(f, val.build_validator())
    assert errs and "no frontmatter" in errs[0].lower()


def test_main_exit_codes(tmp_path):
    good = _write(tmp_path / "good.md", VALID)
    assert val.main(["validate_research_frontmatter.py", str(good)]) == 0
    bad = _write(tmp_path / "bad.md", "# nope\n")
    assert val.main(["validate_research_frontmatter.py", str(bad)]) == 1
    assert val.main(["validate_research_frontmatter.py"]) == 2


def test_unquoted_dates_validate_ok(tmp_path):
    text = VALID.replace('created: "2026-01-01"', "created: 2026-01-01").replace(
        'updated: "2026-01-01"', "updated: 2026-01-01")
    f = _write(tmp_path / "a.md", text)
    assert val.validate_file(f, val.build_validator()) == []


def test_malformed_yaml_reports_error_without_crashing(tmp_path):
    f = _write(tmp_path / "a.md", "---\nid: [unbalanced\n---\n\n# Body\n")
    errs = val.validate_file(f, val.build_validator())
    assert errs and "yaml" in errs[0].lower()


def test_missing_file_reports_error(tmp_path):
    errs = val.validate_file(tmp_path / "nope.md", val.build_validator())
    assert errs and "read" in errs[0].lower()

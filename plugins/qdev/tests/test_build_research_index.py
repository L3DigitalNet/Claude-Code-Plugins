import re
import textwrap
from pathlib import Path

import build_research_index as gen


def _report(d: Path, slug: str, created: str, *, doc_type="research", title="T", tags=("a",)):
    fm = textwrap.dedent(f"""\
        ---
        schema_version: "1.0"
        id: "{slug}"
        title: "{title}"
        description: "d"
        doc_type: "{doc_type}"
        status: "active"
        created: "{created}"
        updated: "{created}"
        tags: [{", ".join(tags)}]
        aliases: []
        related: []
        ---

        # {title}
        """)
    (d / f"{slug}.md").write_text(fm, encoding="utf-8")


def test_collect_skips_index_and_non_research(tmp_path):
    _report(tmp_path, "2026-01-01-alpha", "2026-01-01")
    _report(tmp_path, "2026-02-01-beta", "2026-02-01", doc_type="note")  # excluded
    (tmp_path / "index.md").write_text("---\ndoc_type: index\n---\n", encoding="utf-8")
    rows = gen.collect_reports(tmp_path)
    ids = [r["id"] for r in rows]
    assert ids == ["2026-01-01-alpha"]


def test_collect_skips_report_with_malformed_frontmatter(tmp_path):
    # One unparseable report must not crash regeneration of the whole index.
    _report(tmp_path, "2026-01-01-alpha", "2026-01-01")
    (tmp_path / "2026-02-01-bad.md").write_text(
        "---\nid: [unbalanced\n---\n\n# Bad\n", encoding="utf-8"
    )
    rows = gen.collect_reports(tmp_path)  # must not raise
    assert [r["id"] for r in rows] == ["2026-01-01-alpha"]


def test_collect_skips_report_with_invalid_utf8(tmp_path):
    # A non-UTF-8 byte (UnicodeDecodeError is a ValueError, not OSError) must
    # not crash regeneration any more than malformed YAML does.
    _report(tmp_path, "2026-01-01-alpha", "2026-01-01")
    (tmp_path / "2026-02-01-bad.md").write_bytes(b"---\nid: \xff\xfe bad\n---\n# B\n")
    rows = gen.collect_reports(tmp_path)  # must not raise
    assert [r["id"] for r in rows] == ["2026-01-01-alpha"]


def test_collect_sorts_by_created_desc(tmp_path):
    _report(tmp_path, "2026-01-01-alpha", "2026-01-01")
    _report(tmp_path, "2026-03-01-gamma", "2026-03-01")
    rows = gen.collect_reports(tmp_path)
    assert [r["id"] for r in rows] == ["2026-03-01-gamma", "2026-01-01-alpha"]


def test_main_creates_index_when_absent(tmp_path):
    _report(tmp_path, "2026-01-01-alpha", "2026-01-01")
    assert not (tmp_path / "index.md").exists()
    rc = gen.main(["build_research_index.py", str(tmp_path)])
    assert rc == 0
    index = (tmp_path / "index.md").read_text(encoding="utf-8")
    assert "2026-01-01-alpha" in index
    assert "doc_type: index" in index


def test_pipe_in_field_is_escaped_not_column_injection(tmp_path):
    # A `|` in report content must not inject extra table columns into the index.
    _report(tmp_path, "2026-01-01-alpha", "2026-01-01", title="Pipe | Inject")
    gen.main(["build_research_index.py", str(tmp_path)])
    index = (tmp_path / "index.md").read_text(encoding="utf-8")
    row = next(
        line for line in index.splitlines()
        if line.startswith("|") and "2026-01-01-alpha" in line
    )
    # split only on UNescaped pipes; a well-formed row is leading "" + N cols + trailing ""
    cells = re.split(r"(?<!\\)\|", row)
    assert len(cells) == len(gen._COLUMNS) + 2
    assert r"\|" in index  # the literal pipe survived as an escaped delimiter


def test_empty_dir_writes_index_with_epoch_defaults(tmp_path):
    rc = gen.main(["build_research_index.py", str(tmp_path)])
    assert rc == 0
    index = (tmp_path / "index.md").read_text(encoding="utf-8")
    assert "doc_type: index" in index
    assert "1970-01-01" in index  # min/max default when there are no reports


def test_main_bad_arg_count_returns_2():
    assert gen.main(["build_research_index.py"]) == 2
    assert gen.main(["build_research_index.py", "a", "b"]) == 2


def test_main_non_directory_returns_2(tmp_path):
    missing = tmp_path / "nope"
    assert gen.main(["build_research_index.py", str(missing)]) == 2


def test_glob_is_non_recursive_skips_subdirectories(tmp_path):
    _report(tmp_path, "2026-01-01-top", "2026-01-01")
    sub = tmp_path / "nested"
    sub.mkdir()
    _report(sub, "2026-02-01-nested", "2026-02-01")
    ids = [r["id"] for r in gen.collect_reports(tmp_path)]
    assert ids == ["2026-01-01-top"]


def test_regeneration_is_idempotent(tmp_path):
    _report(tmp_path, "2026-01-01-alpha", "2026-01-01")
    gen.main(["build_research_index.py", str(tmp_path)])
    first = (tmp_path / "index.md").read_text(encoding="utf-8")
    gen.main(["build_research_index.py", str(tmp_path)])
    second = (tmp_path / "index.md").read_text(encoding="utf-8")
    assert first == second


def test_empty_field_renders_em_dash_not_blank_cell(tmp_path):
    # markdownlint MD060 rejects ambiguous empty `|  |` cells; a report with no
    # related entries must render `—` so consumer-repo lint CI stays green
    # (homelab redness 2026-07-05..10).
    _report(tmp_path, "2026-01-01-alpha", "2026-01-01")  # related: [] in _report
    gen.main(["build_research_index.py", str(tmp_path)])
    index = (tmp_path / "index.md").read_text(encoding="utf-8")
    row = next(
        line for line in index.splitlines()
        if line.startswith("|") and "2026-01-01-alpha" in line
    )
    assert "|  |" not in row
    assert "— |" in row


def test_cell_empty_values_all_render_em_dash():
    assert gen._cell(None) == "—"
    assert gen._cell("") == "—"
    assert gen._cell([]) == "—"
    assert gen._cell("   ") == "—"
    assert gen._cell(["x"]) == "x"  # non-empty values unchanged


def test_index_id_is_v3_validate_id_compliant(tmp_path):
    # project-standards v3: id must be {doc_type}-{base36-6}-{slug}. The old
    # hardcoded `research-index` red-failed every consumer repo's Validate CI.
    gen.main(["build_research_index.py", str(tmp_path)])
    index = (tmp_path / "index.md").read_text(encoding="utf-8")
    m = re.search(r"^id: (\S+)$", index, re.M)
    assert m, "index frontmatter must carry an id"
    assert re.fullmatch(r"index-[0-9a-z]{6}-[a-z0-9-]+", m.group(1)), m.group(1)


def test_index_id_is_stable_across_regenerations(tmp_path):
    # The token must be FIXED — a random token would churn the id (and break
    # consumer-repo references) on every regeneration.
    gen.main(["build_research_index.py", str(tmp_path)])
    first = (tmp_path / "index.md").read_text(encoding="utf-8")
    gen.main(["build_research_index.py", str(tmp_path)])
    assert (tmp_path / "index.md").read_text(encoding="utf-8") == first
    assert "index-7x8u66-research-index" in first


def test_frontmatter_sequences_are_prettier_indented(tmp_path):
    # Prettier's canonical frontmatter style indents block sequences; PyYAML's
    # flush-left default fails consumer repos' Format CI on every regen.
    gen.main(["build_research_index.py", str(tmp_path)])
    index = (tmp_path / "index.md").read_text(encoding="utf-8")
    assert "tags:\n  - research\n  - index\n" in index
    assert "\n- research" not in index

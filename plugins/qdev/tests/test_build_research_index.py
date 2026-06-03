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


def test_regeneration_is_idempotent(tmp_path):
    _report(tmp_path, "2026-01-01-alpha", "2026-01-01")
    gen.main(["build_research_index.py", str(tmp_path)])
    first = (tmp_path / "index.md").read_text(encoding="utf-8")
    gen.main(["build_research_index.py", str(tmp_path)])
    second = (tmp_path / "index.md").read_text(encoding="utf-8")
    assert first == second

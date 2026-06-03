# qdev Research Reporting Cycle + Routing Refinement (D1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give `qdev`'s research corpus structured project-standards frontmatter with a regenerable index + dedup, and refine `qdev-researcher`'s routing to the per-path "context has a lifetime" model.

**Architecture:** Two deterministic PEP 723 Python scripts (run via `uv run`) — an index generator and a frontmatter validator — share a tiny YAML-frontmatter parser. The `qdev-researcher` agent emits project-standards `research` frontmatter, calls the scripts for dedup/index/self-validation, and routes Tavily-first (recall) with a Context7 docs-vs-web gate. One legacy report is migrated into compliance.

**Tech Stack:** Python 3.11+ (PEP 723 inline metadata, `uv run`), `pyyaml`, `jsonschema` (Draft 2020-12), pytest. Markdown agent/command definitions. project-standards Markdown Frontmatter Standard.

**Source spec:** [`docs/plans/2026-06-03-qdev-research-reporting-design.md`](2026-06-03-qdev-research-reporting-design.md) (survived 3 adversarial audit rounds). Section references below (§N) point at it.

**Naming note:** the design's §9 used hyphenated script names; this plan uses **underscores** (`build_research_index.py`, `validate_research_frontmatter.py`, `_frontmatter.py`) so the pytest suite can `import` them. `uv run <path>` is unaffected.

**Revision:** revised after **plan-review audit round 1** (Codex) — CR-001 (qualified `subagent_type`), CR-002 (deterministic dedup helper + tests), CR-003 (date coercion + parser error handling) all addressed; see the Plan-review audit ledger at the end.

---

## File structure

| File | Responsibility | New? |
| --- | --- | --- |
| `plugins/qdev/scripts/_frontmatter.py` | Parse the leading YAML frontmatter block (shared); coerce YAML dates → ISO strings (CR-003) | new |
| `plugins/qdev/scripts/dedup.py` | Deterministic dedup decision (update / new+related / supersede), owned by one testable function (CR-002) | new |
| `plugins/qdev/scripts/build_research_index.py` | Regenerate `docs/research/index.md` from report frontmatter (regenerate-only) | new |
| `plugins/qdev/scripts/validate_research_frontmatter.py` | Validate report frontmatter against the vendored schema | new |
| `plugins/qdev/scripts/markdown-frontmatter.schema.json` | Vendored copy of the project-standards schema (no cross-repo dep) | new |
| `plugins/qdev/tests/conftest.py` | Put `scripts/` on `sys.path` for imports | new |
| `plugins/qdev/tests/requirements.txt` | pytest + pyyaml + jsonschema | new |
| `plugins/qdev/tests/test_frontmatter.py` | Unit tests for the parser | new |
| `plugins/qdev/tests/test_build_research_index.py` | Unit tests for the generator | new |
| `plugins/qdev/tests/test_validate_research_frontmatter.py` | Unit tests for the validator (incl. unquoted dates, malformed YAML, missing file) | new |
| `plugins/qdev/tests/test_dedup.py` | Unit tests for every dedup decision-table branch | new |
| `plugins/qdev/agents/qdev-researcher.md` | Frontmatter emit, Sources table, per-path routing, Context7 gate + dual-grant, quirks, fallback, guardrails, self-validate, dedup/index calls | modify |
| `plugins/qdev/commands/research.md` | Relay reconciled header; mention the index in the handoff | modify |
| `docs/research/2026-05-08-up-docs-plugin-security-eval-infrastructure.md` | Migrate to `research` frontmatter | modify |
| `docs/architecture.md` | qdev gains Python/tests; scrub dead `testing/STRATEGY.md` refs | modify |
| `docs/conventions.md` | TEST-001: add qdev pytest; scrub dead `testing/STRATEGY.md` refs | modify |
| `plugins/qdev/README.md` | Document the reporting cycle + per-path routing | modify |
| `plugins/qdev/CHANGELOG.md` | `[Unreleased]` entries | modify |
| `~/.claude/CLAUDE.md` | Routing reconciliation (§8 — **confirm wording first**) | modify (external) |

---

## Task 0: Scaffold tests dir + vendor the schema

**Files:**
- Create: `plugins/qdev/scripts/markdown-frontmatter.schema.json`
- Create: `plugins/qdev/tests/requirements.txt`
- Create: `plugins/qdev/tests/conftest.py`

- [ ] **Step 1: Vendor the schema**

Copy the canonical schema verbatim:

```bash
mkdir -p plugins/qdev/scripts plugins/qdev/tests
cp /home/chris/projects/project-standards/schemas/markdown-frontmatter.schema.json \
   plugins/qdev/scripts/markdown-frontmatter.schema.json
```

- [ ] **Step 2: Add a sync note beside the vendored schema**

Create `plugins/qdev/scripts/README.md`:

```markdown
# qdev research-KB scripts

`markdown-frontmatter.schema.json` is a **vendored copy** of the canonical
schema at `L3DigitalNet/project-standards:schemas/markdown-frontmatter.schema.json`.
It is a dated snapshot (copied 2026-06-03); re-sync from upstream when the
standard changes. Vendored to avoid a cross-repo path dependency when qdev
runs in arbitrary consuming projects.

Scripts are PEP 723 inline-metadata scripts; run them with `uv run <script>.py`.
```

- [ ] **Step 3: Create the test requirements**

Create `plugins/qdev/tests/requirements.txt`:

```text
pytest>=8.3.0
pyyaml>=6.0.2
jsonschema>=4.23.0
```

- [ ] **Step 4: Create conftest to import the scripts**

Create `plugins/qdev/tests/conftest.py`:

```python
"""Put the plugin's scripts/ dir on sys.path so tests can import the
PEP 723 helper modules (build_research_index, validate_research_frontmatter,
_frontmatter) by name."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
```

- [ ] **Step 5: Verify the vendored schema is valid JSON**

Run: `python3 -c "import json; json.load(open('plugins/qdev/scripts/markdown-frontmatter.schema.json'))" && echo OK`
Expected: `OK`

- [ ] **Step 6: Commit**

```bash
git add plugins/qdev/scripts/markdown-frontmatter.schema.json plugins/qdev/scripts/README.md plugins/qdev/tests/requirements.txt plugins/qdev/tests/conftest.py
git commit -m "test(qdev): scaffold research-KB tests dir + vendor frontmatter schema"
```

---

## Task 1: Shared frontmatter parser (`_frontmatter.py`)

**Files:**
- Create: `plugins/qdev/scripts/_frontmatter.py`
- Test: `plugins/qdev/tests/test_frontmatter.py`

- [ ] **Step 1: Write the failing tests**

Create `plugins/qdev/tests/test_frontmatter.py`:

```python
from _frontmatter import extract_frontmatter


def test_extracts_leading_block():
    text = "---\nid: x\ntags:\n  - a\n---\n\n# Body\n"
    assert extract_frontmatter(text) == {"id": "x", "tags": ["a"]}


def test_absent_block_returns_none():
    assert extract_frontmatter("# No frontmatter here\n") is None


def test_block_not_at_top_is_not_frontmatter():
    text = "Intro paragraph\n\n---\nid: x\n---\n"
    assert extract_frontmatter(text) is None


def test_non_mapping_returns_none():
    # A YAML list at the top is not a frontmatter mapping.
    assert extract_frontmatter("---\n- a\n- b\n---\n") is None


def test_unquoted_dates_coerced_to_iso_strings():
    # YAML parses unquoted dates as datetime.date; the string-typed schema
    # needs ISO strings. (CR-003)
    fm = extract_frontmatter("---\ncreated: 2026-06-03\nupdated: 2026-06-03\n---\n")
    assert fm == {"created": "2026-06-03", "updated": "2026-06-03"}
    assert isinstance(fm["created"], str)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd plugins/qdev/tests && uv run --with pyyaml --with pytest pytest test_frontmatter.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named '_frontmatter'`

- [ ] **Step 3: Implement the parser**

Create `plugins/qdev/scripts/_frontmatter.py`:

```python
"""Shared YAML-frontmatter parsing for the qdev research-KB scripts.

Recognises a frontmatter block only at the very top of the file (the \\A
anchor), matching the canonical project-standards validator: a `---` block
appearing anywhere else is intentionally NOT treated as frontmatter.

Unquoted YAML dates (`created: 2026-06-03`) parse as `datetime.date`, but the
schema validates those fields as strings; `_coerce_dates` converts them to ISO
strings so authors may write either form. (Parity with the canonical
project-standards `_coerce_dates` — CR-003.)
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
    absent or not a mapping. Raises yaml.YAMLError on malformed YAML — callers
    that validate files catch it and report a per-file error."""
    match = _FM_RE.match(text)
    if not match:
        return None
    data = yaml.safe_load(match.group(1))
    return _coerce_dates(data) if isinstance(data, dict) else None


def read_frontmatter(path: Path) -> dict | None:
    """Read a file and return its frontmatter mapping (or None)."""
    return extract_frontmatter(Path(path).read_text(encoding="utf-8"))
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd plugins/qdev/tests && uv run --with pyyaml --with pytest pytest test_frontmatter.py -v`
Expected: PASS — 5 passed

- [ ] **Step 5: Commit**

```bash
git add plugins/qdev/scripts/_frontmatter.py plugins/qdev/tests/test_frontmatter.py
git commit -m "feat(qdev): add shared frontmatter parser for research-KB scripts"
```

---

## Task 2: Index generator (`build_research_index.py`)

**Files:**
- Create: `plugins/qdev/scripts/build_research_index.py`
- Test: `plugins/qdev/tests/test_build_research_index.py`

Design points (from §4.1): scans **non-recursive** `*.md`; skips `index.md` and any file whose `doc_type` is not `research`; sorts by `created` desc; the index's own `created`/`updated` derive from report content (min/max) so re-runs are **idempotent**; builds from existing frontmatter when `index.md` is absent (§4.4 bootstrap).

- [ ] **Step 1: Write the failing tests**

Create `plugins/qdev/tests/test_build_research_index.py`:

```python
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
    assert 'doc_type: index' in index


def test_regeneration_is_idempotent(tmp_path):
    _report(tmp_path, "2026-01-01-alpha", "2026-01-01")
    gen.main(["build_research_index.py", str(tmp_path)])
    first = (tmp_path / "index.md").read_text(encoding="utf-8")
    gen.main(["build_research_index.py", str(tmp_path)])
    second = (tmp_path / "index.md").read_text(encoding="utf-8")
    assert first == second
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd plugins/qdev/tests && uv run --with pyyaml --with pytest pytest test_build_research_index.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'build_research_index'`

- [ ] **Step 3: Implement the generator**

Create `plugins/qdev/scripts/build_research_index.py`:

```python
# /// script
# requires-python = ">=3.11"
# dependencies = ["pyyaml>=6.0.2"]
# ///
"""Regenerate docs/research/index.md from report frontmatter.

Scans the TOP-LEVEL <research-dir>/*.md reports (non-recursive), reads each
report's project-standards `research` frontmatter, and rewrites index.md
(doc_type: index) as a table sorted by `created` desc. Regenerate-only — it
never appends, so the index cannot drift from the reports.

The index's own created/updated derive from report content (min/max), so
re-running with unchanged reports yields an identical file (idempotent).

Usage: uv run build_research_index.py <research-dir>      # e.g. docs/research
"""
from __future__ import annotations

import sys
from pathlib import Path

import yaml

from _frontmatter import read_frontmatter

INDEX_NAME = "index.md"
_COLUMNS = ("id", "title", "created", "updated", "status", "confidence", "tags", "related")


def collect_reports(research_dir: Path) -> list[dict]:
    """Frontmatter of every top-level research report, sorted by created desc."""
    rows: list[dict] = []
    for md in sorted(Path(research_dir).glob("*.md")):
        if md.name == INDEX_NAME:
            continue
        fm = read_frontmatter(md)
        if fm is None or fm.get("doc_type") != "research":
            continue
        rows.append(fm)
    rows.sort(key=lambda fm: str(fm.get("created", "")), reverse=True)
    return rows


def _cell(value) -> str:
    if isinstance(value, list):
        return " ".join(str(v) for v in value)
    return "" if value is None else str(value)


def render_index(rows: list[dict]) -> str:
    created = min((str(r.get("created", "")) for r in rows), default="")
    updated = max((str(r.get("updated", "")) for r in rows), default="")
    fm = {
        "schema_version": "1.0",
        "id": "research-index",
        "title": "Research Index",
        "description": "Generated index of qdev research reports. Do not edit by hand.",
        "doc_type": "index",
        "status": "active",
        "created": created or "1970-01-01",
        "updated": updated or "1970-01-01",
        "tags": ["research", "index"],
        "aliases": [],
        "related": [],
    }
    header = "---\n" + yaml.safe_dump(fm, sort_keys=False).strip() + "\n---\n"
    lines = ["", "# Research Index", "",
             "| " + " | ".join(_COLUMNS) + " |",
             "| " + " | ".join("---" for _ in _COLUMNS) + " |"]
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
    (research_dir / INDEX_NAME).write_text(render_index(rows), encoding="utf-8")
    print(f"index: {len(rows)} report(s) -> {research_dir / INDEX_NAME}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd plugins/qdev/tests && uv run --with pyyaml --with pytest pytest test_build_research_index.py -v`
Expected: PASS — 4 passed

- [ ] **Step 5: Commit**

```bash
git add plugins/qdev/scripts/build_research_index.py plugins/qdev/tests/test_build_research_index.py
git commit -m "feat(qdev): add regenerable research-index generator"
```

---

## Task 3: Frontmatter validator (`validate_research_frontmatter.py`)

**Files:**
- Create: `plugins/qdev/scripts/validate_research_frontmatter.py`
- Test: `plugins/qdev/tests/test_validate_research_frontmatter.py`

Design points (from §5): frontmatter is **required** (a top-level report with none is a failure); validates against the vendored schema with `Draft202012Validator`; exit 0 all-valid, 1 any-invalid, 2 bad-invocation.

- [ ] **Step 1: Write the failing tests**

Create `plugins/qdev/tests/test_validate_research_frontmatter.py`:

```python
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
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd plugins/qdev/tests && uv run --with pyyaml --with jsonschema --with pytest pytest test_validate_research_frontmatter.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'validate_research_frontmatter'`

- [ ] **Step 3: Implement the validator**

Create `plugins/qdev/scripts/validate_research_frontmatter.py`:

```python
# /// script
# requires-python = ">=3.11"
# dependencies = ["pyyaml>=6.0.2", "jsonschema>=4.23.0"]
# ///
"""Validate research-report frontmatter against the vendored project-standards schema.

Frontmatter is REQUIRED: a top-level docs/research report with no leading
frontmatter block is a failure (the one legacy report is migrated into
compliance — see the D1 spec §4.4). Validates against the co-located
markdown-frontmatter.schema.json (JSON Schema Draft 2020-12).

Usage: uv run validate_research_frontmatter.py <file.md> [<file.md> ...]
Exit:  0 all valid · 1 any invalid · 2 bad invocation
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
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd plugins/qdev/tests && uv run --with pyyaml --with jsonschema --with pytest pytest test_validate_research_frontmatter.py -v`
Expected: PASS — 9 passed

- [ ] **Step 5: Run the whole qdev suite so far**

Run: `cd plugins/qdev/tests && uv run --with pyyaml --with jsonschema --with pytest pytest -v`
Expected: PASS — 18 passed (5 parser + 4 generator + 9 validator; dedup added in Task 3b)

- [ ] **Step 6: Commit**

```bash
git add plugins/qdev/scripts/validate_research_frontmatter.py plugins/qdev/tests/test_validate_research_frontmatter.py
git commit -m "feat(qdev): add scoped research-frontmatter validator"
```

---

## Task 3b: Deterministic dedup decision helper (CR-002)

**Files:**
- Create: `plugins/qdev/scripts/dedup.py`
- Test: `plugins/qdev/tests/test_dedup.py`

The design's dedup decision table (§4.2) is the KB's core behavior. Extract the _decision_ into one pure function so every branch is unit-tested; the agent supplies the judgment-based inputs (matched-tag count, age, fast-moving?, different-angle?, replaces?) and follows the returned action.

- [ ] **Step 1: Write the failing tests**

Create `plugins/qdev/tests/test_dedup.py`:

```python
from dedup import decide


def test_under_two_matches_is_plain_new():
    assert decide(matched=1, months_old=1, fast_moving=False,
                  different_angle=False, replaces=False) == {
        "action": "new", "related": False, "supersede": False}


def test_recent_overlap_not_fast_moving_updates():
    assert decide(matched=3, months_old=2, fast_moving=False,
                  different_angle=False, replaces=False) == {
        "action": "update", "related": False, "supersede": False}


def test_old_fast_moving_new_related_and_supersedes_when_replacing():
    assert decide(matched=3, months_old=9, fast_moving=True,
                  different_angle=False, replaces=True) == {
        "action": "new", "related": True, "supersede": True}


def test_old_fast_moving_new_related_without_supersede():
    assert decide(matched=3, months_old=9, fast_moving=True,
                  different_angle=False, replaces=False) == {
        "action": "new", "related": True, "supersede": False}


def test_different_angle_new_related():
    assert decide(matched=3, months_old=2, fast_moving=False,
                  different_angle=True, replaces=False) == {
        "action": "new", "related": True, "supersede": False}


def test_old_not_fast_not_different_falls_back_to_new_related():
    assert decide(matched=3, months_old=9, fast_moving=False,
                  different_angle=False, replaces=False) == {
        "action": "new", "related": True, "supersede": False}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd plugins/qdev/tests && uv run --with pytest pytest test_dedup.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'dedup'`

- [ ] **Step 3: Implement the decision helper**

Create `plugins/qdev/scripts/dedup.py`:

```python
# /// script
# requires-python = ">=3.11"
# ///
"""Deterministic dedup decision for the qdev research KB.

The agent computes the (judgment-based) facts about the best-matching existing
report; this module owns the (deterministic) decision so each branch of the
design's decision table (§4.2) is unit-testable. Precedence is explicit:

1. <2 tags match            -> new (no link)
2. different angle          -> new + related
3. recent & not fast-moving -> update in place
4. fast-moving              -> new + related (+ supersede if it replaces the old)
5. otherwise (old, stable)  -> new + related
"""
from __future__ import annotations

import argparse
import json
import sys

RECENT_MONTHS = 6


def decide(*, matched: int, months_old: float, fast_moving: bool,
           different_angle: bool, replaces: bool) -> dict:
    if matched < 2:
        return {"action": "new", "related": False, "supersede": False}
    if different_angle:
        return {"action": "new", "related": True, "supersede": False}
    if months_old < RECENT_MONTHS and not fast_moving:
        return {"action": "update", "related": False, "supersede": False}
    if fast_moving:
        return {"action": "new", "related": True, "supersede": bool(replaces)}
    return {"action": "new", "related": True, "supersede": False}


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--matched", type=int, required=True)
    parser.add_argument("--months-old", type=float, required=True)
    parser.add_argument("--fast-moving", action="store_true")
    parser.add_argument("--different-angle", action="store_true")
    parser.add_argument("--replaces", action="store_true")
    a = parser.parse_args(argv[1:])
    print(json.dumps(decide(matched=a.matched, months_old=a.months_old,
                            fast_moving=a.fast_moving,
                            different_angle=a.different_angle,
                            replaces=a.replaces)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd plugins/qdev/tests && uv run --with pytest pytest test_dedup.py -v`
Expected: PASS — 6 passed

- [ ] **Step 5: Run the whole qdev suite**

Run: `cd plugins/qdev/tests && uv run --with pyyaml --with jsonschema --with pytest pytest -v`
Expected: PASS — 24 passed (5 parser + 4 generator + 9 validator + 6 dedup)

- [ ] **Step 6: Commit**

```bash
git add plugins/qdev/scripts/dedup.py plugins/qdev/tests/test_dedup.py
git commit -m "feat(qdev): deterministic dedup decision helper with per-branch tests"
```

---

## Task 4: Migrate the legacy report (§4.4)

**Files:**
- Modify: `docs/research/2026-05-08-up-docs-plugin-security-eval-infrastructure.md:1`

- [ ] **Step 1: Read the report's first heading + intro**

Run: `head -5 docs/research/2026-05-08-up-docs-plugin-security-eval-infrastructure.md`
Use the heading/intro to fill `title` and `description` below.

- [ ] **Step 2: Prepend the `research` frontmatter block**

Insert at the very top of the file (before the existing `#` heading), filling `title`/`description`/`tags` from the content:

```yaml
---
schema_version: "1.0"
id: "2026-05-08-up-docs-plugin-security-eval-infrastructure"
title: "Plugin-Shipped Security/Eval Infrastructure for Claude Code Plugins"
description: "Research backing the up-docs hardening plan v2: plugin-shipped security and eval infrastructure primitives."
doc_type: "research"
status: "active"
created: "2026-05-08"
updated: "2026-06-03"
reviewed: null
owner: ""
tags:
  - claude-code
  - plugins
  - security
  - eval
aliases:
  - up-docs-security-eval
related: []
source: []
confidence: "high"
visibility: "internal"
license: null
---
```

- [ ] **Step 3: Validate the migrated report**

Run: `uv run plugins/qdev/scripts/validate_research_frontmatter.py docs/research/2026-05-08-up-docs-plugin-security-eval-infrastructure.md`
Expected: `ok: 1 file(s) valid`

- [ ] **Step 4: Generate the index and confirm the report appears**

Run: `uv run plugins/qdev/scripts/build_research_index.py docs/research && grep -c "up-docs-plugin-security-eval-infrastructure" docs/research/index.md`
Expected: `index: 1 report(s) -> docs/research/index.md` then `1`

- [ ] **Step 5: Validate the generated index too**

Run: `uv run plugins/qdev/scripts/validate_research_frontmatter.py docs/research/index.md`
Expected: `ok: 1 file(s) valid`

- [ ] **Step 6: Commit**

```bash
git add docs/research/2026-05-08-up-docs-plugin-security-eval-infrastructure.md docs/research/index.md
git commit -m "docs(qdev): migrate legacy research report to project-standards frontmatter + seed index"
```

---

## Task 5: Refine `qdev-researcher` (routing + reporting + guardrails)

**Files:**
- Modify: `plugins/qdev/agents/qdev-researcher.md`

This is a prose/agent-definition change; verification is structural (grep + validator), with end-to-end behavior deferred to the acceptance task.

- [ ] **Step 1: Grant both Context7 tool-name variants (§6.2, SA-004)**

In the frontmatter `tools:` line, add the `get-library-docs` variant next to `query-docs`. Replace:

```yaml
tools: Read, Write, Bash, WebFetch, mcp__brave-search__brave_web_search, mcp__serper-search__google_search, mcp__tavily-mcp__tavily_search, mcp__tavily-mcp__tavily_extract, mcp__plugin_context7_context7__query-docs, mcp__plugin_context7_context7__resolve-library-id
```

with:

```yaml
tools: Read, Write, Bash, WebFetch, mcp__brave-search__brave_web_search, mcp__serper-search__google_search, mcp__tavily-mcp__tavily_search, mcp__tavily-mcp__tavily_extract, mcp__plugin_context7_context7__query-docs, mcp__plugin_context7_context7__get-library-docs, mcp__plugin_context7_context7__resolve-library-id
```

- [ ] **Step 2: Replace the search step (per-path routing, §6.1)**

Replace task step 5 (`**Execute search.** For each query, run BOTH ...`) with:

```markdown
5. **Execute search (per-path: this agent is the recall engine).** Route Tavily-first:
   `mcp__tavily-mcp__tavily_search` (the primary recall pass; `search_depth=basic`,
   `advanced` for high-stakes — never `fast`, which returns empty) → cross-check the
   top claims with `mcp__brave-search__brave_web_search` → use
   `mcp__serper-search__google_search` only for Google-specific operators (`site:`,
   `filetype:`), always passing `gl: us, hl: en`. `tavily_search`'s `topic` is
   `general`-only in the MCP schema; route news/finance angles to Brave instead.
```

- [ ] **Step 3: Add the Context7 gate + scoring + version pinning (§6.2)**

Replace task step 3 (`**Library route (when applicable).** ...`) with:

```markdown
3. **Library route — Context7 docs-vs-web gate (when applicable).** Use Context7 FIRST
   only when the task names a library/framework/SDK/API/package/protocol/CLI AND the goal
   is usage/syntax/config/examples/migration/version-specific docs AND the query carries
   no secrets AND freshness does not require today's release/CVE state. **Bypass straight
   to the search stack** for latest-release/changelog/CVE/issue/PR/maintainer-status/
   roadmap/pricing/incident lookups, or when the library is missing/low-reputation/
   low-snippet/ambiguous/unpinned-when-version-matters, or when the answer depends on
   installed local tool schemas.
   - Resolve with `mcp__plugin_context7_context7__resolve-library-id`. Context7 usually
     returns SEVERAL candidates — **never take the first match**; score by exact-name ·
     official-vs-community · reputation · snippet-count · benchmark-score · version-match ·
     task-fit. When the project pins a version, prefer a version-pinned ID
     (e.g. `/vercel/next.js/v15.1.8`) over "latest".
   - Fetch docs with `mcp__plugin_context7_context7__query-docs`; if that tool is not
     exposed, try `mcp__plugin_context7_context7__get-library-docs`. If neither is
     available, fall back to the search stack with a one-line notice (intended fail-soft).
```

- [ ] **Step 4: Add the fail-soft fallback guardrail (§6.4) + egress/injection (§7)**

In `<guardrails>`, add these bullets:

```markdown
- **Fail-soft fallback chain.** Context7 → Tavily → Brave → Serper. On a missing/erroring
  server, degrade to the next with a one-line notice — never fail silently.
- **Query egress (sanitize before sending).** Every external/Context7 query leaves the
  machine. Never send secrets, tokens, credentials, proprietary code, customer data, or
  internal hostnames/paths — reduce to a generic task description. Per-provider risk: Brave
  lowest (only with enterprise ZDR), Context7 medium, Tavily/Serper high.
- **Source-graded confidence.** Set the report's frontmatter `confidence` from corroboration
  strength: `high` = 2+ independent or official sources with few `[unverified]` items;
  `medium` = mixed; `low` = single-source-heavy or several `[unverified]`/open items.
```

(The existing corroboration, source-grading, prompt-injection, and Tavily `fast` guardrails stay.)

- [ ] **Step 5: Rewrite the persist step to emit frontmatter, dedup, and regenerate the index (§3, §4)**

`$SCRIPTS` below is the absolute scripts dir the orchestrator passes in (Task 6 Step 2); fall back to `${CLAUDE_PLUGIN_ROOT}/scripts` if unset. Replace task step 10 (`**Persist.** Write the report to ...`) with:

```markdown
10. **Persist with the reporting cycle.**
    a. **Preflight the index (ordering, §4.4):** if `docs/research/index.md` is absent or
       stale, regenerate it first so existing reports are visible to dedup:
       `uv run "$SCRIPTS/build_research_index.py" docs/research`
    b. **Dedup (§4.2):** derive 3–5 keyword tags; match `index.md` rows by tags ∪ aliases ∪
       title overlap to find the best-matching prior report. Compute its facts (matched-tag
       count, age in months, fast-moving?, different angle?, fully-replaces?) and get the
       deterministic action from the helper:
       `uv run "$SCRIPTS/dedup.py" --matched <N> --months-old <M> [--fast-moving] [--different-angle] [--replaces]`
       which prints exactly one of:
       - `{"action":"update",...}` → bump the existing report's `updated`; append a
         `## Update: <date>` section (never rewrite prior content).
       - `{"action":"new","related":true,"supersede":true}` → new report; set
         `supersedes: [<old-id>]` here and `superseded_by: <new-id>` + `status: superseded`
         on the old report.
       - `{"action":"new","related":true,"supersede":false}` → new report; `related: [<old-id>]`.
       - `{"action":"new","related":false,...}` → new report, no link.
    c. **Write** the report to `docs/research/<YYYY-MM-DD>-<slug>.md` (slug = kebab topic,
       ≤60 chars; `id` = the filename stem). Lead the file with the project-standards
       `research` frontmatter block (all 11 required fields + `source`, `confidence`,
       `tags`, `aliases`, `related`), then the body, then the `## Sources` table.
    d. **Self-validate (§5):**
       `uv run "$SCRIPTS/validate_research_frontmatter.py" docs/research/<file>.md`
       — fix the block until it passes before continuing.
    e. **Regenerate the index:**
       `uv run "$SCRIPTS/build_research_index.py" docs/research`
```

- [ ] **Step 6: Add the frontmatter contract + Sources table to `<output_format>` (§3.1–3.2)**

At the top of the persisted-file format in `<output_format>`, document that the file leads
with the `research` frontmatter block (the `Mode: research · …` line remains the **returned**
handoff to the orchestrator, not the persisted first line — §3.4). Add a `## Sources`
section after the existing sections:

```markdown
## Sources

| URL | Title | Date | Authority |
|-----|-------|------|-----------|
```

- [ ] **Step 7: Verify the edits structurally (one check per required topic)**

Run each separately so a single topic can't mask a missing one:

```bash
A=plugins/qdev/agents/qdev-researcher.md
grep -c "get-library-docs" "$A"                  # >=1  Context7 dual grant (SA-004)
grep -c "tavily_search" "$A"                     # >=1  Tavily-first recall
grep -c "dedup.py" "$A"                          # >=1  deterministic dedup call
grep -c "build_research_index.py" "$A"           # >=2  preflight + regenerate
grep -c "validate_research_frontmatter.py" "$A"  # >=1  self-validate
grep -cE "Context7 FIRST|Context7-first" "$A"    # >=1  docs-vs-web gate
grep -cE "fail-soft|fallback chain" "$A"         # >=1  fail-soft fallback
grep -c "## Sources" "$A"                        # >=1  Sources table
grep -ciE "sanitize|egress" "$A"                 # >=1  query-egress guardrail
```

Expected: each count meets its noted minimum.

- [ ] **Step 8: Commit**

```bash
git add plugins/qdev/agents/qdev-researcher.md
git commit -m "feat(qdev): per-path routing, Context7 gate, reporting cycle + guardrails in qdev-researcher"
```

---

## Task 6: Update the `/qdev:research` command (incl. CR-001 dispatch fix)

**Files:**
- Modify: `plugins/qdev/commands/research.md:53`

- [ ] **Step 1: Fix the subagent dispatch to the qualified name (CR-001, blocking)**

Per repo convention PLUGIN-001, a bare `subagent_type` fails at runtime with
"Agent type not found" and the skill silently no-ops. The shipped command uses
the bare name. Change it:

```diff
- Use the `Agent` tool with `subagent_type: qdev-researcher` and a prompt like:
+ Use the `Agent` tool with `subagent_type: qdev:qdev-researcher` and a prompt like:
```

- [ ] **Step 2: Pass an absolute scripts path to the agent**

`${CLAUDE_PLUGIN_ROOT}` is reliably set in the command's context but is NOT
guaranteed inside the spawned agent's Bash. Have the command resolve it and
hand the agent an absolute scripts dir. Add to the dispatch prompt:

> The research-KB scripts live in `${CLAUDE_PLUGIN_ROOT}/scripts/`. Pass that
> absolute path to the agent as `SCRIPTS` so it can invoke
> `uv run "$SCRIPTS/build_research_index.py"`, `"$SCRIPTS/validate_research_frontmatter.py"`,
> and `"$SCRIPTS/dedup.py"`.

- [ ] **Step 3: Mention the reporting cycle in the dispatch prompt**

Append to the dispatch instruction list:
`run the reporting cycle (preflight index → dedup → write report with frontmatter → self-validate → regenerate index) and return the structured report per your output format.`

- [ ] **Step 4: Note the index in the final summary**

Change the final summary block to:

```text
✓ Research complete. Report: <path>  ·  Index: docs/research/index.md
```

- [ ] **Step 5: Verify (CR-001 closed)**

```bash
C=plugins/qdev/commands/research.md
grep -c "subagent_type: qdev:qdev-researcher" "$C"   # ==1  qualified name present
grep -c "subagent_type: qdev-researcher" "$C"        # ==0  bare name gone
grep -c "SCRIPTS" "$C"                                # >=1  scripts path passed
grep -c "index" "$C"                                  # >=1
```

Expected: `1`, `0`, ≥1, ≥1.

- [ ] **Step 6: Commit**

```bash
git add plugins/qdev/commands/research.md
git commit -m "fix(qdev): qualified subagent_type + pass scripts path; relay reporting cycle"
```

---

## Task 7: Repo docs (architecture, conventions, README, CHANGELOG)

**Files:**
- Modify: `docs/architecture.md:21,28,29`
- Modify: `docs/conventions.md:126,137`
- Modify: `plugins/qdev/README.md`
- Modify: `plugins/qdev/CHANGELOG.md`

- [ ] **Step 1: architecture.md — qdev now has Python + scrub dead testing refs**

- Update the "In scope: 8 plugins (all except qdev — pure-markdown only)" line: qdev now ships Python scripts + pytest, so it is no longer pure-markdown. State "9 with qdev's research-KB scripts."
- Replace the two `testing/STRATEGY.md` / `testing/plans/<plugin>.md` references (lines ~28–29) and the line ~21 reference: point at `docs/conventions.md` TEST-001 instead of the deleted `testing/` tree (the tree was removed in `66b02d4`).

- [ ] **Step 2: conventions.md — TEST-001 add qdev + scrub dead refs**

- In TEST-001, add qdev to the Python-pytest list (`qdev: N pytest` once tests land — fill the count from `pytest -q`).
- Replace the two `testing/STRATEGY.md §3` / `§3–4` source references with the surviving guidance (the rule text itself); drop the dead `testing/STRATEGY.md` citation.

- [ ] **Step 3: qdev README — document the reporting cycle + routing**

Add a short "Research reporting cycle" subsection: reports carry project-standards `research` frontmatter; `docs/research/index.md` is regenerated from frontmatter; dedup updates/links/supersedes; per-path routing (Tavily-first recall + Context7 docs-vs-web gate). Reference the two scripts.

- [ ] **Step 4: CHANGELOG `[Unreleased]`**

Add under `[Unreleased]`:

```markdown
### Added
- Research reporting cycle: `qdev-researcher` reports now carry project-standards `research`
  frontmatter; `docs/research/index.md` is regenerated from frontmatter by
  `scripts/build_research_index.py`; `scripts/validate_research_frontmatter.py` enforces the
  schema. Dedup updates/links/supersedes prior reports.

### Changed
- `qdev-researcher` routing: Tavily-first recall → Brave cross-check → Serper operators →
  Tavily extract, with a Context7 docs-vs-web gate (both `query-docs`/`get-library-docs`
  variants), enforced provider quirks (`gl/hl`, `topic=general`→Brave, `search_depth=basic`),
  and a fail-soft fallback chain.
```

- [ ] **Step 5: Verify no dead testing refs remain in the two edited docs**

Run: `grep -n "testing/STRATEGY\|testing/plans" docs/architecture.md docs/conventions.md || echo "clean"`
Expected: `clean`

- [ ] **Step 6: Commit**

```bash
git add docs/architecture.md docs/conventions.md plugins/qdev/README.md plugins/qdev/CHANGELOG.md
git commit -m "docs(qdev): document reporting cycle; bring qdev into test scope; scrub dead testing/ refs"
```

---

## Task 8: Global `~/.claude/CLAUDE.md` routing reconciliation (§8 — CONFIRM FIRST)

**Files:**
- Modify: `~/.claude/CLAUDE.md` (external — not in this repo; **not** a repo commit)

- [ ] **Step 1: Show the user the exact proposed wording and get approval**

Use `AskUserQuestion` to confirm the additive insert for the "Web search routing" section verbatim (the block in §8 of the design). Do **not** edit until approved. If the user edits the wording, use theirs.

- [ ] **Step 2: Apply the approved additive insert**

Add the approved "Route by where the result lands" block to the **Web search routing** section of `~/.claude/CLAUDE.md`. Targeted edit only — change nothing else.

- [ ] **Step 3: Verify**

Run: `grep -n "context has a lifetime\|Route by where the result lands" ~/.claude/CLAUDE.md`
Expected: ≥ 1 match.

(No repo commit — `~/.claude/CLAUDE.md` is outside this repository.)

---

## Task 9 (optional, follow-on): wire the validator into repo hygiene

**Files:** repo CI / `repo-hygiene` hook (scoped to top-level `docs/research/*.md`).

- [ ] Decide at execution time whether to wire `validate_research_frontmatter.py docs/research/*.md` into the existing hygiene/CI sweep, or leave it as the agent's self-validation only (§5 secondary). Stage as a follow-on if it expands scope.

---

## Final acceptance (run after Tasks 0–9)

- [ ] **Full qdev test suite**

Run: `cd plugins/qdev/tests && uv run --with pyyaml --with jsonschema --with pytest pytest -v`
Expected: PASS — 24 passed (5 parser + 4 generator + 9 validator + 6 dedup).

- [ ] **Dispatch smoke test (CR-001)**

In a plugin-loaded session run `/qdev:research <topic>` and confirm the
`qdev:qdev-researcher` subagent actually starts — no "Agent type not found",
no silent no-op.

- [ ] **Generator idempotency on the real corpus**

Run:

```bash
uv run plugins/qdev/scripts/build_research_index.py docs/research
git diff --quiet docs/research/index.md && echo "idempotent" || echo "DRIFT"
```

Expected: `idempotent` (after the first generation is committed).

- [ ] **Validator over the real corpus**

Run: `uv run plugins/qdev/scripts/validate_research_frontmatter.py docs/research/*.md`
Expected: `ok: N file(s) valid`.

- [ ] **End-to-end (manual):** `/qdev:research <topic>` writes a report with valid frontmatter + `## Sources`, regenerates the index, and a repeat/overlapping query exercises a dedup branch (update / new-with-`related` / supersede). A changelog/CVE topic bypasses Context7; a library topic uses it with candidate scoring.

---

## Notes for the executor

- **Worktree:** if executing via subagents, create an isolated worktree first (`superpowers:using-git-worktrees`).
- **uv invocation in tests:** the `uv run --with ... pytest` form provides deps without a `pyproject.toml`; the scripts themselves declare deps via PEP 723 so `uv run <script>.py` works standalone.
- **Do not** resurrect the `testing/` tree (removed deliberately in `66b02d4`).
- **D2 is out of scope** (escalating auto-trigger skill) — see design §12.

---

## Plan-review audit ledger

**Round 1 (2026-06-03, Codex):** verdict _needs major correction_ — 1 blocking + 2 non-blocking. All verified against repo truth and addressed:

| ID | Severity | Resolution |
| --- | --- | --- |
| CR-001 | High (blocking) | Task 6 Step 1 changes `subagent_type: qdev-researcher` → `qdev:qdev-researcher` (PLUGIN-001); Step 5 asserts the bare name is gone. Pre-existing shipped bug in `research.md`. |
| CR-002 | Medium | New Task 3b: deterministic `dedup.py` `decide()` with a per-branch pytest suite; Task 5 Step 5b calls it for the action. |
| CR-003 | Medium | Task 1 adds `_coerce_dates` (unquoted YAML dates → ISO strings); Task 3 wraps read/parse in try/except (malformed YAML / missing file → per-file error, no crash); tests cover all three. |

**Also addressed (review "missing considerations"):** Task 5 Step 7 split into one grep per topic; Task 6 Step 2 passes an absolute `$SCRIPTS` path so the agent does not depend on `${CLAUDE_PLUGIN_ROOT}` in its Bash.

**Carry-forward to verify at execution:** `${CLAUDE_PLUGIN_ROOT}` availability in the agent's Bash (mitigated by passing `$SCRIPTS`); the `get-library-docs` grant is a no-op when unavailable; whether qdev's _other_ commands also need qualified `subagent_type` (out of D1 scope — flag separately).

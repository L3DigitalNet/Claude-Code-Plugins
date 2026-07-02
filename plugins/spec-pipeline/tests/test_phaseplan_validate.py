from specpipe import phaseplan
from specpipe.findings import ERROR

VALID = """\
# Phase Plan — demo

Master spec: `docs/specs/master.md`

## Phase 1 — Foundation

- **status:** complete
- **objective:** Establish toolchain and test harness
- **scope-in:** skeleton, pytest config
- **scope-out:** business logic
- **depends_on:** []
- **spec-slice:** Architecture
- **acceptance:**
  - pytest runs and passes
- **size:** small

## Phase 2 — Core logic

- **status:** pending
- **objective:** Implement the parser
- **scope-in:** parser module
- **scope-out:** CLI
- **depends_on:** [1]
- **spec-slice:** Behavior & rules
- **acceptance:**
  - parser handles empty input
- **size:** medium
"""


def _errors(text, tmp_path):
    f = tmp_path / "phase-plan.md"
    f.write_text(text, encoding="utf-8")
    return [x for x in phaseplan.validate(f) if x.severity == ERROR]


def test_valid_plan_no_errors(tmp_path):
    assert _errors(VALID, tmp_path) == []


def test_parse_fields_and_acceptance():
    phases = phaseplan.parse(VALID)
    assert [p.id for p in phases] == [1, 2]
    assert phases[0].status == "complete"
    assert phases[1].depends_on == [1]
    assert phases[0].acceptance_count == 1
    assert phases[1].title == "Core logic"


def test_duplicate_id(tmp_path):
    bad = VALID.replace("## Phase 2 — Core logic", "## Phase 1 — Core logic")
    assert any(f.code == "PP-DUP-ID" for f in _errors(bad, tmp_path))


def test_forward_dep(tmp_path):
    bad = VALID.replace("- **depends_on:** []", "- **depends_on:** [2]")
    assert any(f.code == "PP-FORWARD-DEP" for f in _errors(bad, tmp_path))


def test_unknown_dep(tmp_path):
    bad = VALID.replace("- **depends_on:** [1]", "- **depends_on:** [9]")
    assert any(f.code == "PP-UNKNOWN-DEP" for f in _errors(bad, tmp_path))


def test_malformed_depends(tmp_path):
    bad = VALID.replace("- **depends_on:** [1]", "- **depends_on:** phase one")
    assert any(f.code == "PP-BAD-DEPENDS" for f in _errors(bad, tmp_path))


def test_bad_status(tmp_path):
    bad = VALID.replace("- **status:** pending", "- **status:** started")
    assert any(f.code == "PP-BAD-STATUS" for f in _errors(bad, tmp_path))


def test_missing_field(tmp_path):
    bad = VALID.replace("- **size:** medium\n", "")
    assert any(f.code == "PP-MISSING-FIELD" for f in _errors(bad, tmp_path))


def test_no_acceptance_items(tmp_path):
    bad = VALID.replace("  - parser handles empty input\n", "")
    assert any(f.code == "PP-NO-ACCEPTANCE" for f in _errors(bad, tmp_path))


def test_two_in_progress(tmp_path):
    bad = VALID.replace("- **status:** complete", "- **status:** in_progress")
    bad = bad.replace("- **status:** pending", "- **status:** in_progress")
    assert any(f.code == "PP-MULTI-ACTIVE" for f in _errors(bad, tmp_path))


def test_empty_file(tmp_path):
    assert any(f.code == "PP-EMPTY" for f in _errors("# nothing here\n", tmp_path))

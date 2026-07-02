from specpipe import plandoc
from specpipe.findings import ERROR, WARNING

VALID_PLAN = """\
# Demo Implementation Plan

**Goal:** Build the demo parser.

**Architecture:** Single module with a pure function.

**Tech Stack:** Python 3.11, pytest

**Spec:** `docs/specs/demo.md` (master governs on conflict)

## Global Constraints

- Python >= 3.11, stdlib only

## File Structure

| Symbol | Kind | Introduced |
| --- | --- | --- |
| `parse_record` | function | Task 1 |

### Task 1: Parser

**Files:**

- Create: `src/parser.py`
- Test: `tests/test_parser.py`

**Interfaces:**

- Consumes: nothing
- Produces: `parse_record(line: str) -> dict`

- [ ] **Step 1: Write the failing test**

```python
def test_parse_record():
    assert parse_record("a=1") == {"a": "1"}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_parser.py -v`
Expected: FAIL with "parse_record not defined"

- [ ] **Step 3: Implement parse_record**

```python
def parse_record(line):
    key, value = line.split("=")
    return {key: value}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/test_parser.py -v`

- [ ] **Step 5: Commit**

```bash
git add src/parser.py tests/test_parser.py
git commit -m "feat: add parse_record"
```
"""


def _findings(tmp_path, text):
    p = tmp_path / "plan.md"
    p.write_text(text, encoding="utf-8")
    return plandoc.validate_plan(p)


def _errors(tmp_path, text):
    return [f for f in _findings(tmp_path, text) if f.severity == ERROR]


def test_valid_plan_no_errors(tmp_path):
    assert _errors(tmp_path, VALID_PLAN) == []


def test_classify_step_titles():
    assert plandoc.classify("Write the failing test") == "test-write"
    assert plandoc.classify("Run test to verify it fails") == "run-fail"
    assert plandoc.classify("Implement parse_record") == "implement"
    assert plandoc.classify("Run test to verify it passes") == "run-pass"
    assert plandoc.classify("Commit") == "commit"
    assert plandoc.classify("Deploy the artifact") == "other"


def test_missing_run_fail_step_is_tdd_error(tmp_path):
    bad = VALID_PLAN.replace(
        "- [ ] **Step 2: Run test to verify it fails**", "Intervening prose.")
    assert any(f.code == "PLAN-TDD-ORDER" for f in _errors(tmp_path, bad))


def test_commit_before_green_is_tdd_error(tmp_path):
    # the only commit lands before the RED→GREEN chain completes
    bad = VALID_PLAN.replace("- [ ] **Step 5: Commit**", "- [ ] **Step 5: Wrap up**")
    bad = bad.replace(
        "- [ ] **Step 2: Run test to verify it fails**",
        "- [ ] **Step 2: Commit**\n\n- [ ] **Step 2: Run test to verify it fails**")
    assert any(f.code == "PLAN-TDD-ORDER" for f in _errors(tmp_path, bad))


def test_no_tdd_marker_downgrades_to_warning(tmp_path):
    bad = VALID_PLAN.replace(
        "- [ ] **Step 2: Run test to verify it fails**",
        "<!-- specpipe: no-tdd — docs-only task -->")
    findings = _findings(tmp_path, bad)
    assert not any(f.code == "PLAN-TDD-ORDER" and f.severity == ERROR for f in findings)
    assert any(f.code == "PLAN-NO-TDD" and f.severity == WARNING for f in findings)


def test_anti_pattern_is_error(tmp_path):
    bad = VALID_PLAN + "\nThe wiring is similar to Task 1.\n"
    assert any(f.code == "PLAN-ANTI-PATTERN" for f in _errors(tmp_path, bad))


def test_missing_header_field(tmp_path):
    bad = VALID_PLAN.replace("**Tech Stack:** Python 3.11, pytest\n", "")
    assert any(f.code == "PLAN-MISSING-HEADER" for f in _errors(tmp_path, bad))


def test_missing_global_constraints(tmp_path):
    bad = VALID_PLAN.replace("## Global Constraints", "## Rules of Thumb")
    assert any(f.code == "PLAN-NO-CONSTRAINTS" for f in _errors(tmp_path, bad))


def test_missing_files_block(tmp_path):
    bad = VALID_PLAN.replace("**Files:**", "**Touched:**")
    assert any(f.code == "PLAN-NO-FILES" for f in _errors(tmp_path, bad))


def test_forward_reference_warns(tmp_path):
    two_tasks = VALID_PLAN.replace("| `parse_record` | function | Task 1 |",
                                   "| `parse_record` | function | Task 2 |")
    warns = [f.code for f in _findings(tmp_path, two_tasks) if f.severity == WARNING]
    assert "PLAN-FORWARD-REF" in warns


def test_placeholder_is_error(tmp_path):
    bad = VALID_PLAN + "\nRemaining work: TBD\n"
    assert any(f.code == "PLAN-PLACEHOLDER" for f in _errors(tmp_path, bad))


def test_classify_implement_step_naming_a_test_symbol():
    # "test" inside a symbol name must not shadow the implement classification
    assert plandoc.classify("Implement run_tests helper") == "implement"


def test_implement_step_with_test_symbol_not_tdd_error(tmp_path):
    ok = VALID_PLAN.replace("- [ ] **Step 3: Implement parse_record**",
                            "- [ ] **Step 3: Implement run_tests_helper**")
    assert not any(f.code == "PLAN-TDD-ORDER" for f in _errors(tmp_path, ok))


def test_anti_pattern_requires_word_boundary(tmp_path):
    ok = VALID_PLAN + "\nThis wiring is dissimilar to task boundaries elsewhere.\n"
    assert not any(f.code == "PLAN-ANTI-PATTERN" for f in _errors(tmp_path, ok))


def test_empty_symbol_table_warns(tmp_path):
    bad = VALID_PLAN.replace("| `parse_record` | function | Task 1 |\n", "")
    warns = [f.code for f in _findings(tmp_path, bad) if f.severity == WARNING]
    assert "PLAN-EMPTY-SYMBOLS" in warns


def test_forward_ref_requires_word_boundary(tmp_path):
    # `cord` (Task 2) appears only inside `parse_record` in Task 1 — no warning
    two = VALID_PLAN.replace(
        "| `parse_record` | function | Task 1 |",
        "| `parse_record` | function | Task 1 |\n| `cord` | function | Task 2 |")
    warns = [f.code for f in _findings(tmp_path, two) if f.severity == WARNING]
    assert "PLAN-FORWARD-REF" not in warns

from specpipe import specdoc
from specpipe.findings import ERROR, WARNING

CORE = ["Overview", "Architecture", "Data model", "Interfaces",
        "Behavior & rules", "Error handling", "Testing strategy",
        "Acceptance criteria", "Rejected alternatives", "Out of scope"]


def _master_text(register="- **D1** — Parser is streaming — rationale.",
                 build="Per-phase task-count ceiling: 10 tasks."):
    body = "\n".join(f"## {name}\n\nSection content.\n" for name in CORE)
    return (f"# Demo — Master Spec\n\n{body}\n"
            f"## Build plan\n\n{build}\n\n"
            f"## Cross-cutting decision register\n\n{register}\n")


def _phase_text(cites="Implements D1 per the master."):
    body = "\n".join(f"## {name}\n\nSection content.\n" for name in CORE)
    extra = "\n".join(f"## {name}\n\nSection content.\n" for name in
                      ["Status & revision provenance", "Provenance & governance",
                       "Inherited contracts", "Scope & decomposition decision",
                       "Sizing flag"])
    return (f"# Demo Phase 2 — Phase Spec\n\n{body}\n{extra}\n"
            f"## Notes\n\n{cites}\nEnvelope shape (inherited from master D1).\n")


def _validate(tmp_path, text, kind, master_text=None):
    p = tmp_path / "spec.md"
    p.write_text(text, encoding="utf-8")
    master = None
    if master_text is not None:
        master = tmp_path / "master.md"
        master.write_text(master_text, encoding="utf-8")
    return specdoc.validate_spec(p, kind, master)


def _errors(findings):
    return [f for f in findings if f.severity == ERROR]


def test_valid_master_no_errors(tmp_path):
    assert _errors(_validate(tmp_path, _master_text(), "master")) == []


def test_master_missing_section(tmp_path):
    text = _master_text().replace("## Error handling\n\nSection content.\n", "")
    codes = [f.code for f in _errors(_validate(tmp_path, text, "master"))]
    assert "SPEC-MISSING-SECTION" in codes


def test_master_placeholder_is_error(tmp_path):
    text = _master_text().replace("Section content.", "Section content. TBD", 1)
    codes = [f.code for f in _errors(_validate(tmp_path, text, "master"))]
    assert "SPEC-PLACEHOLDER" in codes


def test_master_empty_register(tmp_path):
    text = _master_text(register="(decisions to be assigned)")
    codes = [f.code for f in _errors(_validate(tmp_path, text, "master"))]
    assert "SPEC-EMPTY-REGISTER" in codes


def test_master_missing_ceiling(tmp_path):
    text = _master_text(build="Phases ordered by dependency.")
    codes = [f.code for f in _errors(_validate(tmp_path, text, "master"))]
    assert "SPEC-NO-CEILING" in codes


def test_red_flag_phrases_warn(tmp_path):
    text = _master_text().replace("Section content.", "It should probably work.", 1)
    warns = [f.code for f in _validate(tmp_path, text, "master")
             if f.severity == WARNING]
    assert "SPEC-RED-FLAG" in warns


def test_valid_phase_no_errors(tmp_path):
    assert _errors(_validate(tmp_path, _phase_text(), "phase", _master_text())) == []


def test_phase_dangling_decision(tmp_path):
    findings = _validate(tmp_path, _phase_text(cites="Implements D1 and D9."),
                         "phase", _master_text())
    dangling = [f for f in _errors(findings) if f.code == "SPEC-DANGLING-DECISION"]
    assert len(dangling) == 1 and "D9" in dangling[0].message


def test_phase_requires_master(tmp_path):
    codes = [f.code for f in _errors(_validate(tmp_path, _phase_text(), "phase"))]
    assert "SPEC-NO-MASTER" in codes


def test_phase_no_inherited_flags_warns(tmp_path):
    text = _phase_text().replace("(inherited from master D1)", "from master D1")
    warns = [f.code for f in _validate(tmp_path, text, "phase", _master_text())
             if f.severity == WARNING]
    assert "SPEC-NO-INHERITED-FLAGS" in warns

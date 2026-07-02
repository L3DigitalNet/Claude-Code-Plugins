from specpipe import phaseplan
from specpipe.__main__ import main
from test_phaseplan_validate import VALID


def _write(tmp_path, text=VALID):
    f = tmp_path / "phase-plan.md"
    f.write_text(text, encoding="utf-8")
    return f


def test_next_phase_resolves_deps_complete(tmp_path):
    f = _write(tmp_path)
    p = phaseplan.next_phase(f)
    assert p is not None and p.id == 2


def test_next_phase_resume_first(tmp_path):
    # a stale in_progress phase from an interrupted session wins over pending
    text = VALID.replace("- **status:** complete", "- **status:** in_progress")
    p = phaseplan.next_phase(_write(tmp_path, text))
    assert p is not None and p.id == 1 and p.status == "in_progress"


def test_next_phase_blocked_by_incomplete_dep(tmp_path):
    f = _write(tmp_path, VALID.replace("- **status:** complete", "- **status:** pending"))
    p = phaseplan.next_phase(f)
    assert p is not None and p.id == 1  # phase 1 has no deps; it resolves first


def test_next_phase_none_when_all_complete(tmp_path):
    f = _write(tmp_path, VALID.replace("- **status:** pending", "- **status:** complete"))
    assert phaseplan.next_phase(f) is None


def test_set_status_legal(tmp_path):
    f = _write(tmp_path)
    assert phaseplan.set_status(f, 2, "in_progress") is None
    assert phaseplan.parse(f.read_text(encoding="utf-8"))[1].status == "in_progress"


def test_set_status_illegal_leaves_file_untouched(tmp_path):
    f = _write(tmp_path)
    before = f.read_text(encoding="utf-8")
    err = phaseplan.set_status(f, 2, "complete")  # pending -> complete is illegal
    assert err is not None and "illegal transition" in err
    assert f.read_text(encoding="utf-8") == before


def test_set_status_unknown_phase(tmp_path):
    f = _write(tmp_path)
    assert "not found" in phaseplan.set_status(f, 9, "in_progress")


def test_set_status_abandon_recovery(tmp_path):
    f = _write(tmp_path)
    assert phaseplan.set_status(f, 2, "in_progress") is None
    assert phaseplan.set_status(f, 2, "pending") is None  # abandon a wedged run
    assert phaseplan.parse(f.read_text(encoding="utf-8"))[1].status == "pending"


def test_cli_next_phase_reports_resume(tmp_path, capsys):
    text = VALID.replace("- **status:** pending", "- **status:** in_progress")
    f = _write(tmp_path, text)
    assert main(["next-phase", str(f)]) == 0
    assert "RESUME" in capsys.readouterr().out


def test_status_finds_state_by_upward_search(tmp_path, capsys):
    proj = tmp_path / "proj"
    (proj / "docs" / "handoff").mkdir(parents=True)
    f = proj / "docs" / "handoff" / "phase-plan.md"
    f.write_text(VALID, encoding="utf-8")
    (proj / ".spec-pipeline").mkdir()
    (proj / ".spec-pipeline" / "state.json").write_text(
        '{"rounds": {"spec": 2, "plan": 0, "final": 0}}', encoding="utf-8")
    assert main(["status", str(f)]) == 0
    assert "spec=2/3" in capsys.readouterr().out


def test_cli_next_phase_exit_codes(tmp_path, capsys):
    f = _write(tmp_path)
    assert main(["next-phase", str(f)]) == 0
    assert "2" in capsys.readouterr().out
    done = _write(tmp_path, VALID.replace("- **status:** pending", "- **status:** complete"))
    assert main(["next-phase", str(done)]) == 1


def test_cli_status_renders_table(tmp_path, capsys):
    f = _write(tmp_path)
    assert main(["status", str(f)]) == 0
    out = capsys.readouterr().out
    assert "Foundation" in out and "Core logic" in out and "next:" in out

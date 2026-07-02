from pathlib import Path

from specpipe import phaseplan, plandoc, specdoc
from specpipe.findings import ERROR

TPL = Path(__file__).resolve().parents[1] / "templates"


def _errors(findings):
    return [f for f in findings if f.severity == ERROR]


def test_master_template_conforms():
    assert _errors(specdoc.validate_spec(TPL / "master-spec.md", "master")) == []


def test_phase_template_conforms_against_master_template():
    findings = specdoc.validate_spec(TPL / "phase-spec.md", "phase",
                                     TPL / "master-spec.md")
    assert _errors(findings) == []


def test_plan_template_conforms():
    assert _errors(plandoc.validate_plan(TPL / "implementation-plan.md")) == []


def test_phase_plan_template_conforms():
    assert _errors(phaseplan.validate(TPL / "phase-plan.md")) == []

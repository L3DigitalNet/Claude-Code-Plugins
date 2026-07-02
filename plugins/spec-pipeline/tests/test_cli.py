import pytest

from specpipe.__main__ import build_parser


@pytest.mark.parametrize(
    ("argv", "handler"),
    [
        (["validate", "phase-plan", "x.md"], "specpipe.phaseplan:cmd_validate"),
        (["validate", "spec", "x.md", "--kind", "master"], "specpipe.specdoc:cmd_validate_spec"),
        (["validate", "plan", "x.md"], "specpipe.plandoc:cmd_validate_plan"),
        (["next-phase", "x.md"], "specpipe.phaseplan:cmd_next_phase"),
        (["set-status", "x.md", "--id", "2", "--to", "complete"], "specpipe.phaseplan:cmd_set_status"),
        (["status", "x.md"], "specpipe.phaseplan:cmd_status"),
        (["record-red", "--cmd", "true", "--task", "T1", "--audit", "a.md"], "specpipe.evidence:cmd_record_red"),
        (["record-green", "--cmd", "true", "--task", "T1", "--audit", "a.md"], "specpipe.evidence:cmd_record_green"),
        (["rounds", "s.json", "--gate", "spec", "--increment"], "specpipe.rounds:cmd_rounds"),
        (["init-project", "--dir", "."], "specpipe.scaffold:cmd_init_project"),
    ],
)
def test_dispatch_table(argv, handler):
    args = build_parser().parse_args(argv)
    assert args.handler == handler


def test_bad_invocation_exits_2():
    with pytest.raises(SystemExit) as exc:
        build_parser().parse_args(["validate", "spec", "x.md"])  # missing --kind
    assert exc.value.code == 2

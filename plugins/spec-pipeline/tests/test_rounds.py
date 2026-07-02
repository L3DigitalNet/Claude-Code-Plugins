import json
from types import SimpleNamespace

from specpipe.rounds import cmd_rounds


def _args(state, gate=None, increment=False, reset=False):
    return SimpleNamespace(state=str(state), gate=gate, increment=increment, reset=reset)


def test_increment_under_cap(tmp_path):
    state = tmp_path / "state.json"
    for _ in range(3):
        assert cmd_rounds(_args(state, gate="spec", increment=True)) == 0
    data = json.loads(state.read_text(encoding="utf-8"))
    assert data["rounds"]["spec"] == 3


def test_increment_past_cap_exits_1(tmp_path):
    state = tmp_path / "state.json"
    for _ in range(3):
        cmd_rounds(_args(state, gate="spec", increment=True))
    assert cmd_rounds(_args(state, gate="spec", increment=True)) == 1


def test_final_gate_cap_is_5(tmp_path):
    state = tmp_path / "state.json"
    for _ in range(5):
        assert cmd_rounds(_args(state, gate="final", increment=True)) == 0
    assert cmd_rounds(_args(state, gate="final", increment=True)) == 1


def test_reset_zeroes_all_gates(tmp_path):
    state = tmp_path / "state.json"
    cmd_rounds(_args(state, gate="spec", increment=True))
    assert cmd_rounds(_args(state, reset=True)) == 0
    data = json.loads(state.read_text(encoding="utf-8"))
    assert data["rounds"] == {"spec": 0, "plan": 0, "final": 0}


def test_check_without_gate_is_bad_invocation(tmp_path):
    assert cmd_rounds(_args(tmp_path / "state.json")) == 2


def test_corrupt_state_recovers(tmp_path):
    state = tmp_path / "state.json"
    state.write_text("{not json", encoding="utf-8")
    assert cmd_rounds(_args(state, gate="plan", increment=True)) == 0

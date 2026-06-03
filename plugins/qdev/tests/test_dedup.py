import json

from dedup import decide, main


def test_matched_two_boundary_is_not_plain_new():
    # The cutoff is matched < 2; exactly 2 (with recent overlap) updates in place.
    assert decide(matched=2, months_old=1, fast_moving=False,
                  different_angle=False, replaces=False)["action"] == "update"


def test_months_old_at_recent_boundary_is_no_longer_recent():
    # RECENT_MONTHS=6 uses a strict <; exactly 6 months old falls past "recent".
    assert decide(matched=3, months_old=6, fast_moving=False,
                  different_angle=False, replaces=False) == {
        "action": "new", "related": True, "supersede": False}


def test_under_two_matches_takes_precedence_over_different_angle():
    # matched<2 is evaluated first, so it wins even when different_angle is set.
    assert decide(matched=1, months_old=1, fast_moving=False,
                  different_angle=True, replaces=False) == {
        "action": "new", "related": False, "supersede": False}


def test_cli_main_emits_decision_json(capsys):
    rc = main(["dedup.py", "--matched", "3", "--months-old", "2"])
    assert rc == 0
    assert json.loads(capsys.readouterr().out) == {
        "action": "update", "related": False, "supersede": False}


def test_cli_main_store_true_flags_parse(capsys):
    rc = main(["dedup.py", "--matched", "3", "--months-old", "9",
               "--fast-moving", "--replaces"])
    assert rc == 0
    assert json.loads(capsys.readouterr().out) == {
        "action": "new", "related": True, "supersede": True}


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

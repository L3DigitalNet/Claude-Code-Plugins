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

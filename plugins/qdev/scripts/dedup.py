# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""Deterministic dedup decision for the qdev research KB.

The agent computes the judgment-based facts about the best-matching existing
report; this module owns the deterministic decision so each branch of the
design's decision table is unit-testable. Precedence is explicit:

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

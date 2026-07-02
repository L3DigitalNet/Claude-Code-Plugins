"""Review-round counters for the Codex convergence loops.

Caps live in grammar.ROUND_CAPS (spec 3 / plan 3 / final 5). The skill
increments BEFORE each round; the increment that exceeds the cap exits 1,
which is the deterministic 'stop looping, record open findings' signal.
State is transient per-phase (.spec-pipeline/state.json, gitignored).
"""
from __future__ import annotations

import json
from pathlib import Path

from .grammar import ROUND_CAPS


def _load(state: Path) -> dict:
    data: dict = {}
    if state.exists():
        try:
            data = json.loads(state.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            data = {}  # corrupt transient state: recover by resetting
    rounds = data.setdefault("rounds", {})
    for gate in ROUND_CAPS:
        rounds.setdefault(gate, 0)
    return data


def _save(state: Path, data: dict) -> None:
    state.parent.mkdir(parents=True, exist_ok=True)
    state.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")


def cmd_rounds(args) -> int:
    state = Path(args.state)
    data = _load(state)
    if args.reset:
        data["rounds"] = {gate: 0 for gate in ROUND_CAPS}
        _save(state, data)
        print("rounds reset")
        return 0
    if not args.gate:
        print("ERROR: --gate is required unless --reset")
        return 2
    cap = ROUND_CAPS[args.gate]
    if args.increment:
        data["rounds"][args.gate] += 1
        _save(state, data)
        used = data["rounds"][args.gate]
        if used > cap:
            print(f"CAP EXCEEDED: {args.gate} round {used} > cap {cap} — stop "
                  "looping and record remaining open findings")
            return 1
        print(f"{args.gate} round {used}/{cap}")
        return 0
    used = data["rounds"][args.gate]
    print(f"{args.gate} rounds used: {used}/{cap}")
    return 0 if used <= cap else 1

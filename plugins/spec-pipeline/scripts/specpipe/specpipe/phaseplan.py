"""Phase-plan parsing, schema/graph validation, next-phase resolution, and
status transitions. The phase-plan file is the status-tracking projection of
the master spec's build plan: statuses live here, definitions in the master.
"""
from __future__ import annotations

import json
import os
import re
import tempfile
from dataclasses import dataclass, field
from pathlib import Path

from . import grammar
from .findings import ERROR, Finding, exit_code, report

PHASE_HEADING_RE = re.compile(r"^## Phase (\d+) [—-] (.+?)\s*$")
FIELD_RE = re.compile(r"^- \*\*([a-z_-]+):\*\*\s*(.*)$")
ACCEPT_ITEM_RE = re.compile(r"^  - \S")
DEPENDS_RE = re.compile(r"^\[\s*(?:\d+\s*(?:,\s*\d+\s*)*)?\]$")


@dataclass
class Phase:
    id: int
    title: str
    line: int  # 1-based line number of the heading
    fields: dict[str, str] = field(default_factory=dict)
    acceptance_count: int = 0

    @property
    def status(self) -> str:
        return self.fields.get("status", "")

    @property
    def depends_on(self) -> list[int]:
        raw = self.fields.get("depends_on", "")
        if not DEPENDS_RE.match(raw):
            raise ValueError(raw)
        return [int(n) for n in re.findall(r"\d+", raw)]


def parse(text: str) -> list[Phase]:
    phases: list[Phase] = []
    current: Phase | None = None
    last_field: str | None = None
    for lineno, line in enumerate(text.split("\n"), 1):
        m = PHASE_HEADING_RE.match(line)
        if m:
            current = Phase(int(m.group(1)), m.group(2), lineno)
            phases.append(current)
            last_field = None
            continue
        if current is None:
            continue
        f = FIELD_RE.match(line)
        if f:
            current.fields[f.group(1)] = f.group(2).strip()
            last_field = f.group(1)
            continue
        if last_field == "acceptance" and ACCEPT_ITEM_RE.match(line):
            current.acceptance_count += 1
    return phases


def validate(path: Path) -> list[Finding]:
    phases = parse(path.read_text(encoding="utf-8"))
    findings: list[Finding] = []
    loc = str(path)
    if not phases:
        findings.append(Finding(ERROR, "PP-EMPTY",
                        "no '## Phase <id> — <title>' entries found", loc))
        return findings
    all_ids = {p.id for p in phases}
    seen: set[int] = set()
    for p in phases:
        at = f"{loc}:{p.line}"
        if p.id in seen:
            findings.append(Finding(ERROR, "PP-DUP-ID",
                            f"phase id {p.id} defined twice — ids are stable, never reuse", at))
        seen.add(p.id)
        for name in grammar.PHASE_FIELDS:
            if name == "acceptance":
                if p.acceptance_count == 0:
                    findings.append(Finding(ERROR, "PP-NO-ACCEPTANCE",
                                    f"phase {p.id} has no acceptance criteria items", at))
            elif not p.fields.get(name):
                findings.append(Finding(ERROR, "PP-MISSING-FIELD",
                                f"phase {p.id} missing '- **{name}:**'", at))
        if p.fields.get("status") and p.status not in grammar.PHASE_STATUSES:
            findings.append(Finding(ERROR, "PP-BAD-STATUS",
                            f"phase {p.id} status '{p.status}' not in {grammar.PHASE_STATUSES}", at))
        if p.fields.get("depends_on"):
            try:
                deps = p.depends_on
            except ValueError:
                findings.append(Finding(ERROR, "PP-BAD-DEPENDS",
                                f"phase {p.id} depends_on must look like [] or [1, 2]", at))
                continue
            for d in deps:
                if d not in all_ids:
                    findings.append(Finding(ERROR, "PP-UNKNOWN-DEP",
                                    f"phase {p.id} depends on undefined phase {d}", at))
                elif d >= p.id:
                    findings.append(Finding(ERROR, "PP-FORWARD-DEP",
                                    f"phase {p.id} depends on {d}: dependencies must be "
                                    "earlier ids only", at))
    active = [p.id for p in phases if p.status == "in_progress"]
    if len(active) > 1:
        findings.append(Finding(ERROR, "PP-MULTI-ACTIVE",
                        f"more than one phase in_progress: {active}", loc))
    findings.extend(_cycle_check(phases, loc))
    return findings


def _cycle_check(phases: list[Phase], loc: str) -> list[Finding]:
    # Earlier-only deps already imply acyclicity; this guards the report when
    # PP-FORWARD-DEP is present and the graph might genuinely cycle.
    graph: dict[int, list[int]] = {}
    all_ids = {p.id for p in phases}
    for p in phases:
        try:
            graph[p.id] = [d for d in p.depends_on if d in all_ids]
        except ValueError:
            graph[p.id] = []
    state: dict[int, int] = {}  # 0 = visiting, 1 = done

    def visit(n: int) -> bool:
        if state.get(n) == 0:
            return True
        if state.get(n) == 1:
            return False
        state[n] = 0
        cyclic = any(visit(d) for d in graph[n])
        state[n] = 1
        return cyclic

    if any(visit(p.id) for p in phases):
        return [Finding(ERROR, "PP-CYCLE", "dependency graph contains a cycle", loc)]
    return []


def cmd_validate(args) -> int:
    findings = validate(Path(args.path))
    print(report(findings, args.json))
    return exit_code(findings)


def next_phase(path: Path) -> Phase | None:
    """Resume-first resolution.

    An existing in_progress phase (a prior session was interrupted mid-phase)
    is returned before any pending one — the caller resumes or abandons it via
    set-status in_progress->pending. Otherwise: first pending phase (by id)
    whose dependencies are all complete.
    """
    phases = sorted(parse(path.read_text(encoding="utf-8")), key=lambda p: p.id)
    by_id = {p.id: p for p in phases}
    for p in phases:
        if p.status == "in_progress":
            return p
    for p in phases:
        if p.status != "pending":
            continue
        try:
            deps = p.depends_on
        except ValueError:
            continue  # malformed entries are the validator's finding, not ours
        if all(d in by_id and by_id[d].status == "complete" for d in deps):
            return p
    return None


def set_status(path: Path, phase_id: int, to: str) -> str | None:
    """Apply a legal status transition. Returns an error message, or None.

    Atomic: writes a sibling temp file and os.replace()s it, so a crash can
    never leave a half-written phase plan.
    """
    text = path.read_text(encoding="utf-8")
    target = next((p for p in parse(text) if p.id == phase_id), None)
    if target is None:
        return f"phase {phase_id} not found"
    if to not in grammar.PHASE_STATUSES:
        return f"'{to}' is not a valid status {grammar.PHASE_STATUSES}"
    if (target.status, to) not in grammar.LEGAL_TRANSITIONS:
        return f"illegal transition {target.status} -> {to} for phase {phase_id}"
    lines = text.split("\n")
    for i in range(target.line, len(lines)):  # 0-based i starts just past the heading
        if PHASE_HEADING_RE.match(lines[i]):
            return f"phase {phase_id} has no status line"
        m = FIELD_RE.match(lines[i])
        if m and m.group(1) == "status":
            lines[i] = f"- **status:** {to}"
            break
    else:
        return f"phase {phase_id} has no status line"
    fd, tmp = tempfile.mkstemp(dir=str(path.parent), suffix=".tmp")
    with os.fdopen(fd, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines))
    os.chmod(tmp, path.stat().st_mode & 0o777)  # mkstemp is 0600; preserve the original mode
    os.replace(tmp, path)
    return None


def _safe_deps(p: Phase) -> list[int]:
    try:
        return p.depends_on
    except ValueError:
        return []


def _find_state(start: Path) -> Path | None:
    """Upward search from `start` for .spec-pipeline/state.json — deterministic
    regardless of invocation cwd or the project's handoff layout."""
    for d in [start, *start.parents]:
        candidate = d / ".spec-pipeline" / "state.json"
        if candidate.exists():
            return candidate
    return None


def _load_rounds(plan_path: Path, explicit: str | None) -> dict:
    state = Path(explicit) if explicit else _find_state(plan_path.resolve().parent)
    if state is None or not state.exists():
        return {}
    try:
        return json.loads(state.read_text(encoding="utf-8")).get("rounds", {})
    except json.JSONDecodeError:
        return {}


def cmd_next_phase(args) -> int:
    p = next_phase(Path(args.path))
    if p is None:
        print('{"next": null}' if args.json
              else "no resolvable pending phase (all complete, or blocked)")
        return 1
    resume = p.status == "in_progress"
    if args.json:
        print(json.dumps({"next": {"id": p.id, "title": p.title, "resume": resume,
                                   "depends_on": _safe_deps(p)}}))
    else:
        label = "RESUME in_progress phase" if resume else "next phase"
        print(f"{label}: {p.id} — {p.title}")
    return 0


def cmd_set_status(args) -> int:
    err = set_status(Path(args.path), args.id, args.to)
    if err:
        print(f"ERROR: {err}")
        return 1
    print(f"phase {args.id} -> {args.to}")
    return 0


def cmd_status(args) -> int:
    path = Path(args.path)
    phases = sorted(parse(path.read_text(encoding="utf-8")), key=lambda p: p.id)
    nxt = next_phase(path)
    rounds = _load_rounds(path, args.state)
    if args.json:
        print(json.dumps({
            "phases": [{"id": p.id, "title": p.title, "status": p.status,
                        "depends_on": _safe_deps(p)} for p in phases],
            "next": nxt.id if nxt else None,
            "rounds": rounds,
        }, indent=2))
        return 0
    print(f"{'id':>3}  {'status':<12} {'depends_on':<12} title")
    for p in phases:
        print(f"{p.id:>3}  {p.status:<12} {str(_safe_deps(p)):<12} {p.title}")
    print(f"next: {f'{nxt.id} — {nxt.title}' if nxt else '(none resolvable)'}")
    if rounds:
        print("rounds:", ", ".join(
            f"{k}={v}/{grammar.ROUND_CAPS[k]}" for k, v in rounds.items()
            if k in grammar.ROUND_CAPS))
    return 0

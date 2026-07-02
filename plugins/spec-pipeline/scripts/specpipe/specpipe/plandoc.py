"""Implementation-plan validator (validate plan).

Enforces the plan-construction standard's mechanizable surface: header
fields, file-structure symbol table, per-task Files/Interfaces blocks, TDD
step ordering (write-test → run-fail → implement → run-pass, plus a commit),
anti-pattern phrases, placeholders, and heuristic forward-reference checks.
"""
from __future__ import annotations

import re
from pathlib import Path

from . import grammar
from .findings import ERROR, WARNING, Finding, exit_code, report

TASK_RE = re.compile(r"^### Task (\d+): (.+?)\s*$")
STEP_RE = re.compile(r"^- \[[ x]\] \*\*Step \d+: (.+?)\*\*")
HEADER_FIELDS = ["Goal", "Architecture", "Tech Stack", "Spec"]
SYMBOL_ROW_RE = re.compile(r"^\|\s*`([^`]+)`\s*\|[^|]*\|\s*Task (\d+)\s*\|")
NO_TDD_MARKER = "<!-- specpipe: no-tdd"


def classify(step_title: str) -> str:
    t = step_title.lower()
    if ("run" in t or "verify" in t) and "fail" in t:
        return "run-fail"
    if ("run" in t or "verify" in t) and "pass" in t:
        return "run-pass"
    # "implement" before "test": an implement step naming a test-ish symbol
    # ("Implement run_tests helper") must not be classified as test-write.
    if "implement" in t:
        return "implement"
    if "test" in t:
        return "test-write"
    if "commit" in t:
        return "commit"
    return "other"


def _tdd_ok(kinds: list[str]) -> bool:
    want = ["test-write", "run-fail", "implement", "run-pass"]
    idx = 0
    commit_after_pass = False
    for k in kinds:
        if idx < len(want) and k == want[idx]:
            idx += 1
        elif k == "commit" and idx == len(want):
            # a commit only counts once the full RED→GREEN chain has completed;
            # commit-before-green must not satisfy the gate
            commit_after_pass = True
    return idx == len(want) and commit_after_pass


def validate_plan(path: Path) -> list[Finding]:
    text = path.read_text(encoding="utf-8")
    findings: list[Finding] = []
    loc = str(path)
    plain = grammar.strip_fences(text)

    for name in HEADER_FIELDS:
        if not re.search(rf"^\*\*{re.escape(name)}:\*\*", text, re.M | re.I):
            findings.append(Finding(ERROR, "PLAN-MISSING-HEADER",
                            f"missing '**{name}:**' header field", loc))
    sections = grammar.split_sections(text)
    if grammar.find_section(sections, "Global Constraints") is None:
        findings.append(Finding(ERROR, "PLAN-NO-CONSTRAINTS",
                        "missing '## Global Constraints' section", loc))
    if grammar.find_section(sections, "File Structure") is None:
        findings.append(Finding(ERROR, "PLAN-NO-FILE-STRUCTURE",
                        "missing '## File Structure' section", loc))
    symbols = []
    for _, line in plain:
        m = SYMBOL_ROW_RE.match(line)
        if m:
            symbols.append((m.group(1), int(m.group(2))))
    if grammar.find_section(sections, "File Structure") is not None and not symbols:
        findings.append(Finding(WARNING, "PLAN-EMPTY-SYMBOLS",
                        "File Structure section contains no symbol rows "
                        "(| `symbol` | kind | Task N |)", loc))

    # Task boundaries are fence-aware; bodies keep fenced lines (symbol usage
    # lives inside code blocks), steps are matched outside fences only.
    tasks: list[dict] = []
    current: dict | None = None
    fence = False
    for lineno, line in enumerate(text.split("\n"), 1):
        if line.lstrip().startswith("```"):
            fence = not fence
        m = None if fence else TASK_RE.match(line)
        if m:
            current = {"num": int(m.group(1)), "title": m.group(2),
                       "line": lineno, "body": [], "steps": []}
            tasks.append(current)
            continue
        if current is None:
            continue
        current["body"].append(line)
        if not fence:
            s = STEP_RE.match(line)
            if s:
                current["steps"].append(s.group(1))

    if not tasks:
        findings.append(Finding(ERROR, "PLAN-NO-TASKS",
                        "no '### Task N: <title>' tasks found", loc))
    for t in tasks:
        at = f"{loc}:{t['line']}"
        body = "\n".join(t["body"])
        if "**Files:**" not in body:
            findings.append(Finding(ERROR, "PLAN-NO-FILES",
                            f"Task {t['num']} missing '**Files:**' block", at))
        if "**Interfaces:**" not in body:
            findings.append(Finding(ERROR, "PLAN-NO-INTERFACES",
                            f"Task {t['num']} missing '**Interfaces:**' block", at))
        kinds = [classify(s) for s in t["steps"]]
        if NO_TDD_MARKER in body:
            findings.append(Finding(WARNING, "PLAN-NO-TDD",
                            f"Task {t['num']} opts out of TDD order (marker present) — "
                            "the marker must carry a justification", at))
        elif not _tdd_ok(kinds):
            findings.append(Finding(ERROR, "PLAN-TDD-ORDER",
                            f"Task {t['num']} steps must run write-test → run-fail → "
                            "implement → run-pass, with a commit step AFTER the "
                            "passing run", at))

    for phrase in grammar.PLAN_ANTI_PATTERNS:
        rx = grammar.phrase_re(phrase)
        hits = [lineno for lineno, line in plain if rx.search(line)]
        if hits:
            findings.append(Finding(ERROR, "PLAN-ANTI-PATTERN",
                            f'anti-pattern "{phrase}" ({len(hits)}x, first at line '
                            f"{hits[0]})", f"{loc}:{hits[0]}"))
    for lineno, line in plain:
        if grammar.PLACEHOLDER_RE.search(line):
            findings.append(Finding(ERROR, "PLAN-PLACEHOLDER",
                            f"placeholder text: {line.strip()[:80]}", f"{loc}:{lineno}"))

    # Heuristic: a symbol referenced in a task earlier than the one the
    # file-structure table says introduces it. Warning — prose mentions count.
    for sym, intro in symbols:
        # lookarounds, not `in`: symbol `cord` must not match inside `parse_record`
        sym_rx = re.compile(rf"(?<!\w){re.escape(sym)}(?!\w)")
        for t in tasks:
            if t["num"] < intro and sym_rx.search("\n".join(t["body"])):
                findings.append(Finding(WARNING, "PLAN-FORWARD-REF",
                                f"`{sym}` (introduced in Task {intro}) referenced in "
                                f"Task {t['num']}", f"{loc}:{t['line']}"))
                break
    return findings


def cmd_validate_plan(args) -> int:
    findings = validate_plan(Path(args.path))
    print(report(findings, args.json))
    return exit_code(findings)

"""Spec validators (validate spec): core structure + master/phase deltas.

Structure and links only — semantic quality (scope coverage judgment, design
soundness) stays with the review panels; this gate keeps structural defects
out of the expensive passes.
"""
from __future__ import annotations

import re
from pathlib import Path

from . import grammar
from .findings import ERROR, WARNING, Finding, exit_code, report


def _scan_common(path: Path, text: str) -> list[Finding]:
    findings: list[Finding] = []
    lines = grammar.strip_fences(text)
    for lineno, line in lines:
        if grammar.PLACEHOLDER_RE.search(line):
            findings.append(Finding(ERROR, "SPEC-PLACEHOLDER",
                            f"placeholder text: {line.strip()[:80]}", f"{path}:{lineno}"))
    for phrase in grammar.RED_FLAG_PHRASES:
        hits = [lineno for lineno, line in lines if phrase in line.lower()]
        if hits:
            findings.append(Finding(WARNING, "SPEC-RED-FLAG",
                            f'"{phrase}" appears {len(hits)}x — replace with a concrete '
                            "rule wherever it guards behavior", f"{path}:{hits[0]}"))
    return findings


def master_decision_ids(text: str) -> set[str]:
    sections = grammar.split_sections(text)
    reg = grammar.find_section(sections, "Cross-cutting decision register")
    if reg is None:
        return set()
    plain = "\n".join(line for _, line in grammar.strip_fences(reg[2]))
    return set(grammar.DECISION_ID_RE.findall(plain))


def validate_spec(path: Path, kind: str, master: Path | None = None) -> list[Finding]:
    text = path.read_text(encoding="utf-8")
    sections = grammar.split_sections(text)
    findings = _scan_common(path, text)
    required = list(grammar.CORE_SECTIONS)
    required += grammar.MASTER_SECTIONS if kind == "master" else grammar.PHASE_SECTIONS
    for name in required:
        if grammar.find_section(sections, name) is None:
            findings.append(Finding(ERROR, "SPEC-MISSING-SECTION",
                            f'required section "## {name}" not found '
                            '(write it, or "N/A — <reason>" under that heading)', str(path)))

    if kind == "master":
        reg = grammar.find_section(sections, "Cross-cutting decision register")
        if reg is not None and not grammar.DECISION_ID_RE.search(reg[2]):
            findings.append(Finding(ERROR, "SPEC-EMPTY-REGISTER",
                            "decision register defines no D<n> ids", str(path)))
        build = grammar.find_section(sections, "Build plan")
        if build is not None and not re.search(r"ceiling\D{0,40}\d+", build[2], re.I):
            findings.append(Finding(ERROR, "SPEC-NO-CEILING",
                            "build plan does not state the per-phase task-count ceiling "
                            '(e.g. "Per-phase task-count ceiling: 12 tasks.")', str(path)))
    else:  # phase
        if master is None:
            findings.append(Finding(ERROR, "SPEC-NO-MASTER",
                            "--master <master-spec path> is required for --kind phase",
                            str(path)))
        else:
            known = master_decision_ids(master.read_text(encoding="utf-8"))
            plain_text = "\n".join(line for _, line in grammar.strip_fences(text))
            cited = set(grammar.DECISION_ID_RE.findall(plain_text))
            for missing in sorted(cited - known):
                findings.append(Finding(ERROR, "SPEC-DANGLING-DECISION",
                                f"cites {missing}, which the master's cross-cutting "
                                "decision register does not define", str(path)))
        if "(inherited from" not in text:
            findings.append(Finding(WARNING, "SPEC-NO-INHERITED-FLAGS",
                            'no "(inherited from <source>)" flags found — confirm no '
                            "load-bearing inherited invariant is restated unflagged",
                            str(path)))
    return findings


def cmd_validate_spec(args) -> int:
    findings = validate_spec(Path(args.path), args.kind,
                             Path(args.master) if args.master else None)
    print(report(findings, args.json))
    return exit_code(findings)

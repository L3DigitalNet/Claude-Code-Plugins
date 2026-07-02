"""Canonical grammar for spec-pipeline artifacts.

Single source of truth for section headings, phase-plan fields, status enums,
round caps, and scan patterns. The validators AND the template-conformance
tests import from here — grammar changes move templates and validators
together, never one without the other.
"""
from __future__ import annotations

import re

CORE_SECTIONS = [
    "Overview", "Architecture", "Data model", "Interfaces",
    "Behavior & rules", "Error handling", "Testing strategy",
    "Acceptance criteria", "Rejected alternatives", "Out of scope",
]
MASTER_SECTIONS = ["Build plan", "Cross-cutting decision register"]
PHASE_SECTIONS = [
    "Status & revision provenance", "Provenance & governance",
    "Inherited contracts", "Scope & decomposition decision", "Sizing flag",
]

PHASE_FIELDS = ["status", "objective", "scope-in", "scope-out",
                "depends_on", "spec-slice", "acceptance", "size"]
PHASE_STATUSES = ["pending", "in_progress", "complete", "blocked"]
LEGAL_TRANSITIONS = {
    ("pending", "in_progress"),
    ("in_progress", "complete"),
    ("in_progress", "blocked"),
    ("in_progress", "pending"),  # recovery: abandon a stale/wedged run cleanly
    ("blocked", "in_progress"),
    ("blocked", "pending"),  # shelve a blocked phase back to the pool
    # complete is terminal by design: reopening a finished phase is a deliberate
    # manual edit of the plan file, not a transition set-status will perform.
}
ROUND_CAPS = {"spec": 3, "plan": 3, "final": 5}

PLACEHOLDER_RE = re.compile(r"\b(TBD|TODO)\b|\?\?\?")
RED_FLAG_PHRASES = ["should", "probably", "handle appropriately"]
PLAN_ANTI_PATTERNS = ["similar to task", "write tests for the above", "same as above"]
DECISION_ID_RE = re.compile(r"\bD\d+\b")

_HEADING_RE = re.compile(r"^(#{1,6})\s+(.*?)\s*$")


def phrase_re(phrase: str) -> re.Pattern[str]:
    """Word-boundary, case-insensitive matcher for a scan phrase — "should"
    must not flag "shoulder". Used for RED_FLAG_PHRASES and PLAN_ANTI_PATTERNS."""
    return re.compile(rf"\b{re.escape(phrase)}\b", re.I)


def _norm(title: str) -> str:
    return re.sub(r"\s+", " ", title).strip().lower()


def split_sections(text: str, level: int = 2) -> list[tuple[str, int, str]]:
    """Split markdown into (title, start_line, body) at exactly `level` headings.

    Fenced code blocks are opaque: heading-looking lines inside them neither
    open nor close sections (plans embed code whose comments start with '#').
    Deeper headings stay inside the enclosing section's body.
    """
    sections: list[tuple[str, int, str]] = []
    title: str | None = None
    start = 0
    buf: list[str] = []
    fence = False
    for lineno, line in enumerate(text.split("\n"), 1):
        if line.lstrip().startswith("```"):
            fence = not fence
        m = None if fence else _HEADING_RE.match(line)
        if m and len(m.group(1)) <= level:
            if title is not None:
                sections.append((title, start, "\n".join(buf)))
            if len(m.group(1)) == level:
                title, start, buf = m.group(2), lineno, []
            else:  # shallower heading closes the current section
                title, start, buf = None, 0, []
            continue
        if title is not None:
            buf.append(line)
    if title is not None:
        sections.append((title, start, "\n".join(buf)))
    return sections


def find_section(sections: list[tuple[str, int, str]], name: str):
    """First section whose normalized title starts with `name` (lenient on
    suffixes like 'Data model / domain types'), or None."""
    want = _norm(name)
    for section in sections:
        if _norm(section[0]).startswith(want):
            return section
    return None


def strip_fences(text: str) -> list[tuple[int, str]]:
    """(lineno, line) pairs with fenced code blocks removed — for phrase scans."""
    out: list[tuple[int, str]] = []
    fence = False
    for lineno, line in enumerate(text.split("\n"), 1):
        if line.lstrip().startswith("```"):
            fence = not fence
            continue
        if not fence:
            out.append((lineno, line))
    return out

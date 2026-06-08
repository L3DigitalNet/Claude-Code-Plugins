"""Structural validation of the qdev markdown surface (agents, commands, skill).

Nothing else in the repo validates these files: `validate-marketplace.sh` only
checks marketplace.json/plugin.json, and pytest otherwise covers only the Python
scripts. This tier catches malformed frontmatter, ill-formed tool names, and —
most importantly — bare `subagent_type` references (PLUGIN-001), the bug class
where an unqualified plugin-agent name silently dispatches nothing at runtime.
"""
import re
from pathlib import Path

import pytest

from _frontmatter import extract_frontmatter

PLUGIN_ROOT = Path(__file__).resolve().parent.parent
AGENTS = sorted((PLUGIN_ROOT / "agents").glob("*.md"))
COMMANDS = sorted((PLUGIN_ROOT / "commands").glob("*.md"))
SKILLS = sorted((PLUGIN_ROOT / "skills").glob("**/SKILL.md"))
ALL_DEFS = AGENTS + COMMANDS + SKILLS
DISPATCHERS = COMMANDS + SKILLS  # files whose bodies may name a subagent_type

_MCP_TOOL = re.compile(r"mcp__[\w-]+__[\w-]+")
_SUBAGENT_REF = re.compile(r"subagent_type:\s*`?([\w:-]+)")


def _rel(path: Path) -> str:
    return str(path.relative_to(PLUGIN_ROOT))


def _fm(path: Path) -> dict | None:
    return extract_frontmatter(path.read_text(encoding="utf-8"))


def _tool_entries(fm: dict | None) -> list[str]:
    """Tool names from either `allowed-tools` (commands/skill) or `tools`
    (agents), accepting both the comma-string and YAML-list forms."""
    if not isinstance(fm, dict):
        return []
    raw = fm.get("allowed-tools", fm.get("tools"))
    if isinstance(raw, str):
        return [t.strip() for t in raw.split(",") if t.strip()]
    if isinstance(raw, list):
        return [str(t).strip() for t in raw if str(t).strip()]
    return []


def test_discovery_found_the_expected_surface():
    # Guards against a glob that silently matches nothing (vacuous pass).
    # qdev ships commands + agents but no skill since 2.0.0 (search decoupled
    # to the agent-configs web-search skill), so SKILLS is legitimately empty.
    assert AGENTS and COMMANDS


@pytest.mark.parametrize("path", ALL_DEFS, ids=_rel)
def test_definition_has_frontmatter_with_name_and_description(path):
    fm = _fm(path)
    assert isinstance(fm, dict), f"{_rel(path)}: no parseable frontmatter mapping"
    assert fm.get("name"), f"{_rel(path)}: missing name"
    assert fm.get("description"), f"{_rel(path)}: missing description"


@pytest.mark.parametrize("path", ALL_DEFS, ids=_rel)
def test_declared_tools_are_well_formed(path):
    for entry in _tool_entries(_fm(path)):
        assert entry, f"{_rel(path)}: empty tool entry"
        if entry.startswith("mcp"):
            assert _MCP_TOOL.fullmatch(entry), f"{_rel(path)}: malformed MCP tool {entry!r}"


@pytest.mark.parametrize("path", AGENTS + SKILLS, ids=_rel)
def test_agents_and_skill_declare_at_least_one_tool(path):
    assert _tool_entries(_fm(path)), f"{_rel(path)}: declares no tools"


# A file that describes using the Agent tool (or names a subagent_type) is a
# dispatcher and MUST carry a qualified subagent_type. Keying off this marker —
# not a global ref count — catches the real PLUGIN-001 regression: a command
# that still says "use the Agent tool" but lost/garbled its subagent_type line.
_DISPATCH_MARKER = re.compile(r"`Agent` tool|subagent_type")


@pytest.mark.parametrize("path", DISPATCHERS, ids=_rel)
def test_dispatching_file_has_qualified_subagent_type(path):
    body = path.read_text(encoding="utf-8")
    refs = _SUBAGENT_REF.findall(body)
    if _DISPATCH_MARKER.search(body):
        assert refs, (
            f"{_rel(path)}: describes an Agent dispatch but declares no "
            "subagent_type (PLUGIN-001: it would dispatch nothing at runtime)"
        )
    for ref in refs:
        assert ref.startswith("qdev:"), (
            f"{_rel(path)}: bare subagent_type {ref!r} — must be qualified "
            "(PLUGIN-001: an unqualified plugin-agent name dispatches nothing)"
        )


def test_dispatch_markers_present_so_guard_is_not_vacuous():
    # Pin that the per-file guard actually runs against a real dispatcher. Since
    # 2.0.0 the only qdev dispatcher is commands/research.md (-> qdev-researcher);
    # the deprecated subagent commands and the grounding skill were removed.
    marked = [p for p in DISPATCHERS if _DISPATCH_MARKER.search(p.read_text(encoding="utf-8"))]
    assert len(marked) >= 1

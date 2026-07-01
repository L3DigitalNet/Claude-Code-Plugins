# spec-pipeline Plugin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Merge the `author-master-spec` and `autonomous-phase-execution` skills into a new `spec-pipeline` plugin with a deterministic `specpipe` validator CLI, templates, and utility commands.

**Architecture:** A standard marketplace plugin (`plugins/spec-pipeline/`) whose two skills gate their expensive reviews behind a stdlib-only Python CLI. The CLI (`specpipe`) is a plain package directory — no pyproject/venv/lockfile — imported via `PYTHONPATH` and run with `uv run --no-project`, so no invocation ever writes into the plugin tree. It shares one parser layer (`grammar.py`) with the templates, so authored artifacts always parse. Lazy CLI dispatch means each subcommand only imports its own module.

**Tech Stack:** Python ≥ 3.11 (stdlib only at runtime, no packaging), uv (interpreter supply only, `--no-project`), pytest (dev only, via `--with`), bash test wrapper, JSON/Markdown plugin surfaces.

**Spec:** `docs/superpowers/specs/2026-07-01-spec-pipeline-plugin-design.md` (governs on conflict).

**Review status:** Codex-converged 2026-07-01 — spec 4 rounds (SA-001..006, SA-NEW-001/002 resolved), plan 2 rounds (CR-001..005 resolved, round 2 clean). Audits in `docs/codex-reviews/`.

## Global Constraints

- Repo root for all paths: `/home/chris/projects/Claude-Code-Plugins`. All file paths below are relative to it.
- `specpipe` runtime code uses **Python stdlib only**, with **no Python project machinery** (no `pyproject.toml`, venv, or lockfile) — `uv run` against a project would write `.venv/`+`uv.lock` into the plugin root, which must stay clean (installed-plugin cache is not for persistent state). pytest enters via `--with pytest` at test time only.
- Canonical CLI invocation (used verbatim in skills/commands/README): `PYTHONPATH="${CLAUDE_PLUGIN_ROOT}/scripts/specpipe" uv run --no-project python -B -m specpipe <subcommand> …`
- No specpipe invocation may dirty the plugin tree — including gitignored artifacts: `git status --short --ignored plugins/spec-pipeline` stays empty and no `.venv`/`uv.lock`/cache dirs appear under the plugin after any run (Task 14 verifies).
- Exit codes: `0` clean · `1` findings/failure · `2` bad invocation (argparse default).
- Test command for every task: `bash plugins/spec-pipeline/tests/run_tests.sh` (created in Task 2). Run it from the repo root.
- Never `git add -A` / `git add .` — stage by explicit path. Plain `git commit` (a global hook enforces author email + GPG signing; never override `GIT_*_EMAIL`).
- Markdown/JSON must pass `npm run format:check` and `npx markdownlint-cli2 "plugins/spec-pipeline/**/*.md"` (repo configs at root). Run `npm run format` before checking.
- Source skills being merged (read-only inputs, do NOT modify them): `/home/chris/projects/agent-configs/skills/.claude/skills/author-master-spec/` and `.../autonomous-phase-execution/`.

## File Structure

| Symbol / File | Kind | Introduced |
| --- | --- | --- |
| `plugins/spec-pipeline/.claude-plugin/plugin.json` | manifest | Task 1 |
| `plugins/spec-pipeline/references/*.md` (4 files) | reference docs | Task 1 |
| `specpipe/__init__.py` (plain package dir — no pyproject/venv/lock) | package | Task 2 |
| `specpipe/findings.py` (`Finding`, `exit_code`, `report`) | module | Task 2 |
| `specpipe/__main__.py` (`build_parser`, `main`) | CLI dispatch | Task 2 |
| `plugins/spec-pipeline/tests/run_tests.sh` | test wrapper | Task 2 |
| `specpipe/grammar.py` (`split_sections`, `find_section`, `strip_fences`, constants) | module | Task 3 |
| `specpipe/phaseplan.py` (`parse`, `validate`, `next_phase`, `set_status`, `cmd_*`) | module | Task 4 (cmds: 5) |
| `specpipe/specdoc.py` (`validate_spec`, `master_decision_ids`, `cmd_validate_spec`) | module | Task 6 |
| `specpipe/plandoc.py` (`validate_plan`, `classify`, `cmd_validate_plan`) | module | Task 7 |
| `specpipe/evidence.py` (`record`, `cmd_record_red`, `cmd_record_green`) | module | Task 8 |
| `specpipe/rounds.py` (`cmd_rounds`) | module | Task 9 |
| `plugins/spec-pipeline/templates/*.md` (4 templates) | templates | Task 10 |
| `specpipe/scaffold.py` (`init_project`, `cmd_init_project`, `PLUGIN_ROOT`) | module | Task 11 |
| `plugins/spec-pipeline/skills/author/SKILL.md` | skill | Task 12 |
| `plugins/spec-pipeline/skills/execute-phase/SKILL.md` | skill | Task 12 |
| `plugins/spec-pipeline/commands/{validate,status,init-project}.md` | commands | Task 13 |
| `plugins/spec-pipeline/README.md`, `CHANGELOG.md` | docs | Task 13 |

---

### Task 1: Plugin scaffold, manifest, marketplace entry, deduped references

<!-- specpipe: no-tdd — pure scaffolding/config; verified by the marketplace validator and diff, not unit tests -->

**Files:**

- Create: `plugins/spec-pipeline/.claude-plugin/plugin.json`
- Create: `plugins/spec-pipeline/references/spec-construction.md` (copy)
- Create: `plugins/spec-pipeline/references/spec-construction-master.md` (copy)
- Create: `plugins/spec-pipeline/references/spec-construction-phase.md` (copy)
- Create: `plugins/spec-pipeline/references/plan-construction.md` (copy)
- Modify: `.claude-plugin/marketplace.json` (append plugin entry)

**Interfaces:**

- Consumes: source skill reference files in `agent-configs` (read-only).
- Produces: `plugins/spec-pipeline/` root that every later task writes into; references at `${CLAUDE_PLUGIN_ROOT}/references/` consumed by the skills (Task 12).

- [ ] **Step 1: Create directories and copy references (deduping the identical core)**

```bash
SRC=/home/chris/projects/agent-configs/skills/.claude/skills
mkdir -p plugins/spec-pipeline/.claude-plugin plugins/spec-pipeline/references
# The two spec-construction.md copies are byte-identical (verified during design); copy once.
cp "$SRC/author-master-spec/references/spec-construction.md"        plugins/spec-pipeline/references/
cp "$SRC/author-master-spec/references/spec-construction-master.md" plugins/spec-pipeline/references/
cp "$SRC/autonomous-phase-execution/references/spec-construction-phase.md" plugins/spec-pipeline/references/
cp "$SRC/autonomous-phase-execution/references/plan-construction.md" plugins/spec-pipeline/references/
```

- [ ] **Step 2: Write `plugins/spec-pipeline/.claude-plugin/plugin.json`**

```json
{
	"name": "spec-pipeline",
	"description": "Spec-driven autonomous development pipeline: author a master spec, decompose it into phases, and execute each phase under TDD — with deterministic specpipe validator gates in front of every review pass.",
	"version": "0.1.0",
	"author": { "name": "L3DigitalNet", "url": "https://github.com/L3DigitalNet" }
}
```

- [ ] **Step 3: Append the marketplace entry**

In `.claude-plugin/marketplace.json`, the `plugins` array currently ends with the `uv-strict-python` entry. Insert a comma after its closing `}` and append before the closing `]`:

```json
{
	"name": "spec-pipeline",
	"description": "Spec-driven autonomous development pipeline: author a master spec, decompose into phases, execute each phase under TDD with deterministic specpipe validator gates (structure, dependency graphs, decision-id citations, TDD step order, RED/GREEN evidence, round caps) in front of every review pass.",
	"version": "0.1.0",
	"author": { "name": "L3DigitalNet", "url": "https://github.com/L3DigitalNet" },
	"source": "./plugins/spec-pipeline",
	"homepage": "https://github.com/L3DigitalNet/Claude-Code-Plugins/tree/main/plugins/spec-pipeline"
}
```

- [ ] **Step 4: Verify**

```bash
bash scripts/validate-marketplace.sh
diff plugins/spec-pipeline/references/spec-construction.md \
     /home/chris/projects/agent-configs/skills/.claude/skills/autonomous-phase-execution/references/spec-construction.md
jq -e '.plugins[] | select(.name=="spec-pipeline")' .claude-plugin/marketplace.json
```

Expected: validator passes; `diff` silent (dedupe is lossless); `jq` prints the entry.

- [ ] **Step 5: Commit**

```bash
git add plugins/spec-pipeline/.claude-plugin/plugin.json plugins/spec-pipeline/references .claude-plugin/marketplace.json
git commit -m "feat(spec-pipeline): scaffold plugin, dedupe shared references, register in marketplace"
```

---

### Task 2: specpipe project, findings model, CLI dispatch, test wrapper

**Files:**

- Create: `plugins/spec-pipeline/scripts/specpipe/specpipe/__init__.py`
- Create: `plugins/spec-pipeline/scripts/specpipe/specpipe/findings.py`
- Create: `plugins/spec-pipeline/scripts/specpipe/specpipe/__main__.py`
- Create: `plugins/spec-pipeline/tests/run_tests.sh`
- Test: `plugins/spec-pipeline/tests/test_findings.py`, `plugins/spec-pipeline/tests/test_cli.py`

(Deliberately NO `pyproject.toml`/venv/lockfile — the package is imported via `PYTHONPATH` so no uv project sync ever writes into the plugin tree.)

**Interfaces:**

- Consumes: nothing.
- Produces: `Finding(severity, code, message, location="")` dataclass; constants `ERROR = "error"`, `WARNING = "warning"`; `exit_code(findings: list[Finding]) -> int`; `report(findings, as_json: bool = False) -> str`; `build_parser() -> argparse.ArgumentParser`; `main(argv: list[str] | None = None) -> int`. Every later module registers as a `"module:function"` handler string and exposes `cmd_*(args) -> int`.

- [ ] **Step 1: Write the test wrapper and package init (scaffolding the tests need)**

`plugins/spec-pipeline/tests/run_tests.sh`:

```bash
#!/usr/bin/env bash
# Runs the specpipe pytest suite. specpipe is a plain stdlib package imported
# via PYTHONPATH — deliberately NO pyproject/venv/lock, so uv never writes
# into the plugin tree (--no-project skips lock/sync; pytest comes from an
# ephemeral --with env in uv's cache). Always invoke this wrapper, never bare
# pytest (import path).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
export PYTHONPATH="$PLUGIN_ROOT/scripts/specpipe${PYTHONPATH:+:$PYTHONPATH}"
# Keep the plugin tree free of generated state (AC9): no bytecode, no pytest cache.
export PYTHONDONTWRITEBYTECODE=1
exec uv run --no-project --with pytest pytest -p no:cacheprovider "$SCRIPT_DIR" "$@"
```

```bash
chmod +x plugins/spec-pipeline/tests/run_tests.sh
```

`plugins/spec-pipeline/scripts/specpipe/specpipe/__init__.py`:

```python
"""specpipe — deterministic validators and state ops for spec-pipeline."""
```

- [ ] **Step 2: Write the failing tests**

`plugins/spec-pipeline/tests/test_findings.py`:

```python
from specpipe.findings import ERROR, WARNING, Finding, exit_code, report


def test_exit_code_error_is_1():
    assert exit_code([Finding(ERROR, "X-1", "boom")]) == 1


def test_exit_code_warning_only_is_0():
    assert exit_code([Finding(WARNING, "X-2", "meh")]) == 0


def test_exit_code_empty_is_0():
    assert exit_code([]) == 0


def test_report_human_counts():
    out = report([Finding(ERROR, "X-1", "boom", "f.md:3"), Finding(WARNING, "X-2", "meh")])
    assert "X-1" in out and "f.md:3" in out
    assert "1 error(s), 1 warning(s)" in out


def test_report_empty():
    assert report([]) == "OK — no findings"


def test_report_json_shape():
    import json
    data = json.loads(report([Finding(ERROR, "X-1", "boom")], as_json=True))
    assert data["errors"] == 1 and data["warnings"] == 0
    assert data["findings"][0]["code"] == "X-1"
```

`plugins/spec-pipeline/tests/test_cli.py`:

```python
import pytest

from specpipe.__main__ import build_parser


@pytest.mark.parametrize(
    ("argv", "handler"),
    [
        (["validate", "phase-plan", "x.md"], "specpipe.phaseplan:cmd_validate"),
        (["validate", "spec", "x.md", "--kind", "master"], "specpipe.specdoc:cmd_validate_spec"),
        (["validate", "plan", "x.md"], "specpipe.plandoc:cmd_validate_plan"),
        (["next-phase", "x.md"], "specpipe.phaseplan:cmd_next_phase"),
        (["set-status", "x.md", "--id", "2", "--to", "complete"], "specpipe.phaseplan:cmd_set_status"),
        (["status", "x.md"], "specpipe.phaseplan:cmd_status"),
        (["record-red", "--cmd", "true", "--task", "T1", "--audit", "a.md"], "specpipe.evidence:cmd_record_red"),
        (["record-green", "--cmd", "true", "--task", "T1", "--audit", "a.md"], "specpipe.evidence:cmd_record_green"),
        (["rounds", "s.json", "--gate", "spec", "--increment"], "specpipe.rounds:cmd_rounds"),
        (["init-project", "--dir", "."], "specpipe.scaffold:cmd_init_project"),
    ],
)
def test_dispatch_table(argv, handler):
    args = build_parser().parse_args(argv)
    assert args.handler == handler


def test_bad_invocation_exits_2():
    with pytest.raises(SystemExit) as exc:
        build_parser().parse_args(["validate", "spec", "x.md"])  # missing --kind
    assert exc.value.code == 2
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `bash plugins/spec-pipeline/tests/run_tests.sh` Expected: FAIL — `ModuleNotFoundError: No module named 'specpipe.findings'` (collection errors are the expected RED here since the modules do not exist yet).

- [ ] **Step 4: Implement findings.py**

`plugins/spec-pipeline/scripts/specpipe/specpipe/findings.py`:

```python
"""Finding model + report rendering shared by every specpipe validator.

Cross-file contract: validators return list[Finding]; __main__ handlers render
via report() and convert to the process exit code via exit_code().
"""
from __future__ import annotations

import json
from dataclasses import asdict, dataclass

ERROR = "error"
WARNING = "warning"


@dataclass
class Finding:
    severity: str  # ERROR | WARNING
    code: str      # stable machine id, e.g. PP-DUP-ID
    message: str
    location: str = ""  # "file:line" or "file"


def exit_code(findings: list[Finding]) -> int:
    return 1 if any(f.severity == ERROR for f in findings) else 0


def report(findings: list[Finding], as_json: bool = False) -> str:
    errors = [f for f in findings if f.severity == ERROR]
    warnings = [f for f in findings if f.severity == WARNING]
    if as_json:
        return json.dumps(
            {"errors": len(errors), "warnings": len(warnings),
             "findings": [asdict(f) for f in findings]},
            indent=2,
        )
    if not findings:
        return "OK — no findings"
    lines = [
        f"[{f.severity.upper():7}] {f.code}  {f.message}"
        + (f"  ({f.location})" if f.location else "")
        for f in findings
    ]
    lines.append(f"{len(errors)} error(s), {len(warnings)} warning(s)")
    return "\n".join(lines)
```

- [ ] **Step 5: Implement **main**.py**

`plugins/spec-pipeline/scripts/specpipe/specpipe/__main__.py`:

```python
"""specpipe CLI — deterministic validators + state ops for spec-pipeline.

Dispatch is lazy (handlers are "module:function" strings) so each subcommand
imports only its own module: a defect in one validator cannot break the rest
of the CLI, and modules can land task-by-task during the build.
"""
from __future__ import annotations

import argparse
import sys
from importlib import import_module


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="specpipe")
    sub = p.add_subparsers(dest="command", required=True)

    v = sub.add_parser("validate", help="structural validators")
    vsub = v.add_subparsers(dest="artifact", required=True)

    vpp = vsub.add_parser("phase-plan", help="phase-plan schema + dependency graph")
    vpp.add_argument("path")
    vpp.add_argument("--json", action="store_true")
    vpp.set_defaults(handler="specpipe.phaseplan:cmd_validate")

    vs = vsub.add_parser("spec", help="spec structure (core + master/phase delta)")
    vs.add_argument("path")
    vs.add_argument("--kind", choices=["master", "phase"], required=True)
    vs.add_argument("--master", help="master spec path (required for --kind phase)")
    vs.add_argument("--json", action="store_true")
    vs.set_defaults(handler="specpipe.specdoc:cmd_validate_spec")

    vp = vsub.add_parser("plan", help="implementation-plan structure + TDD order")
    vp.add_argument("path")
    vp.add_argument("--json", action="store_true")
    vp.set_defaults(handler="specpipe.plandoc:cmd_validate_plan")

    np = sub.add_parser("next-phase", help="resolve first pending phase with deps complete")
    np.add_argument("path")
    np.add_argument("--json", action="store_true")
    np.set_defaults(handler="specpipe.phaseplan:cmd_next_phase")

    ss = sub.add_parser("set-status", help="legal status transition, atomic rewrite")
    ss.add_argument("path")
    ss.add_argument("--id", type=int, required=True)
    ss.add_argument("--to", required=True)
    ss.set_defaults(handler="specpipe.phaseplan:cmd_set_status")

    st = sub.add_parser("status", help="render phase table + round counters")
    st.add_argument("path")
    st.add_argument("--state", help="explicit state.json path (default: upward "
                                    "search from the phase-plan for .spec-pipeline/state.json)")
    st.add_argument("--json", action="store_true")
    st.set_defaults(handler="specpipe.phaseplan:cmd_status")

    rr = sub.add_parser("record-red", help="run test cmd, assert genuine failure, append evidence")
    rr.add_argument("--cmd", required=True)
    rr.add_argument("--task", required=True)
    rr.add_argument("--audit", required=True)
    rr.add_argument("--framework", choices=["pytest", "generic"], default="pytest",
                    help="pytest: reject collection/import errors as non-RED; "
                         "generic: bats/Jest/other runners (pair with "
                         "--expect-failure-regex to keep fails-for-the-right-reason)")
    rr.add_argument("--expect-failure-regex",
                    help="REQUIRED with --framework generic: output must match this "
                         "regex for RED to count (the expected failing assertion / "
                         "missing symbol); enforced in the handler")
    rr.add_argument("--timeout", type=float, default=600.0)
    rr.set_defaults(handler="specpipe.evidence:cmd_record_red")

    rg = sub.add_parser("record-green", help="run test cmd, assert pass, append evidence")
    rg.add_argument("--cmd", required=True)
    rg.add_argument("--task", required=True)
    rg.add_argument("--audit", required=True)
    rg.add_argument("--timeout", type=float, default=600.0)
    rg.set_defaults(handler="specpipe.evidence:cmd_record_green")

    ro = sub.add_parser("rounds", help="review-round counters vs caps (3/3/5)")
    ro.add_argument("state")
    ro.add_argument("--gate", choices=["spec", "plan", "final"])
    ro.add_argument("--increment", action="store_true")
    ro.add_argument("--reset", action="store_true")
    ro.set_defaults(handler="specpipe.rounds:cmd_rounds")

    ip = sub.add_parser("init-project", help="scaffold minimal handoff layout (idempotent)")
    ip.add_argument("--dir", default=".")
    ip.add_argument("--handoff-dir", default="docs/handoff",
                    help="state-layout directory relative to --dir (projects not "
                         "on the docs/handoff convention pass their own)")
    ip.set_defaults(handler="specpipe.scaffold:cmd_init_project")
    return p


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    mod_name, fn_name = args.handler.split(":")
    handler = getattr(import_module(mod_name), fn_name)
    return handler(args)


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `bash plugins/spec-pipeline/tests/run_tests.sh` Expected: PASS (18 tests).

- [ ] **Step 7: Commit**

```bash
git add plugins/spec-pipeline/scripts/specpipe plugins/spec-pipeline/tests
git commit -m "feat(spec-pipeline): specpipe project skeleton — findings model, lazy CLI dispatch, test wrapper"
```

---

### Task 3: grammar.py — canonical grammar + fence-aware markdown helpers

**Files:**

- Create: `plugins/spec-pipeline/scripts/specpipe/specpipe/grammar.py`
- Test: `plugins/spec-pipeline/tests/test_grammar.py`

**Interfaces:**

- Consumes: nothing.
- Produces: constants `CORE_SECTIONS`, `MASTER_SECTIONS`, `PHASE_SECTIONS`, `PHASE_FIELDS`, `PHASE_STATUSES`, `LEGAL_TRANSITIONS`, `ROUND_CAPS`, `PLACEHOLDER_RE`, `RED_FLAG_PHRASES`, `PLAN_ANTI_PATTERNS`, `DECISION_ID_RE`; functions `split_sections(text, level=2) -> list[tuple[str, int, str]]` (title, start_line, body), `find_section(sections, name) -> tuple | None` (normalized startswith match), `strip_fences(text) -> list[tuple[int, str]]` (lineno, line pairs outside fenced blocks). Consumed by phaseplan/specdoc/plandoc/rounds and by the template-conformance tests (Task 10).

- [ ] **Step 1: Write the failing tests**

`plugins/spec-pipeline/tests/test_grammar.py`:

````python
from specpipe import grammar

DOC = """\
# Title

intro

## Alpha

alpha body

```bash
## not a heading — inside a fence
```

still alpha

## Beta section

beta body

### Beta child

child body
"""


def test_split_sections_fence_aware():
    sections = grammar.split_sections(DOC)
    titles = [t for t, _, _ in sections]
    assert titles == ["Alpha", "Beta section"]
    alpha = sections[0]
    assert "## not a heading — inside a fence" in alpha[2]
    assert "still alpha" in alpha[2]


def test_split_sections_child_headings_stay_in_body():
    sections = grammar.split_sections(DOC)
    beta = sections[1]
    assert "### Beta child" in beta[2] and "child body" in beta[2]


def test_find_section_startswith_case_insensitive():
    sections = grammar.split_sections(DOC)
    assert grammar.find_section(sections, "beta")[0] == "Beta section"
    assert grammar.find_section(sections, "Gamma") is None


def test_strip_fences_removes_fenced_lines():
    lines = dict(grammar.strip_fences(DOC))
    assert all("not a heading" not in line for line in lines.values())
    assert any("beta body" in line for line in lines.values())


def test_placeholder_re():
    assert grammar.PLACEHOLDER_RE.search("this is TBD")
    assert grammar.PLACEHOLDER_RE.search("weird ??? marker")
    assert not grammar.PLACEHOLDER_RE.search("TODOS are fine as a word")


def test_transitions_and_caps():
    assert ("pending", "in_progress") in grammar.LEGAL_TRANSITIONS
    assert ("in_progress", "pending") in grammar.LEGAL_TRANSITIONS  # recovery
    assert ("pending", "complete") not in grammar.LEGAL_TRANSITIONS
    assert grammar.ROUND_CAPS == {"spec": 3, "plan": 3, "final": 5}
````

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash plugins/spec-pipeline/tests/run_tests.sh` Expected: FAIL — `ModuleNotFoundError: No module named 'specpipe.grammar'` (collection error is the expected RED for a missing module).

- [ ] **Step 3: Implement grammar.py**

`plugins/spec-pipeline/scripts/specpipe/specpipe/grammar.py`:

````python
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
}
ROUND_CAPS = {"spec": 3, "plan": 3, "final": 5}

PLACEHOLDER_RE = re.compile(r"\b(TBD|TODO)\b|\?\?\?")
RED_FLAG_PHRASES = ["should", "probably", "handle appropriately"]
PLAN_ANTI_PATTERNS = ["similar to task", "write tests for the above", "same as above"]
DECISION_ID_RE = re.compile(r"\bD\d+\b")

_HEADING_RE = re.compile(r"^(#{1,6})\s+(.*?)\s*$")


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
````

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash plugins/spec-pipeline/tests/run_tests.sh` Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add plugins/spec-pipeline/scripts/specpipe/specpipe/grammar.py plugins/spec-pipeline/tests/test_grammar.py
git commit -m "feat(spec-pipeline): canonical grammar module with fence-aware markdown helpers"
```

---

### Task 4: phaseplan.py — parser + `validate phase-plan`

**Files:**

- Create: `plugins/spec-pipeline/scripts/specpipe/specpipe/phaseplan.py`
- Test: `plugins/spec-pipeline/tests/test_phaseplan_validate.py`

**Interfaces:**

- Consumes: `grammar` constants; `Finding`/`ERROR`/`exit_code`/`report` from `findings`.
- Produces: `Phase` dataclass (`id: int`, `title: str`, `line: int`, `fields: dict[str, str]`, `acceptance_count: int`; properties `status -> str`, `depends_on -> list[int]` raising `ValueError` on malformed input); `parse(text) -> list[Phase]`; `validate(path) -> list[Finding]`; `cmd_validate(args) -> int`. Task 5 adds `next_phase`, `set_status`, and the remaining `cmd_*` to this module.

- [ ] **Step 1: Write the failing tests**

`plugins/spec-pipeline/tests/test_phaseplan_validate.py`:

```python
from specpipe import phaseplan
from specpipe.findings import ERROR

VALID = """\
# Phase Plan — demo

Master spec: `docs/specs/master.md`

## Phase 1 — Foundation

- **status:** complete
- **objective:** Establish toolchain and test harness
- **scope-in:** skeleton, pytest config
- **scope-out:** business logic
- **depends_on:** []
- **spec-slice:** Architecture
- **acceptance:**
  - pytest runs and passes
- **size:** small

## Phase 2 — Core logic

- **status:** pending
- **objective:** Implement the parser
- **scope-in:** parser module
- **scope-out:** CLI
- **depends_on:** [1]
- **spec-slice:** Behavior & rules
- **acceptance:**
  - parser handles empty input
- **size:** medium
"""


def _errors(text, tmp_path):
    f = tmp_path / "phase-plan.md"
    f.write_text(text, encoding="utf-8")
    return [x for x in phaseplan.validate(f) if x.severity == ERROR]


def test_valid_plan_no_errors(tmp_path):
    assert _errors(VALID, tmp_path) == []


def test_parse_fields_and_acceptance():
    phases = phaseplan.parse(VALID)
    assert [p.id for p in phases] == [1, 2]
    assert phases[0].status == "complete"
    assert phases[1].depends_on == [1]
    assert phases[0].acceptance_count == 1
    assert phases[1].title == "Core logic"


def test_duplicate_id(tmp_path):
    bad = VALID.replace("## Phase 2 — Core logic", "## Phase 1 — Core logic")
    assert any(f.code == "PP-DUP-ID" for f in _errors(bad, tmp_path))


def test_forward_dep(tmp_path):
    bad = VALID.replace("- **depends_on:** []", "- **depends_on:** [2]")
    assert any(f.code == "PP-FORWARD-DEP" for f in _errors(bad, tmp_path))


def test_unknown_dep(tmp_path):
    bad = VALID.replace("- **depends_on:** [1]", "- **depends_on:** [9]")
    assert any(f.code == "PP-UNKNOWN-DEP" for f in _errors(bad, tmp_path))


def test_malformed_depends(tmp_path):
    bad = VALID.replace("- **depends_on:** [1]", "- **depends_on:** phase one")
    assert any(f.code == "PP-BAD-DEPENDS" for f in _errors(bad, tmp_path))


def test_bad_status(tmp_path):
    bad = VALID.replace("- **status:** pending", "- **status:** started")
    assert any(f.code == "PP-BAD-STATUS" for f in _errors(bad, tmp_path))


def test_missing_field(tmp_path):
    bad = VALID.replace("- **size:** medium\n", "")
    assert any(f.code == "PP-MISSING-FIELD" for f in _errors(bad, tmp_path))


def test_no_acceptance_items(tmp_path):
    bad = VALID.replace("  - parser handles empty input\n", "")
    assert any(f.code == "PP-NO-ACCEPTANCE" for f in _errors(bad, tmp_path))


def test_two_in_progress(tmp_path):
    bad = VALID.replace("- **status:** complete", "- **status:** in_progress")
    bad = bad.replace("- **status:** pending", "- **status:** in_progress")
    assert any(f.code == "PP-MULTI-ACTIVE" for f in _errors(bad, tmp_path))


def test_empty_file(tmp_path):
    assert any(f.code == "PP-EMPTY" for f in _errors("# nothing here\n", tmp_path))
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash plugins/spec-pipeline/tests/run_tests.sh` Expected: FAIL — `ModuleNotFoundError: No module named 'specpipe.phaseplan'`.

- [ ] **Step 3: Implement phaseplan.py (parser + validate)**

`plugins/spec-pipeline/scripts/specpipe/specpipe/phaseplan.py`:

```python
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
```

(`json`, `os`, `tempfile` imports are used by Task 5's additions to this module; leaving them in place now avoids churn.)

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash plugins/spec-pipeline/tests/run_tests.sh` Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add plugins/spec-pipeline/scripts/specpipe/specpipe/phaseplan.py plugins/spec-pipeline/tests/test_phaseplan_validate.py
git commit -m "feat(spec-pipeline): phase-plan parser and structural/graph validator"
```

---

### Task 5: phaseplan state ops — `next-phase`, `set-status`, `status`

**Files:**

- Modify: `plugins/spec-pipeline/scripts/specpipe/specpipe/phaseplan.py` (append functions)
- Test: `plugins/spec-pipeline/tests/test_phaseplan_state.py`

**Interfaces:**

- Consumes: `parse`, `Phase`, `PHASE_HEADING_RE`, `FIELD_RE` from Task 4; `grammar.LEGAL_TRANSITIONS`, `grammar.ROUND_CAPS`.
- Produces: `next_phase(path) -> Phase | None` (**resume-first**: an `in_progress` phase is returned before any `pending` one); `set_status(path, phase_id: int, to: str) -> str | None` (error message or None; atomic rewrite; includes the `in_progress→pending` recovery transition); `cmd_next_phase` (reports `resume` when returning an `in_progress` phase), `cmd_set_status`, `cmd_status` (resolves the state file from `--state` or upward search). The skills call these via the CLI.

- [ ] **Step 1: Write the failing tests**

`plugins/spec-pipeline/tests/test_phaseplan_state.py`:

```python
from specpipe import phaseplan
from specpipe.__main__ import main
from test_phaseplan_validate import VALID


def _write(tmp_path, text=VALID):
    f = tmp_path / "phase-plan.md"
    f.write_text(text, encoding="utf-8")
    return f


def test_next_phase_resolves_deps_complete(tmp_path):
    f = _write(tmp_path)
    p = phaseplan.next_phase(f)
    assert p is not None and p.id == 2


def test_next_phase_resume_first(tmp_path):
    # a stale in_progress phase from an interrupted session wins over pending
    text = VALID.replace("- **status:** complete", "- **status:** in_progress")
    p = phaseplan.next_phase(_write(tmp_path, text))
    assert p is not None and p.id == 1 and p.status == "in_progress"


def test_next_phase_blocked_by_incomplete_dep(tmp_path):
    f = _write(tmp_path, VALID.replace("- **status:** complete", "- **status:** pending"))
    p = phaseplan.next_phase(f)
    assert p is not None and p.id == 1  # phase 1 has no deps; it resolves first


def test_next_phase_none_when_all_complete(tmp_path):
    f = _write(tmp_path, VALID.replace("- **status:** pending", "- **status:** complete"))
    assert phaseplan.next_phase(f) is None


def test_set_status_legal(tmp_path):
    f = _write(tmp_path)
    assert phaseplan.set_status(f, 2, "in_progress") is None
    assert phaseplan.parse(f.read_text(encoding="utf-8"))[1].status == "in_progress"


def test_set_status_illegal_leaves_file_untouched(tmp_path):
    f = _write(tmp_path)
    before = f.read_text(encoding="utf-8")
    err = phaseplan.set_status(f, 2, "complete")  # pending -> complete is illegal
    assert err is not None and "illegal transition" in err
    assert f.read_text(encoding="utf-8") == before


def test_set_status_unknown_phase(tmp_path):
    f = _write(tmp_path)
    assert "not found" in phaseplan.set_status(f, 9, "in_progress")


def test_set_status_abandon_recovery(tmp_path):
    f = _write(tmp_path)
    assert phaseplan.set_status(f, 2, "in_progress") is None
    assert phaseplan.set_status(f, 2, "pending") is None  # abandon a wedged run
    assert phaseplan.parse(f.read_text(encoding="utf-8"))[1].status == "pending"


def test_cli_next_phase_reports_resume(tmp_path, capsys):
    text = VALID.replace("- **status:** pending", "- **status:** in_progress")
    f = _write(tmp_path, text)
    assert main(["next-phase", str(f)]) == 0
    assert "RESUME" in capsys.readouterr().out


def test_status_finds_state_by_upward_search(tmp_path, capsys):
    proj = tmp_path / "proj"
    (proj / "docs" / "handoff").mkdir(parents=True)
    f = proj / "docs" / "handoff" / "phase-plan.md"
    f.write_text(VALID, encoding="utf-8")
    (proj / ".spec-pipeline").mkdir()
    (proj / ".spec-pipeline" / "state.json").write_text(
        '{"rounds": {"spec": 2, "plan": 0, "final": 0}}', encoding="utf-8")
    assert main(["status", str(f)]) == 0
    assert "spec=2/3" in capsys.readouterr().out


def test_cli_next_phase_exit_codes(tmp_path, capsys):
    f = _write(tmp_path)
    assert main(["next-phase", str(f)]) == 0
    assert "2" in capsys.readouterr().out
    done = _write(tmp_path, VALID.replace("- **status:** pending", "- **status:** complete"))
    assert main(["next-phase", str(done)]) == 1


def test_cli_status_renders_table(tmp_path, capsys):
    f = _write(tmp_path)
    assert main(["status", str(f)]) == 0
    out = capsys.readouterr().out
    assert "Foundation" in out and "Core logic" in out and "next:" in out
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash plugins/spec-pipeline/tests/run_tests.sh` Expected: FAIL — `AttributeError: module 'specpipe.phaseplan' has no attribute 'next_phase'`.

- [ ] **Step 3: Append the state ops to phaseplan.py**

Append to `plugins/spec-pipeline/scripts/specpipe/specpipe/phaseplan.py`:

```python
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash plugins/spec-pipeline/tests/run_tests.sh` Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add plugins/spec-pipeline/scripts/specpipe/specpipe/phaseplan.py plugins/spec-pipeline/tests/test_phaseplan_state.py
git commit -m "feat(spec-pipeline): deterministic next-phase resolution, atomic status transitions, status render"
```

---

### Task 6: specdoc.py — `validate spec` (core + master/phase deltas)

**Files:**

- Create: `plugins/spec-pipeline/scripts/specpipe/specpipe/specdoc.py`
- Test: `plugins/spec-pipeline/tests/test_specdoc.py`

**Interfaces:**

- Consumes: `grammar` sections/patterns; `findings`.
- Produces: `validate_spec(path: Path, kind: str, master: Path | None) -> list[Finding]`; `master_decision_ids(text: str) -> set[str]`; `cmd_validate_spec(args) -> int`. Template-conformance tests (Task 10) call `validate_spec` directly.

- [ ] **Step 1: Write the failing tests**

`plugins/spec-pipeline/tests/test_specdoc.py`:

```python
from specpipe import specdoc
from specpipe.findings import ERROR, WARNING

CORE = ["Overview", "Architecture", "Data model", "Interfaces",
        "Behavior & rules", "Error handling", "Testing strategy",
        "Acceptance criteria", "Rejected alternatives", "Out of scope"]


def _master_text(register="- **D1** — Parser is streaming — rationale.",
                 build="Per-phase task-count ceiling: 10 tasks."):
    body = "\n".join(f"## {name}\n\nSection content.\n" for name in CORE)
    return (f"# Demo — Master Spec\n\n{body}\n"
            f"## Build plan\n\n{build}\n\n"
            f"## Cross-cutting decision register\n\n{register}\n")


def _phase_text(cites="Implements D1 per the master."):
    body = "\n".join(f"## {name}\n\nSection content.\n" for name in CORE)
    extra = "\n".join(f"## {name}\n\nSection content.\n" for name in
                      ["Status & revision provenance", "Provenance & governance",
                       "Inherited contracts", "Scope & decomposition decision",
                       "Sizing flag"])
    return (f"# Demo Phase 2 — Phase Spec\n\n{body}\n{extra}\n"
            f"## Notes\n\n{cites}\nEnvelope shape (inherited from master D1).\n")


def _validate(tmp_path, text, kind, master_text=None):
    p = tmp_path / "spec.md"
    p.write_text(text, encoding="utf-8")
    master = None
    if master_text is not None:
        master = tmp_path / "master.md"
        master.write_text(master_text, encoding="utf-8")
    return specdoc.validate_spec(p, kind, master)


def _errors(findings):
    return [f for f in findings if f.severity == ERROR]


def test_valid_master_no_errors(tmp_path):
    assert _errors(_validate(tmp_path, _master_text(), "master")) == []


def test_master_missing_section(tmp_path):
    text = _master_text().replace("## Error handling\n\nSection content.\n", "")
    codes = [f.code for f in _errors(_validate(tmp_path, text, "master"))]
    assert "SPEC-MISSING-SECTION" in codes


def test_master_placeholder_is_error(tmp_path):
    text = _master_text().replace("Section content.", "Section content. TBD", 1)
    codes = [f.code for f in _errors(_validate(tmp_path, text, "master"))]
    assert "SPEC-PLACEHOLDER" in codes


def test_master_empty_register(tmp_path):
    text = _master_text(register="(decisions to be assigned)")
    codes = [f.code for f in _errors(_validate(tmp_path, text, "master"))]
    assert "SPEC-EMPTY-REGISTER" in codes


def test_master_missing_ceiling(tmp_path):
    text = _master_text(build="Phases ordered by dependency.")
    codes = [f.code for f in _errors(_validate(tmp_path, text, "master"))]
    assert "SPEC-NO-CEILING" in codes


def test_red_flag_phrases_warn(tmp_path):
    text = _master_text().replace("Section content.", "It should probably work.", 1)
    warns = [f.code for f in _validate(tmp_path, text, "master")
             if f.severity == WARNING]
    assert "SPEC-RED-FLAG" in warns


def test_valid_phase_no_errors(tmp_path):
    assert _errors(_validate(tmp_path, _phase_text(), "phase", _master_text())) == []


def test_phase_dangling_decision(tmp_path):
    findings = _validate(tmp_path, _phase_text(cites="Implements D1 and D9."),
                         "phase", _master_text())
    dangling = [f for f in _errors(findings) if f.code == "SPEC-DANGLING-DECISION"]
    assert len(dangling) == 1 and "D9" in dangling[0].message


def test_phase_requires_master(tmp_path):
    codes = [f.code for f in _errors(_validate(tmp_path, _phase_text(), "phase"))]
    assert "SPEC-NO-MASTER" in codes


def test_phase_no_inherited_flags_warns(tmp_path):
    text = _phase_text().replace("(inherited from master D1)", "from master D1")
    warns = [f.code for f in _validate(tmp_path, text, "phase", _master_text())
             if f.severity == WARNING]
    assert "SPEC-NO-INHERITED-FLAGS" in warns
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash plugins/spec-pipeline/tests/run_tests.sh` Expected: FAIL — `ModuleNotFoundError: No module named 'specpipe.specdoc'`.

- [ ] **Step 3: Implement specdoc.py**

`plugins/spec-pipeline/scripts/specpipe/specpipe/specdoc.py`:

```python
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
    return set(grammar.DECISION_ID_RE.findall(reg[2]))


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
            cited = set(grammar.DECISION_ID_RE.findall(text))
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash plugins/spec-pipeline/tests/run_tests.sh` Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add plugins/spec-pipeline/scripts/specpipe/specpipe/specdoc.py plugins/spec-pipeline/tests/test_specdoc.py
git commit -m "feat(spec-pipeline): spec validator — core sections, master register/ceiling, phase citation resolution"
```

---

### Task 7: plandoc.py — `validate plan` (structure + TDD step order)

**Files:**

- Create: `plugins/spec-pipeline/scripts/specpipe/specpipe/plandoc.py`
- Test: `plugins/spec-pipeline/tests/test_plandoc.py`

**Interfaces:**

- Consumes: `grammar` (sections, `strip_fences`, `PLAN_ANTI_PATTERNS`, `PLACEHOLDER_RE`); `findings`.
- Produces: `classify(step_title: str) -> str` (one of `test-write|run-fail|implement|run-pass|commit|other`); `validate_plan(path: Path) -> list[Finding]`; `cmd_validate_plan(args) -> int`. A task opts out of the TDD-order check with the literal marker `<!-- specpipe: no-tdd` in its body (downgraded to a warning).

- [ ] **Step 1: Write the failing tests**

`plugins/spec-pipeline/tests/test_plandoc.py`:

````python
from specpipe import plandoc
from specpipe.findings import ERROR, WARNING

VALID_PLAN = """\
# Demo Implementation Plan

**Goal:** Build the demo parser.

**Architecture:** Single module with a pure function.

**Tech Stack:** Python 3.11, pytest

**Spec:** `docs/specs/demo.md` (master governs on conflict)

## Global Constraints

- Python >= 3.11, stdlib only

## File Structure

| Symbol | Kind | Introduced |
| --- | --- | --- |
| `parse_record` | function | Task 1 |

### Task 1: Parser

**Files:**

- Create: `src/parser.py`
- Test: `tests/test_parser.py`

**Interfaces:**

- Consumes: nothing
- Produces: `parse_record(line: str) -> dict`

- [ ] **Step 1: Write the failing test**

```python
def test_parse_record():
    assert parse_record("a=1") == {"a": "1"}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_parser.py -v`
Expected: FAIL with "parse_record not defined"

- [ ] **Step 3: Implement parse_record**

```python
def parse_record(line):
    key, value = line.split("=")
    return {key: value}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/test_parser.py -v`

- [ ] **Step 5: Commit**

```bash
git add src/parser.py tests/test_parser.py
git commit -m "feat: add parse_record"
```
"""


def _findings(tmp_path, text):
    p = tmp_path / "plan.md"
    p.write_text(text, encoding="utf-8")
    return plandoc.validate_plan(p)


def _errors(tmp_path, text):
    return [f for f in _findings(tmp_path, text) if f.severity == ERROR]


def test_valid_plan_no_errors(tmp_path):
    assert _errors(tmp_path, VALID_PLAN) == []


def test_classify_step_titles():
    assert plandoc.classify("Write the failing test") == "test-write"
    assert plandoc.classify("Run test to verify it fails") == "run-fail"
    assert plandoc.classify("Implement parse_record") == "implement"
    assert plandoc.classify("Run test to verify it passes") == "run-pass"
    assert plandoc.classify("Commit") == "commit"
    assert plandoc.classify("Deploy the artifact") == "other"


def test_missing_run_fail_step_is_tdd_error(tmp_path):
    bad = VALID_PLAN.replace(
        "- [ ] **Step 2: Run test to verify it fails**", "Intervening prose.")
    assert any(f.code == "PLAN-TDD-ORDER" for f in _errors(tmp_path, bad))


def test_commit_before_green_is_tdd_error(tmp_path):
    # the only commit lands before the RED→GREEN chain completes
    bad = VALID_PLAN.replace("- [ ] **Step 5: Commit**", "- [ ] **Step 5: Wrap up**")
    bad = bad.replace(
        "- [ ] **Step 2: Run test to verify it fails**",
        "- [ ] **Step 2: Commit**\n\n- [ ] **Step 2: Run test to verify it fails**")
    assert any(f.code == "PLAN-TDD-ORDER" for f in _errors(tmp_path, bad))


def test_no_tdd_marker_downgrades_to_warning(tmp_path):
    bad = VALID_PLAN.replace(
        "- [ ] **Step 2: Run test to verify it fails**",
        "<!-- specpipe: no-tdd — docs-only task -->")
    findings = _findings(tmp_path, bad)
    assert not any(f.code == "PLAN-TDD-ORDER" and f.severity == ERROR for f in findings)
    assert any(f.code == "PLAN-NO-TDD" and f.severity == WARNING for f in findings)


def test_anti_pattern_is_error(tmp_path):
    bad = VALID_PLAN + "\nThe wiring is similar to Task 1.\n"
    assert any(f.code == "PLAN-ANTI-PATTERN" for f in _errors(tmp_path, bad))


def test_missing_header_field(tmp_path):
    bad = VALID_PLAN.replace("**Tech Stack:** Python 3.11, pytest\n", "")
    assert any(f.code == "PLAN-MISSING-HEADER" for f in _errors(tmp_path, bad))


def test_missing_global_constraints(tmp_path):
    bad = VALID_PLAN.replace("## Global Constraints", "## Rules of Thumb")
    assert any(f.code == "PLAN-NO-CONSTRAINTS" for f in _errors(tmp_path, bad))


def test_missing_files_block(tmp_path):
    bad = VALID_PLAN.replace("**Files:**", "**Touched:**")
    assert any(f.code == "PLAN-NO-FILES" for f in _errors(tmp_path, bad))


def test_forward_reference_warns(tmp_path):
    two_tasks = VALID_PLAN.replace("| `parse_record` | function | Task 1 |",
                                   "| `parse_record` | function | Task 2 |")
    warns = [f.code for f in _findings(tmp_path, two_tasks) if f.severity == WARNING]
    assert "PLAN-FORWARD-REF" in warns


def test_placeholder_is_error(tmp_path):
    bad = VALID_PLAN + "\nRemaining work: TBD\n"
    assert any(f.code == "PLAN-PLACEHOLDER" for f in _errors(tmp_path, bad))
````

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash plugins/spec-pipeline/tests/run_tests.sh` Expected: FAIL — `ModuleNotFoundError: No module named 'specpipe.plandoc'`.

- [ ] **Step 3: Implement plandoc.py**

`plugins/spec-pipeline/scripts/specpipe/specpipe/plandoc.py`:

````python
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
    if "test" in t:
        return "test-write"
    if "implement" in t:
        return "implement"
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
        hits = [lineno for lineno, line in plain if phrase in line.lower()]
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
        for t in tasks:
            if t["num"] < intro and sym in "\n".join(t["body"]):
                findings.append(Finding(WARNING, "PLAN-FORWARD-REF",
                                f"`{sym}` (introduced in Task {intro}) referenced in "
                                f"Task {t['num']}", f"{loc}:{t['line']}"))
                break
    return findings


def cmd_validate_plan(args) -> int:
    findings = validate_plan(Path(args.path))
    print(report(findings, args.json))
    return exit_code(findings)
````

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash plugins/spec-pipeline/tests/run_tests.sh` Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add plugins/spec-pipeline/scripts/specpipe/specpipe/plandoc.py plugins/spec-pipeline/tests/test_plandoc.py
git commit -m "feat(spec-pipeline): plan validator — TDD step order, anti-patterns, symbol forward-refs"
```

---

### Task 8: evidence.py — `record-red` / `record-green`

**Files:**

- Create: `plugins/spec-pipeline/scripts/specpipe/specpipe/evidence.py`
- Test: `plugins/spec-pipeline/tests/test_evidence.py`

**Interfaces:**

- Consumes: nothing from specpipe (subprocess + filesystem only).
- Produces: `record(cmd: str, task: str, audit: Path, expect: str, framework: str = "pytest", timeout: float = 600.0, expect_failure_regex: str | None = None) -> int` (`expect` in `{"red","green"}`); `cmd_record_red(args) -> int`; `cmd_record_green(args) -> int`. Execution-safety contract (the audit file is committed): `shlex.split` argv with `shell=False` (metacharacters inert), timeout rejects the gate, capture capped at 64 KiB before excerpting, best-effort secret redaction over the WHOLE evidence block (recorded command string included, rejected attempts included), single `O_APPEND` write. RED demands a **positive failure signature**, never just a non-zero exit: pytest mode requires a `N failed`/`FAILED` marker (so "no tests ran", usage errors, and arbitrary failing commands are REJECTED) on top of the collection-error rejection; `framework="generic"` (bats/Jest/other) keeps fails-for-the-right-reason via `expect_failure_regex`, which is MANDATORY with generic — output must match it or RED is REJECTED (exit 1); generic without a regex is a bad invocation (exit 2, nothing runs, nothing recorded). Rejected attempts are ALSO appended (labelled REJECTED) — the trail shows failures to establish RED, not just successes.

- [ ] **Step 1: Write the failing tests**

`plugins/spec-pipeline/tests/test_evidence.py`:

```python
import sys
from pathlib import Path

from specpipe import evidence

PASSING = "def test_ok():\n    assert True\n"
FAILING = "def test_no():\n    assert 1 == 2\n"
BROKEN = "import module_that_does_not_exist_xyz\n\ndef test_x():\n    assert True\n"


def _pytest_cmd(path: Path) -> str:
    return f'"{sys.executable}" -m pytest "{path}" -q'


def _project(tmp_path, name, body):
    f = tmp_path / name
    f.write_text(body, encoding="utf-8")
    return f


def test_red_on_genuine_failure(tmp_path):
    f = _project(tmp_path, "test_fail.py", FAILING)
    audit = tmp_path / "audit.md"
    assert evidence.record(_pytest_cmd(f), "T1", audit, "red") == 0
    content = audit.read_text(encoding="utf-8")
    assert "## Task T1 — RED" in content and "exit:" in content


def test_red_rejected_when_tests_pass(tmp_path):
    f = _project(tmp_path, "test_pass.py", PASSING)
    audit = tmp_path / "audit.md"
    assert evidence.record(_pytest_cmd(f), "T1", audit, "red") == 1
    assert "REJECTED" in audit.read_text(encoding="utf-8")


def test_red_rejected_on_collection_error(tmp_path):
    f = _project(tmp_path, "test_broken.py", BROKEN)
    audit = tmp_path / "audit.md"
    assert evidence.record(_pytest_cmd(f), "T1", audit, "red") == 1
    assert "collection" in audit.read_text(encoding="utf-8")


def test_green_on_pass(tmp_path):
    f = _project(tmp_path, "test_pass.py", PASSING)
    audit = tmp_path / "audit.md"
    assert evidence.record(_pytest_cmd(f), "T1", audit, "green") == 0
    assert "## Task T1 — GREEN" in audit.read_text(encoding="utf-8")


def test_green_rejected_on_failure(tmp_path):
    f = _project(tmp_path, "test_fail.py", FAILING)
    audit = tmp_path / "audit.md"
    assert evidence.record(_pytest_cmd(f), "T1", audit, "green") == 1
    assert "REJECTED" in audit.read_text(encoding="utf-8")


def test_audit_parent_dirs_created(tmp_path):
    f = _project(tmp_path, "test_fail.py", FAILING)
    audit = tmp_path / "docs" / "handoff" / "audit" / "phase-1.md"
    assert evidence.record(_pytest_cmd(f), "T1", audit, "red") == 0
    assert audit.exists()


def test_shell_metacharacters_are_inert(tmp_path):
    marker = tmp_path / "pwned.txt"
    audit = tmp_path / "audit.md"
    cmd = f'"{sys.executable}" -c "print(\'boom\'); exit(1)" ; touch "{marker}"'
    evidence.record(cmd, "T1", audit, "red", framework="generic",
                    expect_failure_regex="boom")
    assert not marker.exists()  # ';' was an argv token, not a shell operator


def test_timeout_rejects_gate(tmp_path):
    audit = tmp_path / "audit.md"
    cmd = f'"{sys.executable}" -c "import time; time.sleep(5)"'
    assert evidence.record(cmd, "T1", audit, "green", timeout=0.5) == 1
    assert "timeout" in audit.read_text(encoding="utf-8")


def test_secret_output_redacted(tmp_path):
    audit = tmp_path / "audit.md"
    script = tmp_path / "leak.py"
    script.write_text("print('token ghp_" + "a" * 30 + "')\nraise SystemExit(1)\n",
                      encoding="utf-8")
    cmd = f'"{sys.executable}" "{script}"'
    assert evidence.record(cmd, "T1", audit, "red", framework="generic",
                           expect_failure_regex="token") == 0
    content = audit.read_text(encoding="utf-8")
    assert "[REDACTED]" in content
    assert "ghp_" not in content


def test_command_string_redacted(tmp_path):
    audit = tmp_path / "audit.md"
    token = "ghp_" + "b" * 30
    script = tmp_path / "fail.py"
    script.write_text("print('boom')\nraise SystemExit(1)\n", encoding="utf-8")
    cmd = f'"{sys.executable}" "{script}" {token}'  # token as an argv arg
    assert evidence.record(cmd, "T1", audit, "red", framework="generic",
                           expect_failure_regex="boom") == 0
    content = audit.read_text(encoding="utf-8")
    assert "[REDACTED]" in content
    assert "ghp_" not in content  # redaction covers the recorded cmd line too


def test_pytest_red_rejects_arbitrary_nonzero(tmp_path):
    # a non-pytest failing command must not pass as pytest RED evidence
    audit = tmp_path / "audit.md"
    cmd = f'"{sys.executable}" -c "raise SystemExit(1)"'
    assert evidence.record(cmd, "T1", audit, "red") == 1
    assert "no test-failure signature" in audit.read_text(encoding="utf-8")


def test_pytest_red_rejects_no_tests_ran(tmp_path):
    # pytest exit 5 (no tests collected) is non-zero but proves nothing
    f = _project(tmp_path, "test_empty.py", "# intentionally no tests\n")
    audit = tmp_path / "audit.md"
    assert evidence.record(_pytest_cmd(f), "T1", audit, "red") == 1
    assert "REJECTED" in audit.read_text(encoding="utf-8")


def test_timeout_with_partial_output_still_recorded(tmp_path):
    # TimeoutExpired.stdout/stderr are BYTES even with text=True — the handler
    # must decode, not crash, and still record the rejected gate
    audit = tmp_path / "audit.md"
    script = tmp_path / "noisy.py"
    script.write_text(
        "import sys, time\nprint('partial output', flush=True)\n"
        "print('warn', file=sys.stderr, flush=True)\ntime.sleep(5)\n",
        encoding="utf-8")
    cmd = f'"{sys.executable}" "{script}"'
    assert evidence.record(cmd, "T1", audit, "green", timeout=1.0) == 1
    content = audit.read_text(encoding="utf-8")
    assert "timeout" in content and "partial output" in content


def test_generic_without_regex_is_bad_invocation(tmp_path):
    audit = tmp_path / "audit.md"
    cmd = f'"{sys.executable}" -c "raise SystemExit(3)"'
    assert evidence.record(cmd, "T1", audit, "red", framework="generic") == 2
    assert not audit.exists()  # rejected before anything ran or was recorded


def test_generic_expect_failure_regex_matched(tmp_path):
    audit = tmp_path / "audit.md"
    cmd = f'"{sys.executable}" -c "print(\'boom_assert failed\'); raise SystemExit(1)"'
    assert evidence.record(cmd, "T1", audit, "red", framework="generic",
                           expect_failure_regex="boom_assert") == 0
    assert "signature matched" in audit.read_text(encoding="utf-8")


def test_generic_expect_failure_regex_unmatched_rejected(tmp_path):
    audit = tmp_path / "audit.md"
    cmd = f'"{sys.executable}" -c "print(\'segfault-ish runner crash\'); raise SystemExit(1)"'
    assert evidence.record(cmd, "T1", audit, "red", framework="generic",
                           expect_failure_regex="boom_assert") == 1
    assert "REJECTED" in audit.read_text(encoding="utf-8")
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash plugins/spec-pipeline/tests/run_tests.sh` Expected: FAIL — `ModuleNotFoundError: No module named 'specpipe.evidence'`.

- [ ] **Step 3: Implement evidence.py**

`plugins/spec-pipeline/scripts/specpipe/specpipe/evidence.py`:

````python
"""RED/GREEN evidence capture under the execution-safety contract.

Runs the task's test command, asserts the expected outcome, and appends the
captured excerpt to the phase audit file — the committed RED→GREEN trail the
close-out report cites. Because the audit file is committed, execution is
constrained: shlex argv with no shell (metacharacters inert), timeout, 64 KiB
capture cap, best-effort secret redaction over the whole evidence block
(command string included), single O_APPEND write. Encodes the skill rule that
RED must fail for the RIGHT reason via positive signatures: pytest mode needs
a 'N failed'/'FAILED' marker and rejects collection/import errors, "no tests
ran", and arbitrary non-zero commands; --framework generic requires
--expect-failure-regex (no verification-free RED path exists). Rejected
attempts are appended too (labelled REJECTED) so the trail is honest about
failed gates.
"""
from __future__ import annotations

import datetime
import re
import shlex
import subprocess
from pathlib import Path

COLLECTION_ERROR_RE = re.compile(
    r"errors? during collection|ImportError while importing|INTERNALERROR"
    r"|error collecting|SyntaxError: invalid syntax", re.I)
# RED needs a POSITIVE pytest failure marker, not merely a non-zero exit —
# "no tests ran" (exit 5), usage/config errors (exit 4), and arbitrary
# failing commands must never pass as TDD evidence.
PYTEST_FAILURE_RE = re.compile(r"^FAILED |\b\d+ failed\b", re.M)
# Best-effort shapes of common credentials; the primary defense is the skill
# rule that only reviewed-plan test commands are ever passed here.
REDACTION_RES = [
    re.compile(r"gh[pousr]_[A-Za-z0-9]{20,}"),
    re.compile(r"github_pat_[A-Za-z0-9_]{20,}"),
    re.compile(r"AKIA[0-9A-Z]{16}"),
    re.compile(r"xox[a-z]-[A-Za-z0-9-]{10,}"),
    re.compile(r"\bsk-[A-Za-z0-9_-]{20,}"),
    re.compile(r"\bhvs\.[A-Za-z0-9_-]{20,}"),
    re.compile(r"(?i)\bbearer\s+[A-Za-z0-9._-]{20,}"),
]
TAIL_LINES = 30
CAPTURE_CAP = 64 * 1024  # bytes of combined output kept before excerpting


def _redact(text: str) -> str:
    for pattern in REDACTION_RES:
        text = pattern.sub("[REDACTED]", text)
    return text


def _to_text(v) -> str:
    # subprocess.TimeoutExpired captures stdout/stderr as BYTES even under
    # text=True (documented behavior) — decode defensively.
    if v is None:
        return ""
    return v.decode("utf-8", "replace") if isinstance(v, bytes) else v


def _append(audit: Path, task: str, label: str, cmd: str, code: int, output: str) -> None:
    audit.parent.mkdir(parents=True, exist_ok=True)
    capped = output[-CAPTURE_CAP:]
    tail = "\n".join(_redact(capped).strip().split("\n")[-TAIL_LINES:])
    stamp = datetime.datetime.now().astimezone().isoformat(timespec="seconds")
    # Redaction covers the WHOLE block — the command string can carry a token
    # (e.g. a test env arg) just as easily as the output can.
    block = (f"\n## Task {task} — {label}\n\n"
             f"- time: {stamp}\n- cmd: `{_redact(cmd)}`\n- exit: {code}\n\n"
             f"```text\n{tail}\n```\n")
    with audit.open("a", encoding="utf-8") as fh:  # single O_APPEND write
        fh.write(block)


def record(cmd: str, task: str, audit: Path, expect: str,
           framework: str = "pytest", timeout: float = 600.0,
           expect_failure_regex: str | None = None) -> int:
    if framework == "generic" and expect == "red" and not expect_failure_regex:
        # No verification-free RED path: generic runners must state the
        # expected failure signature, mirroring pytest's collection-error rule.
        print("ERROR: --framework generic requires --expect-failure-regex "
              "(the expected failing-assertion / missing-symbol signature)")
        return 2
    try:
        argv = shlex.split(cmd)
    except ValueError as exc:
        print(f"ERROR: cannot parse command: {exc}")
        return 1
    if not argv:
        print("ERROR: empty command")
        return 1
    try:
        proc = subprocess.run(argv, shell=False, capture_output=True, text=True,
                              timeout=timeout)
    except FileNotFoundError:
        print(f"ERROR: command not found: {argv[0]}")
        return 1
    except subprocess.TimeoutExpired as exc:
        output = _to_text(exc.stdout)
        stderr_text = _to_text(exc.stderr)
        if stderr_text:
            output += "\n" + stderr_text
        _append(audit, task, f"{expect.upper()} (REJECTED — timeout after {timeout:g}s)",
                cmd, -1, output)
        print(f"GATE NOT ESTABLISHED: command timed out after {timeout:g}s")
        return 1
    output = proc.stdout + ("\n" + proc.stderr if proc.stderr else "")
    if expect == "red":
        if proc.returncode == 0:
            _append(audit, task, "RED (REJECTED — command passed)", cmd,
                    proc.returncode, output)
            print("RED NOT ESTABLISHED: command passed (expected a failing test)")
            return 1
        if framework == "pytest" and COLLECTION_ERROR_RE.search(output):
            _append(audit, task, "RED (REJECTED — collection error)", cmd,
                    proc.returncode, output)
            print("RED NOT ESTABLISHED: collection/import/syntax error — a test that "
                  "errors on collection has not established RED; fix the test first")
            return 1
        if framework == "pytest" and not PYTEST_FAILURE_RE.search(output):
            _append(audit, task, "RED (REJECTED — no test-failure signature)", cmd,
                    proc.returncode, output)
            print("RED NOT ESTABLISHED: non-zero exit but no pytest failure marker "
                  "('N failed' / 'FAILED') — no failing test was proven (no tests "
                  "ran, usage/config error, or non-pytest command)")
            return 1
        if framework == "generic":
            if not re.search(expect_failure_regex, output):
                _append(audit, task, "RED (REJECTED — expected failure signature "
                        f"/{expect_failure_regex}/ not found)", cmd,
                        proc.returncode, output)
                print("RED NOT ESTABLISHED: command failed, but not for the expected "
                      f"reason (output does not match /{expect_failure_regex}/)")
                return 1
            label = "RED (generic — expected failure signature matched)"
        else:
            label = "RED"
        _append(audit, task, label, cmd, proc.returncode, output)
        print(f"RED established for task {task} (exit {proc.returncode}); "
              f"evidence appended to {audit}")
        return 0
    if proc.returncode != 0:
        _append(audit, task, "GREEN (REJECTED — command failed)", cmd,
                proc.returncode, output)
        print(f"GREEN NOT ESTABLISHED: command failed (exit {proc.returncode})")
        return 1
    _append(audit, task, "GREEN", cmd, proc.returncode, output)
    print(f"GREEN recorded for task {task}; evidence appended to {audit}")
    return 0


def cmd_record_red(args) -> int:
    return record(args.cmd, args.task, Path(args.audit), "red",
                  framework=args.framework, timeout=args.timeout,
                  expect_failure_regex=args.expect_failure_regex)


def cmd_record_green(args) -> int:
    return record(args.cmd, args.task, Path(args.audit), "green",
                  timeout=args.timeout)
````

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash plugins/spec-pipeline/tests/run_tests.sh` Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add plugins/spec-pipeline/scripts/specpipe/specpipe/evidence.py plugins/spec-pipeline/tests/test_evidence.py
git commit -m "feat(spec-pipeline): RED/GREEN evidence capture with collection-error rejection"
```

---

### Task 9: rounds.py — Codex round-cap counters

**Files:**

- Create: `plugins/spec-pipeline/scripts/specpipe/specpipe/rounds.py`
- Test: `plugins/spec-pipeline/tests/test_rounds.py`

**Interfaces:**

- Consumes: `grammar.ROUND_CAPS` (`{"spec": 3, "plan": 3, "final": 5}`).
- Produces: `cmd_rounds(args) -> int` where `args` has `state` (path), `gate` (`spec|plan|final` or None), `increment` (bool), `reset` (bool). Semantics: increment BEFORE running a review round; exit 1 on the increment that exceeds the cap = "do not run this round, record open findings instead". `--reset` zeroes all gates (start of a phase). State JSON shape: `{"rounds": {"spec": 0, "plan": 0, "final": 0}}`.

- [ ] **Step 1: Write the failing tests**

`plugins/spec-pipeline/tests/test_rounds.py`:

```python
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash plugins/spec-pipeline/tests/run_tests.sh` Expected: FAIL — `ModuleNotFoundError: No module named 'specpipe.rounds'`.

- [ ] **Step 3: Implement rounds.py**

`plugins/spec-pipeline/scripts/specpipe/specpipe/rounds.py`:

```python
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash plugins/spec-pipeline/tests/run_tests.sh` Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add plugins/spec-pipeline/scripts/specpipe/specpipe/rounds.py plugins/spec-pipeline/tests/test_rounds.py
git commit -m "feat(spec-pipeline): review-round counters with deterministic cap enforcement"
```

---

### Task 10: Templates + grammar-conformance tests

**Files:**

- Create: `plugins/spec-pipeline/templates/master-spec.md`
- Create: `plugins/spec-pipeline/templates/phase-spec.md`
- Create: `plugins/spec-pipeline/templates/implementation-plan.md`
- Create: `plugins/spec-pipeline/templates/phase-plan.md`
- Test: `plugins/spec-pipeline/tests/test_templates.py`

**Interfaces:**

- Consumes: `validate_spec` (Task 6), `validate_plan` (Task 7), `phaseplan.validate` (Task 4).
- Produces: the four templates the skills instantiate (Task 12) and `scaffold.init_project` copies (Task 11). Contract: every template validates with ZERO errors through its validator — the templates and validators share the grammar, so authored-from-template artifacts always parse.

- [ ] **Step 1: Write the failing conformance tests**

`plugins/spec-pipeline/tests/test_templates.py`:

```python
from pathlib import Path

from specpipe import phaseplan, plandoc, specdoc
from specpipe.findings import ERROR

TPL = Path(__file__).resolve().parents[1] / "templates"


def _errors(findings):
    return [f for f in findings if f.severity == ERROR]


def test_master_template_conforms():
    assert _errors(specdoc.validate_spec(TPL / "master-spec.md", "master")) == []


def test_phase_template_conforms_against_master_template():
    findings = specdoc.validate_spec(TPL / "phase-spec.md", "phase",
                                     TPL / "master-spec.md")
    assert _errors(findings) == []


def test_plan_template_conforms():
    assert _errors(plandoc.validate_plan(TPL / "implementation-plan.md")) == []


def test_phase_plan_template_conforms():
    assert _errors(phaseplan.validate(TPL / "phase-plan.md")) == []
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash plugins/spec-pipeline/tests/run_tests.sh` Expected: FAIL — `FileNotFoundError` for `templates/master-spec.md`.

- [ ] **Step 3: Write the four templates**

`plugins/spec-pipeline/templates/master-spec.md`:

```markdown
# {{PROJECT}} — Master Spec

- **Date:** {{DATE}}
- **Status:** Draft

## Overview

{{Problem statement; goals; explicit non-goals.}}

## Architecture

{{Components, boundaries, key technical decisions with rationale. State each cross-cutting decision once in the register below and cite it here by id (D1, D2, …).}}

## Data model

{{Domain types and their relationships. Shared types phases consume are defined here, once.}}

## Interfaces

{{CLI / API / contracts the system exposes or consumes.}}

## Behavior & rules

{{What each component does, per case. Concrete rules, not "handled appropriately".}}

## Error handling

{{Failure modes and how each is handled.}}

## Testing strategy

{{Mutation mindset: per load-bearing unit, name the adversarial cases that make a wrong answer observable — both sides of each branch, boundary values, degradation arms.}}

## Acceptance criteria

- {{Each criterion expressible as a failing test.}}

## Rejected alternatives

- {{Approach considered}} — {{why not taken}}.

## Out of scope

- {{Deliberate exclusion.}}

## Build plan

Per-phase task-count ceiling: 12 tasks.

{{Ordered phase list — mirror each entry into docs/handoff/phase-plan.md (the status-tracking projection; definitions stay here, and on conflict this master governs). Each phase: id (stable — never renumber), objective, scope in/out, depends-on (earlier ids only, acyclic), the master-spec slice it implements, phase-level acceptance criteria, size note. Phase 1 establishes the toolchain + test harness. Prefer vertical slices over horizontal layers.}}

## Cross-cutting decision register

- **D1** — {{Decision statement, once, in citable form}} — {{rationale}}.
```

`plugins/spec-pipeline/templates/phase-spec.md`:

```markdown
# {{PROJECT}} Phase {{N}} — {{TITLE}} — Phase Spec

## Status & revision provenance

- **Status:** Draft
- **Reviews:** {{panel lenses, raw → confirmed counts; Codex rounds consumed}}

## Provenance & governance

Sits under {{master-spec path}} and defers to it except dated inline supersession. Consumes contracts from {{predecessor phase specs}}. Conflict order: master governs; AGENTS.md governs where they overlap.

## Inherited contracts

- {{Load-bearing invariant restated verbatim}} (inherited from master D1).
- {{Predecessor contract this phase extends, and precisely how.}}

## Scope & decomposition decision

{{What this phase covers and the deliberate cuts: what re-homes to which sibling phase, and why.}}

## Sizing flag

{{Fits the master's task-count ceiling in one plan/session? If not, where to split into a micro-batch.}}

## Overview

{{This phase's slice: problem, goals, non-goals — full depth on the slice only; cite the master (e.g. D1) rather than restating system architecture.}}

## Architecture

{{Only what this phase adds or touches. Cite master decisions by id.}}

## Data model

{{New/extended types this phase introduces. Reference master-defined types.}}

## Interfaces

{{Contract touch-points: exit codes / interface deltas this phase touches.}}

## Behavior & rules

{{Per-case rules for this phase's components.}}

## Error handling

{{Failure modes this phase owns.}}

## Testing strategy

{{Adversarial cases per load-bearing unit; logic-bearing vs glue classification hints.}}

## Acceptance criteria

- {{Phase-level, each one testable.}}

## Rejected alternatives

- {{Approach}} — {{why rejected}}.

## Out of scope

- {{Excluded item}} — owned by Phase {{M}}.
```

`plugins/spec-pipeline/templates/implementation-plan.md`:

````markdown
# {{PROJECT}} Phase {{N}} Implementation Plan

**Goal:** {{One sentence: what this phase builds.}}

**Architecture:** {{2-3 sentences naming the key constructs.}}

**Tech Stack:** {{Language, runtime, key tools.}}

**Spec:** {{phase-spec path}} (defers to {{master path}}; master governs on conflict)

## Global Constraints

- {{Project-wide requirements binding every task: version floors, typing rules, the exact verification-gate command(s).}}

## File Structure

| Symbol           | Kind               | Introduced |
| ---------------- | ------------------ | ---------- |
| `{{new_symbol}}` | {{function/class}} | Task 1     |

### Task 1: {{Component}}

**Files:**

- Create: `{{exact/path}}`
- Test: `{{tests/exact/path}}`

**Interfaces:**

- Consumes: {{existing symbols this task relies on}}
- Produces: `{{new_symbol}}({{args}}) -> {{type}}` — consumed by {{later task}}

- [ ] **Step 1: Write the failing test**

```python
def test_{{behavior}}():
    assert {{new_symbol}}({{adversarial_input}}) == {{expected}}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `{{exact test command}}` Expected: FAIL with "{{expected failure, e.g. name not defined}}"

- [ ] **Step 3: Implement {{new_symbol}}**

```python
{{complete minimal implementation}}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `{{exact test command}}`

- [ ] **Step 5: Run the full verification gate; commit**

```bash
{{verification gate command}}
git add {{explicit paths}}
git commit -m "{{imperative message}}"
```
````

`plugins/spec-pipeline/templates/phase-plan.md`:

```markdown
# Phase Plan — {{PROJECT}}

Master spec: `{{master-spec path}}`

<!-- Statuses live HERE; phase definitions live in the master spec's build
     plan — on conflict the master governs. Phase ids are STABLE: never
     renumber once execution begins; append or split instead. -->

## Phase 1 — {{TITLE}}

- **status:** pending
- **objective:** {{One line.}}
- **scope-in:** {{What this phase covers.}}
- **scope-out:** {{What it deliberately excludes.}}
- **depends_on:** []
- **spec-slice:** {{Master-spec sections this phase implements.}}
- **acceptance:**
  - {{Phase-level testable criterion.}}
- **size:** {{Size note vs the master's task-count ceiling.}}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash plugins/spec-pipeline/tests/run_tests.sh` Expected: PASS — all four templates validate with zero errors.

- [ ] **Step 5: Commit**

```bash
git add plugins/spec-pipeline/templates plugins/spec-pipeline/tests/test_templates.py
git commit -m "feat(spec-pipeline): artifact templates conformant with the validator grammar"
```

---

### Task 11: scaffold.py — `init-project`

**Files:**

- Create: `plugins/spec-pipeline/scripts/specpipe/specpipe/scaffold.py`
- Test: `plugins/spec-pipeline/tests/test_scaffold.py`

**Interfaces:**

- Consumes: `templates/phase-plan.md` (Task 10) via the module-level `PLUGIN_ROOT` path (tests monkeypatch it).
- Produces: `PLUGIN_ROOT: Path`; `init_project(target: Path, handoff_dir: str = "docs/handoff") -> list[str]` (action log); `cmd_init_project(args) -> int`. Idempotent: never overwrites; appends `.spec-pipeline/` to `.gitignore` once. `handoff_dir` supports projects whose state layout is not `docs/handoff/`; the audit dir always sits beside the phase plan at `<handoff_dir>/audit/`.

- [ ] **Step 1: Write the failing tests**

`plugins/spec-pipeline/tests/test_scaffold.py`:

```python
from specpipe import scaffold


def _fake_plugin(tmp_path, monkeypatch):
    root = tmp_path / "plugin"
    (root / "templates").mkdir(parents=True)
    (root / "templates" / "phase-plan.md").write_text("# Phase Plan — {{PROJECT}}\n",
                                                      encoding="utf-8")
    monkeypatch.setattr(scaffold, "PLUGIN_ROOT", root)
    target = tmp_path / "project"
    target.mkdir()
    return target


def test_init_creates_layout(tmp_path, monkeypatch):
    target = _fake_plugin(tmp_path, monkeypatch)
    scaffold.init_project(target)
    assert (target / "docs" / "handoff" / "audit").is_dir()
    assert (target / "docs" / "handoff" / "phase-plan.md").read_text(
        encoding="utf-8").startswith("# Phase Plan")
    assert ".spec-pipeline/" in (target / ".gitignore").read_text(encoding="utf-8")


def test_init_never_overwrites(tmp_path, monkeypatch):
    target = _fake_plugin(tmp_path, monkeypatch)
    plan = target / "docs" / "handoff" / "phase-plan.md"
    plan.parent.mkdir(parents=True)
    plan.write_text("existing content\n", encoding="utf-8")
    actions = scaffold.init_project(target)
    assert plan.read_text(encoding="utf-8") == "existing content\n"
    assert any("skipped" in a for a in actions)


def test_gitignore_appended_once(tmp_path, monkeypatch):
    target = _fake_plugin(tmp_path, monkeypatch)
    (target / ".gitignore").write_text("node_modules", encoding="utf-8")  # no newline
    scaffold.init_project(target)
    scaffold.init_project(target)
    content = (target / ".gitignore").read_text(encoding="utf-8")
    assert content.count(".spec-pipeline/") == 1
    assert "node_modules\n.spec-pipeline/\n" in content


def test_custom_handoff_dir(tmp_path, monkeypatch):
    target = _fake_plugin(tmp_path, monkeypatch)
    scaffold.init_project(target, handoff_dir="notes/state")
    assert (target / "notes" / "state" / "audit").is_dir()
    assert (target / "notes" / "state" / "phase-plan.md").exists()
    assert not (target / "docs").exists()
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash plugins/spec-pipeline/tests/run_tests.sh` Expected: FAIL — `ModuleNotFoundError: No module named 'specpipe.scaffold'`.

- [ ] **Step 3: Implement scaffold.py**

`plugins/spec-pipeline/scripts/specpipe/specpipe/scaffold.py`:

```python
"""init-project: scaffold the minimal layout the execute-phase skill expects.

Idempotent — never overwrites; reports created vs skipped. handoff_dir is the
project's state-layout directory (greenfield default docs/handoff; projects on
a different handoff convention pass their own — specpipe itself is
layout-agnostic since every subcommand takes explicit paths). The phase-plan
template is read from the plugin's templates/ directory: this file lives at
<plugin>/scripts/specpipe/specpipe/scaffold.py, so the plugin root is
parents[3]. Tests monkeypatch PLUGIN_ROOT.
"""
from __future__ import annotations

from pathlib import Path

PLUGIN_ROOT = Path(__file__).resolve().parents[3]
GITIGNORE_LINE = ".spec-pipeline/"


def init_project(target: Path, handoff_dir: str = "docs/handoff") -> list[str]:
    actions: list[str] = []
    handoff = target / handoff_dir
    audit = handoff / "audit"
    audit.mkdir(parents=True, exist_ok=True)
    actions.append(f"ensured {audit}/")

    plan = handoff / "phase-plan.md"
    if plan.exists():
        actions.append(f"skipped {plan} (exists)")
    else:
        template = PLUGIN_ROOT / "templates" / "phase-plan.md"
        plan.write_text(template.read_text(encoding="utf-8"), encoding="utf-8")
        actions.append(f"created {plan}")

    gitignore = target / ".gitignore"
    existing = gitignore.read_text(encoding="utf-8") if gitignore.exists() else ""
    if GITIGNORE_LINE in existing.split("\n"):
        actions.append(f"skipped {gitignore} ({GITIGNORE_LINE} already present)")
    else:
        with gitignore.open("a", encoding="utf-8") as fh:
            if existing and not existing.endswith("\n"):
                fh.write("\n")
            fh.write(f"{GITIGNORE_LINE}\n")
        actions.append(f"appended {GITIGNORE_LINE} to {gitignore}")
    return actions


def cmd_init_project(args) -> int:
    for action in init_project(Path(args.dir), args.handoff_dir):
        print(action)
    return 0
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash plugins/spec-pipeline/tests/run_tests.sh` Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add plugins/spec-pipeline/scripts/specpipe/specpipe/scaffold.py plugins/spec-pipeline/tests/test_scaffold.py
git commit -m "feat(spec-pipeline): idempotent init-project scaffolding"
```

---

### Task 12: Skills migration — `author` and `execute-phase`

<!-- specpipe: no-tdd — markdown skill migration; verified by greps, not unit tests -->

**Files:**

- Create: `plugins/spec-pipeline/skills/author/SKILL.md` (copy of `author-master-spec/SKILL.md`, then edits below)
- Create: `plugins/spec-pipeline/skills/execute-phase/SKILL.md` (copy of `autonomous-phase-execution/SKILL.md`, then edits below)

**Interfaces:**

- Consumes: `${CLAUDE_PLUGIN_ROOT}/references/*.md` (Task 1), templates (Task 10), every specpipe subcommand (Tasks 4–11).
- Produces: `/spec-pipeline:author` and `/spec-pipeline:execute-phase`. Source skill CONTENT is preserved; only the edits listed here are applied. Do NOT modify the source files in `agent-configs`.

- [ ] **Step 1: Copy both skills**

```bash
SRC=/home/chris/projects/agent-configs/skills/.claude/skills
mkdir -p plugins/spec-pipeline/skills/author plugins/spec-pipeline/skills/execute-phase
cp "$SRC/author-master-spec/SKILL.md"        plugins/spec-pipeline/skills/author/SKILL.md
cp "$SRC/autonomous-phase-execution/SKILL.md" plugins/spec-pipeline/skills/execute-phase/SKILL.md
```

- [ ] **Step 2: Apply the shared edits to BOTH files**

Each edit is an exact old → new replacement.

(a) Replace ALL occurrences of the sibling names (order matters — run these first):

- In `author/SKILL.md`: every `autonomous-phase-execution` → `execute-phase`.
- In `execute-phase/SKILL.md`: no sibling-name occurrences exist; skip.

(b) References intro line (both files; the trailing word differs — "gate." in author, "gates." in execute-phase):

- old: ``Shared standards live in `./references/`.``
- new: ``Shared standards live in `${CLAUDE_PLUGIN_ROOT}/references/`.``

(c) Reference paths (replace each occurrence):

- `` `./references/spec-construction.md` `` → `` `${CLAUDE_PLUGIN_ROOT}/references/spec-construction.md` ``
- `` `./references/spec-construction-master.md` `` → `` `${CLAUDE_PLUGIN_ROOT}/references/spec-construction-master.md` `` (author only)
- `` `./references/spec-construction-phase.md` `` → `` `${CLAUDE_PLUGIN_ROOT}/references/spec-construction-phase.md` `` (execute-phase only)
- `` `./references/plan-construction.md` `` → `` `${CLAUDE_PLUGIN_ROOT}/references/plan-construction.md` `` (execute-phase only)

(d) Insert this section into BOTH files, immediately before the pipeline heading (`## Pipeline` in author; `## Phase pipeline` in execute-phase):

```markdown
## Validator gates (specpipe)

Structural gates run through the bundled specpipe CLI (a plain stdlib package — the invocation never writes into the plugin tree):

`PYTHONPATH="${CLAUDE_PLUGIN_ROOT}/scripts/specpipe" uv run --no-project python -B -m specpipe <subcommand> …`

(Below, `specpipe <subcommand>` abbreviates that invocation.) Errors (exit 1) MUST be fixed and the validator re-run clean BEFORE the gate's workflow/Codex pass — the deterministic pass is free; do not spend panel review on structural defects. Warnings may be accepted with a one-line recorded justification in the artifact. Validator failures are NOT halt conditions: fix and re-run.

Path convention: specpipe is layout-agnostic — every subcommand takes explicit paths. Examples below use the greenfield default `docs/handoff/`; if the project keeps its state elsewhere, resolve paths per that project's convention (the audit file always sits beside the phase plan in an `audit/` subdirectory, and `init-project` accepts `--handoff-dir`).
```

- [ ] **Step 3: Apply the author-specific edits**

Every old/new below is an exact, whole-line replacement (shown in fenced blocks so backticks and leading spaces are unambiguous).

(a) Frontmatter — three replacements:

```text
old: name: author-master-spec
new: name: author

old: description: Author the canonical project spec and decompose it into phases for execution by execute-phase. Run once at project inception.
new: description: Author the canonical project spec and decompose it into phases for execution by /spec-pipeline:execute-phase. Run once at project inception.

old:   version: '1.6'
new:   version: '2.0'
```

(b) Step 3 template pointer — replace this line:

```text
- Write the canonical spec per the spec construction standard — core + master delta (see References), formatted for LLM/agent consumption (structured, not narrative prose). Sections:
```

with:

```text
- Instantiate `${CLAUDE_PLUGIN_ROOT}/templates/master-spec.md` (its headings are the canonical grammar specpipe validates) and write the canonical spec per the spec construction standard — core + master delta (see References), formatted for LLM/agent consumption (structured, not narrative prose). Sections:
```

(c) Step 4 phase-plan template pointer — replace this line:

```text
- Each phase entry uses this stable schema (consumed by execute-phase step 1):
```

with:

```text
- Each phase entry uses this stable schema (consumed by execute-phase step 1), written to the phase-plan file instantiated from `${CLAUDE_PLUGIN_ROOT}/templates/phase-plan.md`:
```

(d) Step 5 validator gate — insert a new first bullet directly under the `### 5. Review (spec + phase plan)` heading, before the WORKFLOW PASS bullet:

```text
- VALIDATOR GATE: run `specpipe validate spec --kind master <spec-path>` and `specpipe validate phase-plan <plan-path>`; fix all errors and re-run until clean before the workflow pass.
```

(e) Step 5 Codex rounds — append to the CODEX CONVERGENCE bullet, after "On hitting the cap, record remaining open findings and proceed.":

```text
 Count rounds deterministically: run `specpipe rounds .spec-pipeline/state.json --gate spec --increment` before each round; a cap-exceeded exit (1) ends the loop.
```

(f) Step 6 scaffolding — prepend a new first bullet before the "- Seed the project's handoff state" bullet:

```text
- Run `specpipe init-project` to scaffold the minimal layout (docs/handoff/phase-plan.md from template, docs/handoff/audit/, .spec-pipeline/ gitignored); pass `--handoff-dir` when the project's existing state layout is not docs/handoff/. It is idempotent and never overwrites existing handoff files.
```

- [ ] **Step 4: Apply the execute-phase-specific edits**

Same convention: exact whole-line replacements shown in fenced blocks.

(a) Frontmatter — two replacements:

```text
old: name: autonomous-phase-execution
new: name: execute-phase

old:   version: '1.11'
new:   version: '2.0'
```

(b) Step 1 deterministic resume — replace this bullet:

```text
- Identify the next phase (= first entry with status: pending) from the project's handoff phase-plan file — the status-tracking projection of the master spec's build-plan section. Statuses live in the plan file; phase definitions live in the master; on conflict the master governs.
```

with:

```text
- Resolve the next phase deterministically: `specpipe next-phase docs/handoff/phase-plan.md` (resume-first: an in_progress phase from an interrupted session is returned before any pending one) from the project's handoff phase-plan file — the status-tracking projection of the master spec's build-plan section. Statuses live in the plan file; phase definitions live in the master; on conflict the master governs. If it reports RESUME, reassess that phase's partial state — committed tasks stand, continue from the first incomplete task — or abandon an unsalvageable run with `specpipe set-status docs/handoff/phase-plan.md --id <id> --to pending` and re-resolve. For a fresh phase, mark it active with `specpipe set-status docs/handoff/phase-plan.md --id <id> --to in_progress` and reset round counters with `specpipe rounds .spec-pipeline/state.json --reset`.
```

(c) Step 2 spec authoring — replace this bullet:

```text
- Write the phase spec per the spec construction standard — core + phase delta (see References). Full depth on this phase's slice; inherit system context from the master and predecessor phases by reference per the phase delta's inheritance rule.
```

with:

```text
- Instantiate `${CLAUDE_PLUGIN_ROOT}/templates/phase-spec.md` and write the phase spec per the spec construction standard — core + phase delta (see References). Full depth on this phase's slice; inherit system context from the master and predecessor phases by reference per the phase delta's inheritance rule. VALIDATOR GATE: `specpipe validate spec --kind phase <spec-path> --master <master-path>` clean before the workflow pass.
```

(d) Step 2 Codex rounds — append to the step-2 CODEX CONVERGENCE bullet, after "unresolved errors — not warnings — are a halt, not a proceed).":

```text
 Count rounds with `specpipe rounds .spec-pipeline/state.json --gate spec --increment` before each round.
```

(e) Step 3 plan authoring — replace this bullet:

```text
- Write the implementation plan per the plan construction standard (see References). Each task embeds its complete failing-test code and implementation code in TDD order; the RED gate is preserved at execution by step ordering (write test → run/fail → implement → run/pass), not by withholding code.
```

with:

```text
- Instantiate `${CLAUDE_PLUGIN_ROOT}/templates/implementation-plan.md` and write the implementation plan per the plan construction standard (see References). Each task embeds its complete failing-test code and implementation code in TDD order; the RED gate is preserved at execution by step ordering (write test → run/fail → implement → run/pass), not by withholding code. VALIDATOR GATE: `specpipe validate plan <plan-path>` clean before the workflow pass.
```

(f) Step 3 Codex rounds — append to the step-3 CODEX CONVERGENCE bullet, after "unresolved errors — not warnings — are a halt, not a proceed).":

```text
 Count rounds with `specpipe rounds .spec-pipeline/state.json --gate plan --increment` before each round.
```

(g) Step 4 RED evidence — replace this sentence (end of the RED bullet):

```text
Record the RED evidence (test name + failure reason) for the close-out report.
```

with:

```text
Record the RED evidence with `specpipe record-red --cmd '<test command>' --task <task-id> --audit docs/handoff/audit/phase-<id>.md` — it rejects collection errors (RED not established) and appends the evidence block the close-out report cites.
```

(h) Step 4 GREEN evidence — replace this bullet:

```text
- GREEN — apply the task's implementation from the plan. Run the tests; iterate on the IMPLEMENTATION (never the frozen tests) until green.
```

with:

```text
- GREEN — apply the task's implementation from the plan. Run the tests; iterate on the IMPLEMENTATION (never the frozen tests) until green. Record with `specpipe record-green --cmd '<test command>' --task <task-id> --audit docs/handoff/audit/phase-<id>.md`.
```

(i) Step 6 final-review rounds — append to the step-6 CODEX CONVERGENCE bullet, after "(subject to HALT CONDITIONS for unresolved errors).":

```text
 Count rounds with `specpipe rounds .spec-pipeline/state.json --gate final --increment` before each round.
```

(j) Step 7 close-out — insert a new bullet after "- Summarize phase outcome + any open/deferred items into the handoff state.":

```text
- Mark the phase done: `specpipe set-status docs/handoff/phase-plan.md --id <id> --to complete`. Commit `docs/handoff/audit/phase-<id>.md` with the close-out — it IS the RED→GREEN audit trail the report cites.
```

- [ ] **Step 5: Verify by grep**

```bash
# no stale relative reference paths, no stale sibling names, gates present
! grep -rn '\./references/' plugins/spec-pipeline/skills/
! grep -rn 'autonomous-phase-execution\|author-master-spec' plugins/spec-pipeline/skills/
grep -c 'specpipe' plugins/spec-pipeline/skills/author/SKILL.md        # expect >= 5
grep -c 'specpipe' plugins/spec-pipeline/skills/execute-phase/SKILL.md # expect >= 9
grep -n 'Validator gates (specpipe)' plugins/spec-pipeline/skills/*/SKILL.md  # expect 2 hits
grep -n '^name: author$' plugins/spec-pipeline/skills/author/SKILL.md
grep -n '^name: execute-phase$' plugins/spec-pipeline/skills/execute-phase/SKILL.md
```

Expected: all assertions hold (the `!`-prefixed greps must find nothing).

- [ ] **Step 6: Commit**

```bash
git add plugins/spec-pipeline/skills
git commit -m "feat(spec-pipeline): migrate author + execute-phase skills with specpipe validator gates"
```

---

### Task 13: Utility commands, README, CHANGELOG

<!-- specpipe: no-tdd — markdown surfaces; verified by greps and the lint gate in Task 14 -->

**Files:**

- Create: `plugins/spec-pipeline/commands/validate.md`
- Create: `plugins/spec-pipeline/commands/status.md`
- Create: `plugins/spec-pipeline/commands/init-project.md`
- Create: `plugins/spec-pipeline/README.md`
- Create: `plugins/spec-pipeline/CHANGELOG.md`

**Interfaces:**

- Consumes: the specpipe CLI (all subcommands).
- Produces: `/spec-pipeline:validate`, `/spec-pipeline:status`, `/spec-pipeline:init-project`; human-facing README.

- [ ] **Step 1: Write the three command files**

`plugins/spec-pipeline/commands/validate.md`:

```markdown
---
description: Run spec-pipeline structural validators against a spec, plan, or phase-plan file
argument-hint: '[path] [master|phase|plan|phase-plan]'
allowed-tools: Bash, Read, Glob, Grep
---

Validate the artifact at the path given in $ARGUMENTS with the specpipe CLI:

`PYTHONPATH="${CLAUDE_PLUGIN_ROOT}/scripts/specpipe" uv run --no-project python -B -m specpipe validate …`

1. Determine the artifact kind — from the second argument if given, otherwise infer: a file with `## Phase <n> —` entries is a phase-plan; one with `### Task <n>:` tasks is a plan; one with a `## Cross-cutting decision register` section is a master spec; one with `## Provenance & governance` is a phase spec. If the kind is ambiguous, ask.
2. Run the matching subcommand: `validate phase-plan <path>` · `validate spec <path> --kind master` · `validate spec <path> --kind phase --master <master-path>` (locate the master via the phase-plan's `Master spec:` line or ask) · `validate plan <path>`.
3. Render the findings grouped by severity. For each error, state the concrete fix. Warnings are judgment calls — say whether each is worth acting on and why.
```

`plugins/spec-pipeline/commands/status.md`:

```markdown
---
description: Render the spec-pipeline phase plan — statuses, next pending phase, review-round counters
argument-hint: '[phase-plan-path]'
allowed-tools: Bash, Read, Glob
---

Show project phase status via the specpipe CLI:

`PYTHONPATH="${CLAUDE_PLUGIN_ROOT}/scripts/specpipe" uv run --no-project python -B -m specpipe status <path>`

Use the path from $ARGUMENTS; if omitted, default to `docs/handoff/phase-plan.md`, and if that does not exist, locate the phase-plan file per the project's handoff convention (search for a file with `## Phase <n> —` entries under the project's state/docs layout). Present the table (id → status → depends_on → title), the resolved next phase, and any round counters. If no phase resolves as next, explain why (all complete, or a dependency chain is blocked — name the blocking phase).
```

`plugins/spec-pipeline/commands/init-project.md`:

```markdown
---
description: Scaffold the minimal spec-pipeline handoff layout (phase-plan, audit dir, gitignore entry)
argument-hint: '[target-dir]'
allowed-tools: Bash, Read, Glob
---

Scaffold the layout the execute-phase skill expects, via the specpipe CLI:

`PYTHONPATH="${CLAUDE_PLUGIN_ROOT}/scripts/specpipe" uv run --no-project python -B -m specpipe init-project --dir <target>`

Use the directory from $ARGUMENTS, defaulting to the current project root. If the project already keeps agent state somewhere other than `docs/handoff/` (check for an existing handoff/state convention first), pass `--handoff-dir <relative-path>` so the phase plan and audit dir land inside that convention. The operation is idempotent and never overwrites existing files — report what was created vs skipped. Afterwards, point at the created `docs/handoff/phase-plan.md` and note that `/spec-pipeline:author` fills it from a project brief.
```

- [ ] **Step 2: Write README.md**

`plugins/spec-pipeline/README.md`:

```markdown
# spec-pipeline

Spec-driven autonomous development pipeline for Claude Code: author a canonical master spec once, decompose it into ordered phases, then execute each phase end-to-end under TDD — with deterministic validator gates in front of every expensive review pass.

## How it works

1. `/spec-pipeline:author <brief>` — writes the master spec and phase plan from a project brief (one human checkpoint: architecture + scope), reviews them through a single ultracode workflow pass plus Codex convergence, and seeds the handoff layout.
2. `/spec-pipeline:execute-phase <project>` — resolves the next pending phase, derives its phase spec and implementation plan from the master, implements task-by-task under strict RED→GREEN→refactor TDD with frozen tests, and closes out the handoff state. One phase per session.

Every artifact gate runs the bundled `specpipe` CLI first: structural defects (missing sections, dangling decision-id citations, dependency cycles, broken TDD step order, placeholders) are caught deterministically and for free, so the review panels spend their budget on semantics.

## Commands

| Command | Purpose |
| --- | --- |
| `/spec-pipeline:author` | Author master spec + phase decomposition (run once at inception) |
| `/spec-pipeline:execute-phase` | Execute the next pending phase end-to-end (run once per phase) |
| `/spec-pipeline:validate` | Run the structural validators against any artifact, standalone |
| `/spec-pipeline:status` | Phase table, next pending phase, review-round counters |
| `/spec-pipeline:init-project` | Scaffold the minimal handoff layout without authoring a spec |

## The specpipe CLI

Stdlib-only Python with no packaging at all — a plain package directory imported via `PYTHONPATH` and run with `uv run --no-project`, so no invocation ever writes a venv or lockfile into the plugin. Query subcommands (`validate`, `next-phase`, `status`) support `--json`; state operations speak via exit codes and stable single-line output. Exit codes are `0` clean, `1` findings/failure, `2` bad invocation.

| Subcommand | Enforces |
| --- | --- |
| `validate phase-plan` | Entry schema, unique stable ids, earlier-only acyclic dependencies, status enum, single active phase |
| `validate spec --kind master\|phase` | Required sections, placeholder/red-flag scans, decision register + task ceiling (master), decision-id citation resolution + inheritance flags (phase) |
| `validate plan` | Header, symbol table, per-task Files/Interfaces, TDD step order, anti-patterns, forward references |
| `next-phase` | First pending phase whose dependencies are complete — computed, not re-read |
| `set-status` | Legal status transitions only, atomic rewrite |
| `status` | Phase table + round counters |
| `record-red` / `record-green` | Runs the test command under the safety contract (argv/no-shell, timeout, output cap, redaction), rejects collection errors as RED (pytest) or unmatched `--expect-failure-regex` (generic), appends evidence to the committed audit trail |
| `rounds` | Codex convergence round caps (spec 3 / plan 3 / final 5) |
| `init-project` | Idempotent handoff scaffolding |

## State locations (in the target project)

- `docs/handoff/phase-plan.md` — phase statuses (committed; definitions live in the master spec, which governs on conflict)
- `docs/handoff/audit/phase-<id>.md` — RED→GREEN evidence trail (committed with the phase)
- `.spec-pipeline/state.json` — transient round counters (gitignored)

The `docs/handoff/` paths are greenfield defaults, not requirements: the skills conform to whatever handoff/state convention the project already uses, specpipe takes every path as an explicit argument, and `init-project --handoff-dir` scaffolds into a non-default layout (the audit dir always sits beside the phase plan).

## Requirements

- [uv](https://docs.astral.sh/uv/) on PATH (supplies the interpreter via `--no-project`; specpipe itself has zero deps and no packaging)
- Python ≥ 3.11
- The review gates hard-require a `/codex-review` skill (Codex CLI) and ultracode workflow support; the skills HALT if unavailable

## Layout

- `skills/author`, `skills/execute-phase` — the two pipeline skills
- `commands/` — thin wrappers over specpipe
- `references/` — the shared spec/plan construction standards (the review rubric)
- `templates/` — artifact templates; their headings are the exact grammar specpipe validates
- `scripts/specpipe/` — the validator CLI, a plain stdlib package (pytest suite in `tests/`; no pyproject/venv/lock by design)
```

- [ ] **Step 3: Write CHANGELOG.md**

`plugins/spec-pipeline/CHANGELOG.md`:

```markdown
# Changelog

## 0.1.0 — 2026-07-01

Initial release. Merges the `author-master-spec` (v1.6) and `autonomous-phase-execution` (v1.11) skills from agent-configs into one plugin:

- Skills `/spec-pipeline:author` and `/spec-pipeline:execute-phase` (content preserved; validator gates added)
- Deduped shared references (one `spec-construction.md` instead of two identical copies)
- `specpipe` CLI: structural validation for specs/plans/phase-plans, deterministic next-phase resolution, legal status transitions, RED/GREEN evidence capture with collection-error rejection, review-round caps, idempotent project scaffolding
- Templates whose headings are the validator grammar (conformance-tested)
- Utility commands `/spec-pipeline:validate`, `/spec-pipeline:status`, `/spec-pipeline:init-project`
```

- [ ] **Step 4: Verify**

```bash
ls plugins/spec-pipeline/commands   # validate.md status.md init-project.md
grep -l 'CLAUDE_PLUGIN_ROOT' plugins/spec-pipeline/commands/*.md | wc -l   # expect 3
```

- [ ] **Step 5: Commit**

```bash
git add plugins/spec-pipeline/commands plugins/spec-pipeline/README.md plugins/spec-pipeline/CHANGELOG.md
git commit -m "feat(spec-pipeline): utility commands, README, changelog"
```

---

### Task 14: Full acceptance gate

<!-- specpipe: no-tdd — final verification + doc bookkeeping; runs the whole suite rather than adding one -->

**Files:**

- Modify: `docs/handoff/specs-plans.md` (status of the spec row + add the plan row)

**Interfaces:**

- Consumes: everything above.
- Produces: the released-ready plugin tree, all gates green.

- [ ] **Step 1: Run the full test suite**

Run: `bash plugins/spec-pipeline/tests/run_tests.sh -v` Expected: PASS — every test from Tasks 2–11 (≈60 tests), zero failures.

- [ ] **Step 2: Marketplace + formatting gates**

```bash
bash scripts/validate-marketplace.sh
claude plugin validate --strict plugins/spec-pipeline
npm run format                                  # prettier --write (repo config)
npx markdownlint-cli2 --fix "**/*.md"           # repo contract: fix pass before check
npm run format:check
npx markdownlint-cli2 "plugins/spec-pipeline/**/*.md"
git status --short                              # note every file the fixers rewrote
```

Expected: all pass (`--strict` treats runtime-tolerated warnings as errors — fix anything it reports). If the format/fix passes rewrote files, re-run the test suite (templates are conformance-tested) and carry the full rewritten-file list forward to Step 5's commit.

- [ ] **Step 3: Acceptance-criteria spot checks (from the spec)**

```bash
# AC4: no residual pointers into agent-configs
! grep -rn 'agent-configs' plugins/spec-pipeline/skills plugins/spec-pipeline/commands
# AC5: exactly the four deduped references
ls plugins/spec-pipeline/references | sort   # expect the 4 standard files
# AC9: the canonical invocation leaves the plugin tree clean — INCLUDING gitignored
# artifacts (plain git status is silent on ignored .venv/ etc., which is exactly
# the forbidden state)
PYTHONPATH="$PWD/plugins/spec-pipeline/scripts/specpipe" uv run --no-project python -B -m specpipe --help >/dev/null
test -z "$(git status --short --ignored plugins/spec-pipeline)" && echo "AC9 status clean"
test -z "$(find plugins/spec-pipeline \( -name .venv -o -name uv.lock -o -name .pytest_cache -o -name .ruff_cache -o -name __pycache__ \))" && echo "AC9 no generated artifacts"
# AC2 evidence: suite green (step 1). AC1/AC6: marketplace validator (step 2).
```

- [ ] **Step 4: Update the specs-plans index**

In `docs/handoff/specs-plans.md`: change the 2026-07-01 spec row's status from `Draft — pending user spec review` (or `Approved…`) to `Implemented`, and add a row for this plan file (`docs/superpowers/plans/2026-07-01-spec-pipeline-plugin.md`, status `Executed`) following the existing table format.

- [ ] **Step 5: Commit**

Stage `docs/handoff/specs-plans.md` PLUS every file the Step 2 format/fix passes rewrote (from the `git status --short` inventory) — by explicit path, never `git add -A`:

```bash
git add docs/handoff/specs-plans.md <each-rewritten-path>
git commit -m "docs(handoff): spec-pipeline design implemented; index the implementation plan"
```

Remaining follow-ups (NOT part of this plan — surface them to the user at completion): install/smoke-test the plugin in a live session, deprecate the two source skills in `agent-configs`, and run `/release-pipeline:release` when ready to tag 0.1.0.

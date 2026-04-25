# Plan: qt-suite

> **Status: Phase 1 plan — execute only after STRATEGY.md is approved.**
> **Phase 2 priority: 13 of 15.**

## Current state

| Field | Value |
|---|---|
| Source files | 2 shell scripts (`check-prerequisites.sh`, `start-qt-pilot.sh`) + 3 Python files in `mcp/qt-pilot/` (`__init__.py`, `harness.py`, `main.py`) |
| Existing tests | 4 pytest in `mcp/qt-pilot/tests/` (`test_annotations`, `test_harness`, `test_imports`, `test_main`) + 1 reference (`references/qtest-patterns/test_calculator.py`) |
| Framework | pytest |
| Conftest | `mcp/qt-pilot/tests/conftest.py` |
| Hooks | No |
| Agents | Yes (qt-app-dev, qt-debugger, qt-app-reviewer, qt-ux-advisor, test-generator) |

Principles: `[P1] Right knowledge at right moment`, `[P2] Testability is first-class`, `[P3] Complete implementations`, `[P4] Binding-agnostic`, `[P5] Coverage-driven generation`, `[P6] Headless-first GUI testing`.

Most principles target *generated code* and *agent behavior*, both behavioral. The mechanical surface is the Qt Pilot MCP server (Python).

## Gap table

| Principle | Layer | Proposed test | Rationale |
|---|---|---|---|
| [P1] Right knowledge at right moment | Behavioral — out of scope | n/a | Skill auto-load timing is determined by Claude. |
| [P2] Testability first-class | Behavioral — out of scope | n/a | The principle constrains generated component code; agents emit it. |
| [P3] Complete implementations | Behavioral — out of scope | n/a | Scaffold output quality. |
| [P4] Binding-agnostic | Mechanical | New `mcp/qt-pilot/tests/test_binding_detection.py` — given fixtures with `import PySide6` vs `import PyQt6`, the harness selects the matching binding without error; given a project with both available, prefers PySide6 by documented default. | Binding negotiation is mechanical. |
| [P5] Coverage-driven generation | Mechanical | New `mcp/qt-pilot/tests/test_coverage_gap.py` — given a coverage report fixture, the gap-extractor produces a list of file:line targets; given a clean coverage report (100%), produces empty list and the harness no-ops. | Encoding of "coverage is source of truth". |
| [P6] Headless-first GUI testing | Mechanical | Extend `mcp/qt-pilot/tests/test_main.py` — Qt Pilot startup with `DISPLAY` unset → spawns Xvfb (or stub equivalent); with `DISPLAY` set → uses existing display. | Headless launch contract. |
| [P6] Headless-first GUI testing | Mechanical | Extend `test_harness.py` — widget identification by `objectName` is preferred; coordinate-fallback only triggers when `objectName` is absent. | Two-tier identification claim. |
| Cross-cutting (start-qt-pilot.sh) | Mechanical | New `tests/start-qt-pilot.bats` — script bootstraps the venv on first run; subsequent runs reuse the venv; missing `xvfb-run` fails loudly with install hint. | Untested infrastructure script. |
| Cross-cutting (check-prerequisites.sh) | Mechanical | New `tests/check-prerequisites.bats` — emits a clean check matrix; missing `lcov` is a warning (optional), missing `xvfb` is an error (required). | Untested script. |

## Files to create / modify

```
plugins/qt-suite/
├── tests/                                    (new top-level dir)
│   ├── start-qt-pilot.bats                   (new)
│   └── check-prerequisites.bats              (new)
└── mcp/qt-pilot/tests/
    ├── test_annotations.py                   (existing)
    ├── test_harness.py                       (extend — objectName fallback)
    ├── test_imports.py                       (existing)
    ├── test_main.py                          (extend — Xvfb spawn path)
    ├── test_binding_detection.py             (new)
    └── test_coverage_gap.py                  (new)
```

## Fixtures needed

- `mcp/qt-pilot/tests/fixtures/coverage-reports/` — JSON or LCOV format coverage with various gap shapes.
- `mcp/qt-pilot/tests/fixtures/qt-projects/pyside/` and `qt-projects/pyqt/` — minimal main.py for binding detection.
- `tests/fixtures/stubs/xvfb-run` — bats PATH stub.

## Runtime estimate

- 2 new bats × ~3 cases = ~6 cases.
- 2 new + 2 extended pytest × ~4 cases = ~16 cases.
- Total ~22 cases. ~5 s suite (Python startup dominates).

## Risks (flag, do not fix)

1. **Xvfb spawn test may require `xvfb-run` binary in CI.** PATH-stub workaround should be sufficient; if the harness probes `xvfb-run --version` for a real version, stub must mimic. **Flag** if no stub design works.
2. **PySide6/PyQt6 detection** may use try-except imports rather than introspection. Pytest fixtures must isolate `sys.modules` between cases; conftest fixture should clear cached imports.
3. **`mcp/qt-pilot/__init__.py` references** the package name with a hyphen (`qt-pilot`), which is not a valid Python module name. The directory may be loaded via path manipulation. If the test imports break because of this, **flag the un-importable structure**, do not rename. (This may already be why `test_imports.py` exists — to validate the workaround.)
4. **`pyproject.toml` / package config for the qt-pilot venv** is the runtime install boundary. Tests run inside the activated venv; if pytest is invoked from outside, `pip install -e .` may be needed. Document the activation step in the plan execution.

## What this plan does NOT do

- Test the qt-suite agents. Behavioral.
- Test scaffold-command output quality. Behavioral.
- Cover C++/Qt build path (`qt-coverage-workflow/run-coverage.sh`). Optional dep (lcov, cmake) — out of scope unless user adds.
- Modify Qt Pilot or scripts.

# test-driver

Teaches Claude to proactively drive thorough testing across any project type via gap analysis, convergence loops, and persistent status tracking.

## Summary

Claude doesn't systematically think about testing unless asked. This plugin installs an always-on testing mindset that evaluates whether testing is needed at natural breakpoints (feature complete, bug fixed, pre-merge), runs structured gap analysis to find what's missing, and iterates through a convergence loop to generate tests and fix issues until everything passes. Testing posture is tracked in a persistent JSON file so future sessions start with full awareness of the project's test health.

## Principles

**[P1] Test at Breakpoints, Not Every Edit**: Surface testing at natural breakpoints (feature done, bug fixed, pre-merge), never after individual edits. Silent change tracking; noisy only when it matters.

**[P2] Inline Over Delegated**: All analysis and test generation happens in the main context window for maximum code awareness. No agent delegation -- aligned with opus-context.

**[P3] Converge, Don't Repeat**: The convergence loop drives toward all-green with oscillation detection. If the same fixes keep breaking each other, stop and surface the pattern rather than cycling forever.

**[P4] Profile-Driven Stack Knowledge**: Framework-specific testing knowledge lives in lightweight, swappable profiles. Adding support for a new stack means adding one file; the core skills stay untouched.

## Requirements

None beyond Claude Code.

Enhanced by (optional):
- `python-dev` plugin for pytest patterns
- `qt-suite` plugin for Qt/PySide6 testing
- `home-assistant-dev` plugin for HA integration testing

## Installation

```bash
/plugin marketplace add L3DigitalNet/Claude-Code-Plugins
/plugin install test-driver@l3digitalnet-plugins
```

For local development or testing without installing:

```bash
claude --plugin-dir ./plugins/test-driver
```

## How It Works

```mermaid
flowchart TD
    Task([Code change completed]) --> Mindset[testing-mindset evaluates]
    Mindset --> BP{Natural breakpoint?}
    BP -->|No| Silent((Note silently,<br/>continue))
    BP -->|Yes| Gap[gap-analysis scans project]
    Gap --> Found{Gaps found?}
    Found -->|No| Green((All tested,<br/>update status))
    Found -->|Yes| Ask{User confirms?}
    Ask -->|Fill gaps| Loop[convergence-loop iterates:<br/>generate, run, fix, verify]
    Ask -->|Record only| Status[Update TEST_STATUS.json]
    Loop --> Status
```

## Usage

**Automatic (always-on):** The `testing-mindset` skill loads for any implementation task and suggests gap analysis at natural breakpoints. No manual invocation needed.

**Explicit commands:**

```
/test-driver:analyze              # Full gap analysis, optionally fill gaps
/test-driver:analyze src/api/     # Scoped to a directory
/test-driver:status               # View current test posture
```

Optional CLAUDE.md reinforcement:

```markdown
## Testing

When working on code changes, always consult the `test-driver:testing-mindset` skill for testing awareness.
```

## Commands

| Command | Description |
|---------|-------------|
| `/test-driver:analyze` | Force a gap analysis. Detects project type, identifies missing tests, offers to fill gaps via convergence loop. |
| `/test-driver:status` | View current test posture from TEST_STATUS.json without running tests. |

## Skills

| Skill | Loaded when |
|-------|-------------|
| `testing-mindset` | Always, via broad description matching. Drives when to suggest testing. |
| `gap-analysis` | On `/test-driver:analyze` or when Claude decides a gap analysis is warranted. |
| `convergence-loop` | During test generation loops after gap analysis identifies missing tests. |
| `test-status` | When reading or writing `docs/testing/TEST_STATUS.json`. |
| `test-design` | When writing tests; provides universal design principles. |
| `profiles/python-fastapi` | When project uses FastAPI or Starlette. |
| `profiles/python-pyside6` | When project uses PySide6 or PyQt6. |
| `profiles/python-django` | When project uses Django. |
| `profiles/home-assistant` | When project is an HA custom integration. |
| `profiles/swift-swiftui` | When project uses Swift Package Manager or Xcode. |

## Design Decisions

- **No agents:** Testing benefits from full project context in the main window. Delegating to subagents loses the nuance that makes test generation accurate. Aligned with opus-context philosophy.

- **No hooks:** A behavioral skill (testing-mindset) handles proactive triggers more flexibly than a PostToolUse hook counting file edits. Hooks are mechanical; the mindset skill understands breakpoints.

- **Delegates framework knowledge:** Rather than duplicating pytest patterns from python-dev or Qt test patterns from qt-suite, test-driver identifies *what* to test and *when*, then consults existing plugins for *how*.

## Planned Features

- Additional stack profiles (Rust, Go, TypeScript/Node)
- PreCompact hook to save test analysis state before context compaction
- Integration with CI results to correlate local gap analysis with pipeline failures

## Known Issues

- Profile detection relies on dependency names in `pyproject.toml` or `Package.swift`; non-standard project setups may need manual profile selection via the gap-analysis skill's "No Profile Match" flow.
- Coverage metrics require the project's coverage toolchain (coverage.py, llvm-cov) to be installed and configured. The plugin does not install these tools.

## Links

- Repository: [L3DigitalNet/Claude-Code-Plugins](https://github.com/L3DigitalNet/Claude-Code-Plugins)
- Changelog: [`CHANGELOG.md`](CHANGELOG.md)
- Issues and feedback: [GitHub Issues](https://github.com/L3DigitalNet/Claude-Code-Plugins/issues)
- Design document: [`docs/superpowers/specs/2026-03-16-test-driver-design.md`](../../docs/superpowers/specs/2026-03-16-test-driver-design.md)

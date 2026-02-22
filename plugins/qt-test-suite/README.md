# qt-test-suite

A Claude Code plugin that provides an AI-powered Qt testing pipeline: test generation, coverage-gap analysis, and headless GUI testing for PySide6 and C++/Qt projects.

## Features

- **AI test generation** — scans your codebase, identifies untested code, writes test files
- **Coverage-driven loop** — gcov/lcov (C++) or coverage.py (Python) → HTML report → gap-targeted test generation
- **Headless GUI testing** — launches your PySide6 app via Xvfb, Claude visually interacts with it using the bundled Qt Pilot MCP server
- **Dual-language support** — Python/PySide6 now, C++/Qt ready for when you migrate
- **CI templates** — GitHub Actions workflow and portable shell script included

## Commands

| Command | Description |
|---------|-------------|
| `/qt:generate` | Scan the project and generate unit tests for untested files |
| `/qt:run` | Auto-detect project type and run the full test suite |
| `/qt:coverage` | Run coverage analysis, generate HTML report, identify gaps |
| `/qt:visual` | Launch app headlessly and run visual GUI tests |

## Skills (auto-activated)

- **`qtest-patterns`** — Activates when writing QTest (C++), pytest-qt (Python), or QML TestCase tests
- **`qt-coverage-workflow`** — Activates when working with coverage gaps, gcov, lcov, or coverage.py
- **`qt-pilot-usage`** — Activates for headless GUI testing, widget interaction, Qt Pilot MCP usage

## Agents

- **`test-generator`** — Generates coverage-targeted tests; activates after `/qt:coverage` finds gaps
- **`gui-tester`** — Drives the Qt Pilot MCP server for visual test sessions and writes markdown reports

## Prerequisites

| Requirement | Purpose | Install |
|-------------|---------|---------|
| Python 3.10+ | Qt Pilot MCP server | System package |
| Xvfb | Virtual display for headless GUI testing | `apt install xvfb` / `dnf install xorg-x11-server-Xvfb` |
| PySide6 | Auto-installed into plugin venv on first run | Automatic |
| mcp | Auto-installed into plugin venv on first run | Automatic |
| lcov | C++ coverage HTML reports | `apt install lcov` (optional for C++ projects) |
| cmake | C++ build/test | `apt install cmake` (optional for C++ projects) |

> **Note:** Qt Pilot's Python dependencies (PySide6, mcp) are automatically installed into a virtual environment inside the plugin on first use. No manual pip install needed.

Run `bash <plugin-root>/scripts/check-prerequisites.sh` to verify your setup.

## Installation

Install via the Claude Code plugin marketplace or directly:

```bash
claude plugin install qt-test-suite
```

Or load locally for development:

```bash
claude --plugin-dir ./plugins/qt-test-suite
```

## Configuration

Create `.qt-test.json` in your project root (copy from `templates/qt-test.json`):

```json
{
  "project_type": "python",
  "build_dir": "build",
  "test_dir": "tests",
  "app_entry": "main.py",
  "coverage_threshold": 80,
  "coverage_exclude": ["tests/*"]
}
```

For personal overrides (gitignored), create `.claude/qt-test.local.md`:

```markdown
# Qt Test Suite local overrides
My app entry is src/app.py (not main.py).
Coverage threshold for this machine: 70% (still setting up tests).
```

## Setting Widget Object Names (for GUI testing)

The Qt Pilot MCP server identifies widgets by their `objectName`. Set names on all interactive elements:

```python
# Python/PySide6
self.save_btn = QPushButton("Save")
self.save_btn.setObjectName("save_btn")

self.filename_input = QLineEdit()
self.filename_input.setObjectName("filename_input")
```

```cpp
// C++
QPushButton *btn = new QPushButton("Save");
btn->setObjectName("save_btn");
```

Without object names, the GUI tester still works but falls back to coordinate-based clicks.

## Quick Start

```bash
# 1. Generate tests for your project
/qt:generate

# 2. Run the test suite
/qt:run

# 3. Check coverage
/qt:coverage

# 4. Visual test the UI
/qt:visual
```

## CI Integration

Copy `skills/qt-coverage-workflow/templates/qt-coverage.yml` to `.github/workflows/` for automated coverage on every push.

Or use the portable shell script:
```bash
bash skills/qt-coverage-workflow/templates/run-coverage.sh --python --threshold 80
```

## Credits

Headless GUI testing powered by [Qt Pilot](https://github.com/neatobandit0/qt-pilot) (MIT License).
Coverage workflow inspired by [Qt Company's Coco + AI blog post](https://www.qt.io/quality-assurance/blog/a-practical-guide-to-generating-unit-tests-with-ai-code-assistants).

## License

MIT

# Changelog

All notable changes to the qt-suite plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2026-03-01

### Added
- merge qt-dev-suite and qt-test-suite into unified qt-suite plugin

### Changed
- remove unused pytest-mock dep; simplify conftest.py
- add pytest config and dev dependencies
- extract magic numbers to named constants
- replace _app_state dict with AppState dataclass
- add Binding column to skills table (Python/Both)
- fix structural README issues and docs path

### Fixed
- hoist late imports in tests; use rmtree for robust temp dir cleanup
- use local vars for Pyright narrowing in _cleanup_app; fix remaining str|None annotations
- cleanup on launch_app failure paths; remove unused imports in tests
- cleanup on launch_app failure paths; strengthen socket test assertion
- replace mktemp with mkdtemp; use socket context manager
- remove unused import types from test_annotations.py
- add missing type annotations — Optional params and return types
- fix inverted assertion in test_main_no_unused_stdlib_imports
- remove unused imports; move late imports to module level
- fix path injection in validate-agent-frontmatter.sh; fix CHANGELOG em dashes

## [0.1.0] - 2026-03-01

### Added

- Merged `qt-dev-suite` and `qt-test-suite` into a single plugin; all components carried forward unchanged
- 13 domain skills: `qt-architecture`, `qt-signals-slots`, `qt-layouts`, `qt-model-view`, `qt-threading`, `qt-styling`, `qt-resources`, `qt-dialogs`, `qt-packaging`, `qt-debugging`, `qt-qml`, `qt-settings`, `qt-bindings`
- 3 testing skills: `qtest-patterns`, `qt-coverage-workflow`, `qt-pilot-usage`
- 4 development agents: `qt-app-dev`, `qt-debugger`, `qt-app-reviewer`, `qt-ux-advisor`
- 2 testing agents: `test-generator`, `gui-tester`
- `/qt-suite:scaffold` command — scaffold a new Python/PySide6 project
- `/qt-suite:new-component` command — generate a widget, dialog, or window class
- `/qt-suite:generate` command — AI-driven test generation from coverage gaps
- `/qt-suite:run` command — auto-detect Python/C++ and run the test suite
- `/qt-suite:coverage` command — coverage analysis with gcov/lcov and coverage.py
- `/qt-suite:visual` command — headless GUI testing via Qt Pilot MCP server
- Bundled Qt Pilot MCP server (source: github.com/neatobandit0/qt-pilot, MIT license)
- Auto-installing venv for Qt Pilot dependencies on first run
- Prerequisite check script with per-distro Xvfb install instructions
- GitHub Actions workflow template (`qt-coverage.yml`)
- Portable coverage shell script (`run-coverage.sh`)
- `.qt-test.json` configuration template

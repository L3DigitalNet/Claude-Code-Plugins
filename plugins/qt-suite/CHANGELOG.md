# Changelog

All notable changes to the qt-suite plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- Added `Binding` column to the Skills table annotating each skill's applicability: `Python` (3 skills: `qt-packaging`, `qt-bindings`, `qt-pilot-usage`) or `Both` (13 skills)

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

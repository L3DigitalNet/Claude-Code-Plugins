# Changelog

All notable changes to the `qt-test-suite` plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-02-22

### Added
- Initial release
- `/qt:generate` command — AI-driven test generation (scans repo, writes test files)
- `/qt:run` command — auto-detects Python (pytest) / C++ (CTest) and runs test suite
- `/qt:coverage` command — gcov/lcov (C++) and coverage.py (Python) with HTML reports and gap identification
- `/qt:visual` command — headless GUI testing via bundled Qt Pilot MCP server
- `qtest-patterns` skill — C++ QTest, Python pytest-qt, QML TestCase patterns with CMake integration
- `qt-coverage-workflow` skill — coverage feedback loop, gcov/lcov workflow, coverage.py workflow
- `qt-pilot-usage` skill — Qt Pilot MCP tool reference, widget naming patterns, test report format
- `test-generator` agent — coverage-gap-driven test generation with pass verification
- `gui-tester` agent — autonomous visual testing with Qt Pilot, screenshot capture, markdown reports
- Bundled Qt Pilot MCP server (source from github.com/neatobandit0/qt-pilot, MIT license)
- Auto-installing venv for Qt Pilot dependencies on first run
- Prerequisite check script with per-distro Xvfb install instructions
- GitHub Actions workflow template (`qt-coverage.yml`) for Python + C++ CI
- Portable shell script (`run-coverage.sh`) for local and generic CI coverage
- `.qt-test.json` configuration template
- C++ and Python example test files

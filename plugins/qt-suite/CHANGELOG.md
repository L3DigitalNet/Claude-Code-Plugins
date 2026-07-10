# Changelog

All notable changes to the qt-suite plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.4] - 2026-07-02

### Changed

- Add comprehensive references for Python tooling standards

## [0.3.3] - 2026-06-08

### Changed

- one-time Prettier normalization
- move session-state docs under docs/handoff/ (v3.1)

### Fixed

- final structural fixes — markdownlint now 0
- scripted structural fixes (MD036/MD040/MD025)

## [0.3.2] - 2026-05-25

### Changed

- qt-suite: add run-tests.sh wrapper for qt-pilot pytest
- qt-suite: Phase 2 — bats coverage on check-prerequisites + manifest (6 cases)

### Fixed

- canonicalize TEST-003 — bats helper bypass (prophylactic)

## [0.3.1] - 2026-04-23

### Changed

- `gui-tester` and `test-generator` agents changed from `model: inherit` to `model: sonnet`. Invoked from Opus sessions, inherit meant these agents ran on Opus for deterministic multi-step MCP interactions and coverage-gap test generation — Sonnet is the correct tier. About 5× cheaper per invocation for Opus users.

## [0.3.0] - 2026-03-27

### Changed

- Converted 16 skills to on-demand references loaded by agents, following the nominal plugin's architecture pattern
- Replaced `skills:` frontmatter in 4 agents with explicit Read pointers to `references/`
- Skill sub-files (examples, templates, reference docs) preserved in `references/` subdirectories

### Removed

- Deleted all 16 skills; the `skills/` directory no longer exists

## [0.2.1] - 2026-03-04

### Changed

- update org references from L3Digital-Net to L3DigitalNet

### Fixed

- apply /hygiene sweep fixes — em dashes, root README python-dev entry
- apply audit findings — namespace, UX, docs, skills
- fix 7 code review issues in qt-pilot MCP server

## [Unreleased]

## [0.2.0] - 2026-03-01

### Added

- Merge qt-dev-suite and qt-test-suite into unified qt-suite plugin

### Changed

- Remove unused pytest-mock dep; simplify conftest.py
- Add pytest config and dev dependencies
- Extract magic numbers to named constants
- Replace \_app_state dict with AppState dataclass
- Add Binding column to skills table (Python/Both)
- Fix structural README issues and docs path

### Fixed

- Hoist late imports in tests; use rmtree for robust temp dir cleanup
- Use local vars for Pyright narrowing in \_cleanup_app; fix remaining str|None annotations
- Cleanup on launch_app failure paths; remove unused imports in tests
- Cleanup on launch_app failure paths; strengthen socket test assertion
- Replace mktemp with mkdtemp; use socket context manager
- Remove unused import types from test_annotations.py
- Add missing type annotations for Optional params and return types
- Fix inverted assertion in test_main_no_unused_stdlib_imports
- Remove unused imports; move late imports to module level
- Fix path injection in validate-agent-frontmatter.sh; fix CHANGELOG em dashes

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

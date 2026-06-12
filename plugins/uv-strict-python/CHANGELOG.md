# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Fixed
- Conformance pass against `project-standards` python-tooling (README at `79daeae`) and python-coding draft v0.4 (`a14ac7d`):
  - uv-commands: CI guidance corrected from `uv sync --frozen` to the standard-mandated `uv sync --locked --all-groups`; Python version examples aligned to the 3.14 baseline; workflow examples now install the full dev toolchain; dropped `pipx install uv` bootstrap
  - testing: replaced the pre-softening "every feature, 5 cases" matrix with the standard's material-change SHOULD/MUST/MAY coverage expectations; marked `markers`/`filterwarnings` as optional additions beyond the baseline
  - pep723-scripts: examples reworked to argparse-by-default with typed `main() -> int` (coding standard); 3.14 shebang; scope note that PEP 723 is a plugin extension (the standard governs script projects, not single files)
  - pyproject: `check.yml` now pins the reviewed uv version (`0.11.6`, matching the adopt-CLI bundle); dev group gains the bundle's `pytest>=9.0` and `ruff>=0.9.0` floors; uv.lock library guidance labeled as plugin recommendation

### Changed
- SKILL.md: added sync pin to the mirrored standard commits, pointer to the `project-standards adopt python-tooling` CLI, and PEP 723 extension marker
- uv shim: read-only `uv pip list|show|tree|check` now passes through; mutating/legacy `uv pip` subcommands remain blocked (suggestions now include `uv export`)
- coding-standard summary and AGENTS.md template now state the Python Coding standard's draft (v0.4, reference-only) status

## [0.1.0] - 2026-06-09

### Changed
- Add comprehensive references for Python tooling standards


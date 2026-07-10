# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [0.2.1] - 2026-07-02

### Fixed

- re-sync standards to project-standards@6cf2228
- adopt project-standards v3.0.0 (pin @v3, MD060, format)

## [0.2.0] - 2026-06-12

### Added

- **BasedPyright LSP integration** (`.lsp.json` + `scripts/basedpyright-lsp.sh`) implementing the standard's §13 CLI-agent language-server policy — resolves `basedpyright-langserver` from PATH with a `uvx` fallback
- **Scaffold templates**: byte-identical copies of the adopt-CLI bundle artifacts (`check.py`, `check.yml`, `python-version`, `pyproject.python-tooling.toml`, shared `editorconfig` + `vscode-extensions.json`) plus `vscode-settings.json`/`vscode-tasks.json` (standard §13) and an ADR exception skeleton (standard §20)
- **Standard-sync drift test** (`tests/check-standard-sync.sh`): fails when project-standards moves past the SKILL.md sync pin or a template diverges from its bundle artifact
- **Fenced-block validation** (`tests/validate-fenced-blocks.sh`): parses every fenced toml/json/yaml block in the skill content
- **Shim scope gating**: SessionStart hook now activates shims only in Python projects (`pyproject.toml`/`.python-version`/`uv.lock`); override via `.claude/uv-strict-python.local.md` (`shims: always|never|auto`)
- BasedPyright **baseline how-to** (`--writebaseline` workflow) in the migration checklist

### Fixed

- Conformance pass against `project-standards` python-tooling (README at `79daeae`) and python-coding draft v0.4 (`a14ac7d`):
  - uv-commands: CI guidance corrected from `uv sync --frozen` to the standard-mandated `uv sync --locked --all-groups`; Python version examples aligned to the 3.14 baseline; workflow examples now install the full dev toolchain; dropped `pipx install uv` bootstrap
  - testing: replaced the pre-softening "every feature, 5 cases" matrix with the standard's material-change SHOULD/MUST/MAY coverage expectations; marked `markers`/`filterwarnings` as optional additions beyond the baseline
  - pep723-scripts: examples reworked to argparse-by-default with typed `main() -> int` (coding standard); 3.14 shebang; scope note that PEP 723 is a plugin extension (the standard governs script projects, not single files)
  - pyproject: `check.yml` now pins the reviewed uv version (`0.11.6`, matching the adopt-CLI bundle); dev group gains the bundle's `pytest>=9.0` and `ruff>=0.9.0` floors; uv.lock library guidance labeled as plugin recommendation

### Changed

- SKILL.md: added sync pin to the mirrored standard commits, pointer to the `project-standards adopt python-tooling` CLI, PEP 723 extension marker, scaffold-template table, and audit/conformance trigger phrasing in the description
- uv shim: read-only `uv pip list|show|tree|check` now passes through; mutating/legacy `uv pip` subcommands remain blocked (suggestions now include `uv export`)
- python shim: `--version`/`-V` now passes through to the real interpreter; pip shim suggests `uv pip list`/`uv pip show` for inspection queries
- Tests relocated from `hooks/` to `tests/` with a hardened `run.sh` wrapper (drops the release-pipeline `missing_tests` waiver)
- coding-standard summary and AGENTS.md template now state the Python Coding standard's draft (v0.4, reference-only) status

## [0.1.0] - 2026-06-09

### Changed

- Add comprehensive references for Python tooling standards

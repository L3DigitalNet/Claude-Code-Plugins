# Project Configuration Reference

The complete project configuration for the Python Tooling SSOT Standard: `pyproject.toml`, `.editorconfig`, VS Code workspace, CI, and the local check script. Every surface drives the **same** `uv run` commands so CLI, editor, and CI never diverge.

**Important**: always use `uv add` / `uv remove` to manage dependencies. Do not hand-edit `dependencies` or `[dependency-groups]`, and do not edit `uv.lock`.

## Canonical pyproject.toml

```toml
[project]
name = "myproject"
version = "0.1.0"
description = "Short project description."
readme = "README.md"
requires-python = ">=3.14"
dependencies = []

[dependency-groups]
# Floors match the adopt-CLI bundle: pytest>=9.0 backs minversion below;
# ruff>=0.9.0 guarantees the 2025 stable style the curated select set assumes.
dev = [
    "basedpyright",
    "coverage[toml]",
    "pip-audit",
    "pytest>=9.0",
    "pytest-cov",
    "ruff>=0.9.0",
]

[build-system]
requires = ["uv_build>=0.11,<0.12"]
build-backend = "uv_build"

[tool.ruff]
target-version = "py314"
line-length = 100
src = ["src", "tests"]
# Directories owned by external programs are never linted/formatted by this standard.
# Extend with vendored/generated/archived paths a project opts out of.
extend-exclude = [".claude", ".agents", ".codex", ".continue"]

[tool.ruff.lint]
select = ["E", "F", "I", "B", "UP", "SIM", "C4", "PIE", "PTH", "RET", "RUF"]
ignore = ["E501"]  # formatter owns line wrapping

[tool.ruff.lint.per-file-ignores]
"tests/**/*.py" = ["S101"]  # assert is normal in pytest tests

[tool.ruff.format]
quote-style = "double"
indent-style = "space"
docstring-code-format = true

[tool.basedpyright]
include = ["src", "tests"]
typeCheckingMode = "strict"
pythonVersion = "3.14"
pythonPlatform = "All"
failOnWarnings = true

[tool.pytest.ini_options]
minversion = "9.0"
testpaths = ["tests"]
addopts = ["-ra", "--strict-markers", "--strict-config"]

[tool.coverage.run]
branch = true
source = ["src"]

[tool.coverage.report]
show_missing = true
skip_covered = true
fail_under = 85
```

### Why these choices

- **`requires-python = ">=3.14"`** — current stable CPython baseline. Pin lower only when a dependency forces it, and record the reason.
- **Curated Ruff `select`** (not `["ALL"]`) — `ALL` silently enables new rules on every Ruff upgrade, producing churn and surprise. The curated set is stable and boring. Projects may add rules; they must not weaken the baseline without a documented exception.
- **`[tool.pytest.ini_options]`** — recognized by pytest back to 6.0. Native `[tool.pytest]` (pytest 9.0+) is valid only with a documented exception; a misplaced pytest table silently runs with defaults.
- **Coverage via `[tool.coverage.run]` + `coverage run -m pytest`** — branch coverage is required because LLM-authored tests over-cover happy paths and under-cover decision behavior. Do **not** put `--cov` flags in pytest `addopts`.
- **`uv_build`** — native, simple, sufficient for pure-Python packages. Static `[project] version`, not VCS-dynamic. How the four `[build-system]` lines turn the `src/` tree into an installable console script (`[project.scripts]` → wheel → `bin/` wrapper) is walked through in the Python Tooling standard's `build-backend.md`.

### Section notes

- **`[project.scripts]`** — console entry points for CLI apps: `myproject = "myproject.cli:main"`.
- **`[project.optional-dependencies]`** — only for optional _runtime_ features users install (e.g. `myproject[postgres]`). Never for dev tools — those go in `[dependency-groups]`.
- **`[build-system]` for flat layout** — `src/` is required for importable products, so flat layout is the exception; if used, set `[tool.uv.build-backend] module-root = ""`.

### uv.lock handling

| Project type               | `uv.lock` in Git? | Why                              |
| -------------------------- | ----------------- | -------------------------------- |
| Application / internal     | ✅ Commit         | Standard policy: reproducible deploys |
| Library for external reuse | ❌ `.gitignore`   | Plugin recommendation (the standard only mandates the app/internal case); consumers resolve their own deps |

## .editorconfig

```ini
root = true

[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
trim_trailing_whitespace = true
indent_style = tab
indent_size = 2

[*.py]
indent_style = space
indent_size = 4

[*.toml]
indent_style = space
indent_size = 4

[*.{yml,yaml}]
indent_style = space
indent_size = 2

[*.md]
trim_trailing_whitespace = false  # Markdown uses trailing spaces for hard breaks
```

This is the **shared superset** reconciled with the Markdown Tooling standard: the global `indent_style = tab` makes JSON/JSONC and Markdown tab-indented to match Prettier (which emits tabs), while each language toolchain pins its own indentation — Python and TOML use 4 spaces (PEP 8 / ruff), YAML uses 2 spaces (the YAML spec forbids tab indentation). A repo that adopts both Python Tooling and Markdown Tooling gets one reconciled `.editorconfig`, not two divergent copies.

## VS Code workspace

VS Code is a front end over the same `uv`/Ruff/BasedPyright/pytest commands, never a second source of truth. Use exactly one type authority (BasedPyright) and one format/lint authority (Ruff). **Do not** add Pylance or the Python Environments extension as competing authorities.

`.vscode/extensions.json`:

```json
{
	"recommendations": [
		"ms-python.python",
		"charliermarsh.ruff",
		"detachhead.basedpyright",
		"tamasfe.even-better-toml",
		"redhat.vscode-yaml",
		"github.vscode-github-actions",
		"editorconfig.editorconfig"
	]
}
```

`.vscode/settings.json`:

```json
{
	"python.defaultInterpreterPath": "${workspaceFolder}/.venv/bin/python",
	"python.testing.pytestEnabled": true,
	"python.testing.unittestEnabled": false,
	"python.testing.pytestArgs": ["tests"],
	"[python]": {
		"editor.defaultFormatter": "charliermarsh.ruff",
		"editor.formatOnSave": true,
		"editor.codeActionsOnSave": {
			"source.fixAll.ruff": "explicit",
			"source.organizeImports.ruff": "explicit"
		}
	},
	"ruff.nativeServer": "on",
	"basedpyright.analysis.typeCheckingMode": "strict",
	"files.exclude": {
		"**/__pycache__": true,
		"**/.pytest_cache": true,
		"**/.ruff_cache": true,
		"**/.mypy_cache": true,
		"**/.coverage": true
	}
}
```

`.vscode/tasks.json` — `check`, `fix`, `test`, `typecheck`, `audit`, each running the matching `uv run` command. Workspace settings define **project behavior only**, never personal preferences (theme, font, keybindings).

## CI: .github/workflows/check.yml

```yaml
name: Check

on:
  pull_request:
  push:
    branches: ['main']

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6

      - uses: actions/setup-python@v6
        with:
          python-version-file: '.python-version'

      # SHA-pin setup-uv: as of v8.0.0 it publishes NO moving major/minor tag,
      # so a tag pin no longer resolves. Pin a full-version commit SHA and let
      # Dependabot bump it. Re-resolve the SHA when adopting.
      - uses: astral-sh/setup-uv@fac544c07dec837d0ccb6301d7b5580bf5edae39 # v8.2.0
        with:
          # Pin the reviewed uv version when applying this template (best practice
          # per the uv GitHub Actions guide); Dependabot keeps it current.
          version: '0.11.6'
          enable-cache: true

      - name: Sync dependencies
        run: uv sync --locked --all-groups

      - name: Check formatting
        run: uv run ruff format --check .
      - name: Lint
        run: uv run ruff check .
      - name: Type check
        run: uv run basedpyright
      - name: Test with coverage
        run: uv run coverage run -m pytest
      - name: Coverage report
        run: uv run coverage report
      - name: Dependency audit
        run: uv run pip-audit
```

CI must use the lockfile (`--locked`) and must not install dependencies outside uv.

## scripts/check.py

A small wrapper so agents and humans run the whole gate with one command:

```python
import subprocess
import sys
from collections.abc import Sequence

COMMANDS: tuple[tuple[str, ...], ...] = (
    ("uv", "run", "ruff", "format", "--check", "."),
    ("uv", "run", "ruff", "check", "."),
    ("uv", "run", "basedpyright"),
    ("uv", "run", "coverage", "run", "-m", "pytest"),
    ("uv", "run", "coverage", "report"),
    ("uv", "run", "pip-audit"),
)


def run_command(command: Sequence[str]) -> int:
    print(f"\n$ {' '.join(command)}", flush=True)
    completed = subprocess.run(command, check=False)
    return completed.returncode


def main() -> int:
    for command in COMMANDS:
        return_code = run_command(command)
        if return_code != 0:
            return return_code
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

```bash
uv run python -m scripts.check
```

## Version specifiers

| Specifier    | Meaning                           |
| ------------ | --------------------------------- |
| `>=1.0`      | At least 1.0                      |
| `>=1.0,<2.0` | 1.x only                          |
| `~=1.4`      | Compatible release (`>=1.4,<2.0`) |
| `==1.4.*`    | Any 1.4.x                         |

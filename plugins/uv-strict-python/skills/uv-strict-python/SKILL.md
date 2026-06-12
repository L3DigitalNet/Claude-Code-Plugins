---
name: uv-strict-python
description: Configures Python projects to the Python Tooling SSOT Standard (uv, Ruff, BasedPyright strict, pytest+coverage, pip-audit). Use when creating projects, writing standalone scripts, configuring pyproject.toml, or migrating from pip/Poetry/mypy/black/flake8.
---

# uv-strict-python

Operational guide for the **Python Tooling SSOT Standard**: one small, strict, boring toolchain that behaves identically in CLI, VS Code, and CI. The standard prefers a few non-overlapping authorities over many competing tools, because contradictory feedback is expensive for coding agents.

This plugin operationalizes the **Python Tooling** standard — toolchain, layout, and the verification gate. Code _shape_ and agent-behavior rules (error handling, side-effect boundaries, trust boundaries, prohibited behaviors) live in the companion **Python Coding** standard, summarized in [coding-standard.md](./references/coding-standard.md). A green gate on badly shaped code is not done — read both.

> **Sync pin:** mirrors `project-standards` python-tooling (contract v1.0, README at commit `79daeae`, 2026-06-12) and the python-coding draft v0.4 (commit `a14ac7d`). The standards repo is canonical; if it has moved past these commits, prefer it and re-sync this plugin.

## When to Use This Skill

- Creating a new Python project or package
- Setting up or auditing `pyproject.toml`
- Configuring the toolchain (format, lint, type-check, test, coverage, audit)
- Writing Python scripts with external dependencies
- Migrating an existing project to the standard toolchain

## When NOT to Use This Skill

- **User wants to keep legacy tooling**: respect existing workflows if explicitly requested; record the deviation as an ADR exception, not a silent drift.
- **Documented project exception applies**: a project may pin a lower `requires-python`, add scanners, or keep mypy if an ADR records why.
- **Non-Python projects**: mixed codebases where Python isn't primary.

## The two commands that matter

**Verification gate** — the non-mutating proof the repo is clean. Code is not complete until this passes (or the response says exactly what failed and why):

```bash
uv run ruff format --check .
uv run ruff check .
uv run basedpyright
uv run coverage run -m pytest
uv run coverage report
uv run pip-audit
```

**Fix pass** — allowed to modify source; run it first when changing code:

```bash
uv run ruff format .
uv run ruff check . --fix
```

## Anti-Patterns to Avoid

| Avoid | Use Instead |
| --- | --- |
| `mypy` / `pyright` / `ty` | **`basedpyright`** strict — one semantic/type authority |
| `select = ["ALL"]` (auto-enables new rules on every Ruff bump) | A **curated** Ruff `select` set (stable, boring) |
| `[tool.pytest]` in templates | `[tool.pytest.ini_options]` (recognized back to pytest 6.0; avoids silent inert config) |
| `--cov` flags in pytest `addopts` | `coverage run -m pytest` + `coverage report` (branch coverage) |
| `pre-commit` / `prek` | The gate runs in CI + VS Code tasks + `scripts/check.py` — no overlapping hook runner |
| `uv pip install` | `uv add` / `uv sync` |
| Editing `pyproject.toml` to add deps by hand | `uv add <pkg>` / `uv remove <pkg>` |
| `hatchling` build backend | `uv_build` |
| Poetry / Pipenv / PDM | `uv` |
| `requirements.txt` | PEP 723 for single-file scripts, `pyproject.toml` for projects |
| `[project.optional-dependencies]` for dev tools | `[dependency-groups]` (PEP 735) |
| Manual venv activation (`source .venv/bin/activate`) | `uv run <cmd>` |
| Pylance / Python Environments as a second authority | BasedPyright (type) + Ruff (format/lint), nothing overlapping |

**Key principles:**

- `uv` owns dependency resolution, the lockfile, the virtualenv, and command execution — always `uv add`/`uv remove`, never hand-edit deps or activate venvs.
- Exactly **one** semantic/type authority (BasedPyright) and **one** format/lint/import authority (Ruff). Do not add a second.
- The toolchain stack is non-negotiable; only its **scope** (which paths it covers) is tunable, via `extend-exclude` / `[tool.basedpyright].include`.
- Use `[dependency-groups]` for dev/test deps, not `[project.optional-dependencies]`.

## Decision Tree

```text
What are you doing?
│
├─ Single-file script with dependencies?
│   └─ Use PEP 723 inline metadata (./references/pep723-scripts.md — plugin
│      extension; the standard governs script *projects*, not single files)
│
├─ New importable project or package?
│   └─ Full setup with src/ layout (see Full Setup below)
│
├─ Small automation/script project (lives in Git)?
│   └─ Still uv + pyproject + ruff + basic typing (Quick Start below)
│
└─ Migrating an existing project?
    └─ See Migration Guide below
```

## Tool Overview

| Tool | Purpose | Replaces |
| --- | --- | --- |
| **uv** | Package/dependency management, venv, command execution | pip, virtualenv, pip-tools, pipx, pyenv |
| **ruff** | Linting AND formatting AND import sorting | flake8, black, isort, pyupgrade |
| **basedpyright** | Strict type checking (CLI + language server) | mypy, pyright, ty |
| **pytest** | Testing | unittest |
| **coverage.py** | Branch coverage enforcement | — |
| **pip-audit** | Dependency vulnerability scanning | — |

Security baseline is **`pip-audit`** (run in CI) plus **Dependabot** for update PRs. Extra scanners (Bandit, shellcheck, actionlint, zizmor, detect-secrets) are **threat-model-driven additions**, not part of the baseline — add them when a project handles auth, secrets, public network services, subprocess execution, or uploaded files, and document the addition. See [security-setup.md](./references/security-setup.md).

## Quick Start: Minimal Project

For small multi-file or automation projects that still live in Git:

```bash
# Create project with uv (src/ layout)
uv init --package myproject
cd myproject

# Runtime dependencies
uv add requests rich

# Standard dev toolchain (flat dev group)
uv add --dev basedpyright "coverage[toml]" pip-audit pytest pytest-cov ruff

# Run code and tools through uv (never activate the venv)
uv run python -m myproject
uv run ruff check .
uv run basedpyright
uv run coverage run -m pytest && uv run coverage report
```

## Full Project Setup

**Prefer the adopt CLI when the standards repo is reachable** — it materializes the scaffolds (`.python-version`, `check.yml`, `scripts/check.py`, `AGENTS.md`/`CLAUDE.md`, `.editorconfig`, `.vscode/extensions.json`) and prints the `pyproject.toml` sections to copy:

```bash
uvx --from 'git+https://github.com/L3DigitalNet/project-standards@v3' \
  project-standards adopt python-tooling
```

The steps below produce the same result manually.

### 1. Create Project Structure

```bash
uv init --package myproject
cd myproject
```

Target layout (importable code under `src/`, tooling/scripts outside it):

```text
myproject/
├── pyproject.toml
├── uv.lock
├── .python-version
├── .editorconfig
├── README.md
├── AGENTS.md            # full instructions or pointer to the canonical source
├── CLAUDE.md            # Claude-specific notes or pointer
├── .github/workflows/check.yml
├── .vscode/             # extensions.json, settings.json, tasks.json
├── src/
│   └── myproject/
│       ├── __init__.py
│       └── py.typed     # for packages exposing typed interfaces
├── tests/
│   ├── unit/
│   └── integration/
└── scripts/
    └── check.py
```

`src/` governs the **importable product only**. Repo tooling (`scripts/check.py`, automation under `scripts/`) MAY live outside `src/`; it is still linted and formatted and SHOULD carry basic typing, but is not held to the strict-`src/` bar.

### 2. Configure pyproject.toml

See [pyproject.md](./references/pyproject.md) for the complete baseline. The canonical starting point:

```toml
[project]
name = "myproject"
version = "0.1.0"
description = "Short project description."
readme = "README.md"
requires-python = ">=3.14"
dependencies = []

[dependency-groups]
# pytest floor backs minversion; ruff floor matches the adopt-CLI bundle
dev = ["basedpyright", "coverage[toml]", "pip-audit", "pytest>=9.0", "pytest-cov", "ruff>=0.9.0"]

[build-system]
requires = ["uv_build>=0.11,<0.12"]
build-backend = "uv_build"

[tool.ruff]
target-version = "py314"
line-length = 100
src = ["src", "tests"]
extend-exclude = [".claude", ".agents", ".codex", ".continue"]

[tool.ruff.lint]
select = ["E", "F", "I", "B", "UP", "SIM", "C4", "PIE", "PTH", "RET", "RUF"]
ignore = ["E501"]  # formatter owns line wrapping

[tool.ruff.lint.per-file-ignores]
"tests/**/*.py" = ["S101"]

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

### 3. Install Dependencies

```bash
uv sync --all-groups
```

### 4. Wire the gate (not a Makefile)

The standard runs the gate three ways — all the same `uv run` commands — so CLI, editor, and CI never diverge:

- **`scripts/check.py`** — a small Python wrapper that runs the gate in order (see §18 of the standard).
- **`.vscode/tasks.json`** — tasks `check`, `fix`, `test`, `typecheck`, `audit`.
- **`.github/workflows/check.yml`** — the same sequence in CI on `uv sync --locked --all-groups`.

```bash
uv run python -m scripts.check   # if using the wrapper
```

See [pyproject.md](./references/pyproject.md) for VS Code and CI specifics.

### 5. Agent instruction entry points

`AGENTS.md` and `CLAUDE.md` are part of the repo contract, not optional docs — a fresh CLI or VS Code agent must discover the gate, fix pass, and the dependency/typing/testing/security rules before editing. Copy a template:

- [templates/AGENTS.md](./templates/AGENTS.md) — full cross-agent instructions
- [templates/AGENTS.pointer.md](./templates/AGENTS.pointer.md) — thin pointer when the canonical contract lives in a session-memory/handoff system
- [templates/CLAUDE.md](./templates/CLAUDE.md) — Claude-specific block that defers to `AGENTS.md`

A pointer file is valid only when the resolved source preserves this standard and is discoverable from a fresh session; if it can't be resolved, the agent must stop and report rather than guess.

## Migration Guide

When a user requests migration from legacy tooling (stage it; do not weaken the final standard):

### From requirements.txt + pip

**Standalone scripts**: convert to PEP 723 inline metadata (see [pep723-scripts.md](./references/pep723-scripts.md)).

**Projects**:

```bash
uv init --bare
uv add requests rich        # add each package via uv, not by editing pyproject.toml

# Or import from requirements.txt (review each package first)
grep -v '^#' requirements.txt | grep -v '^-' | grep -v '^\s*$' | while read -r pkg; do
    uv add "$pkg" || echo "Failed to add: $pkg"
done
uv sync
```

Then delete `requirements*.txt` and any `venv/`, and commit `uv.lock`.

### From setup.py / setup.cfg

1. `uv init --bare`
2. `uv add` each dependency from `install_requires`; `uv add --dev` for dev deps
3. Copy non-dependency metadata into `[project]`
4. Delete `setup.py`, `setup.cfg`, `MANIFEST.in`

### From flake8 + black + isort → Ruff

1. `uv remove flake8 black isort`
2. Delete `.flake8`, `[tool.black]`, `[tool.isort]`
3. `uv add --dev ruff`, add the curated config (see [ruff-config.md](./references/ruff-config.md))
4. `uv run ruff check . --fix` then `uv run ruff format .`

### From mypy / pyright / ty → BasedPyright

1. `uv remove mypy pyright ty` (whichever is present)
2. Delete `mypy.ini`, `pyrightconfig.json`, `[tool.mypy]`/`[tool.pyright]`/`[tool.ty]`
3. `uv add --dev basedpyright`
4. Add `[tool.basedpyright]` with `typeCheckingMode = "strict"`
5. `uv run basedpyright` — for messy codebases, adopt strictness in stages (BasedPyright baselines) rather than weakening the final bar.

## Quick Reference: uv Commands

| Command | Description |
| --- | --- |
| `uv init --package` | Create a distributable `src/` package |
| `uv add <pkg>` | Add runtime dependency |
| `uv add --dev <pkg>` | Add dev dependency |
| `uv remove <pkg>` | Remove dependency |
| `uv sync --all-groups` | Install everything |
| `uv sync --locked --all-groups` | CI install (fails if lockfile stale) |
| `uv run <cmd>` | Run a command in the project env |
| `uv run --with <pkg> <cmd>` | Run with a one-off dependency |
| `uv tool install <pkg>` | Install a global ad-hoc CLI (ruff, basedpyright, pip-audit) |

### Ad-hoc Dependencies with `--with`

```bash
uv run --with httpx python script.py   # project deps + httpx, not added to the project
```

- `uv add`: package is a real project dependency (lands in `pyproject.toml`/`uv.lock`).
- `--with`: one-off usage or a script outside a project context.

See [uv-commands.md](./references/uv-commands.md) for the complete reference.

## Best Practices Checklist

- [ ] `src/` layout for importable code
- [ ] `requires-python = ">=3.14"`, `.python-version` = `3.14`
- [ ] Ruff curated `select` set (not `ALL`)
- [ ] BasedPyright `typeCheckingMode = "strict"`
- [ ] pytest config in `[tool.pytest.ini_options]` with `--strict-markers --strict-config`
- [ ] Branch coverage on, `fail_under = 85`, via `coverage run -m pytest`
- [ ] `pip-audit` in CI
- [ ] `[dependency-groups]` for dev tools, `uv.lock` committed (apps)
- [ ] Verification gate green before claiming completion

## Read Next

- [coding-standard.md](./references/coding-standard.md) — **companion**: compact summary of the Python Coding standard (code shape + agent behavior)
- [pyproject.md](./references/pyproject.md) — complete `pyproject.toml`, VS Code, and CI baseline
- [ruff-config.md](./references/ruff-config.md) — curated Ruff lint/format configuration
- [testing.md](./references/testing.md) — pytest + coverage (the standard's gate form)
- [uv-commands.md](./references/uv-commands.md) — uv command reference
- [pep723-scripts.md](./references/pep723-scripts.md) — PEP 723 inline script metadata
- [security-setup.md](./references/security-setup.md) — pip-audit baseline + Dependabot
- [dependabot.md](./references/dependabot.md) — automated dependency updates
- [migration-checklist.md](./references/migration-checklist.md) — step-by-step migration cleanup

# uv Command Reference

`uv` is an extremely fast Python package and project manager written in Rust. It replaces pip, virtualenv, pip-tools, pipx, and pyenv.

**Key principle:** Always use `uv run` to execute commands. Never manually activate virtual environments.

## Installation

```bash
# macOS/Linux
curl -LsSf https://astral.sh/uv/install.sh | sh

# Windows
powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"

# Homebrew
brew install uv
```

(Do not bootstrap uv via pip or pipx — this standard replaces both with uv itself.)

## Project Commands

### Initialize Projects

| Command                    | Description                                   |
| -------------------------- | --------------------------------------------- |
| `uv init`                  | Create new project (application)              |
| `uv init --package`        | Create distributable package with src/ layout |
| `uv init --lib`            | Create library package                        |
| `uv init --script file.py` | Create script with PEP 723 metadata           |

### Dependency Management

| Command                           | Description                         |
| --------------------------------- | ----------------------------------- |
| `uv add <pkg>`                    | Add dependency to project           |
| `uv add <pkg> --group dev`        | Add to dependency group             |
| `uv add <pkg> --optional feature` | Add to optional dependency          |
| `uv remove <pkg>`                 | Remove dependency                   |
| `uv lock`                         | Update lock file without installing |

### Environment Management

uv manages virtual environments automatically. Do not manually create or activate venvs.

| Command | Description |
| --- | --- |
| `uv sync` | Install dependencies (creates venv if needed) |
| `uv sync --all-groups` | Install all dependency groups |
| `uv sync --group dev` | Install specific group |
| `uv sync --locked --all-groups` | CI install — fails if the lockfile is stale (the standard's CI rule) |
| `uv sync --frozen` | Install from lockfile without the staleness check (not for CI) |

### Running Code

| Command                   | Description                   |
| ------------------------- | ----------------------------- |
| `uv run <cmd>`            | Run command in project venv   |
| `uv run python script.py` | Run Python script             |
| `uv run pytest`           | Run pytest                    |
| `uv run --with pkg cmd`   | Run with temporary dependency |

### Building & Publishing

| Command                     | Description            |
| --------------------------- | ---------------------- |
| `uv build`                  | Build wheel and sdist  |
| `uv build --wheel`          | Build wheel only       |
| `uv build --sdist`          | Build sdist only       |
| `uv publish`                | Publish to PyPI        |
| `uv publish --token $TOKEN` | Publish with API token |

## Tool Commands

Run Python tools without installing globally:

```bash
# Run any tool
uv tool run ruff check .
uvx ruff check .  # shorthand

# Install tool globally
uv tool install ruff

# List installed tools
uv tool list

# Upgrade tool
uv tool upgrade ruff
```

## Python Version Management

The standard's baseline is **Python 3.14** (`requires-python = ">=3.14"`, `.python-version` = `3.14`). Do not change a project's Python version unless the task explicitly requires it; pinning lower needs a documented exception.

```bash
# Install Python version
uv python install 3.14

# List available versions
uv python list

# Pin project to Python version
uv python pin 3.14

# Run against a specific interpreter (e.g. verifying a documented lower pin)
uv run --python 3.14 pytest
```

## Script Commands (PEP 723)

```bash
# Create script with inline metadata
uv init --script myscript.py

# Add dependency to script
uv add --script myscript.py requests

# Run script (auto-installs deps)
uv run myscript.py
```

## Common Workflows

### New Application Project

The dev group is always the full standard toolchain — the stack is non-negotiable, only its scope is tunable:

```bash
uv init --package myapp
cd myapp
uv add fastapi uvicorn
uv add --dev basedpyright "coverage[toml]" pip-audit pytest pytest-cov ruff
uv sync --all-groups
uv run uvicorn myapp:app
```

### New Library Package

```bash
uv init --package mylib
cd mylib
uv add --dev basedpyright "coverage[toml]" pip-audit pytest pytest-cov ruff
uv add --group docs sphinx
uv sync --all-groups
uv run pytest
uv build
```

### Add Tool to Existing Project

```bash
cd existing-project
uv add --group dev ruff
uv run ruff check .
```

### One-off Script Execution

```bash
# Run script with dependencies (no project needed)
uv run --with requests --with rich script.py

# Or use PEP 723 inline metadata
uv run script_with_metadata.py
```

## Environment Variables

| Variable                 | Description                               |
| ------------------------ | ----------------------------------------- |
| `UV_CACHE_DIR`           | Cache directory location                  |
| `UV_NO_CACHE`            | Disable caching                           |
| `UV_PYTHON`              | Default Python version                    |
| `UV_PROJECT`             | Project directory path                    |
| `UV_PROJECT_ENVIRONMENT` | Custom venv directory (e.g., `.venv-dev`) |
| `UV_SYSTEM_PYTHON`       | Use system Python                         |

## Container/Host Development

When developing on a host machine while also running in containers, you can use separate venvs to avoid rebuilding on each context switch:

```bash
# On host machine (add to shell profile or .envrc)
export UV_PROJECT_ENVIRONMENT=.venv-dev

# Now host uses .venv-dev, containers use default .venv
uv sync  # creates .venv-dev on host
```

Add both to `.gitignore`:

```gitignore
.venv/
.venv-dev/
```

This avoids rebuilding the venv when switching between host and container (different OS, Python versions, or native dependencies).

## Performance Tips

- uv caches aggressively; first install may be slower
- CI must use `uv sync --locked --all-groups` — it fails when the lockfile is stale, which is the point (do **not** substitute `--frozen`, which skips that check)
- Use `uv cache clean` if cache grows too large

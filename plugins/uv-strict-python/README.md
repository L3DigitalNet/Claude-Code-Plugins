# uv-strict-python

A Claude Code plugin that configures Python projects to the **Python Tooling SSOT Standard**: one small, strict, boring toolchain (uv, Ruff, BasedPyright, pytest + coverage, pip-audit) that behaves identically in CLI, VS Code, and CI.

It operationalizes the **Python Tooling** standard (toolchain, layout, gate) and carries a compact summary of the companion **Python Coding** standard (code shape and agent behavior) in `references/coding-standard.md`. These are two of the five standards in the `project-standards` repository (alongside Markdown Frontmatter, Markdown Tooling, and ADR).

## When to Use

- Setting up a new Python project on the standard toolchain
- Replacing pip/virtualenv with uv for dependency management
- Replacing flake8/black/isort with Ruff for unified linting and formatting
- Replacing mypy/pyright/ty with BasedPyright strict type checking
- Migrating an existing project to the standard, or auditing one for conformance

## What It Covers

**Core toolchain:**

- **uv** — package/dependency management, lockfile, virtualenv, command execution (replaces pip, virtualenv, pip-tools, pipx, pyenv)
- **Ruff** — linting, formatting, import sorting (replaces flake8, black, isort, pyupgrade) — a **curated** rule set, not `select = ["ALL"]`
- **BasedPyright** — strict type checking, one semantic authority (replaces mypy, pyright, ty)
- **pytest + coverage.py** — testing with branch-coverage enforcement, run as `coverage run -m pytest`
- **pip-audit** — dependency vulnerability scanning

**Security baseline:**

- **pip-audit** in CI + **Dependabot** update PRs. Additional scanners are threat-model-driven, not part of the baseline.

**Standards:**

- **pyproject.toml** — single configuration center with dependency groups (PEP 735)
- **PEP 723** — inline metadata for single-file scripts
- **src/ layout** — importable product code under `src/<package>/`
- **Python 3.14** — default baseline
- **The verification gate** — one non-mutating command sequence, identical in CLI, VS Code tasks, and CI

This plugin operationalizes the Python Tooling SSOT Standard. Where a project must deviate, record an ADR exception rather than weakening the toolchain silently.

## Hook: Legacy Command Interception

This plugin includes a `SessionStart` hook that prepends PATH shims for `python`, `pip`, `pipx`, and `uv`. When Claude runs a bare `python`, `pip`, or `pipx` command, the shell resolves to the shim, which prints an error with the correct `uv` alternative and exits non-zero. `uv run` is unaffected because it prepends its managed virtualenv's `bin/` to PATH, shadowing the shims.

**Scope gating:** the standard is repository-scoped, so the shims activate only when the project root looks like a Python project (`pyproject.toml`, `.python-version`, or `uv.lock` present). Override per project in `.claude/uv-strict-python.local.md` frontmatter — `shims: always` forces them on (e.g. a polyglot repo whose Python lives in subdirectories), `shims: never` keeps them off, `shims: auto` (default) lets the markers decide.

| Intercepted Command       | Suggested Alternative                |
| ------------------------- | ------------------------------------ |
| `python ...`              | `uv run python ...`                  |
| `python -m module`        | `uv run python -m module`            |
| `python -m pip`           | `uv add`/`uv remove`                 |
| `pip install pkg`         | `uv add pkg` or `uv run --with pkg`  |
| `pip uninstall pkg`       | `uv remove pkg`                      |
| `pip freeze`              | `uv export`                          |
| `uv pip ...` (mutating)   | `uv add`/`uv remove`/`uv sync`/`uv export` |
| `pipx install <pkg>`      | `uv tool install <pkg>`              |
| `pipx run <pkg>`          | `uvx <pkg>`                          |
| `pipx uninstall <pkg>`    | `uv tool uninstall <pkg>`            |
| `pipx upgrade <pkg>`      | `uv tool upgrade <pkg>`              |
| `pipx upgrade-all`        | `uv tool upgrade --all`              |
| `pipx ensurepath`         | `uv tool update-shell`               |
| `pipx inject <pkg> <dep>` | `uv tool install --with <dep> <pkg>` |
| `pipx list`               | `uv tool list`                       |

Read-only `uv pip` introspection (`list`, `show`, `tree`, `check`) passes through to the real uv — the standard only proscribes the legacy install/modify path, and diagnostics should keep working.

Commands like `grep python`, `which python`, and `cat python.txt` work normally because `python` is a shell argument, not the command being invoked.

The shims point only at `uv`/`uv tool` equivalents — they are independent of the type-checker and linter choices, so they enforce the standard's "use uv" rule without touching BasedPyright or Ruff.

Read-only diagnostics pass through to the real binaries: `python --version`/`-V`, and `uv pip list|show|tree|check`.

## LSP: BasedPyright Language Server

The plugin ships an LSP integration (`.lsp.json` → `scripts/basedpyright-lsp.sh`) implementing the standard's §13 CLI-agent language-server policy: **BasedPyright is the single Python semantic/type authority** across editing surfaces. The launcher prefers a `uv tool install basedpyright` install and falls back to `uvx --from basedpyright basedpyright-langserver` (downloads on first use).

Do not enable a second Python language server (Pyright, Pylance, python-lsp-server, Jedi) alongside it — one type authority, per the standard. Run `/reload-plugins` after updating; check the `/plugin` Errors tab if diagnostics don't appear.

## Tests

```bash
plugins/uv-strict-python/tests/run.sh
```

The wrapper runs the bats suites (shims, hook gating, LSP launcher), then `check-standard-sync.sh` — which fails when the `project-standards` repo has moved past the sync pin recorded in SKILL.md or a template no longer byte-matches its adopt-bundle artifact — and `validate-fenced-blocks.sh`, which parses every fenced `toml`/`json`/`yaml` block in the skill content. Always use the wrapper, never bare `bats` (it hardens PATH against this workstation's find/grep shims).

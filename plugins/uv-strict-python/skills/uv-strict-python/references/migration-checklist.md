# Migration Checklist

Step-by-step migration of an existing project to the Python Tooling SSOT Standard. Stage the adoption — new code meets the standard immediately; messy legacy code can ratchet toward it — but never weaken the final standard to make migration easy.

## Before migration

- [ ] **Inventory** current state: Python versions, package manager, lockfiles, formatter, linter, type checker, test framework, CI checks, VS Code settings, existing agent instructions.
- [ ] **Decide layout**: `src/` (required for importable products) vs flat.
- [ ] **Decide uv.lock strategy**: application (commit) vs library (`.gitignore`).
- [ ] **Backup**: create a branch or tag before starting.

## Step 1 — Add uv without changing behavior

```bash
uv init --bare
uv sync
```

## Step 2 — Add Ruff

```bash
uv add --dev ruff
uv run ruff format .
uv run ruff check . --fix
```

Add the curated config (see [ruff-config.md](./ruff-config.md)). Do not start from `select = ["ALL"]`.

## Step 3 — Add pytest + coverage

```bash
uv add --dev pytest "coverage[toml]" pytest-cov
uv run coverage run -m pytest
uv run coverage report
```

## Step 4 — Add BasedPyright

```bash
uv add --dev basedpyright
uv run basedpyright
```

Configure `[tool.basedpyright]` with `typeCheckingMode = "strict"`. For codebases with many existing errors, adopt strictness in stages using BasedPyright **baselines** rather than lowering the final bar:

```bash
uv run basedpyright --writebaseline   # snapshot existing errors into .basedpyright/baseline.json
```

- Commit `.basedpyright/baseline.json` — baselined (pre-existing) errors stop failing the gate, while **new** code is held to full strict immediately.
- Fixing a file removes its entries on the next `--writebaseline`; re-run it after cleanup sessions so the baseline only ever shrinks.
- Never re-run `--writebaseline` to absorb *new* errors — that is the type-weakening anti-pattern the standard prohibits.

## Step 5 — Add pip-audit

```bash
uv add --dev pip-audit
uv run pip-audit
```

## Step 6 — Add editor + CI config

- [ ] `.editorconfig`
- [ ] `.vscode/extensions.json`, `settings.json`, `tasks.json`
- [ ] `.github/workflows/check.yml` (CI uses `uv sync --locked --all-groups`)

See [pyproject.md](./pyproject.md) for all four.

## Step 7 — Add agent instruction entry points

- [ ] `AGENTS.md` and `CLAUDE.md` — full instructions or a thin pointer to the project's canonical session-memory/handoff source. A fresh CLI or VS Code agent must be able to discover the verification gate, fix pass, and the dependency/typing/testing/security rules before editing. Copy from [templates/AGENTS.md](../templates/AGENTS.md), [templates/AGENTS.pointer.md](../templates/AGENTS.pointer.md), or [templates/CLAUDE.md](../templates/CLAUDE.md).

## Cleanup: remove legacy artifacts

Find old linter pragmas and missing packages:

```bash
rg "# pylint:|# noqa:|# type: ignore" --files-with-matches
uv run ruff check . --select INP001    # missing __init__.py
```

Remove these files after migration:

- [ ] `requirements.txt`, `requirements-dev.txt`
- [ ] `setup.py`, `setup.cfg`, `MANIFEST.in`
- [ ] `.flake8`, `mypy.ini`, `pyrightconfig.json`, any `ty` config
- [ ] `tox.ini`, `Pipfile`, `Pipfile.lock` (if not needed)
- [ ] Old virtual environments (`venv/`, `.venv/`)
- [ ] `.pre-commit-config.yaml` (the gate replaces pre-commit/prek)

Remove these `pyproject.toml` sections:

- [ ] `[tool.black]`, `[tool.isort]`, `[tool.mypy]`, `[tool.pyright]`, `[tool.ty]`, `[tool.pylint]`, `[tool.flake8]`

## .gitignore

```gitignore
__pycache__/
*.py[cod]
.venv/
.ruff_cache/
.pytest_cache/
.coverage
# uv.lock — commit for apps; ignore only for libraries
```

## Post-migration easy wins

```bash
uv run ruff check . --select UP --fix     # modernize typing/syntax
uv run ruff check . --select RET --fix    # return-value cleanups
uv run ruff check . --select SIM --fix    # simplifications
```

## Ratchet strictness

Once the project is stable: reduce ignores, improve type specificity, raise coverage _quality_ (not just the number), remove legacy tooling, and document any remaining exceptions as ADRs.

## Verification

After migration, the full gate must pass:

```bash
uv run ruff format --check .
uv run ruff check .
uv run basedpyright
uv run coverage run -m pytest
uv run coverage report
uv run pip-audit
```

See [security-setup.md](./security-setup.md) for the pip-audit baseline and Dependabot.

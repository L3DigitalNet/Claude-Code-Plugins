# Ruff Configuration Reference

Ruff is an extremely fast Rust-based Python linter and formatter. In this standard it owns **formatting, linting, and import sorting** — replacing flake8, black, isort, and pyupgrade. It is the single format/lint/import authority; do not add a second.

## Baseline config

Add to `pyproject.toml`:

```toml
[tool.ruff]
target-version = "py314"
line-length = 100
src = ["src", "tests"]
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
```

## Why a curated `select`, not `["ALL"]`

`select = ["ALL"]` opts into _every_ rule, including ones added in future Ruff releases — so an upgrade can introduce new diagnostics with no code change, producing churn and contradictory feedback for agents. This standard pins a **curated, boring** set instead. A project may add rules; it must not weaken the baseline without a documented exception.

| Code  | Category              | Why it's in the baseline                         |
| ----- | --------------------- | ------------------------------------------------ |
| `E`   | pycodestyle errors    | Core style correctness                           |
| `F`   | Pyflakes              | Logical errors (undefined names, unused imports) |
| `I`   | isort                 | Import sorting (Ruff owns it)                    |
| `B`   | flake8-bugbear        | Common bug patterns                              |
| `UP`  | pyupgrade             | Modernize syntax to the target version           |
| `SIM` | flake8-simplify       | Simplifications                                  |
| `C4`  | flake8-comprehensions | Comprehension improvements                       |
| `PIE` | flake8-pie            | Misc correctness improvements                    |
| `PTH` | flake8-use-pathlib    | Prefer `pathlib.Path`                            |
| `RET` | flake8-return         | Return-value issues                              |
| `RUF` | Ruff-specific         | Ruff's own rules                                 |

`E501` (line length) is ignored because the **formatter** owns wrapping. Don't fight formatter output.

## Running Ruff

```bash
# Lint
uv run ruff check .
uv run ruff check . --fix          # auto-fix

# Format
uv run ruff format .
uv run ruff format --check .       # check only (used in the gate)
uv run ruff format --diff .        # show diff
```

The **fix pass** (`uv run ruff format .` then `uv run ruff check . --fix`) is allowed to modify source — run it first when editing. The **gate** uses the `--check`/no-`--fix` forms, which never mutate.

## Per-File Ignores

Keep these local and documented — prefer fixing the code over ignoring the rule.

```toml
[tool.ruff.lint.per-file-ignores]
"tests/**/*.py" = ["S101"]          # assert usage (only relevant if S is later enabled)
"__init__.py" = ["F401"]            # re-exports
"**/migrations/*.py" = ["E", "F"]   # generated; scope the ignore, avoid blanket "ALL"
```

## Import Sorting (isort)

Configured under `[tool.ruff.lint.isort]` when you need to override defaults:

```toml
[tool.ruff.lint.isort]
known-first-party = ["myproject"]
```

The standard does **not** force `required-imports = ["from __future__ import annotations"]`; add it only if a project needs broad compatibility, and document it.

## Formatter Configuration

```toml
[tool.ruff.format]
quote-style = "double"
indent-style = "space"
docstring-code-format = true
```

Ruff's formatter is a drop-in Black replacement. Formatting disputes are resolved by Ruff.

## Type checking is NOT Ruff's job

Ruff does not type-check. The standard's type authority is **BasedPyright** (strict):

```bash
uv add --dev basedpyright
uv run basedpyright
```

Configure it in `[tool.basedpyright]` with `typeCheckingMode = "strict"` (see [pyproject.md](./pyproject.md)). Do not add mypy, pyright, ty, or Pylance as a second type authority.

## Code modernization

`UP` (pyupgrade) is in the baseline, so modernization runs as part of normal linting:

```bash
uv run ruff check . --select UP --fix   # apply just the upgrades
```

Common modernizations: `Optional[X]` → `X | None`, `List[X]` → `list[X]`, `super(Cls, self)` → `super()`.

## Migrating from other tools

- **From flake8**: remove flake8 + plugins + `.flake8`. Ruff covers most plugins.
- **From black**: remove black + `[tool.black]`; use `ruff format`.
- **From isort**: remove isort + `[tool.isort]`; use `[tool.ruff.lint.isort]`.

### Line-length migration

If a legacy project used 120-char lines, switching to 100 causes churn. For a quieter initial migration, match the existing width and tighten later:

```toml
line-length = 120  # match existing; move to 100 once the dust settles
```

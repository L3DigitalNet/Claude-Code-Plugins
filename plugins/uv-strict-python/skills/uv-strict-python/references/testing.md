# Testing with pytest + coverage

pytest is the default test framework; coverage.py enforces branch coverage. Tests are a **behavior contract for future agents**, not a coverage-number game — high coverage with weak assertions proves nothing.

## Setup

The dev group already includes `pytest`, `pytest-cov`, and `coverage[toml]` (see [pyproject.md](./pyproject.md)). For extras:

```bash
uv add --dev hypothesis pytest-asyncio
```

## pyproject.toml configuration

Use `[tool.pytest.ini_options]` (recognized back to pytest 6.0). Do **not** put `--cov` flags in `addopts` — coverage is driven separately so the gate stays explicit.

```toml
[tool.pytest.ini_options]
minversion = "9.0"
testpaths = ["tests"]
addopts = ["-ra", "--strict-markers", "--strict-config"]
# Optional additions beyond the standard baseline (stricter is allowed):
markers = [
    "slow: marks tests as slow",
    "integration: marks integration tests",
]
filterwarnings = ["error"]

[tool.coverage.run]
branch = true
source = ["src"]

[tool.coverage.report]
show_missing = true
skip_covered = true
fail_under = 85
```

Keep `--strict-markers` and `--strict-config`: a misplaced pytest table is a silent failure (pytest still runs with defaults).

## The gate's coverage form

```bash
uv run coverage run -m pytest    # coverage.py drives pytest
uv run coverage report           # enforces fail_under
```

`pytest-cov` stays available for ad-hoc local use (`uv run pytest --cov=src`), but the gate and CI use `coverage run -m pytest` so branch coverage and the threshold are applied consistently.

## Project structure

```text
myproject/
├── src/myproject/
│   ├── __init__.py
│   └── core.py
└── tests/
    ├── conftest.py        # shared fixtures
    ├── unit/
    └── integration/       # filesystem, network, DB, CLI, API boundaries
```

## Test naming

```python
def test_<unit>__<condition>__<expected_result>() -> None: ...
```

```python
def test_parse_config__missing_required_field__raises_validation_error() -> None: ...
```

Coverage expectations (matching the standard):

- Material behavior changes SHOULD cover the **happy path** plus the most relevant **invalid input**, **boundary case**, and **expected failure behavior**.
- Bug fixes MUST include a **regression test** that fails without the fix.
- Low-risk mechanical edits MAY rely on existing behavior tests when the final report identifies the coverage relied on.

## Running tests

```bash
uv run pytest                       # all tests
uv run pytest -v                    # verbose
uv run pytest tests/test_core.py    # one file
uv run pytest -k "parse"            # match pattern
uv run pytest -m "not slow"         # marked tests
uv run pytest -x                    # stop on first failure
uv run pytest --lf                  # last failed
```

## Coverage reports

```bash
uv run coverage run -m pytest
uv run coverage report              # terminal, enforces fail_under
uv run coverage html && open htmlcov/index.html
```

## Writing tests

### Basic + exceptions

```python
from myproject.core import add_numbers, divide


def test_add_numbers__two_positives__returns_sum() -> None:
    assert add_numbers(2, 3) == 5


def test_divide__zero_divisor__raises_zero_division() -> None:
    import pytest

    with pytest.raises(ZeroDivisionError, match="division by zero"):
        divide(1, 0)
```

### Fixtures

```python
# tests/conftest.py
import pytest
from myproject.db import Database


@pytest.fixture
def db() -> Database:
    database = Database(":memory:")
    database.init()
    yield database
    database.close()
```

### Parametrized

```python
import pytest


@pytest.mark.parametrize(("text", "expected"), [("hello", 5), ("", 0), ("test", 4)])
def test_length__various_strings__matches_len(text: str, expected: int) -> None:
    assert len(text) == expected
```

### Async + property-based

```python
import pytest
from hypothesis import given, strategies as st


@pytest.mark.asyncio
async def test_fetch__valid_url__returns_payload() -> None:
    result = await fetch_data()
    assert result is not None


@given(st.text())
def test_reverse__applied_twice__is_identity(s: str) -> None:
    assert reverse_string(reverse_string(s)) == s
```

## Agent rules

- New behavior requires tests; bug fixes require regression tests.
- Assert **behavior**, not implementation details.
- Do not weaken or delete tests to make the suite pass unless the intended behavior explicitly changed.
- Do not write tests that merely mirror the implementation.
- Prefer small unit tests for pure logic; add integration tests at filesystem/network/DB/CLI/API boundaries.

## CI and the gate

Tests run as part of the verification gate, identical in CLI, VS Code (`test` task), and CI:

```yaml
- name: Test with coverage
  run: uv run coverage run -m pytest
- name: Coverage report
  run: uv run coverage report
```

There is no Makefile and no pre-commit hook — the gate is the single entry point (see [pyproject.md](./pyproject.md) for `scripts/check.py`, `.vscode/tasks.json`, and `check.yml`).

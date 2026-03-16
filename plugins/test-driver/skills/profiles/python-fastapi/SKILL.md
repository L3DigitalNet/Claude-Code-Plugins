---
name: python-fastapi
description: >
  Stack profile for FastAPI and Starlette projects. Activated when test-driver detects fastapi
  or starlette in pyproject.toml dependencies. Defines applicable test categories, discovery
  conventions, execution commands, coverage tools, and key testing patterns for FastAPI APIs.
---

# Stack Profile: Python / FastAPI

## 1. Applicable Test Categories

- **Unit** — always applicable
- **Integration** — always applicable
- **E2E** — applicable (full request lifecycle tests)
- **Contract** — applicable (API schema validation)
- **Security** — applicable (auth, injection, input validation)
- **UI** — not applicable (API-only projects)

## 2. Test Discovery

- **Location:** `tests/` directory at project root
- **Naming:** files matching `test_*.py`
- **Categorization:** by directory or pytest markers

| Category | Directory | Marker |
|----------|-----------|--------|
| Unit | `tests/unit/` | `@pytest.mark.unit` |
| Integration | `tests/integration/` | `@pytest.mark.integration` |
| E2E | `tests/e2e/` | `@pytest.mark.e2e` |
| Contract | `tests/contract/` | `@pytest.mark.contract` |
| Security | `tests/security/` | `@pytest.mark.security` |

Projects may use directories, markers, or both. Check `pyproject.toml` for `[tool.pytest.ini_options]` marker definitions.

## 3. Test Execution

```bash
# All tests
pytest tests/

# By category (marker)
pytest -m unit
pytest -m integration
pytest -m e2e

# Single file
pytest tests/test_auth.py -v

# Single test
pytest tests/test_auth.py::test_login_success -v
```

## 4. Coverage Measurement

- **Tool:** coverage.py via pytest-cov
- **Command:** `pytest --cov=<package> --cov-report=term-missing --cov-branch`
- **Config:** `[tool.coverage.run]` section in `pyproject.toml`

Determine `<package>` from `pyproject.toml` source config or the project's main package directory (typically `src/<name>` or `app/`).

## 5. UI Testing

Not applicable. FastAPI projects are API-only. If the project has a frontend, it should be tested separately with its own profile.

## Key Testing Patterns

### TestClient (synchronous)

FastAPI's `TestClient` wraps httpx and runs the ASGI app synchronously. Suitable for most endpoint tests:

```python
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_read_root():
    response = client.get("/")
    assert response.status_code == 200
    assert response.json() == {"msg": "Hello World"}
```

### AsyncClient (asynchronous)

For testing async-specific behavior, use httpx `AsyncClient` with `ASGITransport`:

```python
import pytest
from httpx import ASGITransport, AsyncClient
from app.main import app

@pytest.mark.anyio
async def test_root_async():
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test"
    ) as ac:
        response = await ac.get("/")
    assert response.status_code == 200
```

Note: requires `pytest-anyio` or `pytest-asyncio` with `anyio` mode.

### Dependency Overrides

Override FastAPI dependencies for testing using `app.dependency_overrides`:

```python
from app.main import app, get_db

def get_test_db():
    return TestDatabase()

app.dependency_overrides[get_db] = get_test_db

def test_with_override(client):
    response = client.get("/items/")
    assert response.status_code == 200

# Clean up after tests
app.dependency_overrides.clear()
```

### Recommended conftest.py

```python
import pytest
from fastapi.testclient import TestClient
from app.main import app

@pytest.fixture
def client():
    """Provide a TestClient with clean dependency overrides."""
    app.dependency_overrides.clear()
    with TestClient(app) as c:
        yield c
    app.dependency_overrides.clear()
```

## Delegates To

- `python-dev:python-testing-patterns` for pytest fixtures, mocking, parametrize patterns
- If not installed, proceed using general pytest knowledge

## conventions, execution commands, coverage tools, and key testing patterns for FastAPI APIs.

# Stack Profile: Python / FastAPI

## 1. Applicable Test Categories

- **Unit** — always applicable
- **Integration** — always applicable
- **E2E** — applicable (full request lifecycle tests)
- **Contract** — applicable (API schema validation)
- **Security** — applicable (auth, injection, input validation)
- **UI** — applicable when the project renders HTML via Jinja2/HTMX; not applicable for pure JSON API projects

## 2. Test Discovery

- **Location:** `tests/` directory at project root
- **Naming:** files matching `test_*.py`
- **Categorization:** by directory or pytest markers

| Category    | Directory            | Marker                     |
| ----------- | -------------------- | -------------------------- |
| Unit        | `tests/unit/`        | `@pytest.mark.unit`        |
| Integration | `tests/integration/` | `@pytest.mark.integration` |
| E2E         | `tests/e2e/`         | `@pytest.mark.e2e`         |
| Contract    | `tests/contract/`    | `@pytest.mark.contract`    |
| Security    | `tests/security/`    | `@pytest.mark.security`    |

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

For pure JSON API projects, UI testing is not applicable.

For projects that render HTML (Jinja2 templates, HTMX partials), UI testing applies:

- **Tool:** Charlotte for browser automation, or `TestClient`/`AsyncClient` with HTML response assertions
- **What to test:** Template rendering with expected context variables, HTMX partial responses (request with `HX-Request: true` header returns fragment, not full page), form submissions, redirect chains after auth
- **Scope:** Focus on critical user flows (login → dashboard → data view). Template rendering bugs are best caught with response content assertions (`assert "Expected Text" in response.text`) rather than full browser automation when possible.

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

## Commonly Undertested Patterns

These FastAPI-specific patterns are frequently missed by gap analysis because they don't appear as obvious standalone functions. Flag them during source file enumeration (gap-analysis Step 4):

- **Custom middleware** (`BaseHTTPMiddleware` subclasses): path exemption logic, redirect behavior, header injection, error handling within `dispatch()`. Middleware bugs affect every request silently.
- **Lifespan events**: `@asynccontextmanager` lifespan handlers — startup initialization (scheduler, database connections), shutdown cleanup, resource disposal on error during startup.
- **Dependency injection in tests**: Verify that `app.dependency_overrides` properly replaces `Depends()` parameters and that overrides are cleaned up between tests. Leaked overrides corrupt subsequent tests.
- **Background tasks**: `BackgroundTasks` parameters in route handlers — verify tasks are queued with correct arguments and that task failures don't crash the response.
- **Exception handlers**: Custom `@app.exception_handler(...)` — verify the handler returns the expected status code and body for each exception type, and that unhandled exceptions don't leak stack traces.
- **Pydantic model validation**: Edge cases in request/response models — optional fields with `None`, type coercion (string-to-int), custom validators, nested model validation failures.
- **Server-rendered HTML (Jinja2/HTMX)**: Routes that return HTML templates — test both full-page renders and HTMX partial responses (check `HX-Request` header handling), verify template context variables are injected correctly.
- **Webhook endpoints**: External callback handlers — signature/token verification, idempotent processing, error payloads, unknown event types returning 200 (not 500).
- **Scheduled jobs** (APScheduler/cron): The job function itself should be tested in isolation with a real or test database session. Verify scheduling configuration (hour, interval) separately.
- **External API clients via `asyncio.to_thread`**: Functions wrapping synchronous SDK calls — test timeout behavior, retry logic, and error mapping from external API exceptions to domain-specific errors.
- **Module-level singletons**: Database engines, API clients, and settings initialized at import time — verify test fixtures properly isolate these to prevent state leakage between tests.

## Delegates To

- `python-dev:python-testing-patterns` for pytest fixtures, mocking, parametrize patterns
- If not installed, proceed using general pytest knowledge
